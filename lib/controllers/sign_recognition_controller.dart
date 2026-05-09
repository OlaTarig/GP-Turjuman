import 'dart:typed_data';
import 'package:flutter/foundation.dart' show ChangeNotifier, debugPrint;
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'dart:convert';

enum SignRecogState { idle, active, results }

class SignRecogPrediction {
  final String arabic;
  final String english;
  final double confidence;
  const SignRecogPrediction({
    required this.arabic,
    required this.english,
    required this.confidence,
  });
}

class SignRecognitionController extends ChangeNotifier {
  static const int _numFrames = 48;
  static const int _featureDim = 126; // lh(63)+rh(63), wrist-centered by native

  SignRecogState state = SignRecogState.idle;
  List<SignRecogPrediction> topPredictions = [];
  bool leftHandVisible = false;
  bool rightHandVisible = false;

  Interpreter? _interp;
  Map<int, Map<String, String>> _labelMap = {};
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    final jsonStr = await rootBundle.loadString('assets/models/label_map.json');
    final raw = json.decode(jsonStr) as Map<String, dynamic>;
    _labelMap = {};
    raw.forEach((k, v) {
      final idx = int.tryParse(k);
      if (idx == null || v is! Map) return;
      _labelMap[idx] = {
        'arabic': (v['sign_arabic'] ?? '?').toString(),
        'english': (v['sign_english'] ?? '?').toString(),
      };
    });
    _interp = await Interpreter.fromAsset('assets/models/model_good.tflite');
    _initialized = true;
    debugPrint('✅ SignRecognitionController initialized (${_labelMap.length} labels)');
  }

  /// Start continuous recognition — called when sign captioning is enabled.
  /// Batches are forwarded by SignCaptioningController (shared EventChannel).
  Future<void> enable() async {
    if (state != SignRecogState.idle) return;
    if (!_initialized) await initialize();
    state = SignRecogState.active;
    topPredictions = [];
    leftHandVisible = false;
    rightHandVisible = false;
    notifyListeners();
  }

  /// Called by SignCaptioningController to forward a raw 10 800-value batch.
  void receiveBatch(List<dynamic> batch) {
    if (state != SignRecogState.idle) _onEvent(batch);
  }

  Future<void> disable() async {
    state = SignRecogState.idle;
    topPredictions = [];
    leftHandVisible = false;
    rightHandVisible = false;
    notifyListeners();
  }

  void clearResults() {
    if (state == SignRecogState.results) {
      topPredictions = [];
      leftHandVisible = false;
      rightHandVisible = false;
      state = SignRecogState.active;
      notifyListeners();
    }
  }

  void _onEvent(dynamic event) {
    if (event is List && state != SignRecogState.idle) {
      _processAndInfer(event);
    }
  }

  Future<void> _processAndInfer(List<dynamic> rawBatch) async {
    try {
      final flat = rawBatch.map<double>((e) => (e as num).toDouble()).toList();
      if (flat.length < _numFrames * _featureDim) return;

      // Determine per-hand visibility from last frame.
      // After the front-camera horizontal un-mirror, MediaPipe labels the user's
      // actual right hand as "Left", so right-hand keypoints land in the lh slot
      // (offset 0) and left-hand keypoints land in the rh slot (offset 63).
      // Swap the display check so the badges reflect the user's actual hands.
      final lastOff = (_numFrames - 1) * _featureDim;
      rightHandVisible = _handPresent(flat, lastOff);        // lh slot = actual right hand
      leftHandVisible  = _handPresent(flat, lastOff + 63);   // rh slot = actual left hand

      // Build input tensor [1, 48, 126]
      final inputFlat = Float32List(flat.length);
      for (int i = 0; i < flat.length; i++) inputFlat[i] = flat[i];
      final inputTensor = inputFlat.reshape([1, _numFrames, _featureDim]);

      final numClasses = _interp!.getOutputTensor(0).shape[1];
      final out = [List<double>.filled(numClasses, 0.0)];
      _interp!.run(inputTensor, out);

      final probs = List<double>.from(out[0] as List);
      topPredictions = _top5(probs);
      state = SignRecogState.results;

      debugPrint('🤟 SignRecognition: ${topPredictions.isNotEmpty ? "${topPredictions.first.arabic} (${(topPredictions.first.confidence * 100).toStringAsFixed(1)}%)" : "none"}');
    } catch (e) {
      debugPrint('❌ SignRecognition error: $e');
    }
    notifyListeners();
  }

  List<SignRecogPrediction> _top5(List<double> probs) {
    final indexed = List.generate(probs.length, (i) => MapEntry(i, probs[i]));
    indexed.sort((a, b) => b.value.compareTo(a.value));
    return indexed.take(5).map((e) {
      final label = _labelMap[e.key];
      return SignRecogPrediction(
        arabic: label?['arabic'] ?? '؟',
        english: label?['english'] ?? '?',
        confidence: e.value,
      );
    }).toList();
  }

  bool _handPresent(List<double> flat, int start) {
    double sum = 0;
    for (int j = 0; j < 63; j++) sum += flat[start + j].abs();
    return sum > 0.01;
  }

  @override
  void dispose() {
    _interp?.close();
    super.dispose();
  }
}

