import 'package:flutter/foundation.dart';

// Static cross-class timer: one class calls startTimer(), another calls stopTimer().
// Used to measure end-to-end latency that spans multiple controllers.
final _globalTimers = <String, DateTime>{};

class LatencyLogger {
  static void startTimer(String key) {
    _globalTimers[key] = DateTime.now();
  }

  static void stopTimer(String key, LatencyLogger logger) {
    final start = _globalTimers.remove(key);
    if (start == null) return;
    logger.record(DateTime.now().difference(start).inMilliseconds);
  }
  final String name;
  final int thresholdMs;
  final int minSamples;

  final List<int> _measurements = [];

  LatencyLogger({
    required this.name,
    required this.thresholdMs,
    this.minSamples = 10,
  });

  void record(int ms) {
    _measurements.add(ms);
    final passed = ms <= thresholdMs;
    debugPrint('⏱️ [PERF] $name: ${ms}ms ${passed ? "✅ PASS" : "❌ FAIL"} '
        '(${_measurements.length}/$minSamples samples)');

    if (_measurements.length >= minSamples) {
      printReport();
      _measurements.clear();
    }
  }

  void printReport() {
    if (_measurements.isEmpty) return;

    final sorted = List<int>.from(_measurements)..sort();
    final avg = _measurements.reduce((a, b) => a + b) ~/ _measurements.length;
    final min = sorted.first;
    final max = sorted.last;
    final p95 = sorted[(sorted.length * 0.95).floor().clamp(0, sorted.length - 1)];
    final passCount = _measurements.where((ms) => ms <= thresholdMs).length;
    final passRate = (passCount / _measurements.length * 100).toStringAsFixed(0);

    debugPrint('');
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('📊 [$name] LATENCY REPORT (${_measurements.length} samples)');
    debugPrint('   Threshold : ${thresholdMs}ms');
    debugPrint('   Min       : ${min}ms');
    debugPrint('   Max       : ${max}ms');
    debugPrint('   Average   : ${avg}ms');
    debugPrint('   P95       : ${p95}ms');
    debugPrint('   Pass rate : $passRate% ($passCount/${_measurements.length})');
    debugPrint('   Result    : ${passCount == _measurements.length ? "✅ ALL PASS" : "❌ SOME FAILED"}');
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('');
  }

  void reset() => _measurements.clear();
}
