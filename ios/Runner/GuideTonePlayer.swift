import AVFoundation
import Foundation

enum BreathnoteAudioSession {
  static func hasMicrophonePermission() -> Bool {
    if #available(iOS 17.0, *) {
      return AVAudioApplication.shared.recordPermission == .granted
    }
    return AVAudioSession.sharedInstance().recordPermission == .granted
  }

  static func activateForPlayback(preserveMeasurementIfRecording: Bool) throws {
    let session = AVAudioSession.sharedInstance()
    if hasMicrophonePermission() {
      if preserveMeasurementIfRecording && session.category == .playAndRecord {
        try session.setActive(true, options: [])
        return
      }
      try session.setCategory(
        .playAndRecord,
        mode: .default,
        options: [.defaultToSpeaker, .mixWithOthers, .allowBluetooth]
      )
    } else {
      try session.setCategory(
        .playback,
        mode: .default,
        options: [.mixWithOthers]
      )
    }
    try session.setActive(true, options: [])
  }
}

final class GuideTonePlayer {
  private let sampleRate: Double = 44_100.0
  private let lock = NSLock()
  private var audioEngine: AVAudioEngine?
  private var playerNode: AVAudioPlayerNode?

  func play(
    frequencies: [Double],
    speed: Double,
    repeatSequence: Bool,
    beats: [Double]? = nil
  ) throws -> Int {
    stop()
    if frequencies.isEmpty { return 0 }

    let safeSpeed = min(max(speed, 0.5), 1.0)
    let gapDurationMs = Int(90.0 / safeSpeed)
    var slotDurationsMs: [Int] = []
    slotDurationsMs.reserveCapacity(frequencies.count)

    for index in frequencies.indices {
      let rawBeat = (beats != nil && index < beats!.count) ? beats![index] : 1.0
      let clampedBeat = min(max(rawBeat, 0.25), 4.0)
      let slotMs = max(160, Int((520.0 + 90.0) * clampedBeat / safeSpeed))
      slotDurationsMs.append(slotMs)
    }

    let sequenceDurationMs = slotDurationsMs.reduce(0, +)
    guard
      let format = AVAudioFormat(
        standardFormatWithSampleRate: sampleRate,
        channels: 1
      )
    else {
      throw NSError(
        domain: "app.breathnote.audio",
        code: -1,
        userInfo: [NSLocalizedDescriptionKey: "Unable to create PCM audio format."]
      )
    }

    var allSamples: [Float] = []
    allSamples.reserveCapacity(Int(Double(sequenceDurationMs) * sampleRate / 1_000.0) + 64)

    for index in frequencies.indices {
      let frequency = frequencies[index]
      let slotMs = slotDurationsMs[index]
      if frequency <= 0.0 {
        let silenceSamples = max(1, Int(Double(slotMs) * sampleRate / 1_000.0))
        allSamples.append(contentsOf: repeatElement(Float(0.0), count: silenceSamples))
      } else {
        let noteMs = max(80, slotMs - gapDurationMs)
        let tailGapMs = max(0, slotMs - noteMs)
        appendSineWave(to: &allSamples, frequency: frequency, durationMs: noteMs)
        if tailGapMs > 0 {
          let gapSamples = Int(Double(tailGapMs) * sampleRate / 1_000.0)
          if gapSamples > 0 {
            allSamples.append(contentsOf: repeatElement(Float(0.0), count: gapSamples))
          }
        }
      }
    }

    let frameCount = AVAudioFrameCount(max(1, allSamples.count))
    guard let pcmBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
      let channel = pcmBuffer.floatChannelData?[0]
    else {
      throw NSError(
        domain: "app.breathnote.audio",
        code: -2,
        userInfo: [NSLocalizedDescriptionKey: "Unable to allocate guide tone buffer."]
      )
    }
    pcmBuffer.frameLength = frameCount
    allSamples.withUnsafeBufferPointer { ptr in
      if let base = ptr.baseAddress {
        channel.update(from: base, count: allSamples.count)
      }
    }

    try BreathnoteAudioSession.activateForPlayback(preserveMeasurementIfRecording: false)

    let engine = AVAudioEngine()
    let node = AVAudioPlayerNode()
    engine.attach(node)
    engine.connect(node, to: engine.mainMixerNode, format: format)
    engine.prepare()
    try engine.start()

    lock.lock()
    audioEngine = engine
    playerNode = node
    lock.unlock()

    let options: AVAudioPlayerNodeBufferOptions = repeatSequence ? [.loops] : []
    node.scheduleBuffer(pcmBuffer, at: nil, options: options) { [weak self, weak engine] in
      if !repeatSequence {
        DispatchQueue.main.async {
          guard let self = self, let engine = engine else { return }
          self.lock.lock()
          let isSame = self.audioEngine === engine
          if isSame {
            self.playerNode?.stop()
            self.audioEngine?.stop()
            self.playerNode = nil
            self.audioEngine = nil
          }
          self.lock.unlock()
        }
      }
    }
    node.play()

    return sequenceDurationMs
  }

  func stop() {
    lock.lock()
    let activeNode = playerNode
    let activeEngine = audioEngine
    playerNode = nil
    audioEngine = nil
    lock.unlock()

    activeNode?.stop()
    activeEngine?.stop()
  }

  private func appendSineWave(
    to output: inout [Float],
    frequency: Double,
    durationMs: Int
  ) {
    let sampleCount = max(1, Int(Double(durationMs) * sampleRate / 1_000.0))
    let fadeSamples = max(1, min(sampleCount / 4, Int(sampleRate / 100.0)))
    let amplitude = 9_000.0 / 32_768.0
    let angularStep = 2.0 * Double.pi * frequency / sampleRate

    for index in 0..<sampleCount {
      let fade: Double
      if index < fadeSamples {
        fade = Double(index) / Double(fadeSamples)
      } else if index >= sampleCount - fadeSamples {
        fade = Double(sampleCount - index - 1) / Double(fadeSamples)
      } else {
        fade = 1.0
      }
      let clampedFade = min(max(fade, 0.0), 1.0)
      let value = sin(angularStep * Double(index)) * amplitude * clampedFade
      output.append(Float(value))
    }
  }
}

final class MetronomePlayer {
  private let sampleRate: Double = 44_100.0
  private let lock = NSLock()
  private let format: AVAudioFormat?
  private var accentBuffer: AVAudioPCMBuffer?
  private var normalBuffer: AVAudioPCMBuffer?
  private var audioEngine: AVAudioEngine?
  private var playerNode: AVAudioPlayerNode?
  private var released = false

  init() {
    let fmt = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)
    self.format = fmt
    if let fmt = fmt {
      self.accentBuffer = Self.buildClickBuffer(accent: true, format: fmt, sampleRate: sampleRate)
      self.normalBuffer = Self.buildClickBuffer(accent: false, format: fmt, sampleRate: sampleRate)
    }
  }

  func playClick(accent: Bool, pitchDetectorRunning: Bool) {
    lock.lock()
    if released {
      lock.unlock()
      return
    }
    guard let fmt = format,
      let buffer = accent ? accentBuffer : normalBuffer
    else {
      lock.unlock()
      return
    }

    do {
      try BreathnoteAudioSession.activateForPlayback(
        preserveMeasurementIfRecording: pitchDetectorRunning
      )
      if audioEngine == nil || !(audioEngine?.isRunning ?? false) {
        let engine = AVAudioEngine()
        let node = AVAudioPlayerNode()
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: fmt)
        engine.prepare()
        try engine.start()
        audioEngine = engine
        playerNode = node
      }
      if let node = playerNode {
        if !node.isPlaying {
          node.play()
        }
        node.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
      }
    } catch {
      // Ignore transient audio session interruptions during metronome clicks.
    }
    lock.unlock()
  }

  func release() {
    lock.lock()
    released = true
    let node = playerNode
    let engine = audioEngine
    playerNode = nil
    audioEngine = nil
    lock.unlock()

    node?.stop()
    engine?.stop()
  }

  private static func buildClickBuffer(
    accent: Bool,
    format: AVAudioFormat,
    sampleRate: Double
  ) -> AVAudioPCMBuffer? {
    let clickSampleCount = max(1, Int((sampleRate * 12.0) / 1_000.0))
    guard
      let buffer = AVAudioPCMBuffer(
        pcmFormat: format,
        frameCapacity: AVAudioFrameCount(clickSampleCount)
      ),
      let channel = buffer.floatChannelData?[0]
    else {
      return nil
    }
    buffer.frameLength = AVAudioFrameCount(clickSampleCount)
    for index in 0..<clickSampleCount {
      let decay = exp(-Double(index) / 110.0)
      let rawSample: Double
      if accent {
        let primary = sin(2.0 * Double.pi * 3_600.0 * Double(index) / sampleRate) * 0.68
        let attack = sin(2.0 * Double.pi * 5_400.0 * Double(index) / sampleRate) * 0.32
        rawSample = (primary + attack) * (11_000.0 / 32_768.0) * decay
      } else {
        rawSample =
          sin(2.0 * Double.pi * 3_350.0 * Double(index) / sampleRate)
          * (9_000.0 / 32_768.0) * decay
      }
      channel[index] = Float(min(max(rawSample, -1.0), 1.0))
    }
    return buffer
  }
}
