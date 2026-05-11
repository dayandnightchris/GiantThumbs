package com.giantthumbs.giant_thumbs

import android.inputmethodservice.InputMethodService
import android.view.View
import android.view.inputmethod.EditorInfo
import io.flutter.embedding.android.FlutterView
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel

class GiantThumbsIME : InputMethodService() {

    private lateinit var flutterEngine: FlutterEngine
    private lateinit var flutterView: FlutterView
    private lateinit var channel: MethodChannel

    companion object {
        private const val CHANNEL = "com.giantthumbs/ime"
    }

    override fun onCreate() {
        super.onCreate()

        flutterEngine = FlutterEngine(this)
        flutterEngine.dartExecutor.executeDartEntrypoint(
            DartExecutor.DartEntrypoint.createDefault()
        )

        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)

        // Receive commit-text calls from Flutter
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "commitText" -> {
                    val text = call.argument<String>("text") ?: ""
                    currentInputConnection?.commitText(text, 1)
                    result.success(null)
                }
                "deleteLast" -> {
                    currentInputConnection?.deleteSurroundingText(1, 0)
                    result.success(null)
                }
                "openSettings" -> {
                    // surfacePackage — let the demo activity handle it on next launch
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onCreateInputView(): View {
        flutterView = FlutterView(this)
        flutterView.attachToFlutterEngine(flutterEngine)
        // Tell Flutter which mode we're in (IME vs demo)
        channel.invokeMethod("setMode", mapOf("mode" to "ime"))
        return flutterView
    }

    override fun onStartInputView(info: EditorInfo?, restarting: Boolean) {
        super.onStartInputView(info, restarting)
        flutterView.attachToFlutterEngine(flutterEngine)
    }

    override fun onFinishInputView(finishingInput: Boolean) {
        super.onFinishInputView(finishingInput)
        flutterView.detachFromFlutterEngine()
    }

    override fun onDestroy() {
        flutterEngine.destroy()
        super.onDestroy()
    }
}
