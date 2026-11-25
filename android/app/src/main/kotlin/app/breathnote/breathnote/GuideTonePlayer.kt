package app.breathnote.breathnote

import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioTrack
import kotlin.concurrent.thread
import kotlin.math.PI
import kotlin.math.exp
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
        beats: List<Double>? = null,
    ): Int {
        stop()
        if (frequencies.isEmpty()) return 0

        val safeSpeed = speed.coerceIn(0.5, 1.0)
        val gapDurationMs = (90 / safeSpeed).toInt()
        val slotDurationsMs = List(frequencies.size) { index ->
            val rawBeat = if (beats != null && index < beats.size) beats[index] else 1.0
            val b = rawBeat.coerceIn(0.25, 4.0)
            ((520 + 90) * b / safeSpeed).toInt().coerceAtLeast(160)
        }
        val sequenceDurationMs = slotDurationsMs.sum()
        val track = createTrack()
        running = true
        audioTrack = track
        worker =
            thread(name = "breathnote-guide-tone") {
                try {
                    if (running) track.play()
                    while (running) {
                        for (index in frequencies.indices) {
                            if (!running) break
                            val frequency = frequencies[index]
                            val slotMs = slotDurationsMs[index]
                            if (frequency <= 0.0) {
                                val silenceSamples = slotMs * sampleRate / 1_000
                                track.write(
                                    ShortArray(silenceSamples),
                                    0,
                                    silenceSamples,
                                    AudioTrack.WRITE_BLOCKING,
                                )
                            } else {
                                val noteMs = maxOf(80, slotMs - gapDurationMs)
                                val tailGapMs = maxOf(0, slotMs - noteMs)
                                val noteSamples = noteMs * sampleRate / 1_000
                                track.write(
                                    sineWave(frequency, noteMs),
                                    0,
                                    noteSamples,
                                    AudioTrack.WRITE_BLOCKING,
                                )
                                if (running && tailGapMs > 0) {
                                    val gapSamples = tailGapMs * sampleRate / 1_000
                                    track.write(
                                        ShortArray(gapSamples),
                                        0,
                                        gapSamples,
                                        AudioTrack.WRITE_BLOCKING,
                                    )
                                }
                            }
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

class MetronomePlayer {
    private val sampleRate = 44_100
    private val clickSampleCount = (sampleRate * 12) / 1_000
    private val accentClick = buildClick(accent = true)
    private val normalClick = buildClick(accent = false)

    @Volatile
    private var released = false
    private val lock = Any()
    private var activeTrack: AudioTrack? = null
    private val executor =
        java.util.concurrent.Executors.newSingleThreadExecutor { runnable ->
            Thread(runnable, "breathnote-metronome").apply { isDaemon = true }
        }

    fun playClick(accent: Boolean) {
        if (released) return
        val pcm = if (accent) accentClick else normalClick
        try {
            executor.execute {
                if (released) return@execute
                var track: AudioTrack? = null
                try {
                    track = AudioTrack.Builder()
                        .setAudioAttributes(
                            AudioAttributes.Builder()
                                .setUsage(AudioAttributes.USAGE_MEDIA)
                                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                                .build(),
                        )
                        .setAudioFormat(
                            AudioFormat.Builder()
                                .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                                .setSampleRate(sampleRate)
                                .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                                .build(),
                        )
                        .setBufferSizeInBytes(pcm.size * 2)
                        .setTransferMode(AudioTrack.MODE_STATIC)
                        .build()
                    synchronized(lock) {
                        if (released) {
                            track.release()
                            return@execute
                        }
                        activeTrack = track
                    }
                    track.write(pcm, 0, pcm.size)
                    track.play()
                    Thread.sleep(24)
                } catch (_: InterruptedException) {
                    // Interrupted during release.
                } catch (_: Exception) {
                    // Ignore transient audio focus or hardware AudioTrack errors.
                } finally {
                    val toRelease = synchronized(lock) {
                        if (activeTrack === track) activeTrack = null
                        track
                    }
                    try {
                        toRelease?.stop()
                    } catch (_: IllegalStateException) {}
                    try {
                        toRelease?.release()
                    } catch (_: Exception) {}
                }
            }
        } catch (_: java.util.concurrent.RejectedExecutionException) {
            // Executor already shut down.
        }
    }

    fun release() {
        released = true
        val track = synchronized(lock) {
            val current = activeTrack
            activeTrack = null
            current
        }
        try {
            track?.pause()
            track?.flush()
            track?.stop()
        } catch (_: IllegalStateException) {}
        try {
            track?.release()
        } catch (_: Exception) {}
        executor.shutdownNow()
    }

    private fun buildClick(accent: Boolean): ShortArray {
        return ShortArray(clickSampleCount) { index ->
            val decay = exp(-index / 110.0)
            val sample = if (accent) {
                val primary = sin(2 * PI * 3_600.0 * index / sampleRate) * 0.68
                val attack = sin(2 * PI * 5_400.0 * index / sampleRate) * 0.32
                (primary + attack) * 11_000.0 * decay
            } else {
                sin(2 * PI * 3_350.0 * index / sampleRate) * 9_000.0 * decay
            }
            sample.toInt().coerceIn(-32_767, 32_767).toShort()
        }
    }
}
