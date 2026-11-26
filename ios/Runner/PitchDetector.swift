import AVFoundation
import Foundation

final class PitchDetector {
  private let onReading: ([String: Any]) -> Void
  private let onError: (String, String) -> Void
  private let stateLock = NSLock()
  private let analysisQueue = DispatchQueue(
    label: "app.breathnote.pitch-detector",
    qos: .userInteractive
  )

  private var audioEngine: AVAudioEngine?
  private var pitchEngine = HarmonicaPitchEngine()
  private var slidingWindow: [Float] = []
  private var _running = false
  private var _sensitivity: Double = 0.68

  var isRunning: Bool {
    stateLock.lock()
    defer { stateLock.unlock() }
    return _running
  }

  var sensitivity: Double {
    get {
      stateLock.lock()
      defer { stateLock.unlock() }
      return _sensitivity
    }
    set {
      stateLock.lock()
      _sensitivity = min(max(newValue, 0.0), 1.0)
      stateLock.unlock()
    }
  }

  init(
    onReading: @escaping ([String: Any]) -> Void,
    onError: @escaping (String, String) -> Void
  ) {
    self.onReading = onReading
    self.onError = onError
  }

  func start(initialSensitivity: Double) -> Bool {
    sensitivity = initialSensitivity
    if isRunning { return true }

    do {
      let session = AVAudioSession.sharedInstance()
      try session.setCategory(
        .playAndRecord,
        mode: .measurement,
        options: [.defaultToSpeaker, .mixWithOthers, .allowBluetooth]
      )
      try? session.setPreferredSampleRate(44_100)
      try? session.setPreferredIOBufferDuration(0.012)
      try session.setActive(true, options: [])

      let engine = AVAudioEngine()
      let inputNode = engine.inputNode
      let inputFormat = inputNode.outputFormat(forBus: 0)

      guard inputFormat.channelCount > 0, inputFormat.sampleRate >= 8_000 else {
        onError("audio_initialization_error", "The microphone could not be initialized.")
        return false
      }

      let hardwareRate = Int(inputFormat.sampleRate.rounded())
      let newPitchEngine = HarmonicaPitchEngine(
        sampleRate: hardwareRate,
        frameSize: 2_048,
        hopSize: 1_024
      )

      stateLock.lock()
      pitchEngine = newPitchEngine
      slidingWindow.removeAll(keepingCapacity: true)
      slidingWindow.reserveCapacity(4_096)
      audioEngine = engine
      _running = true
      stateLock.unlock()

      inputNode.removeTap(onBus: 0)
      inputNode.installTap(
        onBus: 0,
        bufferSize: 1_024,
        format: inputFormat
      ) { [weak self] buffer, _ in
        guard let self = self,
          let channelData = buffer.floatChannelData
        else { return }
        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else { return }

        let samples = Array(
          UnsafeBufferPointer(start: channelData[0], count: frameLength)
        )
        self.analysisQueue.async {
          self.processIncomingSamples(samples)
        }
      }

      engine.prepare()
      try engine.start()
      return true
    } catch {
      stop()
      onError(
        "audio_start_error",
        error.localizedDescription.isEmpty
          ? "The microphone could not be started."
          : error.localizedDescription
      )
      return false
    }
  }

  func stop() {
    stateLock.lock()
    let wasRunning = _running
    let engineToStop = audioEngine
    _running = false
    audioEngine = nil
    stateLock.unlock()

    if let engine = engineToStop {
      engine.inputNode.removeTap(onBus: 0)
      engine.stop()
    }

    if wasRunning {
      analysisQueue.async { [weak self] in
        guard let self = self else { return }
        self.stateLock.lock()
        self.slidingWindow.removeAll(keepingCapacity: false)
        self.pitchEngine.reset()
        self.stateLock.unlock()
      }
    }
  }

  private func processIncomingSamples(_ samples: [Float]) {
    stateLock.lock()
    guard _running else {
      stateLock.unlock()
      return
    }
    let currentSensitivity = _sensitivity
    let engine = pitchEngine
    stateLock.unlock()

    slidingWindow.append(contentsOf: samples)
    let frameSize = engine.frameSize
    let hopSize = engine.hopSize

    while slidingWindow.count >= frameSize {
      if !isRunning { break }
      let frame = Array(slidingWindow.prefix(frameSize))
      slidingWindow.removeFirst(hopSize)
      let result = engine.analyzeFloatFrame(
        samples: frame,
        count: frameSize,
        sensitivity: currentSensitivity
      )
      let timestampMicros = Int64(ProcessInfo.processInfo.systemUptime * 1_000_000.0)
      onReading(result.toMap(timestampMicros: timestampMicros))
    }
  }
}
