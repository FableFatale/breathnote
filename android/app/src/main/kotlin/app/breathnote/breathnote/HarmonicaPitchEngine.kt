package app.breathnote.breathnote

import kotlin.math.abs
import kotlin.math.ln
import kotlin.math.log10
import kotlin.math.max
import kotlin.math.min
import kotlin.math.pow
import kotlin.math.roundToInt
import kotlin.math.sqrt

/**
 * Pure-Kotlin harmonica pitch detection engine calibrated for 10-hole Richter
 * diatonic harmonicas across all 12 standard keys (G3 ~196 Hz through F#7 ~2960 Hz).
 *
 * Kept independent of Android framework APIs so acoustic regression tests can
 * verify synthetic multi-key reed spectra directly on the JVM.
 */
class HarmonicaPitchEngine(
    val sampleRate: Int = 44_100,
    val frameSize: Int = 2_048,
    val hopSize: Int = 1_024,
) {
    private val noteNames =
        arrayOf("C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B")

    // Covers Low C3 (130.8 Hz) & standard G3 (196 Hz) up to F#7 (2960 Hz) with headroom,
    // while rejecting 50/60 Hz mains hum and low-frequency breath wind rumble.
    private val minimumFrequency = 120.0
    private val maximumFrequency = 3_200.0

    // 1st-order high-pass (~95 Hz cutoff at 44.1 kHz) removes DC offset and close-mic wind plosives.
    private val highPassAlpha = 0.9866

    private val recentFrequencies = ArrayDeque<Double>()
    private var pendingJumpFrequency: Double? = null

    data class PitchFrameResult(
        val detected: Boolean,
        val frequency: Double,
        val note: String,
        val octave: Int,
        val cents: Double,
        val confidence: Double,
        val levelDb: Double,
    ) {
        fun toMap(timestampMicros: Long): Map<String, Any> =
            mapOf(
                "detected" to detected,
                "frequency" to frequency,
                "note" to note,
                "octave" to octave,
                "cents" to cents,
                "confidence" to confidence,
                "levelDb" to levelDb,
                "timestampMicros" to timestampMicros,
            )
    }

    private data class PitchEstimate(
        val frequency: Double,
        val confidence: Double,
    )

    fun reset() {
        recentFrequencies.clear()
        pendingJumpFrequency = null
    }

    fun analyzeFrame(
        samples: ShortArray,
        count: Int,
        sensitivity: Double,
    ): PitchFrameResult {
        if (count <= 0) return silentResult(-120.0)

        // Remove DC mean first, then apply ~95 Hz high-pass filter to attenuate breath wind rumble.
        var mean = 0.0
        for (index in 0 until count) {
            mean += samples[index].toDouble()
        }
        mean /= count

        val filtered = DoubleArray(count)
        var prevX = 0.0
        var prevY = 0.0
        var sumSquares = 0.0
        for (index in 0 until count) {
            val x = (samples[index].toDouble() - mean) / 32768.0
            val y =
                if (index == 0) {
                    x
                } else {
                    highPassAlpha * (prevY + x - prevX)
                }
            prevX = x
            prevY = y
            filtered[index] = y
            sumSquares += y * y
        }

        val rms = sqrt(sumSquares / count)
        val levelDb = if (rms > 0.0) 20.0 * log10(rms) else -120.0
        val normalizedSensitivity = sensitivity.coerceIn(0.0, 1.0)
        val thresholdDb = -38.0 - normalizedSensitivity * 34.0
        val confidenceThreshold = 0.80 - normalizedSensitivity * 0.30

        if (levelDb < thresholdDb) {
            return silentResult(levelDb)
        }

        val estimate = yin(filtered, count)
        if (estimate == null || estimate.confidence < confidenceThreshold) {
            return silentResult(levelDb)
        }

        val smoothed = smoothFrequency(estimate.frequency)
        val midi = (69 + 12 * ln(smoothed / 440.0) / ln(2.0)).roundToInt()
        val reference = 440.0 * 2.0.pow((midi - 69) / 12.0)
        val cents = 1200.0 * ln(smoothed / reference) / ln(2.0)
        val noteIndex = ((midi % 12) + 12) % 12
        val octave = midi / 12 - 1

        return PitchFrameResult(
            detected = true,
            frequency = smoothed,
            note = noteNames[noteIndex],
            octave = octave,
            cents = cents,
            confidence = estimate.confidence,
            levelDb = levelDb,
        )
    }

    private fun smoothFrequency(frequency: Double): Double {
        if (recentFrequencies.isNotEmpty()) {
            val currentMedian = medianOf(recentFrequencies)
            val jumpCents = abs(1200.0 * ln(frequency / currentMedian) / ln(2.0))
            if (jumpCents > 80.0) {
                val pending = pendingJumpFrequency
                if (pending != null &&
                    abs(1200.0 * ln(frequency / pending) / ln(2.0)) <= 50.0
                ) {
                    // Two consecutive hops (~46 ms) confirm a deliberate note change.
                    recentFrequencies.clear()
                    recentFrequencies.addLast(pending)
                    recentFrequencies.addLast(frequency)
                    pendingJumpFrequency = null
                    return (pending + frequency) * 0.5
                }
                pendingJumpFrequency = frequency
                return currentMedian
            }
        }

        pendingJumpFrequency = null
        recentFrequencies.addLast(frequency)
        while (recentFrequencies.size > 3) {
            recentFrequencies.removeFirst()
        }
        return medianOf(recentFrequencies)
    }

    private fun medianOf(values: ArrayDeque<Double>): Double {
        val sorted = values.sorted()
        val mid = sorted.size / 2
        return if (sorted.size % 2 == 1) {
            sorted[mid]
        } else {
            (sorted[mid - 1] + sorted[mid]) * 0.5
        }
    }

    private fun silentResult(levelDb: Double): PitchFrameResult {
        reset()
        return PitchFrameResult(
            detected = false,
            frequency = 0.0,
            note = "",
            octave = 0,
            cents = 0.0,
            confidence = 0.0,
            levelDb = levelDb,
        )
    }

    private fun yin(samples: DoubleArray, count: Int): PitchEstimate? {
        val minimumTau = max(2, (sampleRate / maximumFrequency).toInt())
        val maximumTau = min(count / 2, (sampleRate / minimumFrequency).toInt())
        if (maximumTau <= minimumTau + 2) return null

        val difference = DoubleArray(maximumTau + 1)
        val comparisonLength = count - maximumTau
        for (tau in 1..maximumTau) {
            var total = 0.0
            for (index in 0 until comparisonLength) {
                val delta = samples[index] - samples[index + tau]
                total += delta * delta
            }
            difference[tau] = total
        }

        val normalized = DoubleArray(maximumTau + 1)
        normalized[0] = 1.0
        var runningTotal = 0.0
        for (tau in 1..maximumTau) {
            runningTotal += difference[tau]
            normalized[tau] =
                if (runningTotal == 0.0) 1.0 else difference[tau] * tau / runningTotal
        }

        var selectedTau = -1
        var tau = minimumTau
        while (tau < maximumTau) {
            if (normalized[tau] < 0.20) {
                while (tau + 1 < maximumTau && normalized[tau + 1] < normalized[tau]) {
                    tau++
                }
                selectedTau = tau
                break
            }
            tau++
        }
        if (selectedTau == -1) {
            selectedTau =
                (minimumTau..maximumTau).minByOrNull { normalized[it] } ?: return null
        }

        // Disambiguate true YIN subharmonic octave locks while preserving low reeds (G3/A3/C4)
        // whose 2nd harmonic can be strong on smartphone MEMS microphones.
        for (divisor in intArrayOf(4, 2)) {
            val candidateCenter = selectedTau / divisor
            if (candidateCenter >= minimumTau + 1) {
                val searchRadius = min(3, max(1, candidateCenter / 12))
                val searchStart = max(minimumTau, candidateCenter - searchRadius)
                val searchEnd = min(maximumTau, candidateCenter + searchRadius)
                val bestSubTau = (searchStart..searchEnd).minByOrNull { normalized[it] } ?: continue
                if (normalized[bestSubTau] < 0.16 &&
                    normalized[bestSubTau] <= normalized[selectedTau] + 0.04
                ) {
                    selectedTau = bestSubTau
                    break
                }
            }
        }

        val confidence = (1.0 - normalized[selectedTau]).coerceIn(0.0, 1.0)
        val refinedTau =
            if (selectedTau > minimumTau && selectedTau < maximumTau) {
                val left = normalized[selectedTau - 1]
                val center = normalized[selectedTau]
                val right = normalized[selectedTau + 1]
                val denominator = left - 2.0 * center + right
                if (abs(denominator) > 1e-9) {
                    val offset = (0.5 * (left - right) / denominator).coerceIn(-0.5, 0.5)
                    selectedTau + offset
                } else {
                    selectedTau.toDouble()
                }
            } else {
                selectedTau.toDouble()
            }

        val frequency = sampleRate / refinedTau
        if (frequency !in minimumFrequency..maximumFrequency) return null
        return PitchEstimate(frequency, confidence)
    }
}
