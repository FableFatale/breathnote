package app.breathnote.breathnote

import android.Manifest
import android.app.Activity
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
import android.provider.OpenableColumns
import android.provider.Settings
import android.view.HapticFeedbackConstants
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity(), EventChannel.StreamHandler {
    private val audioControlChannel = "app.breathnote/audio_control"
    private val pitchEventsChannel = "app.breathnote/pitch_events"
    private val preferencesChannel = "app.breathnote/preferences"
    private val billingChannel = "app.breathnote/billing"
    private val filePickerChannel = "app.breathnote/file_picker"
    private val shareChannel = "app.breathnote/share"
    private val permissionRequestCode = 4102
    private val scoreFileRequestCode = 4103
    private val backupFileRequestCode = 4104

    private var eventSink: EventChannel.EventSink? = null
    private var pendingPermissionResult: MethodChannel.Result? = null
    private var pendingFilePickerResult: MethodChannel.Result? = null
    private lateinit var pitchDetector: PitchDetector
    private val guideTonePlayer = GuideTonePlayer()
    private val metronomePlayer = MetronomePlayer()

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

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            billingChannel,
        ).setMethodCallHandler(::handleBillingMethod)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            filePickerChannel,
        ).setMethodCallHandler(::handleFilePickerMethod)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            shareChannel,
        ).setMethodCallHandler(::handleShareMethod)
    }

    @Suppress("DEPRECATION")
    private fun handleFilePickerMethod(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "pickScoreFile" -> launchDocumentPicker(
                requestCode = scoreFileRequestCode,
                mimeTypes = arrayOf(
                    "audio/midi",
                    "audio/x-midi",
                    "application/xml",
                    "text/xml",
                    "application/vnd.recordare.musicxml+xml",
                    "application/octet-stream",
                ),
                result = result,
            )
            "pickJsonFile" -> launchDocumentPicker(
                requestCode = backupFileRequestCode,
                mimeTypes = arrayOf(
                    "application/json",
                    "text/json",
                    "text/plain",
                    "application/octet-stream",
                ),
                result = result,
            )
            else -> result.notImplemented()
        }
    }

    @Suppress("DEPRECATION")
    private fun launchDocumentPicker(
        requestCode: Int,
        mimeTypes: Array<String>,
        result: MethodChannel.Result,
    ) {
        if (pendingFilePickerResult != null) {
            result.error("file_picker_active", "A file picker request is already active.", null)
            return
        }
        pendingFilePickerResult = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "*/*"
            putExtra(Intent.EXTRA_MIME_TYPES, mimeTypes)
        }
        try {
            startActivityForResult(intent, requestCode)
        } catch (error: Exception) {
            pendingFilePickerResult = null
            result.error("file_picker_unavailable", error.message, null)
        }
    }

    @Suppress("DEPRECATION")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != scoreFileRequestCode && requestCode != backupFileRequestCode) return
        val pending = pendingFilePickerResult ?: return
        pendingFilePickerResult = null
        if (resultCode != Activity.RESULT_OK || data?.data == null) {
            pending.success(null)
            return
        }
        val uri = data.data!!
        try {
            var fileName =
                if (requestCode == backupFileRequestCode) {
                    "breathnote_backup.json"
                } else {
                    "imported.mid"
                }
            contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { cursor ->
                if (cursor.moveToFirst()) {
                    val idx = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                    if (idx >= 0) {
                        val queried = cursor.getString(idx)
                        if (!queried.isNullOrBlank()) fileName = queried
                    }
                }
            }
            val bytes = contentResolver.openInputStream(uri)?.use { stream ->
                val raw = stream.readBytes()
                if (raw.size > 2 * 1024 * 1024) {
                    throw IllegalArgumentException("File exceeds 2MB limit.")
                }
                raw
            }
            if (bytes == null || bytes.isEmpty()) {
                pending.success(null)
                return
            }
            pending.success(mapOf("name" to fileName, "bytes" to bytes))
        } catch (error: Exception) {
            pending.error("file_read_error", error.message ?: "Unable to read selected file.", null)
        }
    }

    private fun handleBillingMethod(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            // Ready for Google Play Billing Client integration once store SKU `breathnote_pro_lifetime` is published.
            "purchaseProLifetime", "restorePurchases" -> result.success("unavailable")
            else -> result.notImplemented()
        }
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
                        .orEmpty()
                if (frequencies.isEmpty() || frequencies.none { it > 0 }) {
                    result.error(
                        "invalid_guide_sequence",
                        "At least one positive frequency is required.",
                        null,
                    )
                    return
                }
                val beats =
                    call.argument<List<Number>>("beats")
                        ?.map { it.toDouble() }
                val speed = call.argument<Double>("speed") ?: 1.0
                val repeat = call.argument<Boolean>("repeat") ?: false
                pitchDetector.stop()
                try {
                    result.success(guideTonePlayer.play(frequencies, speed, repeat, beats))
                } catch (error: Exception) {
                    result.error(
                        "guide_audio_error",
                        error.message ?: "The guide tone could not be started.",
                        null,
                    )
                }
            }
            "playMetronomeClick" -> {
                val accent = call.argument<Boolean>("accent") ?: false
                metronomePlayer.playClick(accent)
                result.success(null)
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
        metronomePlayer.release()
        pendingPermissionResult = null
        super.onDestroy()
    }

    private fun handleShareMethod(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "shareImage" -> {
                val bytes = call.argument<ByteArray>("bytes")
                if (bytes == null || bytes.isEmpty()) {
                    result.error("invalid_image", "Image bytes are required.", null)
                    return
                }
                val rawName = call.argument<String>("fileName") ?: "breathnote_achievement.png"
                val safeBase =
                    rawName
                        .substringAfterLast('/')
                        .substringAfterLast('\\')
                        .replace(Regex("[^A-Za-z0-9._-]"), "_")
                        .ifBlank { "breathnote_achievement.png" }
                val safeName =
                    if (safeBase.endsWith(".png", ignoreCase = true)) {
                        safeBase
                    } else {
                        "$safeBase.png"
                    }
                val text = call.argument<String>("text")
                val subject = call.argument<String>("subject")
                try {
                    val sharesDir = File(cacheDir, "shares").apply { mkdirs() }
                    val outFile = File(sharesDir, safeName)
                    outFile.writeBytes(bytes)
                    val uri = FileProvider.getUriForFile(this, "$packageName.fileprovider", outFile)
                    val sendIntent =
                        Intent(Intent.ACTION_SEND).apply {
                            type = "image/png"
                            putExtra(Intent.EXTRA_STREAM, uri)
                            if (!text.isNullOrBlank()) putExtra(Intent.EXTRA_TEXT, text)
                            if (!subject.isNullOrBlank()) putExtra(Intent.EXTRA_SUBJECT, subject)
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        }
                    val chooser =
                        Intent.createChooser(sendIntent, subject ?: text ?: "Share").apply {
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        }
                    startActivity(chooser)
                    result.success(true)
                } catch (error: Exception) {
                    result.error("share_error", error.message ?: "Unable to share image.", null)
                }
            }
            "shareTextFile" -> {
                val content = call.argument<String>("content")
                if (content.isNullOrEmpty()) {
                    result.error("invalid_file", "File content is required.", null)
                    return
                }
                val rawName = call.argument<String>("fileName") ?: "breathnote_backup.json"
                val mimeType = call.argument<String>("mimeType") ?: "application/json"
                val subject = call.argument<String>("subject")
                val safeBase =
                    rawName
                        .substringAfterLast('/')
                        .substringAfterLast('\\')
                        .replace(Regex("[^A-Za-z0-9._-]"), "_")
                        .ifBlank { "breathnote_backup.json" }
                val safeName =
                    if (mimeType == "application/json" && !safeBase.endsWith(".json", ignoreCase = true)) {
                        "$safeBase.json"
                    } else {
                        safeBase
                    }
                try {
                    val sharesDir = File(cacheDir, "shares").apply { mkdirs() }
                    val outFile = File(sharesDir, safeName)
                    outFile.writeText(content, Charsets.UTF_8)
                    val uri = FileProvider.getUriForFile(this, "$packageName.fileprovider", outFile)
                    val sendIntent =
                        Intent(Intent.ACTION_SEND).apply {
                            type = mimeType
                            putExtra(Intent.EXTRA_STREAM, uri)
                            if (!subject.isNullOrBlank()) putExtra(Intent.EXTRA_SUBJECT, subject)
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        }
                    val chooser =
                        Intent.createChooser(sendIntent, subject ?: safeName).apply {
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        }
                    startActivity(chooser)
                    result.success(true)
                } catch (error: Exception) {
                    result.error("share_error", error.message ?: "Unable to share file.", null)
                }
            }
            else -> result.notImplemented()
        }
    }
}
