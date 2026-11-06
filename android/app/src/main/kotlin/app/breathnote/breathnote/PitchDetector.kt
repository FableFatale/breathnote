package app.breathnote.breathnote

import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.os.Process
import android.os.SystemClock
import kotlin.concurrent.thread
import kotlin.math.abs
import kotlin.math.ln
import kotlin.math.log10
import kotlin.math.max
import kotlin.math.min
import kotlin.math.pow
import kotlin.math.roundToInt
import kotlin.math.sqrt

class PitchDetector(
    private val onReading: (Map<String, Any>) -> Unit,
    private val onError: (String, String) -> Unit,
) {
    private val sampleRate = 44_100
    private val frameSize = 2_048
    private val noteNames =
        arrayOf("C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B")

    @Volatile
    private var running = false

    @Volatile
    var sensitivity = 0.68

    private var recorder: AudioRecord? = null
    private var worker: Thread? = null
    private val recentFrequencies = ArrayDeque<Double>()

    fun start(initialSensitivity: Double): Boolean {
        sensitivity = initialSensitivity.coerceIn(0.0, 1.0)
        if (running) return true

        return try {
            val minimumBuffer =
                AudioRecord.getMinBufferSize(
                    sampleRate,
                    AudioFormat.CHANNEL_IN_MONO,
                    AudioFormat.ENCODING_PCM_16BIT,
                )
            if (minimumBuffer <= 0) {
                onError("audio_buffer_error", "The microphone buffer could not be created.")
                return false
            }

            val bufferSize = max(minimumBuffer * 2, frameSize * 4)
            val audioRecord =
                buildRecorder(MediaRecorder.AudioSource.UNPROCESSED, bufferSize)
                    ?: buildRecorder(MediaRecorder.AudioSource.MIC, bufferSize)

            if (audioRecord == null) {
                onError("audio_initialization_error", "The microphone could not be initialized.")
                return false
            }

            recorder = audioRecord
            running = true
            audioRecord.startRecording()
            worker =
                thread(name = "breathnote-pitch-detector", priority = Thread.MAX_PRIORITY) {
                    Process.setThreadPriority(Process.THREAD_PRIORITY_AUDIO)
                    captureLoop(audioRecord)
                }
            true
        } catch (error: SecurityException) {
            running = false
            releaseRecorderAfterStartFailure()
            onError("microphone_permission_required", "Microphone permission is required.")
            false
        } catch (error: Exception) {
            running = false
            releaseRecorderAfterStartFailure()
            onError(
                "audio_start_error",
                error.message ?: "The microphone could not be started.",
            )
            false
        }
    }

    private fun releaseRecorderAfterStartFailure() {
        val failedRecorder = recorder
        recorder = null
        try {
            failedRecorder?.release()
        } catch (_: IllegalStateException) {
            // A partially initialized recorder may reject release.
        }
        worker = null
        recentFrequencies.clear()
    }

    private fun buildRecorder(
        source: Int,
        bufferSize: Int,
    ): AudioRecord? {
        return try {
            val candidate =
                AudioRecord.Builder()
                    .setAudioSource(source)
                    .setAudioFormat(
                        AudioFormat.Builder()
                            .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                            .setSampleRate(sampleRate)
                            .setChannelMask(AudioFormat.CHANNEL_IN_MONO)
                            .build(),
                    )
                    .setBufferSizeInBytes(bufferSize)
                    .build()
            if (candidate.state == AudioRecord.STATE_INITIALIZED) {
                candidate
            } else {
                candidate.release()
                null
            }
        } catch (_: Exception) {
            null
        }
    }

    fun stop() {
        if (!running && recorder == null) return
        running = false
        val activeRecorder = recorder
        recorder = null
        try {
            activeRecorder?.stop()
        } catch (_: IllegalStateException) {
            // The recorder may already have stopped during an activity transition.
        }
        activeRecorder?.release()
        worker?.interrupt()
        worker = null
        recentFrequencies.clear()
    }

    private fun captureLoop(audioRecord: AudioRecord) {
        val frame = ShortArray(frameSize)
        try {
            while (running) {
                val count =
                    audioRecord.read(
                        frame,
                        0,
                        frame.size,
                        AudioRecord.READ_BLOCKING,
                    )
                if (count <= 0) {
                    if (running) onError("audio_read_error", "The microphone stream stopped.")
                    break
                }
                analyze(frame, count)
            }
        } finally {
            if (recorder === audioRecord) {
                running = false
                recorder = null
                try {
                    audioRecord.stop()
                } catch (_: IllegalStateException) {
                    // A read error may already have stopped the recorder.
                }
                audioRecord.release()
                worker = null
                recentFrequencies.clear()
            }
        }
    }

    private fun analyze(samples: ShortArray, count: Int) {
        var sumSquares = 0.0
        for (index in 0 until count) {
            val normalized = samples[index] / 32768.0
            sumSquares += normalized * normalized
        }
        val rms = sqrt(sumSquares / count)
        val levelDb = if (rms > 0) 20 * log10(rms) else -120.0
        val normalizedSensitivity = sensitivity.coerceIn(0.0, 1.0)
        val thresholdDb = -38.0 - normalizedSensitivity * 34.0
        val confidenceThreshold = 0.80 - normalizedSensitivity * 0.30

        if (levelDb < thresholdDb) {
            onReading(silentReading(levelDb))
            return
        }

        val estimate = yin(samples, count)
        if (estimate == null || estimate.confidence < confidenceThreshold) {
            onReading(silentReading(levelDb))
            return
        }

        recentFrequencies.addLast(estimate.frequency)
        while (recentFrequencies.size > 5) recentFrequencies.removeFirst()
        val smoothed = recentFrequencies.sorted()[recentFrequencies.size / 2]

        val midi = (69 + 12 * ln(smoothed / 440.0) / ln(2.0)).roundToInt()
        val reference = 440.0 * 2.0.pow((midi - 69) / 12.0)
        val cents = 1200 * ln(smoothed / reference) / ln(2.0)
        val noteIndex = ((midi % 12) + 12) % 12
        val octave = midi / 12 - 1

        onReading(
            mapOf(
                "detected" to true,
                "frequency" to smoothed,
                "note" to noteNames[noteIndex],
                "octave" to octave,
                "cents" to cents,
                "confidence" to estimate.confidence,
                "levelDb" to levelDb,
                "timestampMicros" to SystemClock.elapsedRealtimeNanos() / 1_000,
            ),
        )
    }

    private fun silentReading(levelDb: Double): Map<String, Any> {
        recentFrequencies.clear()
        return mapOf(
            "detected" to false,
            "frequency" to 0.0,
            "note" to "",
            "octave" to 0,
            "cents" to 0.0,
            "confidence" to 0.0,
            "levelDb" to levelDb,
            "timestampMicros" to SystemClock.elapsedRealtimeNanos() / 1_000,
        )
    }

    private fun yin(samples: ShortArray, count: Int): PitchEstimate? {
        val minimumFrequency = 65.0
        val maximumFrequency = 2_100.0
        val minimumTau = max(2, (sampleRate / maximumFrequency).toInt())
        val maximumTau = min(count / 2, (sampleRate / minimumFrequency).toInt())
        if (maximumTau <= minimumTau + 2) return null

        val difference = DoubleArray(maximumTau + 1)
        val comparisonLength = count - maximumTau
        for (tau in 1..maximumTau) {
            var total = 0.0
            for (index in 0 until comparisonLength) {
                val delta = samples[index].toDouble() - samples[index + tau].toDouble()
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
            if (normalized[tau] < 0.16) {
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

        val confidence = (1.0 - normalized[selectedTau]).coerceIn(0.0, 1.0)
        val refinedTau =
            if (selectedTau > 1 && selectedTau < maximumTau) {
                val left = normalized[selectedTau - 1]
                val center = normalized[selectedTau]
                val right = normalized[selectedTau + 1]
                val denominator = left - 2 * center + right
                if (abs(denominator) > 1e-9) {
                    selectedTau + 0.5 * (left - right) / denominator
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

    private data class PitchEstimate(
        val frequency: Double,
        val confidence: Double,
    )
}
