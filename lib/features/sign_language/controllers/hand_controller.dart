import 'dart:collection';
import 'package:flutter/foundation.dart';
import '../models/hand_model.dart';
import '../models/gesture_data.dart';

/// Manages the sign animation queue and drives [HandView] via ChangeNotifier.
///
/// Token types accepted in [setText]:
///   • plain Arabic word  — looked up directly in [HandModel]
///   • `#fingerspell:XYZ` — expanded into individual `#letter:X`, `#letter:Y`, …
///
/// [HandView] should call [onVideoFinished] when the current clip ends so
/// the controller can advance to the next queued token.
class HandController extends ChangeNotifier {
  final HandModel _handModel;

  final Queue<String> _queue = Queue();

  bool _isPlaying = false;
  bool _stopRequested = false;
  String? _currentWord;
  String? _currentVideoPath;
  int? _currentDurationMs;

  HandController(this._handModel);

  // ── Public state ───────────────────────────────────────────────────

  /// The Arabic word/letter currently being signed (shown as subtitle).
  String? get currentWord => _currentWord;

  /// Asset path of the GLB (or mp4) currently being rendered.
  String? get currentVideoPath => _currentVideoPath;

  /// Duration of the current sign animation in milliseconds.
  int? get currentDurationMs => _currentDurationMs;

  bool get isPlaying => _isPlaying;

  /// Number of tokens still waiting in the queue.
  int get queueLength => _queue.length;

  // ── Token ingestion ────────────────────────────────────────────────

  /// Enqueues [tokens] and starts playback if not already running.
  ///
  /// `#fingerspell:WORD` tokens are expanded into per-letter entries here.
  void setText(List<String> tokens) {
    _stopRequested = false;

    for (final token in tokens) {
      if (token.startsWith('#fingerspell:')) {
        final word = token.substring('#fingerspell:'.length);
        for (final codeUnit in word.runes) {
          final letter = String.fromCharCode(codeUnit);
          if (letter.trim().isNotEmpty) {
            _queue.add('#letter:$letter');
          }
        }
      } else if (token.isNotEmpty) {
        _queue.add(token);
      }
    }

    if (!_isPlaying) _playNext();
  }

  // ── Playback control ───────────────────────────────────────────────

  /// Called by [HandView] when the current video clip has finished playing.
  void onVideoFinished() {
    _playNext();
  }

  /// Stops playback and clears the queue.
  void stopAnimation() {
    _stopRequested = true;
    _isPlaying = false;
    _queue.clear();
    _currentWord = null;
    _currentVideoPath = null;
    _currentDurationMs = null;
    notifyListeners();
  }

  /// Resumes playback if there are queued tokens.
  void resume() {
    _stopRequested = false;
    if (!_isPlaying && _queue.isNotEmpty) _playNext();
  }

  /// Immediately displays [gesture] (bypasses queue).
  void setGesture(GestureData gesture) {
    _currentWord = gesture.word;
    _currentVideoPath = gesture.videoPath;
    notifyListeners();
  }

  /// Clears the currently displayed gesture without touching the queue.
  void resetGesture() {
    _currentWord = null;
    _currentVideoPath = null;
    notifyListeners();
  }

  // ── Internal ───────────────────────────────────────────────────────

  void _playNext() {
    if (_stopRequested || _queue.isEmpty) {
      _isPlaying = false;
      _currentWord = null;
      _currentVideoPath = null;
      _currentDurationMs = null;
      notifyListeners();
      return;
    }

    final token = _queue.removeFirst();
    _isPlaying = true;

    String? videoPath;
    String? displayWord;

    if (token.startsWith('#letter:')) {
      // Fingerspelled letter
      final letter = token.substring('#letter:'.length);
      final gesture = _handModel.getGesture(letter);
      if (gesture != null) {
        videoPath = gesture.videoPath;
        displayWord = letter;
        _currentDurationMs = gesture.durationMs;
      } else {
        debugPrint('⚠️ HandController: no fingerspell video for "$letter" — skipping');
        _playNext(); // skip silently
        return;
      }
    } else {
      // Regular sign word
      final gesture = _handModel.getGesture(token);
      if (gesture != null) {
        videoPath = gesture.videoPath;
        displayWord = token;
        _currentDurationMs = gesture.durationMs;
      } else {
        debugPrint('⚠️ HandController: no gesture for "$token" — skipping');
        _playNext(); // skip silently
        return;
      }
    }

    _currentWord = displayWord;
    _currentVideoPath = videoPath;
    debugPrint('▶️ HandController: playing "$displayWord" → $videoPath');
    notifyListeners();
  }

  @override
  void dispose() {
    _queue.clear();
    super.dispose();
  }
}
