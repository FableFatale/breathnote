package app.breathnote.breathnote

import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioTrack
import kotlin.concurrent.thread
import kotlin.math.PI
import kotlin.math.sin

class GuideTonePlayer {
    private val sampleRate = 44_100

    @Volatile
    private var running = false

    private var audioTrack: AudioTrack? = null
    private var worker: Thread? = null

    fun play(
        frequencies: List<Double>,
        speed: Double,
        repeat: Boolean,
    ): Int {
        stop()
        if (frequencies.isEmpty()) return 0

        val safeSpeed = speed.coerceIn(0.5, 1.0)
        val noteDurationMs = (520 / safeSpeed).toInt()
        val gapDurationMs = (90 / safeSpeed).toInt()
        val sequenceDurationMs = frequencies.size * (noteDurationMs + gapDurationMs)
        val track = createTrack()
        running = true
        audioTrack = track
        worker =
            thread(name = "breathnote-guide-tone") {
                try {
                    if (running) track.play()
                    while (running) {
                        for (frequency in frequencies) {
                            if (!running) break
                            track.write(
                                sineWave(frequency, noteDurationMs),
                                0,
                                noteDurationMs * sampleRate / 1_000,
                                AudioTrack.WRITE_BLOCKING,
                            )
                            if (!running) break
                            track.write(
                                ShortArray(gapDurationMs * sampleRate / 1_000),
                                0,
                                gapDurationMs * sampleRate / 1_000,
                                AudioTrack.WRITE_BLOCKING,
                            )
                        }
                        if (!repeat) break
                    }
                } finally {
                    running = false
                    try {
                        track.stop()
                    } catch (_: IllegalStateException) {
                        // The track may already be stopped during an activity transition.
                    }
                    track.release()
                    if (audioTrack === track) audioTrack = null
                }
            }
        return sequenceDurationMs
    }

    fun stop() {
        running = false
        val activeTrack = audioTrack
        audioTrack = null
        try {
            activeTrack?.pause()
            activeTrack?.flush()
        } catch (_: IllegalStateException) {
            // Start, stop, and activity lifecycle callbacks can race.
        }
        worker?.interrupt()
        worker = null
    }

    private fun createTrack(): AudioTrack {
        val minimumBuffer =
            AudioTrack.getMinBufferSize(
                sampleRate,
                AudioFormat.CHANNEL_OUT_MONO,
                AudioFormat.ENCODING_PCM_16BIT,
            )
        return AudioTrack.Builder()
            .setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_MEDIA)
                    .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                    .build(),
            )
            .setAudioFormat(
                AudioFormat.Builder()
                    .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                    .setSampleRate(sampleRate)
                    .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                    .build(),
            )
            .setBufferSizeInBytes(maxOf(minimumBuffer, sampleRate))
            .setTransferMode(AudioTrack.MODE_STREAM)
            .build()
    }

    private fun sineWave(
        frequency: Double,
        durationMs: Int,
    ): ShortArray {
        val sampleCount = durationMs * sampleRate / 1_000
        val fadeSamples = minOf(sampleCount / 4, sampleRate / 100)
        return ShortArray(sampleCount) { index ->
            val fade =
                when {
                    index < fadeSamples -> index.toDouble() / fadeSamples
                    index >= sampleCount - fadeSamples ->
                        (sampleCount - index - 1).toDouble() / fadeSamples
                    else -> 1.0
                }.coerceIn(0.0, 1.0)
            (sin(2 * PI * frequency * index / sampleRate) * 9_000 * fade).toInt().toShort()
        }
    }
}
