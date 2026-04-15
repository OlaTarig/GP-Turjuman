import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'gesture_data.dart';

/// Loads and stores the sign language gesture dictionary.
///
/// Dictionary format (assets/signs_dictionary.json):
/// ```json
/// {
///   "signs": {
///     "مرحبا": { "videoPath": "assets/signs/مرحبا.mp4", "durationMs": 2000, "word": "مرحبا" },
///     "ا":    { "videoPath": "assets/fingerspelling/ا.mp4", "durationMs": 800, "word": "ا" }
///   }
/// }
/// ```
class HandModel {
  static const String _defaultAssetPath = 'assets/signs_dictionary.json';

  Map<String, GestureData> _gestureMap = {};

  /// Unmodifiable view of the gesture map.
  Map<String, GestureData> get gestureMap => Map.unmodifiable(_gestureMap);

  // ── Initialization ─────────────────────────────────────────────────

  /// Loads the gesture dictionary from a bundled JSON asset.
  /// Safe to call multiple times — subsequent calls reload the dictionary.
  Future<void> loadFromAsset([String assetPath = _defaultAssetPath]) async {
    try {
      final jsonStr = await rootBundle.loadString(assetPath);
      final jsonMap = json.decode(jsonStr) as Map<String, dynamic>;
      final signs = jsonMap['signs'] as Map<String, dynamic>? ?? {};

      _gestureMap = signs.map(
        (key, value) =>
            MapEntry(key, GestureData.fromJson(value as Map<String, dynamic>)),
      );

      debugPrint('✅ HandModel: loaded ${_gestureMap.length} gestures');
    } catch (e) {
      debugPrint('⚠️ HandModel: failed to load dictionary — $e');
      _gestureMap = {};
    }
  }

  // ── Query ───────────────────────────────────────────────────────────

  /// Returns the [GestureData] for [gestureName], or null if not found.
  GestureData? getGesture(String gestureName) => _gestureMap[gestureName];

  /// Returns true when [word] has a corresponding video in the dictionary.
  bool hasGesture(String word) => _gestureMap.containsKey(word);

  /// All words/letters that have a registered gesture.
  List<String> listGestures() => _gestureMap.keys.toList();

  // ── Mutation ────────────────────────────────────────────────────────

  /// Registers or replaces a gesture at runtime (e.g. for dynamic download).
  void addGesture(String gestureName, GestureData gestureData) {
    _gestureMap = Map.from(_gestureMap)..[gestureName] = gestureData;
    debugPrint('➕ HandModel: added gesture for "$gestureName"');
  }
}
