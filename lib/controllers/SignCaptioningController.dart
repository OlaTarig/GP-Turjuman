import 'dart:async';
import 'dart:collection';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'dart:convert';
import 'ZegoSessionController.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SignCaptioningController
//
// Full sign-recognition pipeline:
//   Camera frame (via ZegoSessionController._mlCamera imageStream)
//     → MediaPipe Holistic  (pose 33pts + left hand 21pts + right hand 21pts)
//       → extractKeypoints()  →  Float32List[225]
//         → rolling sequence buffer (70 frames)
//           → hasMotion() gate
//             → TCN TFLite inference  [1, 70, 225]
//               → threshold (0.3) + smoothing (window=5, consensus=3)
//                 → currentArabicSign  (notifies listeners)
//
// CaptionController listens via addListener(_onSignLabel) and calls
// its own updateCaption() → Firestore captionsBuffer.
// ─────────────────────────────────────────────────────────────────────────────

class SignCaptioningController extends ChangeNotifier {
  // ── Constants — mirror Python script exactly ───────────────────────
  static const int    _maxFrames           = 70;
  static const int    _featureDim          = 225; // 33*3 + 21*3 + 21*3
  static const double _motionThreshold     = 0.01;
  static const double _confidenceThreshold = 0.3;
  static const int    _smoothingWindow     = 5;
  static const int    _minConsensus        = 3;

  // ── Public state ───────────────────────────────────────────────────
  bool    isEnabled         = false;
  String? currentArabicSign;
  double  currentConfidence = 0.0;

  // ── Internal buffers ───────────────────────────────────────────────
  final _sequenceBuffer    = ListQueue<Float32List>();
  final _predictionHistory = ListQueue<String>();

  // ── Label data ─────────────────────────────────────────────────────
  List<dynamic>        _labelClasses = [];
  Map<String, dynamic> _labelMapping = {};

  // ── TFLite interpreter ─────────────────────────────────────────────
  Interpreter? _interpreter;
  List<int> _outputShape = [];

  // ── MediaPipe Holistic ─────────────────────────────────────────────
  // Replace with your actual MediaPipe binding.
  dynamic _holistic;

  // ── Zego controller reference (for starting/stopping ML camera) ───
  ZegoSessionController? _zegoController;

  bool _initialized = false;

  // ── Initialization ─────────────────────────────────────────────────

  Future<void> initialize() async {
    if (_initialized) return;

    // 1. Load label assets
    _labelClasses = json.decode(
      await rootBundle
          .loadString('assets/models/label_encoder_classes.json'),
    ) as List<dynamic>;

    _labelMapping = json.decode(
      await rootBundle.loadString('assets/models/label_mapping.json'),
    ) as Map<String, dynamic>;

    // 2. Load TFLite model — uncomment after adding tflite_flutter:
    //
     final options = InterpreterOptions();
     _interpreter = await Interpreter.fromAsset(
       'assets/models/tcn_final.tflite',
       options: options,
     );
    // _outputShape = _interpreter!.getOutputTensor(0).shape; // [1, numClasses]

    // 3. Initialize MediaPipe Holistic — replace with your binding:
    //
    // _holistic = await HolisticLandmarker.create(
    //   minPoseDetectionConfidence: 0.5,
    //   minTrackingConfidence:      0.5,
    // );

    _initialized = true;
    debugPrint('✅ SignCaptioningController initialized');
  }

  // ── Attach Zego controller (called by MeetingSessionManager) ───────

  void attachZegoController(ZegoSessionController controller) {
    _zegoController = controller;
  }

  // ── Enable / Disable ──────────────────────────────────────────────

  Future<void> enable() async {
    if (!_initialized) await initialize();
    _sequenceBuffer.clear();
    _predictionHistory.clear();
    currentArabicSign = null;
    currentConfidence = 0.0;
    isEnabled         = true;
    await _zegoController?.startMLCameraStream();
    notifyListeners();
    debugPrint('✅ Sign captioning ENABLED');
  }

  Future<void> disable() async {
    isEnabled         = false;
    currentArabicSign = null;
    currentConfidence = 0.0;
    _sequenceBuffer.clear();
    _predictionHistory.clear();
    await _zegoController?.stopMLCameraStream();
    notifyListeners();
    debugPrint('✅ Sign captioning DISABLED');
  }

  // ── Frame entry point (called by ZegoSessionController._mlCamera) ──

  Future<void> onVideoFrame(
      Uint8List bytes, int width, int height) async {
    if (!isEnabled || !_initialized) return;

    // 1. Run MediaPipe Holistic
    //    Replace _runHolisticStub with your actual binding call, e.g.:
    //    final result = await _holistic.processBytes(bytes, width, height);
    //    if (result.poseLandmarks == null) return;
    final result = await _runHolisticStub(bytes, width, height);
    if (result == null) return;

    // 2. Extract 225-float keypoints — mirrors Python extract_keypoints()
    final keypoints = _extractKeypoints(result);

    // 3. Push to rolling buffer
    _sequenceBuffer.addLast(keypoints);
    if (_sequenceBuffer.length > _maxFrames) _sequenceBuffer.removeFirst();

    // 4. Only infer when buffer full AND motion detected
    if (_sequenceBuffer.length < _maxFrames) return;
    if (!_hasMotion()) return;

    // 5. Run TCN inference
    final rawOutput = _runInference(_sequenceBuffer.toList());
    if (rawOutput == null) return;

    // 6. Threshold + smoothing
    final processed = _processOutput(rawOutput);
    if (processed == null) return;

    final (arabicSign, confidence) = processed;
    final smoothed = _smooth(arabicSign);
    if (smoothed == null) return;

    // 7. Publish — CaptionController._onSignLabel fires here
    currentArabicSign = smoothed;
    currentConfidence = confidence;
    notifyListeners();
  }

  // ── Keypoint extraction ────────────────────────────────────────────
  // Mirrors Python extract_keypoints() + adjust_landmarks() exactly.
  // pose: 33*3=99, lh: 21*3=63, rh: 21*3=63 → total 225

  Float32List _extractKeypoints(HolisticResult result) {
    final pose = result.poseLandmarks != null
        ? result.poseLandmarks!
        .expand((l) => [l.x, l.y, l.z])
        .toList()
        : List<double>.filled(99, 0.0);

    final lh = result.leftHandLandmarks != null
        ? result.leftHandLandmarks!
        .expand((l) => [l.x, l.y, l.z])
        .toList()
        : List<double>.filled(63, 0.0);

    final rh = result.rightHandLandmarks != null
        ? result.rightHandLandmarks!
        .expand((l) => [l.x, l.y, l.z])
        .toList()
        : List<double>.filled(63, 0.0);

    final nose    = [pose[0], pose[1], pose[2]];
    final lhWrist = [lh[0],   lh[1],   lh[2]];
    final rhWrist = [rh[0],   rh[1],   rh[2]];

    List<double> adjust(List<double> arr, List<double> anchor) {
      final out = <double>[];
      for (int i = 0; i < arr.length; i += 3) {
        out.add(arr[i]     - anchor[0]);
        out.add(arr[i + 1] - anchor[1]);
        out.add(arr[i + 2] - anchor[2]);
      }
      return out;
    }

    final combined = [
      ...adjust(pose, nose),
      ...adjust(lh,   lhWrist),
      ...adjust(rh,   rhWrist),
    ];

    assert(combined.length == _featureDim);
    return Float32List.fromList(combined);
  }

  // ── Motion detection ──────────────────────────────────────────────
  // Mirrors Python has_motion()

  bool _hasMotion() {
    final frames = _sequenceBuffer.toList();
    double total = 0.0;
    for (int i = 1; i < frames.length; i++) {
      double diff = 0.0;
      for (int j = 0; j < _featureDim; j++) {
        diff += (frames[i][j] - frames[i - 1][j]).abs();
      }
      total += diff / _featureDim;
    }
    return (total / (frames.length - 1)) > _motionThreshold;
  }

  // ── TCN Inference ─────────────────────────────────────────────────
  // Mirrors Python predict_sign():
  //   subsample to 70 frames (np.linspace) or zero-pad
  //   input shape: [1, 70, 225]

  List<double>? _runInference(List<Float32List> sequence) {
    if (_interpreter == null) return null;

    List<Float32List> seq = List.from(sequence);

    if (seq.length > _maxFrames) {
      final indices = List.generate(_maxFrames, (i) {
        return ((i * (seq.length - 1)) / (_maxFrames - 1)).round();
      });
      seq = indices.map((i) => seq[i]).toList();
    } else if (seq.length < _maxFrames) {
      final pad = Float32List(_featureDim);
      while (seq.length < _maxFrames) seq.add(pad);
    }

    final flat = Float32List(_maxFrames * _featureDim);
    for (int f = 0; f < _maxFrames; f++) {
      flat.setRange(f * _featureDim, (f + 1) * _featureDim, seq[f]);
    }

    // Uncomment when tflite_flutter is wired up:
    // final inputTensor  = flat.reshape([1, _maxFrames, _featureDim]);
    // final numClasses   = _outputShape[1];
    // final outputBuffer = List.filled(numClasses, 0.0).reshape([1, numClasses]);
    // _interpreter!.run(inputTensor, outputBuffer);
    // return List<double>.from(outputBuffer[0] as List);

    return null;
  }

  // ── Output processing ─────────────────────────────────────────────
  // Mirrors Python: argmax → confidence threshold → label mapping

  (String, double)? _processOutput(List<double> rawOutput) {
    final predIdx    = rawOutput.indexOf(rawOutput.reduce(max));
    final confidence = rawOutput[predIdx];
    if (confidence < _confidenceThreshold) return null;

    final originalLabel = _labelClasses[predIdx].toString();
    final arabicLabel   =
        _labelMapping[originalLabel] as String? ?? '؟';

    return (arabicLabel, confidence);
  }

  // ── Smoothing ─────────────────────────────────────────────────────
  // Mirrors Python Counter(recent_predictions).most_common(1)[0]

  String? _smooth(String label) {
    _predictionHistory.addLast(label);
    if (_predictionHistory.length > _smoothingWindow) {
      _predictionHistory.removeFirst();
    }
    final counts = <String, int>{};
    for (final p in _predictionHistory) {
      counts[p] = (counts[p] ?? 0) + 1;
    }
    final best =
    counts.entries.reduce((a, b) => a.value > b.value ? a : b);
    return best.value >= _minConsensus ? best.key : null;
  }

  // ── MediaPipe stub ─────────────────────────────────────────────────
  // Remove once your MediaPipe binding is wired up.
  Future<HolisticResult?> _runHolisticStub(
      Uint8List bytes, int width, int height) async {
    return null; // null = no person detected → frame skipped
  }

  // ── Dispose ───────────────────────────────────────────────────────
  @override
  void dispose() {
    // _holistic?.close();
    // _interpreter?.close();
    super.dispose();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Data classes — replace with actual types from your MediaPipe binding
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