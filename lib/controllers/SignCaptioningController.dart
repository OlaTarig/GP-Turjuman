import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'dart:convert';
import 'CaptionController.dart';
import 'sign_recognition_controller.dart';

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
  static const int    _featureDim          = 126; // lh(63)+rh(63), wrist-centered by native
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

  // null = indeterminate (animated) — frames are accumulated natively,
  // so there is no per-frame progress to report from Dart.
  double? get captureProgress => null;

  // ── Internal ───────────────────────────────────────────────────────
  StreamSubscription<dynamic>? _keypointsSub;

  // Hands-out-of-frame tracking
  int  _noDetectionFrames    = 0;
  static const int _maxNoDetectionFrames = 20;

  // Sentence accumulation
  final _sentenceWords = <String>[];
  Timer? _sentenceFlushTimer;
  static const Duration _sentenceFlushDelay = Duration(seconds: 1);

  CaptionController? _captionController;
  SignRecognitionController? _recognitionController;
  String _userId    = '';
  String _userName  = '';
  String _meetingId = '';

  Map<String, dynamic> _labelMapping = {};

  Interpreter? _interpreter;
  bool         _initialized = false;

  // ── Initialization ─────────────────────────────────────────────────

  Future<void> initialize() async {
    if (_initialized) return;

    // label_map.json: {"0": {"orig_label": N, "sign_arabic": "...", "sign_english": "..."}, ...}
    _labelMapping = json.decode(
      await rootBundle.loadString('assets/models/label_map.json'),
    ) as Map<String, dynamic>;

    // TFLite model — input [1, 48, 225], output [1, N]
    _interpreter = await Interpreter.fromAsset(
      'assets/models/model_good.tflite',
      options: InterpreterOptions(),
    );

    // Initialize native MediaPipe landmarkers
    await _methodChannel.invokeMethod<void>('initialize');

    _initialized = true;
    debugPrint('✅ SignCaptioningController initialized');
    debugPrint('📐 model input shape:  ${_interpreter!.getInputTensor(0).shape}');
    debugPrint('📐 model output shape: ${_interpreter!.getOutputTensor(0).shape}');
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

  void attachRecognitionController(SignRecognitionController r) {
    _recognitionController = r;
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
      debugPrint('🤟 Batch received from native: ${event.length} values');
      _recognitionController?.receiveBatch(event);
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
      // Native already sends wrist-centered lh(63)+rh(63) per frame — use directly.
      final inputFlat = Float32List(flat.length);
      for (int i = 0; i < flat.length; i++) inputFlat[i] = flat[i];
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

      final topVal = topPredictions.isNotEmpty ? topPredictions.first.confidence : 0.0;
      debugPrint('🔍 Inference done — top: ${topPredictions.isNotEmpty ? topPredictions.first.arabicWord : "none"} '
          '(${(topVal * 100).toStringAsFixed(1)}%), threshold=${(_confidenceThreshold * 100).toStringAsFixed(0)}%');
      debugPrint('✅ Sign accepted: $currentArabicSign '
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
    // Single-char words are individual letters — concatenate them directly.
    // Multi-char words (full words) are separated by spaces.
    final buf = StringBuffer();
    for (final word in _sentenceWords) {
      if (word.length == 1) {
        buf.write(word);
      } else {
        if (buf.isNotEmpty) buf.write(' ');
        buf.write(word);
      }
    }
    final sentence = buf.toString();
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
      final info = _labelMapping[entry.key.toString()] as Map<String, dynamic>?;
      if (info == null) continue;
      final arabicWord = info['sign_arabic']?.toString() ?? '؟';
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
