package app.breathnote.breathnote

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.ln
import kotlin.math.pow
import kotlin.math.sin

class HarmonicaPitchEngineTest {
    private val sampleRate = 44_100

    private fun midiToHz(midi: Int): Double = 440.0 * 2.0.pow((midi - 69) / 12.0)

    /**
     * Synthesizes a harmonica brass free-reed tone with realistic harmonic overtones,
     * optional DC offset, and optional low-frequency breath wind rumble.
     */
    private fun synthReedFrame(
        fundamentalHz: Double,
        frameSize: Int = 2_048,
        harmonics: DoubleArray = doubleArrayOf(1.0, 0.65, 0.35, 0.18),
        amplitude: Double = 0.25,
        dcOffset: Double = 0.0,
        windRumbleHz: Double = 0.0,
        windAmplitude: Double = 0.0,
        phaseOffset: Double = 0.0,
    ): ShortArray {
        val norm = harmonics.sum().coerceAtLeast(1.0)
        return ShortArray(frameSize) { i ->
            val t = i.toDouble() / sampleRate
            var sample = dcOffset
            for (h in harmonics.indices) {
                val harmonicFreq = fundamentalHz * (h + 1)
                if (harmonicFreq < sampleRate * 0.45) {
                    sample += (harmonics[h] / norm) * amplitude *
                        sin(2.0 * PI * harmonicFreq * t + phaseOffset)
                }
            }
            if (windRumbleHz > 0.0 && windAmplitude > 0.0) {
                sample += windAmplitude * sin(2.0 * PI * windRumbleHz * t)
            }
            (sample.coerceIn(-0.98, 0.98) * 32767.0).toInt().toShort()
        }
    }

    private fun centsError(measured: Double, expected: Double): Double =
        1200.0 * ln(measured / expected) / ln(2.0)

    @Test
    fun tracksAll12StandardRichterKeysAcrossLowMiddleAndHighReeds() {
        // Standard 10-hole Richter offsets relative to C (G=-5 .. F#=+6)
        val keyOffsets = mapOf(
            "G" to -5,
            "Ab" to -4,
            "A" to -3,
            "Bb" to -2,
            "B" to -1,
            "C" to 0,
            "Db" to 1,
            "D" to 2,
            "Eb" to 3,
            "E" to 4,
            "F" to 5,
            "F#" to 6,
        )
        // Test Hole 1 blow (base MIDI 60), Hole 4 blow (base MIDI 72), Hole 10 blow (base MIDI 96)
        val testBaseMidis = intArrayOf(60, 72, 96)

        for ((key, offset) in keyOffsets) {
            for (baseMidi in testBaseMidis) {
                val engine = HarmonicaPitchEngine()
                val targetMidi = baseMidi + offset
                val expectedHz = midiToHz(targetMidi)
                val frame = synthReedFrame(fundamentalHz = expectedHz)
                val result = engine.analyzeFrame(frame, frame.size, sensitivity = 0.68)

                assertTrue("Expected detection for key=$key midi=$targetMidi (${expectedHz}Hz)", result.detected)
                val err = abs(centsError(result.frequency, expectedHz))
                assertTrue(
                    "Pitch error too large for key=$key midi=$targetMidi: expected=$expectedHz got=${result.frequency} (${err}¢)",
                    err <= 12.0,
                )
            }
        }
    }

    @Test
    fun preservesLowG3AndA3FundamentalUnderSmartphoneMemsBassRollOff() {
        // Smartphone MEMS mics often attenuate 196–220 Hz relative to their 2nd harmonic (392–440 Hz).
        val lowReedFreqs = doubleArrayOf(196.00, 220.00, 261.63) // G3, A3, C4
        for (freq in lowReedFreqs) {
            val engine = HarmonicaPitchEngine()
            val frame = synthReedFrame(
                fundamentalHz = freq,
                harmonics = doubleArrayOf(0.42, 1.0, 0.45, 0.25),
            )
            val result = engine.analyzeFrame(frame, frame.size, sensitivity = 0.68)
            assertTrue("Expected detection for low reed ${freq}Hz", result.detected)
            val err = abs(centsError(result.frequency, freq))
            assertTrue(
                "Low reed ${freq}Hz falsely jumped octave to ${result.frequency}Hz (${err}¢)",
                err <= 12.0,
            )
        }
    }

    @Test
    fun rejectsCloseMicWindRumbleAndTracksReedWithDcOffset() {
        val engine = HarmonicaPitchEngine()
        // Pure 30 Hz breath puff + DC offset must not trigger a false musical note
        val pureWind = synthReedFrame(
            fundamentalHz = 30.0,
            harmonics = doubleArrayOf(1.0),
            amplitude = 0.30,
            dcOffset = 0.15,
        )
        val windResult = engine.analyzeFrame(pureWind, pureWind.size, sensitivity = 0.68)
        assertFalse("Pure 30Hz wind rumble should not detect a harmonica pitch", windResult.detected)

        // Real C5 reed (523.25 Hz) mixed with DC offset and 35 Hz breath rumble must lock cleanly
        val reedWithWind = synthReedFrame(
            fundamentalHz = 523.25,
            dcOffset = 0.12,
            windRumbleHz = 35.0,
            windAmplitude = 0.10,
        )
        val reedResult = engine.analyzeFrame(reedWithWind, reedWithWind.size, sensitivity = 0.68)
        assertTrue("Expected C5 lock despite DC offset and wind rumble", reedResult.detected)
        assertEquals("C", reedResult.note)
        assertEquals(5, reedResult.octave)
        assertTrue(abs(centsError(reedResult.frequency, 523.25)) <= 10.0)
    }

    @Test
    fun snapsFastLegatoTransitionWithinTwoHopsWhileIgnoringSingleFrameGlitch() {
        val engine = HarmonicaPitchEngine()
        val c5 = synthReedFrame(fundamentalHz = 523.25)
        val g5 = synthReedFrame(fundamentalHz = 783.99)
        val glitch = synthReedFrame(fundamentalHz = 1_318.51) // brief E6 glitch

        // Stabilize on C5
        engine.analyzeFrame(c5, c5.size, sensitivity = 0.68)
        val stableC5 = engine.analyzeFrame(c5, c5.size, sensitivity = 0.68)
        assertEquals("C", stableC5.note)

        // Single-frame glitch must NOT flip output away from C5
        val duringGlitch = engine.analyzeFrame(glitch, glitch.size, sensitivity = 0.68)
        assertEquals("C", duringGlitch.note)

        // Two consecutive hops on G5 (~46 ms) must snap immediately to G5
        engine.analyzeFrame(g5, g5.size, sensitivity = 0.68)
        val snappedG5 = engine.analyzeFrame(g5, g5.size, sensitivity = 0.68)
        assertEquals("G", snappedG5.note)
        assertEquals(5, snappedG5.octave)
        assertTrue(abs(centsError(snappedG5.frequency, 783.99)) <= 10.0)
    }
}
