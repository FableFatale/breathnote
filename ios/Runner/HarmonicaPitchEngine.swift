import Foundation

/// Pure-Swift harmonica pitch detection engine calibrated for 10-hole Richter
/// diatonic harmonicas across all 12 standard keys (G3 ~196 Hz through F#7 ~2960 Hz).
///
/// Direct 1:1 acoustic port of Android's `HarmonicaPitchEngine.kt`.
final class HarmonicaPitchEngine {
  let sampleRate: Int
  let frameSize: Int
  let hopSize: Int

  private let noteNames = [
    "C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B",
  ]

  // Covers Low C3 (130.8 Hz) & standard G3 (196 Hz) up to F#7 (2960 Hz) with headroom,
  // while rejecting 50/60 Hz mains hum and low-frequency breath wind rumble.
  private let minimumFrequency = 120.0
  private let maximumFrequency = 3_200.0

  // 1st-order high-pass (~95 Hz cutoff) removes DC offset and close-mic wind plosives.
  private let highPassAlpha: Double

  private var recentFrequencies: [Double] = []
  private var pendingJumpFrequency: Double?

  struct PitchFrameResult {
    let detected: Bool
    let frequency: Double
    let note: String
    let octave: Int
    let cents: Double
    let confidence: Double
    let levelDb: Double

    func toMap(timestampMicros: Int64) -> [String: Any] {
      return [
        "detected": detected,
        "frequency": frequency,
        "note": note,
        "octave": octave,
        "cents": cents,
        "confidence": confidence,
        "levelDb": levelDb,
        "timestampMicros": timestampMicros,
      ]
    }
  }

  private struct PitchEstimate {
    let frequency: Double
    let confidence: Double
  }

  init(
    sampleRate: Int = 44_100,
    frameSize: Int = 2_048,
    hopSize: Int = 1_024
  ) {
    self.sampleRate = max(8_000, sampleRate)
    self.frameSize = frameSize
    self.hopSize = hopSize
    self.highPassAlpha =
      1.0 / (1.0 + (2.0 * Double.pi * 95.0) / Double(max(8_000, sampleRate)))
  }

  func reset() {
    recentFrequencies.removeAll(keepingCapacity: true)
    pendingJumpFrequency = nil
  }

  func analyzeFrame(
    samples: [Int16],
    count: Int,
    sensitivity: Double
  ) -> PitchFrameResult {
    let usableCount = min(count, samples.count)
    guard usableCount > 0 else { return silentResult(levelDb: -120.0) }

    var normalized = [Double](repeating: 0.0, count: usableCount)
    var mean = 0.0
    for index in 0..<usableCount {
      mean += Double(samples[index])
    }
    mean /= Double(usableCount)

    for index in 0..<usableCount {
      normalized[index] = (Double(samples[index]) - mean) / 32_768.0
    }
    return analyzeNormalized(normalized, count: usableCount, sensitivity: sensitivity)
  }

  func analyzeFloatFrame(
    samples: [Float],
    count: Int,
    sensitivity: Double
  ) -> PitchFrameResult {
    let usableCount = min(count, samples.count)
    guard usableCount > 0 else { return silentResult(levelDb: -120.0) }

    var normalized = [Double](repeating: 0.0, count: usableCount)
    var mean = 0.0
    for index in 0..<usableCount {
      mean += Double(samples[index])
    }
    mean /= Double(usableCount)

    for index in 0..<usableCount {
      normalized[index] = Double(samples[index]) - mean
    }
    return analyzeNormalized(normalized, count: usableCount, sensitivity: sensitivity)
  }

  private func analyzeNormalized(
    _ zeroMeanSamples: [Double],
    count: Int,
    sensitivity: Double
  ) -> PitchFrameResult {
    var filtered = [Double](repeating: 0.0, count: count)
    var prevX = 0.0
    var prevY = 0.0
    var sumSquares = 0.0

    for index in 0..<count {
      let x = zeroMeanSamples[index]
      let y = index == 0 ? x : highPassAlpha * (prevY + x - prevX)
      prevX = x
      prevY = y
      filtered[index] = y
      sumSquares += y * y
    }

    let rms = sqrt(sumSquares / Double(count))
    let levelDb = rms > 0.0 ? 20.0 * log10(rms) : -120.0
    let normalizedSensitivity = min(max(sensitivity, 0.0), 1.0)
    let thresholdDb = -38.0 - normalizedSensitivity * 34.0
    let confidenceThreshold = 0.80 - normalizedSensitivity * 0.30

    if levelDb < thresholdDb {
      return silentResult(levelDb: levelDb)
    }

    guard let estimate = yin(samples: filtered, count: count),
      estimate.confidence >= confidenceThreshold
    else {
      return silentResult(levelDb: levelDb)
    }

    let smoothed = smoothFrequency(estimate.frequency)
    let midi = Int((69.0 + 12.0 * log(smoothed / 440.0) / log(2.0)).rounded())
    let reference = 440.0 * pow(2.0, Double(midi - 69) / 12.0)
    let cents = 1200.0 * log(smoothed / reference) / log(2.0)
    let noteIndex = ((midi % 12) + 12) % 12
    let octave = midi / 12 - 1

    return PitchFrameResult(
      detected: true,
      frequency: smoothed,
      note: noteNames[noteIndex],
      octave: octave,
      cents: cents,
      confidence: estimate.confidence,
      levelDb: levelDb
    )
  }

  private func smoothFrequency(_ frequency: Double) -> Double {
    if !recentFrequencies.isEmpty {
      let currentMedian = medianOf(recentFrequencies)
      let jumpCents = abs(1200.0 * log(frequency / currentMedian) / log(2.0))
      if jumpCents > 80.0 {
        if let pending = pendingJumpFrequency,
          abs(1200.0 * log(frequency / pending) / log(2.0)) <= 50.0
        {
          // Two consecutive hops (~46 ms) confirm a deliberate note change.
          recentFrequencies.removeAll(keepingCapacity: true)
          recentFrequencies.append(pending)
          recentFrequencies.append(frequency)
          pendingJumpFrequency = nil
          return (pending + frequency) * 0.5
        }
        pendingJumpFrequency = frequency
        return currentMedian
      }
    }

    pendingJumpFrequency = nil
    recentFrequencies.append(frequency)
    while recentFrequencies.count > 3 {
      recentFrequencies.removeFirst()
    }
    return medianOf(recentFrequencies)
  }

  private func medianOf(_ values: [Double]) -> Double {
    let sorted = values.sorted()
    let mid = sorted.count / 2
    if sorted.count % 2 == 1 {
      return sorted[mid]
    }
    return (sorted[mid - 1] + sorted[mid]) * 0.5
  }

  private func silentResult(levelDb: Double) -> PitchFrameResult {
    reset()
    return PitchFrameResult(
      detected: false,
      frequency: 0.0,
      note: "",
      octave: 0,
      cents: 0.0,
      confidence: 0.0,
      levelDb: levelDb
    )
  }

  private func yin(samples: [Double], count: Int) -> PitchEstimate? {
    let minimumTau = max(2, Int(Double(sampleRate) / maximumFrequency))
    let maximumTau = min(count / 2, Int(Double(sampleRate) / minimumFrequency))
    if maximumTau <= minimumTau + 2 { return nil }

    var difference = [Double](repeating: 0.0, count: maximumTau + 1)
    let comparisonLength = count - maximumTau
    for tau in 1...maximumTau {
      var total = 0.0
      for index in 0..<comparisonLength {
        let delta = samples[index] - samples[index + tau]
        total += delta * delta
      }
      difference[tau] = total
    }

    var normalized = [Double](repeating: 0.0, count: maximumTau + 1)
    normalized[0] = 1.0
    var runningTotal = 0.0
    for tau in 1...maximumTau {
      runningTotal += difference[tau]
      normalized[tau] =
        runningTotal == 0.0 ? 1.0 : difference[tau] * Double(tau) / runningTotal
    }

    var selectedTau = -1
    var tau = minimumTau
    while tau < maximumTau {
      if normalized[tau] < 0.20 {
        while tau + 1 < maximumTau && normalized[tau + 1] < normalized[tau] {
          tau += 1
        }
        selectedTau = tau
        break
      }
      tau += 1
    }

    if selectedTau == -1 {
      var minVal = Double.greatestFiniteMagnitude
      for candidate in minimumTau...maximumTau where normalized[candidate] < minVal {
        minVal = normalized[candidate]
        selectedTau = candidate
      }
      if selectedTau == -1 { return nil }
    }

    // Disambiguate true YIN subharmonic octave locks while preserving low reeds (G3/A3/C4).
    for divisor in [4, 2] {
      let candidateCenter = selectedTau / divisor
      if candidateCenter >= minimumTau + 1 {
        let searchRadius = min(3, max(1, candidateCenter / 12))
        let searchStart = max(minimumTau, candidateCenter - searchRadius)
        let searchEnd = min(maximumTau, candidateCenter + searchRadius)
        if searchStart <= searchEnd {
          var bestSubTau = searchStart
          for candidate in searchStart...searchEnd
          where normalized[candidate] < normalized[bestSubTau] {
            bestSubTau = candidate
          }
          if normalized[bestSubTau] < 0.16
            && normalized[bestSubTau] <= normalized[selectedTau] + 0.04
          {
            selectedTau = bestSubTau
            break
          }
        }
      }
    }

    let confidence = min(max(1.0 - normalized[selectedTau], 0.0), 1.0)
    let refinedTau: Double
    if selectedTau > minimumTau && selectedTau < maximumTau {
      let left = normalized[selectedTau - 1]
      let center = normalized[selectedTau]
      let right = normalized[selectedTau + 1]
      let denominator = left - 2.0 * center + right
      if abs(denominator) > 1e-9 {
        let offset = min(max(0.5 * (left - right) / denominator, -0.5), 0.5)
        refinedTau = Double(selectedTau) + offset
      } else {
        refinedTau = Double(selectedTau)
      }
    } else {
      refinedTau = Double(selectedTau)
    }

    let frequency = Double(sampleRate) / refinedTau
    guard frequency >= minimumFrequency && frequency <= maximumFrequency else {
      return nil
    }
    return PitchEstimate(frequency: frequency, confidence: confidence)
  }
}
