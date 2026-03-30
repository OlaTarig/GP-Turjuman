package com.example.turjuman

import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Sign recognition — MediaPipe keypoint extraction via Zego frame interception
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        MethodChannel(
            messenger,
            SignRecognitionChannel.CHANNEL_NAME,
        ).setMethodCallHandler(SignRecognitionChannel(this, messenger))

        // Window flags — FLAG_SECURE (prevents screenshots / screen recording)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.example.turjuman/window_flags",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "addSecureFlag" -> {
                    window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    result.success(null)
                }
                "clearSecureFlag" -> {
                    window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
}
