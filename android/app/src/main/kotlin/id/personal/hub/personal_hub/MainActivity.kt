package id.personal.hub.personal_hub

import android.content.Intent
import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val SHORTCUT_CHANNEL = "personal_hub/app_shortcuts"
    }

    private var pendingShortcutId: String? = null
    private var shortcutChannel: MethodChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Block screenshots, screen recording, and system task previews on Android.
        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        pendingShortcutId = extractShortcutId(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val shortcutId = extractShortcutId(intent) ?: return
        val channel = shortcutChannel
        if (channel != null) {
            channel.invokeMethod("onShortcutTriggered", shortcutId)
        } else {
            pendingShortcutId = shortcutId
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Enforce FLAG_SECURE window flag when Flutter engine is configured.
        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)

        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SHORTCUT_CHANNEL)
        shortcutChannel = channel
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialShortcut" -> {
                    val initial = pendingShortcutId
                    pendingShortcutId = null
                    result.success(initial)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun extractShortcutId(intent: Intent?): String? {
        if (intent == null) return null
        val fromExtra = intent.getStringExtra("shortcut_id")?.trim()
        if (!fromExtra.isNullOrEmpty()) return fromExtra
        val fromUri = intent.dataString?.trim()
        if (!fromUri.isNullOrEmpty()) return fromUri
        return null
    }
}
