package com.example.turjuman

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Matrix
import android.opengl.GLES20
import com.google.mediapipe.framework.image.BitmapImageBuilder
import com.google.mediapipe.tasks.core.BaseOptions
import com.google.mediapipe.tasks.core.Delegate
import com.google.mediapipe.tasks.vision.core.RunningMode
import com.google.mediapipe.tasks.vision.handlandmarker.HandLandmarker
import com.google.mediapipe.tasks.vision.handlandmarker.HandLandmarkerResult
import im.zego.zegoexpress.ZegoExpressEngine
import im.zego.zegoexpress.callback.IZegoCustomVideoProcessHandler
import im.zego.zegoexpress.constants.ZegoPublishChannel
import im.zego.zegoexpress.constants.ZegoVideoBufferType
import im.zego.zegoexpress.entity.ZegoCustomVideoProcessConfig
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

class SignRecognitionChannel(
    private val context: Context,
    private val binaryMessenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL_NAME       = "com.example.turjuman/sign_recognition"
        const val EVENT_CHANNEL_NAME = "com.example.turjuman/sign_keypoints"

        private const val HAND_MODEL  = "models/hand_landmarker.task"
        private const val FEATURE_DIM = 126          // lh(63) + rh(63)
        private const val NUM_FRAMES  = 48
        private const val TARGET_FPS      = 25
        private const val FRAME_MS        = (1000 / TARGET_FPS).toLong()  // 40ms
        // Training window: 48 frames @ 30 fps ≈ 1600 ms.
        // At device speed (~3 fps) we collect 3–5 frames then resample to NUM_FRAMES.
        // 800ms gives ~3 frames (≥ minimum) at half the latency; resampling stretches
        // the temporal axis to match training regardless of actual collection rate.
        private const val BATCH_WINDOW_MS = 1200L

        // GL_BGRA_EXT: reads bytes as B,G,R,A which maps directly to Android ARGB_8888 memory layout
        // (on little-endian ARM, ARGB_8888 stores pixels as B-G-R-A bytes).
        // Using GL_RGBA would swap R and B, sending BGR to MediaPipe instead of RGB.
        private const val GL_BGRA_EXT = 0x80E1
    }

    // ── EventChannel ─────────────────────────────────────────────────────────
    private var eventSink: EventChannel.EventSink? = null
    private val mainHandler = android.os.Handler(android.os.Looper.getMainLooper())

    init {
        EventChannel(binaryMessenger, EVENT_CHANNEL_NAME).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, sink: EventChannel.EventSink?) {
                    eventSink = sink
                }
                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            }
        )
    }

    // ── MediaPipe ─────────────────────────────────────────────────────────────
    private var handLandmarker: HandLandmarker? = null
    private var initialized = false

    // ── Background executor ───────────────────────────────────────────────────
    private val executor: ExecutorService = Executors.newSingleThreadExecutor()
    private val isProcessing              = AtomicBoolean(false)

    // ── State ─────────────────────────────────────────────────────────────────
    @Volatile private var isCapturing = false
    private val nativeFrameBuffer = mutableListOf<DoubleArray>()

    // ── Frame timing ──────────────────────────────────────────────────────────
    private var lastCollectedMs   = 0L
    private var batchStartMs      = 0L
    private var processedCount    = 0
    private var detectedCount     = 0

    // ── Debug ─────────────────────────────────────────────────────────────────
    private val debugFrameSaved = AtomicBoolean(false)

    // ─────────────────────────────────────────────────────────────────────────
    // MethodChannel
    // ─────────────────────────────────────────────────────────────────────────

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "initialize" -> {
                try {
                    initializeMediaPipe()
                    result.success(null)
                } catch (e: Exception) {
                    result.error("INIT_ERROR", "MediaPipe init failed: ${e.message}", null)
                }
            }
            "setupVideoProcessing" -> {
                try {
                    setupZegoVideoProcessing()
                    result.success(null)
                } catch (e: Exception) {
                    result.error("SETUP_ERROR", "Setup failed: ${e.message}", null)
                }
            }
            "startContinuous" -> {
                nativeFrameBuffer.clear()
                lastCollectedMs = 0L
                batchStartMs    = 0L
                processedCount  = 0
                detectedCount   = 0
                isCapturing     = true
                result.success(null)
            }
            "stopContinuous" -> {
                isCapturing = false
                nativeFrameBuffer.clear()
                result.success(null)
            }
            "dispose" -> {
                isCapturing = false
                nativeFrameBuffer.clear()
                handLandmarker?.close()
                handLandmarker = null
                initialized    = false
                executor.shutdown()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Zego GL_TEXTURE_2D processing
    // ─────────────────────────────────────────────────────────────────────────

    private var frameCallbackCount = 0

    private fun setupZegoVideoProcessing() {
        val engine = ZegoExpressEngine.getEngine()
            ?: throw IllegalStateException("Zego engine not yet created")

        android.util.Log.d("SignRec", "setupZegoVideoProcessing: GL_TEXTURE_2D")

        val config = ZegoCustomVideoProcessConfig()
        config.bufferType = ZegoVideoBufferType.GL_TEXTURE_2D
        engine.enableCustomVideoProcessing(true, config, ZegoPublishChannel.MAIN)

        engine.setCustomVideoProcessHandler(object : IZegoCustomVideoProcessHandler() {

            override fun onCapturedUnprocessedTextureData(
                textureID: Int,
                width: Int,
                height: Int,
                referenceTimeMillisecond: Long,
                channel: ZegoPublishChannel,
            ) {
                frameCallbackCount++
                if (frameCallbackCount == 1) {
                    android.util.Log.d("SignRec", "first GL frame: w=$width h=$height texID=$textureID")
                }

                val now = System.currentTimeMillis()
                // Frame-rate check comes first so compareAndSet is only called when we
                // truly intend to capture. This prevents the else branch from accidentally
                // releasing the lock while a previous task is still running in the executor
                // (which would let new tasks queue up faster than they finish).
                val shouldCapture = isCapturing
                    && (now - lastCollectedMs) >= FRAME_MS
                    && isProcessing.compareAndSet(false, true)

                if (shouldCapture) {
                    // Read pixels on the GL thread (active EGL context required).
                    val bitmap = readBitmapFromTexture(textureID, width, height)

                    // Always return texture to Zego immediately.
                    ZegoExpressEngine.getEngine()?.sendCustomVideoProcessedTextureData(
                        textureID, width, height, referenceTimeMillisecond, channel
                    )

                    if (bitmap != null) {
                        lastCollectedMs = now
                        executor.execute {
                            try {
                                handleSignFrameFromBitmap(bitmap)
                            } finally {
                                isProcessing.set(false)
                            }
                        }
                    } else {
                        isProcessing.set(false)
                    }
                } else {
                    // Pass frame through unchanged. isProcessing is NOT touched here —
                    // compareAndSet was never called (frame rate / capturing guard failed),
                    // or it returned false (task already running), so nothing to undo.
                    ZegoExpressEngine.getEngine()?.sendCustomVideoProcessedTextureData(
                        textureID, width, height, referenceTimeMillisecond, channel
                    )
                }
            }
        })
        android.util.Log.d("SignRec", "setupZegoVideoProcessing: DONE")
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Read bitmap from GL texture.
    //
    // Color: GL_BGRA_EXT (0x80E1) maps directly to Android ARGB_8888 memory layout.
    //
    // Orientation: Zego GL_TEXTURE_2D textures are top-down (origin top-left),
    // so glReadPixels gives correct top-to-bottom order — NO vertical flip needed.
    // (Previous vertical flip was causing upside-down images → 15% detection rate.)
    //
    // Mirror: front camera preview is mirrored; MIRROR_FRONT_CAMERA un-mirrors it
    // so hands match the un-mirrored training data orientation.
    // ─────────────────────────────────────────────────────────────────────────

    // Toggle if predictions are consistently wrong-handed (handedness swap symptom).
    private val MIRROR_FRONT_CAMERA = true

    private fun readBitmapFromTexture(textureID: Int, width: Int, height: Int): Bitmap? {
        return try {
            val fbo = IntArray(1)
            GLES20.glGenFramebuffers(1, fbo, 0)
            GLES20.glBindFramebuffer(GLES20.GL_FRAMEBUFFER, fbo[0])
            GLES20.glFramebufferTexture2D(
                GLES20.GL_FRAMEBUFFER, GLES20.GL_COLOR_ATTACHMENT0,
                GLES20.GL_TEXTURE_2D, textureID, 0
            )

            val status = GLES20.glCheckFramebufferStatus(GLES20.GL_FRAMEBUFFER)
            if (status != GLES20.GL_FRAMEBUFFER_COMPLETE) {
                android.util.Log.w("SignRec", "FBO incomplete: 0x${status.toString(16)}")
                GLES20.glDeleteFramebuffers(1, fbo, 0)
                GLES20.glBindFramebuffer(GLES20.GL_FRAMEBUFFER, 0)
                return null
            }

            val pixels = ByteBuffer.allocateDirect(width * height * 4)
            pixels.order(ByteOrder.nativeOrder())
            GLES20.glReadPixels(0, 0, width, height, GL_BGRA_EXT, GLES20.GL_UNSIGNED_BYTE, pixels)

            val glError = GLES20.glGetError()
            if (glError != GLES20.GL_NO_ERROR) {
                android.util.Log.w("SignRec", "GL_BGRA_EXT failed (err=0x${glError.toString(16)}), falling back to GL_RGBA + swap")
                pixels.rewind()
                GLES20.glReadPixels(0, 0, width, height, GLES20.GL_RGBA, GLES20.GL_UNSIGNED_BYTE, pixels)
                pixels.rewind()
                val bytes = ByteArray(pixels.remaining())
                pixels.get(bytes)
                for (i in bytes.indices step 4) {
                    val r = bytes[i]; bytes[i] = bytes[i + 2]; bytes[i + 2] = r
                }
                pixels.rewind()
                pixels.put(bytes)
            }

            GLES20.glDeleteFramebuffers(1, fbo, 0)
            GLES20.glBindFramebuffer(GLES20.GL_FRAMEBUFFER, 0)

            pixels.rewind()
            val raw = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
            raw.copyPixelsFromBuffer(pixels)

            // Log center pixel to verify color quality (first frame only).
            if (frameCallbackCount <= 1) {
                val px = raw.getPixel(width / 2, height / 2)
                android.util.Log.d("SignRec",
                    "center pixel: R=${(px shr 16) and 0xFF} G=${(px shr 8) and 0xFF} " +
                    "B=${px and 0xFF} A=${(px ushr 24) and 0xFF}")
            }

            // Apply horizontal mirror for front camera (no vertical flip — Zego is top-down).
            val bmp = if (MIRROR_FRONT_CAMERA) {
                val m = Matrix().apply { postScale(-1f, 1f, width / 2f, height / 2f) }
                Bitmap.createBitmap(raw, 0, 0, width, height, m, false)
            } else raw

            // 256px wide: MediaPipe runs ~80ms → ~12fps → ~19 frames per 1.6s window.
            val targetW = minOf(256, bmp.width)
            val targetH  = (bmp.height * targetW.toFloat() / bmp.width).toInt()
            val scaled = if (targetW < bmp.width) Bitmap.createScaledBitmap(bmp, targetW, targetH, true) else bmp

            // Save first processed frame for visual inspection.
            if (debugFrameSaved.compareAndSet(false, true)) {
                try {
                    val file = java.io.File(context.getExternalFilesDir(null), "sign_debug.png")
                    java.io.FileOutputStream(file).use { scaled.compress(Bitmap.CompressFormat.PNG, 100, it) }
                    android.util.Log.d("SignRec", "debug frame saved → ${file.absolutePath}")
                } catch (e: Exception) {
                    android.util.Log.w("SignRec", "debug frame save failed: ${e.message}")
                }
            }

            scaled
        } catch (e: Exception) {
            android.util.Log.e("SignRec", "readBitmapFromTexture error: ${e.message}", e)
            null
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Per-frame processing (background executor)
    // ─────────────────────────────────────────────────────────────────────────

    private fun handleSignFrameFromBitmap(bitmap: Bitmap) {
        val frameMs = System.currentTimeMillis()
        try {
            val mpImage    = BitmapImageBuilder(bitmap).build()
            // VIDEO mode requires strictly increasing timestamps in milliseconds.
            val handResult = handLandmarker?.detectForVideo(mpImage, frameMs)
            val handCount  = handResult?.landmarks()?.size ?: 0

            processedCount++
            if (handCount > 0) detectedCount++

            // Log detection rate every 20 processed frames
            if (processedCount % 20 == 0) {
                android.util.Log.d("SignRec",
                    "detection rate: $detectedCount/$processedCount " +
                    "(${100 * detectedCount / processedCount}%) bufSize=${nativeFrameBuffer.size}")
            }

            if (handCount == 0) {
                emit("handsOutOfFrame")
                return
            }

            emit("handsDetected")

            val nowMs = frameMs
            if (batchStartMs == 0L) batchStartMs = nowMs

            val keypoints = extractHandKeypoints(handResult)

            // Debug: log first frame's thumb MCP (landmark 1, indices 3-5) — non-zero only when hand detected.
            if (nativeFrameBuffer.isEmpty()) {
                val lhL1 = keypoints.drop(3).take(3).map { String.format("%.4f", it) }
                val rhL1 = keypoints.drop(66).take(3).map { String.format("%.4f", it) }
                android.util.Log.d("SignRec", "frame0 lh_l1=$lhL1 rh_l1=$rhL1 (non-zero=detected)")
            }

            nativeFrameBuffer.add(keypoints.toDoubleArray())

            val elapsed = nowMs - batchStartMs
            if (elapsed >= BATCH_WINDOW_MS) {
                val n = nativeFrameBuffer.size
                if (n >= 3) {
                    // Resample whatever frames we collected to exactly NUM_FRAMES so the
                    // temporal pattern always spans ~1.6s, matching the training window.
                    android.util.Log.d("SignRec",
                        "batch complete: $n frames in ${elapsed}ms " +
                        "(${1000L * n / elapsed.coerceAtLeast(1)}fps) → resample→$NUM_FRAMES")
                    val flat = resampleToFlat(nativeFrameBuffer, NUM_FRAMES, FEATURE_DIM)
                    android.util.Log.d("SignRec", "emitting ${flat.size} values to Dart")
                    emit(flat.toList())
                } else {
                    android.util.Log.d("SignRec", "batch discarded: only $n frames in ${elapsed}ms")
                }
                nativeFrameBuffer.clear()
                batchStartMs   = 0L
                processedCount = 0
                detectedCount  = 0
            }
        } catch (e: Exception) {
            android.util.Log.e("SignRec", "handleSignFrame error: ${e.javaClass.simpleName}: ${e.message}", e)
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Resample a variable-length frame list to exactly targetCount frames by
    // linearly interpolating between adjacent source frames.
    // This normalises the temporal axis so inference always sees ~1.6 s of motion
    // regardless of the actual collection fps.
    // ─────────────────────────────────────────────────────────────────────────

    private fun resampleToFlat(frames: List<DoubleArray>, targetCount: Int, featureDim: Int): DoubleArray {
        val flat = DoubleArray(targetCount * featureDim)
        val n    = frames.size
        if (n == 1) {
            for (i in 0 until targetCount)
                System.arraycopy(frames[0], 0, flat, i * featureDim, featureDim)
            return flat
        }
        for (i in 0 until targetCount) {
            val srcF  = i.toFloat() * (n - 1) / (targetCount - 1)
            val srcLo = srcF.toInt().coerceIn(0, n - 1)
            val srcHi = (srcLo + 1).coerceIn(0, n - 1)
            val t     = srcF - srcLo
            for (j in 0 until featureDim)
                flat[i * featureDim + j] = frames[srcLo][j] * (1.0 - t) + frames[srcHi][j] * t
        }
        return flat
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Extract wrist-centered hand keypoints: lh(63) + rh(63) = 126 doubles.
    //
    // lh slot = image-left hand  (offset 0–62)
    // rh slot = image-right hand (offset 63–125)
    // Assigned by wrist X position, not by MediaPipe's "Left"/"Right" label,
    // because the label is unreliable when both hands are simultaneously visible.
    // ─────────────────────────────────────────────────────────────────────────

    private fun extractHandKeypoints(handResult: HandLandmarkerResult?): List<Double> {
        var lhRaw: List<Double>? = null   // lh slot (offset   0) = user's left hand
        var rhRaw: List<Double>? = null   // rh slot (offset  63) = user's right hand
        val landmarks = handResult?.landmarks() ?: emptyList()

        for (i in landmarks.indices) {
            val landmarkList = landmarks[i]
            val wristX = landmarkList.firstOrNull()?.x()?.toDouble() ?: continue
            val flat = landmarkList.flatMap { lm ->
                listOf(lm.x().toDouble(), lm.y().toDouble(), lm.z().toDouble())
            }
            // After MIRROR_FRONT_CAMERA flip the image is a selfie view:
            // user's right hand appears on the image-LEFT (X < 0.5) → rh slot.
            // user's left hand appears on the image-RIGHT (X >= 0.5) → lh slot.
            if (wristX < 0.5) {
                if (rhRaw == null) rhRaw = flat   // image-left = user's right hand
            } else {
                if (lhRaw == null) lhRaw = flat   // image-right = user's left hand
            }
            if (i == 0) {
                android.util.Log.d("SignRec",
                    "hand[$i] wristX=${String.format("%.3f", wristX)} → ${if (wristX < 0.5) "rh" else "lh"} slot")
            }
        }
        if (landmarks.size == 2) {
            val x0 = landmarks[0].firstOrNull()?.x() ?: 0f
            val x1 = landmarks[1].firstOrNull()?.x() ?: 0f
            android.util.Log.d("SignRec",
                "two hands: x0=${String.format("%.3f", x0)} x1=${String.format("%.3f", x1)}" +
                " lhRaw=${lhRaw != null} rhRaw=${rhRaw != null}")
        }

        val lh = if (lhRaw != null) adjustWrist(lhRaw) else List(63) { 0.0 }
        val rh = if (rhRaw != null) adjustWrist(rhRaw) else List(63) { 0.0 }
        return lh + rh
    }

    // Subtracts wrist (landmark 0) from all 21 landmarks. Wrist becomes (0,0,0).
    private fun adjustWrist(arr: List<Double>): List<Double> {
        val wx = arr[0]; val wy = arr[1]; val wz = arr[2]
        val out = ArrayList<Double>(63)
        var i = 0
        while (i < arr.size) {
            out += arr[i] - wx
            out += arr[i + 1] - wy
            out += arr[i + 2] - wz
            i += 3
        }
        return out
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MediaPipe init
    // ─────────────────────────────────────────────────────────────────────────

    private fun initializeMediaPipe() {
        if (initialized) return
        android.util.Log.d("SignRec", "initializeMediaPipe: loading hand model…")

        handLandmarker = HandLandmarker.createFromOptions(
            context,
            HandLandmarker.HandLandmarkerOptions.builder()
                .setBaseOptions(
                    BaseOptions.builder()
                        .setModelAssetPath(HAND_MODEL)
                        .setDelegate(Delegate.CPU)
                        .build()
                )
                // VIDEO mode uses inter-frame tracking — far higher detection rate than IMAGE mode.
                .setRunningMode(RunningMode.VIDEO)
                .setNumHands(2)
                .setMinHandDetectionConfidence(0.5f)
                .setMinHandPresenceConfidence(0.5f)
                .setMinTrackingConfidence(0.5f)
                .build()
        )

        initialized = true
        android.util.Log.d("SignRec", "initializeMediaPipe: handLandmarker OK")
    }

    // ─────────────────────────────────────────────────────────────────────────
    // EventChannel helpers
    // ─────────────────────────────────────────────────────────────────────────

    private fun emit(event: Any) {
        mainHandler.post { eventSink?.success(event) }
    }
}
