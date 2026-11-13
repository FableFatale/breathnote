package app.breathnote.breathnote

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.media.AudioAttributes
import android.net.Uri
import android.os.Build
import android.os.VibrationAttributes
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.provider.Settings
import android.view.HapticFeedbackConstants
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity(), EventChannel.StreamHandler {
    private val audioControlChannel = "app.breathnote/audio_control"
    private val pitchEventsChannel = "app.breathnote/pitch_events"
    private val preferencesChannel = "app.breathnote/preferences"
    private val permissionRequestCode = 4102

    private var eventSink: EventChannel.EventSink? = null
    private var pendingPermissionResult: MethodChannel.Result? = null
    private lateinit var pitchDetector: PitchDetector
    private val guideTonePlayer = GuideTonePlayer()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        pitchDetector = PitchDetector(::emitPitch, ::emitAudioError)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            audioControlChannel,
        ).setMethodCallHandler(::handleAudioMethod)

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            pitchEventsChannel,
        ).setStreamHandler(this)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            preferencesChannel,
        ).setMethodCallHandler(::handlePreferencesMethod)
    }

    private fun handleAudioMethod(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "hasMicrophonePermission" -> result.success(hasMicrophonePermission())
            "requestMicrophonePermission" -> requestMicrophonePermission(result)
            "startPitchDetection" -> {
                if (!hasMicrophonePermission()) {
                    result.error(
                        "microphone_permission_required",
                        "Microphone permission has not been granted.",
                        null,
                    )
                    return
                }
                val sensitivity = call.argument<Double>("sensitivity") ?: 0.68
                result.success(pitchDetector.start(sensitivity))
            }
            "setSensitivity" -> {
                pitchDetector.sensitivity = call.argument<Double>("value") ?: 0.68
                result.success(null)
            }
            "stopPitchDetection" -> {
                pitchDetector.stop()
                result.success(null)
            }
            "playGuideSequence" -> {
                val frequencies =
                    call.argument<List<Number>>("frequencies")
                        ?.map { it.toDouble() }
                        ?.filter { it > 0 }
                        .orEmpty()
                if (frequencies.isEmpty()) {
                    result.error(
                        "invalid_guide_sequence",
                        "At least one positive frequency is required.",
                        null,
                    )
                    return
                }
                val speed = call.argument<Double>("speed") ?: 1.0
                val repeat = call.argument<Boolean>("repeat") ?: false
                pitchDetector.stop()
                try {
                    result.success(guideTonePlayer.play(frequencies, speed, repeat))
                } catch (error: Exception) {
                    result.error(
                        "guide_audio_error",
                        error.message ?: "The guide tone could not be started.",
                        null,
                    )
                }
            }
            "stopGuideSequence" -> {
                guideTonePlayer.stop()
                result.success(null)
            }
            "triggerHaptic" -> {
                val type = call.argument<String>("type") ?: "selection"
                triggerNativeHaptic(type)
                result.success(null)
            }
            "openAppSettings" -> {
                val intent =
                    Intent(
                        Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                        Uri.parse("package:$packageName"),
                    )
                startActivity(intent)
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun handlePreferencesMethod(call: MethodCall, result: MethodChannel.Result) {
        val preferences = getSharedPreferences("breathnote_preferences", MODE_PRIVATE)
        when (call.method) {
            "getAll" -> {
                val payload = HashMap<String, Any?>(preferences.all)
                try {
                    val pkgInfo = packageManager.getPackageInfo(packageName, 0)
                    payload["__runtimeAppVersion"] =
                        "v${pkgInfo.versionName} (${pkgInfo.longVersionCode})"
                } catch (_: Exception) {}
                result.success(payload)
            }
            "setValue" -> {
                val key = call.argument<String>("key")
                val value = call.argument<Any>("value")
                if (key == null || value == null) {
                    result.error("invalid_preference", "A key and value are required.", null)
                    return
                }
                val editor = preferences.edit()
                when (value) {
                    is String -> editor.putString(key, value)
                    is Boolean -> editor.putBoolean(key, value)
                    is Int -> editor.putInt(key, value)
                    is Long -> editor.putLong(key, value)
                    is Float -> editor.putFloat(key, value)
                    is Double -> editor.putFloat(key, value.toFloat())
                    else -> {
                        result.error(
                            "unsupported_preference",
                            "Unsupported preference type.",
                            null,
                        )
                        return
                    }
                }
                editor.apply()
                result.success(null)
            }
            "clear" -> {
                preferences.edit().clear().apply()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun hasMicrophonePermission(): Boolean {
        return ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.RECORD_AUDIO,
        ) == PackageManager.PERMISSION_GRANTED
    }

    private fun requestMicrophonePermission(result: MethodChannel.Result) {
        if (hasMicrophonePermission()) {
            result.success("granted")
            return
        }
        if (pendingPermissionResult != null) {
            result.error(
                "permission_request_active",
                "A microphone permission request is already active.",
                null,
            )
            return
        }
        pendingPermissionResult = result
        ActivityCompat.requestPermissions(
            this,
            arrayOf(Manifest.permission.RECORD_AUDIO),
            permissionRequestCode,
        )
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != permissionRequestCode) return

        val granted = grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED
        val response =
            if (granted) {
                "granted"
            } else if (!ActivityCompat.shouldShowRequestPermissionRationale(
                    this,
                    Manifest.permission.RECORD_AUDIO,
                )
            ) {
                "permanentlyDenied"
            } else {
                "denied"
            }
        pendingPermissionResult?.success(response)
        pendingPermissionResult = null
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
        pitchDetector.stop()
    }

    private fun emitPitch(reading: Map<String, Any>) {
        runOnUiThread { eventSink?.success(reading) }
    }

    private fun emitAudioError(code: String, message: String) {
        runOnUiThread { eventSink?.error(code, message, null) }
    }

    @Suppress("DEPRECATION")
    private fun triggerNativeHaptic(type: String) {
        try {
            val view = window?.decorView
            if (view != null) {
                val feedbackConstant =
                    when (type) {
                        "reed" -> HapticFeedbackConstants.LONG_PRESS
                        "success" ->
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                                HapticFeedbackConstants.CONFIRM
                            } else {
                                HapticFeedbackConstants.VIRTUAL_KEY
                            }
                        "warning" ->
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                                HapticFeedbackConstants.REJECT
                            } else {
                                HapticFeedbackConstants.LONG_PRESS
                            }
                        "light" -> HapticFeedbackConstants.KEYBOARD_TAP
                        else -> HapticFeedbackConstants.CLOCK_TICK
                    }
                view.performHapticFeedback(
                    feedbackConstant,
                    HapticFeedbackConstants.FLAG_IGNORE_GLOBAL_SETTING or
                        HapticFeedbackConstants.FLAG_IGNORE_VIEW_SETTING,
                )
            }

            val vibrator: Vibrator? =
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    val manager =
                        getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager
                    manager?.defaultVibrator
                } else {
                    getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
                }

            if (vibrator == null || !vibrator.hasVibrator()) return

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val effect =
                    when (type) {
                        "reed" ->
                            VibrationEffect.createWaveform(
                                longArrayOf(0, 18, 12, 30),
                                intArrayOf(0, 190, 0, 255),
                                -1,
                            )
                        "success" ->
                            VibrationEffect.createWaveform(
                                longArrayOf(0, 22, 36, 40),
                                intArrayOf(0, 180, 0, 255),
                                -1,
                            )
                        "warning" ->
                            VibrationEffect.createWaveform(
                                longArrayOf(0, 42, 38, 52),
                                intArrayOf(0, 255, 0, 255),
                                -1,
                            )
                        "light" -> VibrationEffect.createOneShot(24, 190)
                        else -> VibrationEffect.createOneShot(18, 165)
                    }
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    val attrs =
                        VibrationAttributes.Builder()
                            .setUsage(VibrationAttributes.USAGE_TOUCH)
                            .build()
                    vibrator.vibrate(effect, attrs)
                } else {
                    val audioAttrs =
                        AudioAttributes.Builder()
                            .setUsage(AudioAttributes.USAGE_ASSISTANCE_SONIFICATION)
                            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                            .build()
                    vibrator.vibrate(effect, audioAttrs)
                }
            } else {
                vibrator.vibrate(if (type == "reed") 35L else 20L)
            }
        } catch (_: Exception) {
            // Ignore hardware vibrator exceptions on unsupported devices.
        }
    }

    override fun onStop() {
        pitchDetector.stop()
        guideTonePlayer.stop()
        super.onStop()
    }

    override fun onDestroy() {
        pitchDetector.stop()
        guideTonePlayer.stop()
        pendingPermissionResult = null
        super.onDestroy()
    }
}
