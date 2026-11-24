package app.breathnote.breathnote

import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.os.Process
import android.os.SystemClock
import kotlin.concurrent.thread
import kotlin.math.max

class PitchDetector(
    private val onReading: (Map<String, Any>) -> Unit,
    private val onError: (String, String) -> Unit,
) {
    private val engine = HarmonicaPitchEngine()
    private val sampleRate = engine.sampleRate
    private val frameSize = engine.frameSize
    private val hopSize = engine.hopSize

    @Volatile
    private var running = false

    @Volatile
    var sensitivity = 0.68

    private var recorder: AudioRecord? = null
    private var worker: Thread? = null

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

            engine.reset()
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
        engine.reset()
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
        engine.reset()
    }

    private fun captureLoop(audioRecord: AudioRecord) {
        val window = ShortArray(frameSize)
        val hop = ShortArray(hopSize)
        var filled = false
        try {
            while (running) {
                if (!filled) {
                    if (!readExact(audioRecord, window, frameSize)) break
                    filled = true
                } else {
                    if (!readExact(audioRecord, hop, hopSize)) break
                    System.arraycopy(window, hopSize, window, 0, frameSize - hopSize)
                    System.arraycopy(hop, 0, window, frameSize - hopSize, hopSize)
                }
                val result = engine.analyzeFrame(window, frameSize, sensitivity)
                val timestampMicros = SystemClock.elapsedRealtimeNanos() / 1_000
                onReading(result.toMap(timestampMicros))
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
                engine.reset()
            }
        }
    }

    private fun readExact(
        audioRecord: AudioRecord,
        destination: ShortArray,
        targetLength: Int,
    ): Boolean {
        var offset = 0
        while (running && offset < targetLength) {
            val count =
                audioRecord.read(
                    destination,
                    offset,
                    targetLength - offset,
                    AudioRecord.READ_BLOCKING,
                )
            if (count <= 0) {
                if (running) onError("audio_read_error", "The microphone stream stopped.")
                return false
            }
            offset += count
        }
        return running && offset == targetLength
    }
}
