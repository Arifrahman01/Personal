package id.personal.hub.personal_hub

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.provider.Settings
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val BACKGROUND_RECORDING_CHANNEL = "id.personal.hub/background_recording"
        private const val AUDIO_RECORDER_EVENTS_CHANNEL = "id.personal.hub/audio_recorder_events"
    }

    private val mainHandler = Handler(Looper.getMainLooper())
    private var nativeSpeechBridge: NativeContinuousSpeechBridge? = null
    private var audioEventsSink: EventChannel.EventSink? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Block screenshots, screen recording, and system task previews on Android.
        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Enforce FLAG_SECURE window flag when Flutter engine is configured.
        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)

        val messenger = flutterEngine.dartExecutor.binaryMessenger
        nativeSpeechBridge = NativeContinuousSpeechBridge(applicationContext, messenger)

        EventChannel(messenger, AUDIO_RECORDER_EVENTS_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    audioEventsSink = events
                    MeetingRecordingForegroundService.serviceEventListener = { payload ->
                        mainHandler.post {
                            audioEventsSink?.success(payload)
                        }
                    }
                    val pending = MeetingRecordingForegroundService.drainPendingEvents()
                    for (item in pending) {
                        audioEventsSink?.success(item)
                    }
                }

                override fun onCancel(arguments: Any?) {
                    audioEventsSink = null
                    MeetingRecordingForegroundService.serviceEventListener = null
                }
            }
        )

        MethodChannel(messenger, BACKGROUND_RECORDING_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startService" -> {
                    if (!hasMicPermission()) {
                        result.success(false)
                        return@setMethodCallHandler
                    }
                    val title = call.argument<String>("title") ?: ""
                    val statusText = call.argument<String>("statusText") ?: ""
                    val intent = Intent(this, MeetingRecordingForegroundService::class.java).apply {
                        action = MeetingRecordingForegroundService.ACTION_START
                        putExtra(MeetingRecordingForegroundService.EXTRA_TITLE, title)
                        putExtra(MeetingRecordingForegroundService.EXTRA_STATUS, statusText)
                    }
                    startFgServiceCompat(intent)
                    result.success(true)
                }

                "updateNotification" -> {
                    if (MeetingRecordingForegroundService.isRunning) {
                        val title = call.argument<String>("title") ?: ""
                        val statusText = call.argument<String>("statusText") ?: ""
                        val intent = Intent(this, MeetingRecordingForegroundService::class.java).apply {
                            action = MeetingRecordingForegroundService.ACTION_UPDATE
                            putExtra(MeetingRecordingForegroundService.EXTRA_TITLE, title)
                            putExtra(MeetingRecordingForegroundService.EXTRA_STATUS, statusText)
                        }
                        startService(intent)
                    }
                    result.success(true)
                }

                "stopService" -> {
                    if (MeetingRecordingForegroundService.isRunning) {
                        val intent = Intent(this, MeetingRecordingForegroundService::class.java).apply {
                            action = MeetingRecordingForegroundService.ACTION_STOP
                        }
                        startService(intent)
                    }
                    result.success(true)
                }

                "setKeepScreenOn" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    runOnUiThread {
                        if (enabled) {
                            window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                        } else {
                            window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                        }
                    }
                    result.success(true)
                }

                "startAudioCapture" -> {
                    if (!hasMicPermission()) {
                        result.success(false)
                        return@setMethodCallHandler
                    }
                    val outputPath = call.argument<String>("outputPath") ?: ""
                    val append = call.argument<Boolean>("append") ?: false
                    val title = call.argument<String>("title") ?: ""
                    val statusText = call.argument<String>("statusText") ?: ""
                    val intent = Intent(this, MeetingRecordingForegroundService::class.java).apply {
                        action = MeetingRecordingForegroundService.ACTION_START_AUDIO_CAPTURE
                        putExtra(MeetingRecordingForegroundService.EXTRA_OUTPUT_PATH, outputPath)
                        putExtra(MeetingRecordingForegroundService.EXTRA_APPEND, append)
                        putExtra(MeetingRecordingForegroundService.EXTRA_TITLE, title)
                        putExtra(MeetingRecordingForegroundService.EXTRA_STATUS, statusText)
                    }
                    startFgServiceCompat(intent)
                    result.success(true)
                }

                "pauseAudioCapture" -> {
                    if (!MeetingRecordingForegroundService.isRunning) {
                        result.success(null)
                        return@setMethodCallHandler
                    }
                    awaitAudioStopAction(MeetingRecordingForegroundService.ACTION_PAUSE_AUDIO_CAPTURE, result)
                }

                "stopAudioCapture" -> {
                    if (!MeetingRecordingForegroundService.isRunning) {
                        result.success(null)
                        return@setMethodCallHandler
                    }
                    awaitAudioStopAction(MeetingRecordingForegroundService.ACTION_STOP_AUDIO_CAPTURE, result)
                }

                "isAudioCapturing" -> {
                    result.success(MeetingRecordingForegroundService.isCapturingAudio)
                }

                "drainPendingServiceEvents" -> {
                    result.success(MeetingRecordingForegroundService.drainPendingEvents())
                }

                "startTranscriptionService" -> {
                    val title = call.argument<String>("title") ?: ""
                    val statusText = call.argument<String>("statusText") ?: ""
                    val intent = Intent(this, MeetingRecordingForegroundService::class.java).apply {
                        action = MeetingRecordingForegroundService.ACTION_START_TRANSCRIPTION
                        putExtra(MeetingRecordingForegroundService.EXTRA_TITLE, title)
                        putExtra(MeetingRecordingForegroundService.EXTRA_STATUS, statusText)
                    }
                    startFgServiceCompat(intent)
                    result.success(true)
                }

                "updateTranscriptionService" -> {
                    if (MeetingRecordingForegroundService.isRunning) {
                        val title = call.argument<String>("title") ?: ""
                        val statusText = call.argument<String>("statusText") ?: ""
                        val intent = Intent(this, MeetingRecordingForegroundService::class.java).apply {
                            action = MeetingRecordingForegroundService.ACTION_UPDATE_TRANSCRIPTION
                            putExtra(MeetingRecordingForegroundService.EXTRA_TITLE, title)
                            putExtra(MeetingRecordingForegroundService.EXTRA_STATUS, statusText)
                        }
                        startService(intent)
                    }
                    result.success(true)
                }

                "stopTranscriptionService" -> {
                    if (MeetingRecordingForegroundService.isRunning) {
                        val intent = Intent(this, MeetingRecordingForegroundService::class.java).apply {
                            action = MeetingRecordingForegroundService.ACTION_STOP_TRANSCRIPTION
                        }
                        startService(intent)
                    }
                    result.success(true)
                }

                "isIgnoringBatteryOptimizations" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        val pm = getSystemService(Context.POWER_SERVICE) as? PowerManager
                        result.success(pm?.isIgnoringBatteryOptimizations(packageName) ?: true)
                    } else {
                        result.success(true)
                    }
                }

                "openBatteryOptimizationSettings" -> {
                    try {
                        val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
                        } else {
                            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                                data = Uri.parse("package:$packageName")
                            }
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (_: Throwable) {
                        try {
                            val fallback = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                                data = Uri.parse("package:$packageName")
                            }
                            startActivity(fallback)
                            result.success(true)
                        } catch (_: Throwable) {
                            result.success(false)
                        }
                    }
                }

                else -> result.notImplemented()
            }
        }
    }

    private fun awaitAudioStopAction(actionName: String, result: MethodChannel.Result) {
        var replied = false
        val timeoutRunnable = Runnable {
            if (!replied) {
                replied = true
                MeetingRecordingForegroundService.pendingStopCallback = null
                result.success(
                    mapOf(
                        "path" to MeetingRecordingForegroundService.activeAudioPath,
                        "durationMs" to (MeetingRecordingForegroundService.totalPcmBytesRecorded * 1000L / 32000L),
                        "sizeBytes" to (MeetingRecordingForegroundService.totalPcmBytesRecorded + 44L)
                    )
                )
            }
        }
        MeetingRecordingForegroundService.pendingStopCallback = { summary ->
            mainHandler.removeCallbacks(timeoutRunnable)
            if (!replied) {
                replied = true
                result.success(summary)
            }
        }
        mainHandler.postDelayed(timeoutRunnable, 2000L)
        val intent = Intent(this, MeetingRecordingForegroundService::class.java).apply {
            action = actionName
        }
        startService(intent)
    }

    private fun hasMicPermission(): Boolean {
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.M ||
            checkSelfPermission(Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED
    }

    private fun startFgServiceCompat(intent: Intent) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }

    override fun onDestroy() {
        MeetingRecordingForegroundService.serviceEventListener = null
        MeetingRecordingForegroundService.pendingStopCallback = null
        nativeSpeechBridge?.dispose()
        nativeSpeechBridge = null
        super.onDestroy()
    }
}
