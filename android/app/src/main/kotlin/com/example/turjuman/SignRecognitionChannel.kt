package com.example.turjuman

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.ImageFormat
import android.graphics.Matrix
import android.graphics.Rect
import android.graphics.YuvImage
import com.google.mediapipe.framework.image.BitmapImageBuilder
import com.google.mediapipe.tasks.core.BaseOptions
import com.google.mediapipe.tasks.core.Delegate
import com.google.mediapipe.tasks.vision.core.RunningMode
import com.google.mediapipe.tasks.vision.handlandmarker.HandLandmarker
import com.google.mediapipe.tasks.vision.handlandmarker.HandLandmarkerResult
import com.google.mediapipe.tasks.vision.poselandmarker.PoseLandmarker
import com.google.mediapipe.tasks.vision.poselandmarker.PoseLandmarkerResult
import im.zego.zegoexpress.ZegoExpressEngine
import im.zego.zegoexpress.callback.IZegoCustomVideoProcessHandler
import im.zego.zegoexpress.constants.ZegoPublishChannel
import im.zego.zegoexpress.constants.ZegoVideoBufferType
import im.zego.zegoexpress.entity.ZegoCustomVideoProcessConfig
import im.zego.zegoexpress.entity.ZegoVideoFrameParam
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.nio.ByteBuffer
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Platform channel handler that exposes MediaPipe pose + hand landmark detection to Flutter,
 * using Zego's IZegoCustomVideoProcessHandler to intercept camera frames natively —
 * no second CameraController needed.
 *
 * MethodChannel  : "com.example.turjuman/sign_recognition"
 * EventChannel   : "com.example.turjuman/sign_keypoints"
 *
 * Methods
 * -------
 * initialize()
 *   Creates PoseLandmarker and HandLandmarker from model files in Android assets.
 *
 * setupVideoProcessing()
 *   Registers Zego custom video processing handler.
 *   Must be called AFTER ZegoExpressEngine.createEngineWithProfile()
 *   and BEFORE ZegoExpressEngine.startPublishingStream().
 *
 * startContinuous()
 *   Activates frame processing. Frames start flowing to the EventChannel.
 *
 * stopContinuous()
 *   Pauses frame processing. Zego video continues unaffected.
 *
 * dispose()
 *   Releases landmarkers and shuts down the executor.
 *
 * EventChannel events
 * -------------------
 * String "handsOutOfFrame"  — no pose/hands detected
 * String "handsDetected"    — hands re-appeared
 * List<double> (10 800)     — 48 frames × 225 keypoints flattened, ready for TFLite
 */
class SignRecognitionChannel(
    private val context: Context,
    private val binaryMessenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL_NAME       = "com.example.turjuman/sign_recognition"
        const val EVENT_CHANNEL_NAME = "com.example.turjuman/sign_keypoints"

        private const val POSE_MODEL  = "models/pose_landmarker_lite.task"
        private const val HAND_MODEL  = "models/hand_landmarker.task"
        private const val FEATURE_DIM = 225
        private const val NUM_FRAMES  = 48
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
    private var poseLandmarker: PoseLandmarker? = null
    private var handLandmarker: HandLandmarker? = null
    private var initialized      = false

    // ── Background executor (single thread — frames processed in order) ───────
    private val executor: ExecutorService = Executors.newSingleThreadExecutor()
    private val isProcessing              = AtomicBoolean(false)

    // ── State ─────────────────────────────────────────────────────────────────
    @Volatile private var isCapturing = false

    // Native-side frame accumulation buffer (48 frames of 225 doubles each)
    private val nativeFrameBuffer = mutableListOf<DoubleArray>()

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
                    result.error("SETUP_ERROR", "Video processing setup failed: ${e.message}", null)
                }
            }

            "startContinuous" -> {
                nativeFrameBuffer.clear()
                isCapturing = true
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
                poseLandmarker?.close()
                handLandmarker?.close()
                poseLandmarker = null
                handLandmarker = null
                initialized    = false
                executor.shutdown()
                result.success(null)
            }

            else -> result.notImplemented()
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Zego custom video processing
    // ─────────────────────────────────────────────────────────────────────────

    private fun setupZegoVideoProcessing() {
        val engine = ZegoExpressEngine.getEngine()
            ?: throw IllegalStateException("Zego engine not yet created")

        val config = ZegoCustomVideoProcessConfig()
        config.bufferType = ZegoVideoBufferType.RAW_DATA
        engine.enableCustomVideoProcessing(true, config, ZegoPublishChannel.MAIN)

        engine.setCustomVideoProcessHandler(object : IZegoCustomVideoProcessHandler() {

            override fun onCapturedUnprocessedRawData(
                data: ByteBuffer,
                dataLength: IntArray,
                param: ZegoVideoFrameParam,
                referenceTimeMillisecond: Long,
                channel: ZegoPublishChannel,
            ) {
                // 1. Copy bytes before the buffer is recycled by Zego.
                val totalSize = dataLength.sum()
                val copy      = ByteArray(totalSize)
                data.rewind()
                data.get(copy, 0, totalSize)
                // SDK 3.x passes the frame through automatically after the
                // callback returns — no sendCustomVideoProcessedRawData needed.

                // 2. Process for sign recognition when active and not already busy.
                if (!isCapturing) return
                if (!isProcessing.compareAndSet(false, true)) return // drop frame if busy

                val width  = param.width
                val height = param.height
                val dl     = dataLength.clone()

                executor.execute {
                    try {
                        handleSignFrame(copy, width, height, dl)
                    } finally {
                        isProcessing.set(false)
                    }
                }
            }
        })
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Per-frame sign processing
    // ─────────────────────────────────────────────────────────────────────────

    private fun handleSignFrame(
        rawData: ByteArray,
        width: Int,
        height: Int,
        dataLength: IntArray,
    ) {
        try {
            val nv21   = i420ToNv21(rawData, width, height, dataLength)
            val bitmap = nv21ToBitmap(nv21, width, height, rotationDegrees = 270)
            if (bitmap == null) {
                emit("handsOutOfFrame")
                return
            }

            val mpImage    = BitmapImageBuilder(bitmap).build()
            val poseResult = poseLandmarker?.detect(mpImage)
            val handResult = handLandmarker?.detect(mpImage)

            if (poseResult == null || poseResult.landmarks().isEmpty()) {
                emit("handsOutOfFrame")
                return
            }

            emit("handsDetected")

            val keypoints = extractAndNormalizeKeypoints(poseResult, handResult!!)
            nativeFrameBuffer.add(keypoints.toDoubleArray())

            if (nativeFrameBuffer.size >= NUM_FRAMES) {
                // Flatten 48 × 225 = 10 800 doubles and send to Dart for TFLite.
                val flat = DoubleArray(NUM_FRAMES * FEATURE_DIM)
                for (f in 0 until NUM_FRAMES) {
                    val frame = nativeFrameBuffer[f]
                    System.arraycopy(frame, 0, flat, f * FEATURE_DIM, FEATURE_DIM)
                }
                nativeFrameBuffer.clear()
                emit(flat.toList()) // List<Double>
            }
        } catch (e: Exception) {
            // Silently skip bad frames — don't crash the processing loop.
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // I420 → NV21 conversion
    //
    // I420 layout : Y plane | U plane | V plane   (U and V separate)
    // NV21 layout : Y plane | VU interleaved
    // ─────────────────────────────────────────────────────────────────────────

    private fun i420ToNv21(
        data: ByteArray, width: Int, height: Int, dataLength: IntArray,
    ): ByteArray {
        val ySize  = dataLength[0]             // width × height
        val uSize  = dataLength[1]             // width/2 × height/2
        val uStart = ySize
        val vStart = ySize + uSize
        val uvPixels = uSize                   // same as vSize

        val nv21 = ByteArray(ySize + uvPixels * 2)
        System.arraycopy(data, 0, nv21, 0, ySize) // copy Y unchanged

        // Interleave V, U (NV21 is V-first)
        var dst = ySize
        for (i in 0 until uvPixels) {
            nv21[dst++] = data[vStart + i]
            nv21[dst++] = data[uStart + i]
        }
        return nv21
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MediaPipe init
    // ─────────────────────────────────────────────────────────────────────────

    private fun initializeMediaPipe() {
        if (initialized) return

        poseLandmarker = PoseLandmarker.createFromOptions(
            context,
            PoseLandmarker.PoseLandmarkerOptions.builder()
                .setBaseOptions(
                    BaseOptions.builder()
                        .setModelAssetPath(POSE_MODEL)
                        .setDelegate(Delegate.CPU)
                        .build()
                )
                .setRunningMode(RunningMode.IMAGE)
                .setNumPoses(1)
                .setMinPoseDetectionConfidence(0.5f)
                .setMinPosePresenceConfidence(0.5f)
                .setMinTrackingConfidence(0.5f)
                .build()
        )

        handLandmarker = HandLandmarker.createFromOptions(
            context,
            HandLandmarker.HandLandmarkerOptions.builder()
                .setBaseOptions(
                    BaseOptions.builder()
                        .setModelAssetPath(HAND_MODEL)
                        .setDelegate(Delegate.CPU)
                        .build()
                )
                .setRunningMode(RunningMode.IMAGE)
                .setNumHands(2)
                .setMinHandDetectionConfidence(0.5f)
                .setMinHandPresenceConfidence(0.5f)
                .setMinTrackingConfidence(0.5f)
                .build()
        )

        initialized = true
    }

    // ─────────────────────────────────────────────────────────────────────────
    // NV21 → Bitmap
    // ─────────────────────────────────────────────────────────────────────────

    private fun nv21ToBitmap(
        nv21: ByteArray, width: Int, height: Int, rotationDegrees: Int,
    ): Bitmap? = try {
        val yuv  = YuvImage(nv21, ImageFormat.NV21, width, height, null)
        val baos = ByteArrayOutputStream()
        yuv.compressToJpeg(Rect(0, 0, width, height), 85, baos)
        var bmp  = BitmapFactory.decodeByteArray(baos.toByteArray(), 0, baos.size())
            ?: return null
        if (rotationDegrees != 0) {
            val m = Matrix().apply { postRotate(rotationDegrees.toFloat()) }
            bmp = Bitmap.createBitmap(bmp, 0, 0, bmp.width, bmp.height, m, true)
        }
        bmp
    } catch (e: Exception) { null }

    // ─────────────────────────────────────────────────────────────────────────
    // Keypoint extraction — must mirror Python training code exactly
    //
    // Python reference:
    //   def adjust_landmarks(landmarks, center_idx=0):
    //       arr = np.array([[l.x, l.y, l.z] for l in landmarks])
    //       arr -= arr[center_idx]
    //       return arr.flatten()
    //
    //   features = np.concatenate([
    //       adjust_landmarks(pose, center_idx=0),   # nose
    //       adjust_landmarks(lh,  center_idx=0),   # left wrist
    //       adjust_landmarks(rh,  center_idx=0),   # right wrist
    //   ])
    // ─────────────────────────────────────────────────────────────────────────

    private fun extractAndNormalizeKeypoints(
        poseResult: PoseLandmarkerResult,
        handResult: HandLandmarkerResult,
    ): List<Double> {
        val poseRaw: List<Double> = poseResult.landmarks().firstOrNull()
            ?.flatMap { lm -> listOf(lm.x().toDouble(), lm.y().toDouble(), lm.z().toDouble()) }
            ?: List(99) { 0.0 }

        var lhRaw: List<Double>? = null
        var rhRaw: List<Double>? = null
        for (i in handResult.handednesses().indices) {
            val category  = handResult.handednesses()[i].firstOrNull()?.categoryName() ?: continue
            val landmarks = handResult.landmarks().getOrNull(i) ?: continue
            val flat      = landmarks.flatMap { lm ->
                listOf(lm.x().toDouble(), lm.y().toDouble(), lm.z().toDouble())
            }
            when (category) {
                "Left"  -> lhRaw = flat
                "Right" -> rhRaw = flat
            }
        }
        val lh = lhRaw ?: List(63) { 0.0 }
        val rh = rhRaw ?: List(63) { 0.0 }

        val nose    = doubleArrayOf(poseRaw[0], poseRaw[1], poseRaw[2])
        val lhWrist = doubleArrayOf(lh[0],      lh[1],      lh[2])
        val rhWrist = doubleArrayOf(rh[0],      rh[1],      rh[2])

        return adjust(poseRaw, nose) + adjust(lh, lhWrist) + adjust(rh, rhWrist)
    }

    private fun adjust(arr: List<Double>, anchor: DoubleArray): List<Double> {
        val out = ArrayList<Double>(arr.size)
        var i = 0
        while (i < arr.size) {
            out += arr[i]     - anchor[0]
            out += arr[i + 1] - anchor[1]
            out += arr[i + 2] - anchor[2]
            i += 3
        }
        return out
    }

    // ─────────────────────────────────────────────────────────────────────────
    // EventChannel helpers
    // ─────────────────────────────────────────────────────────────────────────

    private fun emit(event: Any) {
        mainHandler.post { eventSink?.success(event) }
    }
}
