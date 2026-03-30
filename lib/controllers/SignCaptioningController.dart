import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'dart:convert';
import 'CaptionController.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SignCaptioningController — continuous real-time sign recognition
//
// Pipeline (toggled on/off by button press):
//   User enables Sign mode
//     → native SignRecognitionChannel intercepts Zego camera frames
//       → MediaPipe extracts 225 keypoints per frame
//         → 48-frame batches (10 800 floats) streamed to Dart via EventChannel
//           → TCN TFLite inference  [1, 48, 225]
//             → top-5 predictions (confidence-sorted)
//               → currentArabicSign + topPredictions notified to listeners
//                 → automatically ready for the next sign
//
// Native Android (SignRecognitionChannel.kt) handles:
//   Zego IZegoCustomVideoProcessHandler → I420→NV21→Bitmap → MediaPipe → 225 floats
//   Accumulates 48 frames natively, then sends a flat List<double>(10 800) via EventChannel.
//   Sends "handsOutOfFrame" / "handsDetected" String events for UX feedback.
//
// Zego video is always passed through unmodified — sign mode adds zero latency to video.
// ─────────────────────────────────────────────────────────────────────────────

enum CaptureState { idle, capturing, inferring }

class SignPrediction {
  final String arabicWord;
  final double confidence;
  const SignPrediction(this.arabicWord, this.confidence);
}

class SignCaptioningController extends ChangeNotifier {
  // ── Constants — must match training ───────────────────────────────
  static const int    _numFrames           = 48;
  static const int    _featureDim          = 225; // 33*3 + 21*3 + 21*3
  static const double _confidenceThreshold = 0.3;

  // ── Platform channels ──────────────────────────────────────────────
  static const _methodChannel = MethodChannel('com.example.turjuman/sign_recognition');
  static const _eventChannel  = EventChannel('com.example.turjuman/sign_keypoints');

  // ── Public state ───────────────────────────────────────────────────
  CaptureState         captureState      = CaptureState.idle;
  List<SignPrediction> topPredictions    = [];
  String?              currentArabicSign;
  double               currentConfidence = 0.0;
  bool                 isEnabled         = false;

  /// True when native reports no hands/pose for [_maxNoDetectionFrames].
  bool handsOutOfFrame = false;

  // captureProgress is always 0 with native accumulation
  // (48 frames are buffered on the Kotlin side, then sent as one batch)
  double get captureProgress => 0.0;

  // ── Internal ───────────────────────────────────────────────────────
  StreamSubscription<dynamic>? _keypointsSub;

  // Hands-out-of-frame tracking
  int  _noDetectionFrames    = 0;
  static const int _maxNoDetectionFrames = 20;

  // Sentence accumulation
  final _sentenceWords = <String>[];
  Timer? _sentenceFlushTimer;
  static const Duration _sentenceFlushDelay = Duration(seconds: 3);

  CaptionController? _captionController;
  String _userId    = '';
  String _userName  = '';
  String _meetingId = '';

  List<dynamic>        _labelClasses = [];
  Map<String, dynamic> _labelMapping = {};

  Interpreter? _interpreter;
  bool         _initialized = false;

  // ── Initialization ─────────────────────────────────────────────────

  Future<void> initialize() async {
    if (_initialized) return;

    // 1. Label encoder
    _labelClasses = json.decode(
      await rootBundle.loadString('assets/model/le_48_clean_final.json'),
    ) as List<dynamic>;

    // 2. Word mapping
    _labelMapping = json.decode(
      await rootBundle.loadString('assets/model/label_mapping.json'),
    ) as Map<String, dynamic>;

    // 3. TFLite model — input [1, 48, 225], output [1, N]
    _interpreter = await Interpreter.fromAsset(
      'assets/model/tcn_48_clean_final.tflite',
      options: InterpreterOptions(),
    );

    // 4. Initialize native MediaPipe landmarkers
    await _methodChannel.invokeMethod<void>('initialize');

    _initialized = true;
    debugPrint('✅ SignCaptioningController initialized');
  }

  // ── One-time Zego hook setup ───────────────────────────────────────
  //
  // Must be called AFTER ZegoExpressEngine is created (session.initialize())
  // and BEFORE startPublishingStream (session.startPublishing()).

  Future<void> setupVideoProcessing() async {
    if (!_initialized) await initialize();
    await _methodChannel.invokeMethod<void>('setupVideoProcessing');
    debugPrint('✅ Zego custom video processing hook registered');
  }

  // ── Attach/detach CaptionController ───────────────────────────────

  void attachCaptionController(
      CaptionController cc, String userId, String userName, String meetingId) {
    _captionController = cc;
    _userId    = userId;
    _userName  = userName;
    _meetingId = meetingId;
  }

  // ── Enable / Disable ──────────────────────────────────────────────

  Future<void> enable() async {
    if (!_initialized) await initialize();
    if (isEnabled) return;

    isEnabled          = true;
    handsOutOfFrame    = false;
    _noDetectionFrames = 0;
    captureState       = CaptureState.capturing;
    topPredictions     = [];

    await _methodChannel.invokeMethod<void>('startContinuous');

    _keypointsSub = _eventChannel.receiveBroadcastStream().listen(
      _onKeypointEvent,
      onError: (e) => debugPrint('⚠️ sign_keypoints channel error: $e'),
    );

    notifyListeners();
    debugPrint('✅ Sign captioning ENABLED (continuous native)');
  }

  Future<void> disable() async {
    isEnabled          = false;
    captureState       = CaptureState.idle;
    topPredictions     = [];
    currentArabicSign  = null;
    currentConfidence  = 0.0;
    handsOutOfFrame    = false;
    _noDetectionFrames = 0;

    await _methodChannel.invokeMethod<void>('stopContinuous');
    await _keypointsSub?.cancel();
    _keypointsSub = null;

    // Flush any words the user signed before disabling
    _sentenceFlushTimer?.cancel();
    _flushSentence();

    notifyListeners();
    debugPrint('✅ Sign captioning DISABLED');
  }

  // ── Continuous toggle ──────────────────────────────────────────────

  Future<void> startCapture() async {
    if (!isEnabled) await enable();
  }

  // ── EventChannel handler ───────────────────────────────────────────

  void _onKeypointEvent(dynamic event) {
    if (event is String) {
      if (event == 'handsOutOfFrame') {
        _noDetectionFrames++;
        if (_noDetectionFrames >= _maxNoDetectionFrames && !handsOutOfFrame) {
          handsOutOfFrame = true;
          notifyListeners();
        }
      } else if (event == 'handsDetected') {
        if (_noDetectionFrames > 0 || handsOutOfFrame) {
          _noDetectionFrames = 0;
          handsOutOfFrame    = false;
          notifyListeners();
        }
      }
    } else if (event is List && isEnabled) {
      // 10 800 values = 48 frames × 225 keypoints, sent as List<dynamic>
      final flat = event.map<double>((e) => (e as num).toDouble()).toList();
      _runInferenceFromFlat(flat);
    }
  }

  // ── Inference ──────────────────────────────────────────────────────

  Future<void> _runInferenceFromFlat(List<double> flat) async {
    if (_interpreter == null) return;
    if (flat.length < _numFrames * _featureDim) return;

    captureState = CaptureState.inferring;
    notifyListeners();

    try {
      // Build flat [1, 48, 225] float32 input
      final inputFlat = Float32List(_numFrames * _featureDim);
      for (int i = 0; i < _numFrames * _featureDim; i++) {
        inputFlat[i] = flat[i];
      }
      final inputTensor = inputFlat.reshape([1, _numFrames, _featureDim]);

      // Output buffer [1, numClasses]
      final numClasses   = _interpreter!.getOutputTensor(0).shape[1];
      final outputBuffer = [List<double>.filled(numClasses, 0.0)];
      _interpreter!.run(inputTensor, outputBuffer);

      final rawOutput = List<double>.from(outputBuffer[0] as List);
      topPredictions  = _buildTop5(rawOutput);

      if (topPredictions.isNotEmpty &&
          topPredictions.first.confidence >= _confidenceThreshold) {
        currentArabicSign = topPredictions.first.arabicWord;
        currentConfidence = topPredictions.first.confidence;
        _onSignRecognized(currentArabicSign!);
      } else {
        currentArabicSign = null;
        currentConfidence = 0.0;
      }

      debugPrint('✅ Sign: $currentArabicSign '
          '(${(currentConfidence * 100).toStringAsFixed(1)}%)');
    } catch (e) {
      debugPrint('❌ Inference error: $e');
    } finally {
      // Auto-restart continuous capture while sign mode is active
      captureState = isEnabled ? CaptureState.capturing : CaptureState.idle;
      notifyListeners();
    }
  }

  // ── Sentence accumulation ─────────────────────────────────────────

  void _onSignRecognized(String word) {
    _sentenceWords.add(word);
    _sentenceFlushTimer?.cancel();
    _sentenceFlushTimer = Timer(_sentenceFlushDelay, _flushSentence);
  }

  void _flushSentence() {
    if (_sentenceWords.isEmpty) return;
    final sentence = _sentenceWords.join(' ');
    _sentenceWords.clear();
    _captionController?.pushSignCaption(
        sentence, _userId, _userName, _meetingId);
    debugPrint('🤟 Sentence flushed: $sentence');
  }

  // ── Label lookup ───────────────────────────────────────────────────

  List<SignPrediction> _buildTop5(List<double> rawOutput) {
    final indexed = List.generate(rawOutput.length, (i) => MapEntry(i, rawOutput[i]));
    indexed.sort((a, b) => b.value.compareTo(a.value));

    final top5 = <SignPrediction>[];
    for (final entry in indexed.take(5)) {
      if (entry.key >= _labelClasses.length) continue;
      final originalLabel = _labelClasses[entry.key].toString();
      final arabicWord    = _labelMapping[originalLabel]?.toString() ?? '؟';
      top5.add(SignPrediction(arabicWord, entry.value));
    }
    return top5;
  }

  // ── Dispose ───────────────────────────────────────────────────────

  @override
  void dispose() {
    _keypointsSub?.cancel();
    _methodChannel.invokeMethod<void>('dispose').ignore();
    _interpreter?.close();
    super.dispose();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Legacy data classes (kept for API compatibility)
// ─────────────────────────────────────────────────────────────────────────────

class LandmarkPoint {
  final double x, y, z;
  const LandmarkPoint(this.x, this.y, this.z);
}

class HolisticResult {
  final List<LandmarkPoint>? poseLandmarks;
  final List<LandmarkPoint>? leftHandLandmarks;
  final List<LandmarkPoint>? rightHandLandmarks;
  const HolisticResult({
    this.poseLandmarks,
    this.leftHandLandmarks,
    this.rightHandLandmarks,
  });
}
