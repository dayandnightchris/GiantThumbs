package com.giantthumbs.giant_thumbs

import android.content.Intent
import android.graphics.Color
import android.inputmethodservice.InputMethodService
import android.view.View
import android.view.ViewGroup
import android.view.inputmethod.EditorInfo
import android.widget.FrameLayout
import io.flutter.embedding.android.FlutterTextureView
import io.flutter.embedding.android.FlutterView
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel

/**
 * Hosts the Giant Thumbs Flutter UI as a system keyboard (IME).
 *
 * The keyboard runs on a dedicated FlutterEngine that is cached app-wide, so it
 * opens fast on repeat use. That engine is intentionally *separate* from
 * MainActivity's: the app and the keyboard can be foregrounded at the same time
 * (e.g. typing into the layout editor's own text field while Giant Thumbs is the
 * active keyboard), and a single engine can only be attached to one host — one
 * shared instance would blank whichever side lost the attachment. Settings and
 * the custom layout still stay in sync because both sides read them from storage.
 */
class GiantThumbsIME : InputMethodService() {

    private lateinit var flutterEngine: FlutterEngine
    private var flutterView: FlutterView? = null
    private var channel: MethodChannel? = null

    override fun onCreate() {
        super.onCreate()
        flutterEngine = cachedEngine()
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "commitText" -> {
                        currentInputConnection?.commitText(call.argument<String>("text") ?: "", 1)
                        result.success(null)
                    }
                    "deleteLast" -> {
                        currentInputConnection?.deleteSurroundingText(1, 0)
                        result.success(null)
                    }
                    "deleteWord" -> {
                        val ic = currentInputConnection
                        if (ic != null) {
                            val before = ic.getTextBeforeCursor(256, 0) ?: ""
                            var i = before.length
                            while (i > 0 && before[i - 1].isWhitespace()) i--
                            while (i > 0 && !before[i - 1].isWhitespace()) i--
                            val count = before.length - i
                            ic.deleteSurroundingText(if (count > 0) count else 1, 0)
                        }
                        result.success(null)
                    }
                    "deleteAll" -> {
                        val ic = currentInputConnection
                        if (ic != null) {
                            val before = ic.getTextBeforeCursor(100000, 0)?.length ?: 0
                            val after = ic.getTextAfterCursor(100000, 0)?.length ?: 0
                            ic.deleteSurroundingText(before, after)
                        }
                        result.success(null)
                    }
                    "launchHostApp" -> {
                        startActivity(
                            Intent(this@GiantThumbsIME, MainActivity::class.java)
                                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        )
                        result.success(null)
                    }
                    "imeClientReady" -> {
                        // Dart's handler is now registered — hand it the mode
                        // without racing engine startup.
                        invokeMethod("setMode", mapOf("mode" to "ime"))
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    override fun onCreateInputView(): View {
        // Non-opaque texture so the host app shows through the transparent gaps
        // between keys (the keys honour the in-app opacity setting).
        val textureView = FlutterTextureView(this).apply { isOpaque = false }
        val fv = FlutterView(this, textureView)
        fv.attachToFlutterEngine(flutterEngine)
        flutterView = fv

        // Claim a generous slice of the screen for the "giant thumbs" keyboard.
        val container = FrameLayout(this).apply { setBackgroundColor(Color.TRANSPARENT) }
        val height = (resources.displayMetrics.heightPixels * KEYBOARD_HEIGHT_FRACTION).toInt()
        container.addView(
            fv,
            FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, height)
        )
        return container
    }

    override fun onStartInputView(info: EditorInfo?, restarting: Boolean) {
        super.onStartInputView(info, restarting)
        // Let the host app show through the keyboard's transparent areas.
        window?.window?.setBackgroundDrawableResource(android.R.color.transparent)
        // Drive Flutter rendering while the keyboard is visible, and (re)assert
        // IME mode each time it shows.
        flutterEngine.lifecycleChannel.appIsResumed()
        channel?.invokeMethod("setMode", mapOf("mode" to "ime"))
    }

    override fun onFinishInputView(finishingInput: Boolean) {
        flutterEngine.lifecycleChannel.appIsInactive()
        super.onFinishInputView(finishingInput)
    }

    override fun onDestroy() {
        flutterView?.detachFromFlutterEngine()
        flutterView = null
        super.onDestroy()
    }

    /** The shared, lazily-created keyboard engine (kept alive for fast reopen). */
    private fun cachedEngine(): FlutterEngine {
        FlutterEngineCache.getInstance().get(ENGINE_ID)?.let { return it }
        val engine = FlutterEngine(applicationContext)
        engine.dartExecutor.executeDartEntrypoint(DartExecutor.DartEntrypoint.createDefault())
        FlutterEngineCache.getInstance().put(ENGINE_ID, engine)
        return engine
    }

    companion object {
        private const val ENGINE_ID = "giant_thumbs_ime_engine"
        private const val CHANNEL = "com.giantthumbs/ime"
        private const val KEYBOARD_HEIGHT_FRACTION = 0.55
    }
}
