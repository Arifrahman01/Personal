package id.personal.hub.personal_hub

import android.Manifest
import android.annotation.SuppressLint
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.RemoteInput
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.media.AudioFormat
import android.media.AudioManager
import android.media.AudioRecord
import android.media.AudioRecordingConfiguration
import android.media.MediaRecorder
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.os.Process
import java.io.File
import java.io.RandomAccessFile
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.concurrent.Executors
import kotlin.math.max
import kotlin.math.sqrt

class MeetingRecordingForegroundService : Service() {
    companion object {
        const val CHANNEL_ID = "meeting_recording_channel"
        const val NOTIFICATION_ID = 4102

        const val ACTION_START = "id.personal.hub.ACTION_START_RECORDING"
        const val ACTION_UPDATE = "id.personal.hub.ACTION_UPDATE_RECORDING"
        const val ACTION_STOP = "id.personal.hub.ACTION_STOP_RECORDING"

        const val ACTION_START_AUDIO_CAPTURE = "id.personal.hub.ACTION_START_AUDIO_CAPTURE"
        const val ACTION_PAUSE_AUDIO_CAPTURE = "id.personal.hub.ACTION_PAUSE_AUDIO_CAPTURE"
        const val ACTION_STOP_AUDIO_CAPTURE = "id.personal.hub.ACTION_STOP_AUDIO_CAPTURE"

        const val ACTION_NOTIF_PAUSE = "id.personal.hub.ACTION_NOTIF_PAUSE"
        const val ACTION_NOTIF_RESUME = "id.personal.hub.ACTION_NOTIF_RESUME"
        const val ACTION_NOTIF_ADD_NOTE = "id.personal.hub.ACTION_NOTIF_ADD_NOTE"
        const val ACTION_NOTIF_STOP = "id.personal.hub.ACTION_NOTIF_STOP"

        const val ACTION_START_TRANSCRIPTION = "id.personal.hub.ACTION_START_TRANSCRIPTION"
        const val ACTION_UPDATE_TRANSCRIPTION = "id.personal.hub.ACTION_UPDATE_TRANSCRIPTION"
        const val ACTION_STOP_TRANSCRIPTION = "id.personal.hub.ACTION_STOP_TRANSCRIPTION"

        const val EXTRA_TITLE = "extra_title"
        const val EXTRA_STATUS = "extra_status"
        const val EXTRA_OUTPUT_PATH = "extra_output_path"
        const val EXTRA_APPEND = "extra_append"
        const val KEY_QUICK_NOTE_TEXT = "key_quick_note_text"

        private const val SAMPLE_RATE = 16000
        private const val CHANNELS = 1
        private const val BITS_PER_SAMPLE = 16
        private const val BYTES_PER_SECOND = SAMPLE_RATE * CHANNELS * (BITS_PER_SAMPLE / 8)
        private const val WAV_HEADER_BYTES = 44

        @Volatile
        var isRunning: Boolean = false

        @Volatile
        var isCapturingAudio: Boolean = false

        @Volatile
        var isAudioPaused: Boolean = false

        @Volatile
        var isTranscribing: Boolean = false

        @Volatile
        var activeAudioPath: String? = null

        @Volatile
        var totalPcmBytesRecorded: Long = 0L

        @Volatile
        var isMicSilenced: Boolean = false

        @Volatile
        var serviceEventListener: ((Map<String, Any?>) -> Unit)? = null

        @Volatile
        var pendingStopCallback: ((Map<String, Any?>) -> Unit)? = null

        private val pendingEventsLock = Any()
        private val pendingEvents = mutableListOf<Map<String, Any?>>()

        fun emitServiceEvent(event: Map<String, Any?>, queueIfDetached: Boolean = true) {
            val listener = serviceEventListener
            if (listener != null) {
                Handler(Looper.getMainLooper()).post {
                    val currentListener = serviceEventListener
                    if (currentListener != null) {
                        currentListener.invoke(event)
                    } else if (queueIfDetached) {
                        synchronized(pendingEventsLock) {
                            pendingEvents.add(event)
                        }
                    }
                }
            } else if (queueIfDetached) {
                synchronized(pendingEventsLock) {
                    pendingEvents.add(event)
                }
            }
        }

        fun drainPendingEvents(): List<Map<String, Any?>> {
            synchronized(pendingEventsLock) {
                if (pendingEvents.isEmpty()) return emptyList()
                val copy = ArrayList<Map<String, Any?>>(pendingEvents)
                pendingEvents.clear()
                return copy
            }
        }
    }

    private val mainHandler = Handler(Looper.getMainLooper())
    private var wakeLock: PowerManager.WakeLock? = null

    private var currentTitle: String = ""
    private var currentStatus: String = ""
    private var isAudioSessionMode: Boolean = false

    @Volatile
    private var shouldCapture: Boolean = false
    private var audioRecord: AudioRecord? = null
    private var captureThread: Thread? = null
    private val captureLock = Any()

    private val callbackExecutor = Executors.newSingleThreadExecutor()
    private var recordingCallback: Any? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                stopAudioCaptureInternal(clearPath = true)
                isTranscribing = false
                isAudioSessionMode = false
                stopServiceCleanly()
                return START_NOT_STICKY
            }

            ACTION_UPDATE -> {
                if (isRunning) {
                    currentTitle = intent.getStringExtra(EXTRA_TITLE) ?: currentTitle
                    currentStatus = intent.getStringExtra(EXTRA_STATUS) ?: currentStatus
                    refreshNotification()
                }
                return START_STICKY
            }

            ACTION_START_AUDIO_CAPTURE -> {
                if (!hasMicPermission()) {
                    emitServiceEvent(
                        mapOf("type" to "audioError", "message" to "Izin mikrofon tidak tersedia.")
                    )
                    stopServiceCleanly()
                    return START_NOT_STICKY
                }
                val outputPath = intent.getStringExtra(EXTRA_OUTPUT_PATH)?.trim().orEmpty()
                if (outputPath.isEmpty()) {
                    return START_NOT_STICKY
                }
                val append = intent.getBooleanExtra(EXTRA_APPEND, false)
                currentTitle = intent.getStringExtra(EXTRA_TITLE) ?: currentTitle
                currentStatus = intent.getStringExtra(EXTRA_STATUS) ?: "Audio Senyap aktif"
                isAudioSessionMode = true
                isAudioPaused = false
                isTranscribing = false

                ensureNotificationChannel()
                startForegroundWithType(
                    buildNotification(currentTitle, currentStatus),
                    isMicService = true
                )
                acquireWakeLock()
                isRunning = true

                startAudioCaptureLoop(outputPath, append)
                return START_STICKY
            }

            ACTION_PAUSE_AUDIO_CAPTURE -> {
                val summary = stopAudioCaptureInternal(clearPath = false)
                isAudioPaused = true
                isAudioSessionMode = true
                currentStatus = "Rekaman dijeda"
                refreshNotification()
                deliverStopCallback(summary)
                return START_STICKY
            }

            ACTION_STOP_AUDIO_CAPTURE -> {
                val summary = stopAudioCaptureInternal(clearPath = false)
                isAudioPaused = false
                isAudioSessionMode = false
                deliverStopCallback(summary)
                if (!isTranscribing) {
                    stopServiceCleanly()
                }
                return START_NOT_STICKY
            }

            ACTION_NOTIF_PAUSE -> {
                if (isCapturingAudio) {
                    val summary = stopAudioCaptureInternal(clearPath = false)
                    isAudioPaused = true
                    isAudioSessionMode = true
                    currentStatus = "Rekaman dijeda"
                    refreshNotification()
                    emitServiceEvent(
                        mapOf(
                            "type" to "notifPause",
                            "path" to summary["path"],
                            "durationMs" to summary["durationMs"],
                            "sizeBytes" to summary["sizeBytes"]
                        )
                    )
                }
                return START_STICKY
            }

            ACTION_NOTIF_RESUME -> {
                val path = activeAudioPath
                if (isAudioPaused && !path.isNullOrEmpty() && hasMicPermission()) {
                    isAudioPaused = false
                    isAudioSessionMode = true
                    currentStatus = "Audio Senyap aktif"
                    ensureNotificationChannel()
                    startForegroundWithType(
                        buildNotification(currentTitle, currentStatus),
                        isMicService = true
                    )
                    acquireWakeLock()
                    startAudioCaptureLoop(path, append = true)
                    emitServiceEvent(mapOf("type" to "notifResume", "path" to path))
                }
                return START_STICKY
            }

            ACTION_NOTIF_ADD_NOTE -> {
                val results = RemoteInput.getResultsFromIntent(intent)
                val noteText = results?.getCharSequence(KEY_QUICK_NOTE_TEXT)?.toString()?.trim().orEmpty()
                if (noteText.isNotEmpty()) {
                    emitServiceEvent(mapOf("type" to "notifQuickNote", "text" to noteText))
                    val previewStatus = if (currentStatus.isNotEmpty()) currentStatus else "Audio Senyap aktif"
                    currentStatus = "Catatan ditambahkan • $previewStatus"
                    refreshNotification()
                    mainHandler.postDelayed({
                        if (isRunning && (isCapturingAudio || isAudioPaused)) {
                            currentStatus = if (isAudioPaused) "Rekaman dijeda" else "Audio Senyap aktif"
                            refreshNotification()
                        }
                    }, 2200)
                } else {
                    refreshNotification()
                }
                return START_STICKY
            }

            ACTION_NOTIF_STOP -> {
                val summary = stopAudioCaptureInternal(clearPath = false)
                isAudioPaused = false
                isAudioSessionMode = false
                emitServiceEvent(
                    mapOf(
                        "type" to "notifStop",
                        "path" to summary["path"],
                        "durationMs" to summary["durationMs"],
                        "sizeBytes" to summary["sizeBytes"]
                    )
                )
                stopServiceCleanly()
                return START_NOT_STICKY
            }

            ACTION_START_TRANSCRIPTION -> {
                stopAudioCaptureInternal(clearPath = false)
                isAudioPaused = false
                isAudioSessionMode = false
                isTranscribing = true
                currentTitle = intent.getStringExtra(EXTRA_TITLE) ?: currentTitle
                currentStatus = intent.getStringExtra(EXTRA_STATUS) ?: "Mentranskrip audio offline..."
                ensureNotificationChannel()
                startForegroundWithType(
                    buildNotification(currentTitle, currentStatus),
                    isMicService = false
                )
                acquireWakeLock()
                isRunning = true
                return START_STICKY
            }

            ACTION_UPDATE_TRANSCRIPTION -> {
                if (isRunning && isTranscribing) {
                    currentTitle = intent.getStringExtra(EXTRA_TITLE) ?: currentTitle
                    currentStatus = intent.getStringExtra(EXTRA_STATUS) ?: currentStatus
                    refreshNotification()
                }
                return START_STICKY
            }

            ACTION_STOP_TRANSCRIPTION -> {
                isTranscribing = false
                if (!isCapturingAudio && !isAudioPaused) {
                    stopServiceCleanly()
                }
                return START_NOT_STICKY
            }

            else -> {
                if (!hasMicPermission()) {
                    isRunning = false
                    stopSelf()
                    return START_NOT_STICKY
                }
                ensureNotificationChannel()
                currentTitle = intent?.getStringExtra(EXTRA_TITLE) ?: ""
                currentStatus = intent?.getStringExtra(EXTRA_STATUS) ?: ""
                isAudioSessionMode = false
                isAudioPaused = false
                isTranscribing = false
                startForegroundWithType(
                    buildNotification(currentTitle, currentStatus),
                    isMicService = true
                )
                acquireWakeLock()
                isRunning = true
                return START_STICKY
            }
        }
    }

    private fun hasMicPermission(): Boolean {
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.M ||
            checkSelfPermission(Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED
    }

    private fun startForegroundWithType(notification: Notification, isMicService: Boolean) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            val fgType = if (isMicService) {
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE
            } else {
                ServiceInfo.FOREGROUND_SERVICE_TYPE_SHORT_SERVICE
            }
            startForeground(NOTIFICATION_ID, notification, fgType)
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R && isMicService) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    @SuppressLint("MissingPermission")
    private fun startAudioCaptureLoop(outputPath: String, append: Boolean) {
        synchronized(captureLock) {
            if (isCapturingAudio && activeAudioPath == outputPath) {
                return
            }
            if (isCapturingAudio) {
                stopAudioCaptureInternal(clearPath = false)
            }

            val minBuf = AudioRecord.getMinBufferSize(
                SAMPLE_RATE,
                AudioFormat.CHANNEL_IN_MONO,
                AudioFormat.ENCODING_PCM_16BIT
            )
            val bufferSize = max(if (minBuf > 0) minBuf * 2 else 6400, 6400)

            var record = tryCreateAudioRecord(MediaRecorder.AudioSource.VOICE_RECOGNITION, bufferSize)
            if (record == null) {
                record = tryCreateAudioRecord(MediaRecorder.AudioSource.MIC, bufferSize)
            }
            if (record == null) {
                emitServiceEvent(
                    mapOf(
                        "type" to "audioError",
                        "message" to "Gagal membuka mikrofon perangkat untuk rekaman audio."
                    )
                )
                return
            }

            audioRecord = record
            activeAudioPath = outputPath
            isCapturingAudio = true
            isMicSilenced = false
            shouldCapture = true
            registerMicSilenceCallback(record)

            val thread = Thread({
                Process.setThreadPriority(Process.THREAD_PRIORITY_AUDIO)
                var raf: RandomAccessFile? = null
                var pcmBytes: Long = 0L
                try {
                    val outFile = File(outputPath)
                    outFile.parentFile?.mkdirs()
                    raf = RandomAccessFile(outFile, "rw")

                    if (append && outFile.exists() && outFile.length() >= WAV_HEADER_BYTES) {
                        pcmBytes = outFile.length() - WAV_HEADER_BYTES
                        raf.seek(outFile.length())
                    } else {
                        raf.setLength(0)
                        raf.write(buildWavHeader(0L))
                        pcmBytes = 0L
                    }
                    totalPcmBytesRecorded = pcmBytes

                    record.startRecording()

                    val shortBuf = ShortArray(bufferSize / 2)
                    val byteBuf = ByteArray(bufferSize)
                    var lastFlushMs = System.currentTimeMillis()
                    var lastLevelEmitMs = 0L

                    while (shouldCapture) {
                        val readShorts = record.read(shortBuf, 0, shortBuf.size)
                        if (readShorts > 0) {
                            var sumSquares = 0.0
                            for (i in 0 until readShorts) {
                                val s = shortBuf[i]
                                sumSquares += (s.toDouble() * s.toDouble())
                                byteBuf[i * 2] = (s.toInt() and 0xFF).toByte()
                                byteBuf[i * 2 + 1] = ((s.toInt() shr 8) and 0xFF).toByte()
                            }
                            val bytesToWrite = readShorts * 2
                            raf.write(byteBuf, 0, bytesToWrite)
                            pcmBytes += bytesToWrite
                            totalPcmBytesRecorded = pcmBytes

                            val nowMs = System.currentTimeMillis()
                            if (nowMs - lastLevelEmitMs >= 200L) {
                                lastLevelEmitMs = nowMs
                                val rms = sqrt(sumSquares / readShorts)
                                val normalized = (rms / 12000.0).coerceIn(0.0, 1.0)
                                emitServiceEvent(
                                    mapOf("type" to "soundLevel", "level" to normalized),
                                    queueIfDetached = false
                                )
                            }
                            if (nowMs - lastFlushMs >= 5000L) {
                                lastFlushMs = nowMs
                                updateWavHeaderSizes(raf, pcmBytes)
                            }
                        } else if (readShorts < 0) {
                            break
                        }
                    }
                } catch (err: Throwable) {
                    emitServiceEvent(
                        mapOf(
                            "type" to "audioError",
                            "message" to (err.message ?: "Terjadi kesalahan saat menulis audio.")
                        )
                    )
                } finally {
                    try {
                        if (raf != null) {
                            updateWavHeaderSizes(raf, pcmBytes)
                            raf.fd.sync()
                            raf.close()
                        }
                    } catch (_: Throwable) {
                    }
                    totalPcmBytesRecorded = pcmBytes
                }
            }, "PersonalHubAudioCapture")

            captureThread = thread
            thread.start()
        }
    }

    @SuppressLint("MissingPermission")
    private fun tryCreateAudioRecord(source: Int, bufferSize: Int): AudioRecord? {
        return try {
            val candidate = AudioRecord(
                source,
                SAMPLE_RATE,
                AudioFormat.CHANNEL_IN_MONO,
                AudioFormat.ENCODING_PCM_16BIT,
                bufferSize
            )
            if (candidate.state == AudioRecord.STATE_INITIALIZED) {
                candidate
            } else {
                candidate.release()
                null
            }
        } catch (_: Throwable) {
            null
        }
    }

    private fun stopAudioCaptureInternal(clearPath: Boolean): Map<String, Any?> {
        synchronized(captureLock) {
            shouldCapture = false
            val record = audioRecord
            unregisterMicSilenceCallback(record)
            try {
                if (record != null && record.recordingState == AudioRecord.RECORDSTATE_RECORDING) {
                    record.stop()
                }
            } catch (_: Throwable) {
            }

            val thread = captureThread
            if (thread != null && thread != Thread.currentThread()) {
                try {
                    thread.join(1500)
                } catch (_: InterruptedException) {
                }
            }
            captureThread = null

            try {
                record?.release()
            } catch (_: Throwable) {
            }
            audioRecord = null
            isCapturingAudio = false
            isMicSilenced = false

            val path = activeAudioPath
            var sizeBytes = 0L
            var dataBytes = totalPcmBytesRecorded
            if (!path.isNullOrEmpty()) {
                val f = File(path)
                if (f.exists()) {
                    sizeBytes = f.length()
                    if (sizeBytes >= WAV_HEADER_BYTES) {
                        dataBytes = sizeBytes - WAV_HEADER_BYTES
                        totalPcmBytesRecorded = dataBytes
                    }
                }
            }
            val durationMs = (dataBytes * 1000L) / BYTES_PER_SECOND
            if (clearPath) {
                activeAudioPath = null
                totalPcmBytesRecorded = 0L
            }

            return mapOf(
                "path" to path,
                "durationMs" to durationMs,
                "sizeBytes" to sizeBytes
            )
        }
    }

    private fun deliverStopCallback(summary: Map<String, Any?>) {
        val cb = pendingStopCallback
        pendingStopCallback = null
        if (cb != null) {
            mainHandler.post { cb.invoke(summary) }
        }
    }

    private fun registerMicSilenceCallback(record: AudioRecord) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return
        val audioManager = getSystemService(Context.AUDIO_SERVICE) as? AudioManager ?: return
        val sessionId = record.audioSessionId
        val callback = object : AudioManager.AudioRecordingCallback() {
            override fun onRecordingConfigChanged(configs: MutableList<AudioRecordingConfiguration>?) {
                val match = configs?.firstOrNull { it.clientAudioSessionId == sessionId }
                val silenced = match?.isClientSilenced == true
                if (silenced != isMicSilenced) {
                    isMicSilenced = silenced
                    if (isRunning && isCapturingAudio) {
                        currentStatus = if (silenced) {
                            "Mikrofon dipakai aplikasi lain (menunggu...)"
                        } else {
                            "Audio Senyap aktif"
                        }
                        refreshNotification()
                    }
                    emitServiceEvent(mapOf("type" to "micSilenced", "silenced" to silenced))
                }
            }
        }
        recordingCallback = callback
        try {
            audioManager.registerAudioRecordingCallback(callback, mainHandler)
        } catch (_: Throwable) {
            recordingCallback = null
        }
    }

    private fun unregisterMicSilenceCallback(record: AudioRecord?) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return
        val cb = recordingCallback as? AudioManager.AudioRecordingCallback ?: return
        recordingCallback = null
        try {
            val audioManager = getSystemService(Context.AUDIO_SERVICE) as? AudioManager
            audioManager?.unregisterAudioRecordingCallback(cb)
        } catch (_: Throwable) {
        }
    }

    private fun buildWavHeader(dataBytes: Long): ByteArray {
        val totalDataLen = dataBytes + 36L
        val byteRate = BYTES_PER_SECOND.toLong()
        val buffer = ByteBuffer.allocate(WAV_HEADER_BYTES).order(ByteOrder.LITTLE_ENDIAN)
        buffer.put("RIFF".toByteArray(Charsets.US_ASCII))
        buffer.putInt(totalDataLen.toInt())
        buffer.put("WAVE".toByteArray(Charsets.US_ASCII))
        buffer.put("fmt ".toByteArray(Charsets.US_ASCII))
        buffer.putInt(16)
        buffer.putShort(1.toShort())
        buffer.putShort(CHANNELS.toShort())
        buffer.putInt(SAMPLE_RATE)
        buffer.putInt(byteRate.toInt())
        buffer.putShort((CHANNELS * BITS_PER_SAMPLE / 8).toShort())
        buffer.putShort(BITS_PER_SAMPLE.toShort())
        buffer.put("data".toByteArray(Charsets.US_ASCII))
        buffer.putInt(dataBytes.toInt())
        return buffer.array()
    }

    private fun updateWavHeaderSizes(raf: RandomAccessFile, dataBytes: Long) {
        val currentPos = raf.filePointer
        val intBuf = ByteBuffer.allocate(4).order(ByteOrder.LITTLE_ENDIAN)
        intBuf.putInt((dataBytes + 36L).toInt())
        raf.seek(4)
        raf.write(intBuf.array())
        intBuf.clear()
        intBuf.putInt(dataBytes.toInt())
        raf.seek(40)
        raf.write(intBuf.array())
        raf.seek(currentPos)
    }

    private fun refreshNotification() {
        if (!isRunning) return
        val notification = buildNotification(currentTitle, currentStatus)
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.notify(NOTIFICATION_ID, notification)
    }

    private fun stopServiceCleanly() {
        releaseWakeLock()
        isRunning = false
        isCapturingAudio = false
        isAudioPaused = false
        isTranscribing = false
        isAudioSessionMode = false
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
        stopSelf()
    }

    private fun acquireWakeLock() {
        val current = wakeLock
        if (current != null && current.isHeld) {
            return
        }
        val powerManager = getSystemService(Context.POWER_SERVICE) as? PowerManager ?: return
        wakeLock = powerManager.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            "PersonalHub:MeetingRecordingWakeLock"
        ).apply {
            setReferenceCounted(false)
            acquire(4 * 60 * 60 * 1000L)
        }
    }

    private fun releaseWakeLock() {
        try {
            val current = wakeLock
            if (current != null && current.isHeld) {
                current.release()
            }
        } catch (_: Throwable) {
        } finally {
            wakeLock = null
        }
    }

    private fun ensureNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Rekaman Meeting",
            NotificationManager.IMPORTANCE_LOW
        ).apply {
            description = "Menampilkan status perekaman meeting yang berjalan di latar belakang."
            setSound(null, null)
            enableVibration(false)
        }
        manager.createNotificationChannel(channel)
    }

    private fun buildNotification(rawTitle: String, rawStatus: String): Notification {
        val displayTitle = when {
            isTranscribing -> "Personal Hub • Transkrip Offline"
            rawTitle.trim().isNotEmpty() -> "Personal Hub • ${rawTitle.trim()}"
            else -> "Personal Hub • Merekam Meeting"
        }
        val displayStatus = if (rawStatus.trim().isNotEmpty()) {
            rawStatus.trim()
        } else if (isTranscribing) {
            "Memproses transkrip audio secara offline..."
        } else {
            "Mikrofon aktif di latar belakang"
        }

        val launchIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val immutableFlags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        val pendingIntent = PendingIntent.getActivity(this, 0, launchIntent, immutableFlags)

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }

        builder
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(displayTitle)
            .setContentText(displayStatus)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setCategory(Notification.CATEGORY_SERVICE)
            .setContentIntent(pendingIntent)

        if (isAudioSessionMode && !isTranscribing) {
            // Action 1: Jeda or Lanjut
            val toggleAction = if (isAudioPaused) {
                val resumeIntent = Intent(this, MeetingRecordingForegroundService::class.java).apply {
                    action = ACTION_NOTIF_RESUME
                }
                val resumePi = PendingIntent.getService(this, 101, resumeIntent, immutableFlags)
                Notification.Action.Builder(0, "Lanjut", resumePi).build()
            } else {
                val pauseIntent = Intent(this, MeetingRecordingForegroundService::class.java).apply {
                    action = ACTION_NOTIF_PAUSE
                }
                val pausePi = PendingIntent.getService(this, 102, pauseIntent, immutableFlags)
                Notification.Action.Builder(0, "Jeda", pausePi).build()
            }
            builder.addAction(toggleAction)

            // Action 2: + Catatan (Direct Reply via RemoteInput)
            val noteIntent = Intent(this, MeetingRecordingForegroundService::class.java).apply {
                action = ACTION_NOTIF_ADD_NOTE
            }
            val mutableFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
            } else {
                PendingIntent.FLAG_UPDATE_CURRENT
            }
            val notePi = PendingIntent.getService(this, 103, noteIntent, mutableFlags)
            val remoteInput = RemoteInput.Builder(KEY_QUICK_NOTE_TEXT)
                .setLabel("Tulis catatan cepat...")
                .build()
            val noteAction = Notification.Action.Builder(0, "+ Catatan", notePi)
                .addRemoteInput(remoteInput)
                .apply {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                        setAllowGeneratedReplies(false)
                    }
                }
                .build()
            builder.addAction(noteAction)

            // Action 3: Selesai
            val stopIntent = Intent(this, MeetingRecordingForegroundService::class.java).apply {
                action = ACTION_NOTIF_STOP
            }
            val stopPi = PendingIntent.getService(this, 104, stopIntent, immutableFlags)
            builder.addAction(Notification.Action.Builder(0, "Selesai", stopPi).build())
        }

        return builder.build()
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        // Keep active audio capture & offline transcription alive if user swipes Recents.
        if (isCapturingAudio || isAudioPaused || isTranscribing) {
            super.onTaskRemoved(rootIntent)
            return
        }
        stopServiceCleanly()
        super.onTaskRemoved(rootIntent)
    }

    override fun onDestroy() {
        stopAudioCaptureInternal(clearPath = false)
        releaseWakeLock()
        isRunning = false
        callbackExecutor.shutdownNow()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
