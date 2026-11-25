package id.personal.hub.personal_hub

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.media.AudioManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.speech.RecognitionListener
import android.speech.RecognitionService
import android.speech.RecognitionSupport
import android.speech.RecognitionSupportCallback
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.Locale
import java.util.concurrent.Executors

class NativeContinuousSpeechBridge(
    private val context: Context,
    messenger: BinaryMessenger
) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    companion object {
        private const val METHOD_CHANNEL = "id.personal.hub/native_speech"
        private const val EVENT_CHANNEL = "id.personal.hub/native_speech_events"
    }

    private val methodChannel = MethodChannel(messenger, METHOD_CHANNEL)
    private val eventChannel = EventChannel(messenger, EVENT_CHANNEL)
    private val mainHandler = Handler(Looper.getMainLooper())
    private val executor = Executors.newSingleThreadExecutor()

    private var eventSink: EventChannel.EventSink? = null
    private var speechRecognizer: SpeechRecognizer? = null
    private var currentOnDeviceMode: Boolean? = null
    private var isListeningActive: Boolean = false
    private var lastRmsEmitMs: Long = 0L
    private var lastSessionWasSegmented: Boolean = false
    private var notificationMutedByBridge: Boolean = false

    init {
        methodChannel.setMethodCallHandler(this)
        eventChannel.setStreamHandler(this)
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "initialize" -> handleInitialize(result)
            "checkOfflineLanguageSupport" -> {
                val localeId = call.argument<String>("localeId") ?: "id-ID"
                handleCheckOfflineSupport(localeId, result)
            }
            "triggerOfflineLanguageDownload" -> {
                val localeId = call.argument<String>("localeId") ?: "id-ID"
                handleTriggerOfflineDownload(localeId, result)
            }
            "startListening" -> {
                val localeId = call.argument<String>("localeId") ?: ""
                val preferOffline = call.argument<Boolean>("preferOffline") ?: true
                handleStartListening(localeId, preferOffline, result)
            }
            "stopListening" -> handleStopListening(result)
            "cancel" -> handleCancel(result)
            else -> result.notImplemented()
        }
    }

    private fun hasMicPermission(): Boolean {
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.M ||
            context.checkSelfPermission(Manifest.permission.RECORD_AUDIO) ==
                PackageManager.PERMISSION_GRANTED
    }

    private fun isOnDeviceAvailable(): Boolean {
        return Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
            SpeechRecognizer.isOnDeviceRecognitionAvailable(context)
    }

    private fun handleInitialize(result: MethodChannel.Result) {
        if (!hasMicPermission()) {
            result.success(
                mapOf(
                    "available" to false,
                    "onDeviceAvailable" to false,
                    "supportsSegmentedSession" to false
                )
            )
            return
        }
        val onDevice = isOnDeviceAvailable()
        val systemAvailable = SpeechRecognizer.isRecognitionAvailable(context)
        result.success(
            mapOf(
                "available" to (onDevice || systemAvailable),
                "onDeviceAvailable" to onDevice,
                "supportsSegmentedSession" to (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU)
            )
        )
    }

    private fun normalizeLocaleTag(raw: String): String {
        val trimmed = raw.trim()
        if (trimmed.isEmpty()) return ""
        return trimmed.replace('_', '-')
    }

    private fun handleCheckOfflineSupport(localeId: String, result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU || !isOnDeviceAvailable() || !hasMicPermission()) {
            result.success(mapOf("installed" to false, "supported" to false))
            return
        }

        mainHandler.post {
            var tempRecognizer: SpeechRecognizer? = null
            try {
                tempRecognizer = SpeechRecognizer.createOnDeviceSpeechRecognizer(context)
                val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH)
                val targetTag = normalizeLocaleTag(localeId).lowercase(Locale.ROOT)
                tempRecognizer.checkRecognitionSupport(
                    intent,
                    executor,
                    object : RecognitionSupportCallback {
                        override fun onSupportResult(support: RecognitionSupport) {
                            val installed = matchesLocaleList(support.installedOnDeviceLanguages, targetTag)
                            val supported = installed ||
                                matchesLocaleList(support.supportedOnDeviceLanguages, targetTag) ||
                                matchesLocaleList(support.pendingOnDeviceLanguages, targetTag)
                            mainHandler.post {
                                tempRecognizer?.destroy()
                                result.success(mapOf("installed" to installed, "supported" to supported))
                            }
                        }

                        override fun onError(error: Int) {
                            mainHandler.post {
                                tempRecognizer?.destroy()
                                result.success(mapOf("installed" to false, "supported" to false))
                            }
                        }
                    }
                )
            } catch (_: Throwable) {
                tempRecognizer?.destroy()
                result.success(mapOf("installed" to false, "supported" to false))
            }
        }
    }

    private fun matchesLocaleList(locales: List<String>, targetTag: String): Boolean {
        if (targetTag.isEmpty()) return locales.isNotEmpty()
        val prefix = targetTag.substringBefore('-')
        return locales.any { raw ->
            val norm = raw.trim().replace('_', '-').lowercase(Locale.ROOT)
            norm == targetTag || norm == prefix || norm.startsWith("$prefix-")
        }
    }

    private fun handleTriggerOfflineDownload(localeId: String, result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU || !isOnDeviceAvailable()) {
            result.success(false)
            return
        }
        mainHandler.post {
            try {
                val recognizer = ensureRecognizer(useOnDevice = true)
                val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                    val tag = normalizeLocaleTag(localeId)
                    if (tag.isNotEmpty()) {
                        putExtra(RecognizerIntent.EXTRA_LANGUAGE, tag)
                    }
                }
                recognizer.triggerModelDownload(intent)
                result.success(true)
            } catch (_: Throwable) {
                result.success(false)
            }
        }
    }

    private fun handleStartListening(
        localeId: String,
        preferOffline: Boolean,
        result: MethodChannel.Result
    ) {
        if (!hasMicPermission()) {
            result.success(false)
            return
        }

        mainHandler.post {
            try {
                val useOnDevice = preferOffline && isOnDeviceAvailable()
                val recognizer = ensureRecognizer(useOnDevice)
                if (isListeningActive) {
                    try {
                        recognizer.cancel()
                    } catch (_: Throwable) {
                    }
                    isListeningActive = false
                }

                val supportsSegmented = Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU
                lastSessionWasSegmented = supportsSegmented

                val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                    putExtra(
                        RecognizerIntent.EXTRA_LANGUAGE_MODEL,
                        RecognizerIntent.LANGUAGE_MODEL_FREE_FORM
                    )
                    putExtra(RecognizerIntent.EXTRA_CALLING_PACKAGE, context.packageName)
                    putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
                    putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 5)

                    val tag = normalizeLocaleTag(localeId)
                    if (tag.isNotEmpty()) {
                        putExtra(RecognizerIntent.EXTRA_LANGUAGE, tag)
                    }
                    if (preferOffline) {
                        putExtra(RecognizerIntent.EXTRA_PREFER_OFFLINE, true)
                    }

                    if (supportsSegmented) {
                        putExtra(
                            RecognizerIntent.EXTRA_SEGMENTED_SESSION,
                            RecognizerIntent.EXTRA_SPEECH_INPUT_MINIMUM_LENGTH_MILLIS
                        )
                        putExtra(
                            RecognizerIntent.EXTRA_SPEECH_INPUT_MINIMUM_LENGTH_MILLIS,
                            300_000L
                        )
                        putExtra(
                            RecognizerIntent.EXTRA_SPEECH_INPUT_COMPLETE_SILENCE_LENGTH_MILLIS,
                            10_000L
                        )
                        putExtra(
                            RecognizerIntent.EXTRA_SPEECH_INPUT_POSSIBLY_COMPLETE_SILENCE_LENGTH_MILLIS,
                            10_000L
                        )
                    } else {
                        putExtra(
                            RecognizerIntent.EXTRA_SPEECH_INPUT_MINIMUM_LENGTH_MILLIS,
                            30_000L
                        )
                        putExtra(
                            RecognizerIntent.EXTRA_SPEECH_INPUT_COMPLETE_SILENCE_LENGTH_MILLIS,
                            4_000L
                        )
                        putExtra(
                            RecognizerIntent.EXTRA_SPEECH_INPUT_POSSIBLY_COMPLETE_SILENCE_LENGTH_MILLIS,
                            4_000L
                        )
                    }
                }

                if (!supportsSegmented) {
                    muteTransitionBeepBriefly()
                }

                isListeningActive = true
                lastRmsEmitMs = 0L
                recognizer.startListening(intent)
                result.success(true)
            } catch (_: Throwable) {
                isListeningActive = false
                result.success(false)
            }
        }
    }

    private fun handleStopListening(result: MethodChannel.Result) {
        mainHandler.post {
            try {
                isListeningActive = false
                speechRecognizer?.stopListening()
            } catch (_: Throwable) {
            }
            result.success(true)
        }
    }

    private fun handleCancel(result: MethodChannel.Result) {
        mainHandler.post {
            try {
                isListeningActive = false
                speechRecognizer?.cancel()
            } catch (_: Throwable) {
            }
            result.success(true)
        }
    }

    private fun ensureRecognizer(useOnDevice: Boolean): SpeechRecognizer {
        val existing = speechRecognizer
        if (existing != null && currentOnDeviceMode == useOnDevice) {
            return existing
        }
        try {
            existing?.destroy()
        } catch (_: Throwable) {
        }
        speechRecognizer = null

        val created = if (useOnDevice && Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            SpeechRecognizer.createOnDeviceSpeechRecognizer(context)
        } else {
            SpeechRecognizer.createSpeechRecognizer(context)
        }
        created.setRecognitionListener(recognitionListener)
        speechRecognizer = created
        currentOnDeviceMode = useOnDevice
        return created
    }

    private fun muteTransitionBeepBriefly() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return
        try {
            val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as? AudioManager ?: return
            if (audioManager.ringerMode != AudioManager.RINGER_MODE_NORMAL) return
            if (!notificationMutedByBridge) {
                audioManager.adjustStreamVolume(AudioManager.STREAM_NOTIFICATION, AudioManager.ADJUST_MUTE, 0)
                notificationMutedByBridge = true
                mainHandler.postDelayed({
                    restoreNotificationBeep()
                }, 350L)
            }
        } catch (_: Throwable) {
        }
    }

    private fun restoreNotificationBeep() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return
        if (!notificationMutedByBridge) return
        notificationMutedByBridge = false
        try {
            val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as? AudioManager ?: return
            audioManager.adjustStreamVolume(AudioManager.STREAM_NOTIFICATION, AudioManager.ADJUST_UNMUTE, 0)
        } catch (_: Throwable) {
        }
    }

    private fun emitEvent(payload: Map<String, Any?>) {
        mainHandler.post {
            eventSink?.success(payload)
        }
    }

    private val recognitionListener = object : RecognitionListener {
        override fun onReadyForSpeech(params: Bundle?) {
            emitEvent(mapOf("type" to "status", "status" to "listening"))
        }

        override fun onBeginningOfSpeech() {}

        override fun onRmsChanged(rmsdB: Float) {
            val nowMs = System.currentTimeMillis()
            if (nowMs - lastRmsEmitMs < 200L) return
            lastRmsEmitMs = nowMs
            emitEvent(mapOf("type" to "soundLevel", "level" to rmsdB.toDouble()))
        }

        override fun onBufferReceived(buffer: ByteArray?) {}

        override fun onEndOfSpeech() {
            // Do NOT schedule any 5-second blind timer here!
        }

        override fun onPartialResults(partialResults: Bundle?) {
            val text = partialResults
                ?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                ?.firstOrNull()
                ?.trim()
                .orEmpty()
            if (text.isNotEmpty()) {
                emitEvent(mapOf("type" to "result", "text" to text, "isFinal" to false))
            }
        }

        override fun onSegmentResults(segmentResults: Bundle) {
            val text = segmentResults
                .getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                ?.firstOrNull()
                ?.trim()
                .orEmpty()
            if (text.isNotEmpty()) {
                emitEvent(mapOf("type" to "result", "text" to text, "isFinal" to true))
            }
        }

        override fun onEndOfSegmentedSession() {
            isListeningActive = false
            emitEvent(mapOf("type" to "status", "status" to "done"))
        }

        override fun onResults(results: Bundle?) {
            val text = results
                ?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                ?.firstOrNull()
                ?.trim()
                .orEmpty()
            if (text.isNotEmpty()) {
                emitEvent(mapOf("type" to "result", "text" to text, "isFinal" to true))
            }
            isListeningActive = false
            emitEvent(mapOf("type" to "status", "status" to "done"))
        }

        override fun onError(error: Int) {
            isListeningActive = false
            val code = when (error) {
                SpeechRecognizer.ERROR_AUDIO -> "error_audio_error"
                SpeechRecognizer.ERROR_CLIENT -> "error_client"
                SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS -> "error_permission"
                SpeechRecognizer.ERROR_NETWORK -> "error_network"
                SpeechRecognizer.ERROR_NETWORK_TIMEOUT -> "error_network_timeout"
                SpeechRecognizer.ERROR_NO_MATCH -> "error_no_match"
                SpeechRecognizer.ERROR_RECOGNIZER_BUSY -> "error_busy"
                SpeechRecognizer.ERROR_SERVER -> "error_server"
                SpeechRecognizer.ERROR_SPEECH_TIMEOUT -> "error_speech_timeout"
                SpeechRecognizer.ERROR_LANGUAGE_NOT_SUPPORTED -> "error_language_not_supported"
                SpeechRecognizer.ERROR_LANGUAGE_UNAVAILABLE -> "error_language_unavailable"
                SpeechRecognizer.ERROR_SERVER_DISCONNECTED -> "error_server_disconnected"
                SpeechRecognizer.ERROR_TOO_MANY_REQUESTS -> "error_too_many_requests"
                else -> "error_unknown_$error"
            }
            emitEvent(mapOf("type" to "status", "status" to "error:$code"))
        }

        override fun onEvent(eventType: Int, params: Bundle?) {}
    }

    fun dispose() {
        restoreNotificationBeep()
        mainHandler.post {
            try {
                speechRecognizer?.destroy()
            } catch (_: Throwable) {
            }
            speechRecognizer = null
        }
        executor.shutdownNow()
    }
}
