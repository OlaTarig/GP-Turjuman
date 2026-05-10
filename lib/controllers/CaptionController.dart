import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_speech/google_speech.dart';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/CaptionsAndTranscriptionModel.dart';

const String kCaptionsCollection = 'captionsFileTranscription';

class CaptionController extends ChangeNotifier {
  // ── Singleton ──────────────────────────────────────────────────────
  static final CaptionController instance = CaptionController._internal();
  CaptionController._internal();

  // ── State ──────────────────────────────────────────────────────────
  bool _isSpeaking = false;
  // starts true — MeetingView syncs real state after ZEGO joins
  bool isMicMuted = true;
  bool _captionsVisible = false;

  // Holds the locally-recognized caption before Firestore confirms it.
  // Cleared by the Firestore snapshot once the entry appears in captionsBuffer.
  CaptionEntry? _pendingCaption;

  String? lastError;

  final List<CaptionEntry> _fullTranscript = [];
  final List<CaptionEntry> _liveCaptions = [];

  String _currentUserId = '';
  String _currentUserName = '';
  String _currentMeetingId = '';

  // ── Google Speech ──────────────────────────────────────────────────
  SpeechToText? _speechToText;
  final AudioRecorder _recorder = AudioRecorder();
  StreamSubscription? _audioStreamSub;
  StreamSubscription<DocumentSnapshot>? _captionSub;

  // ── Retry / backoff ────────────────────────────────────────────────
  int _consecutiveErrors = 0;
  static const int _maxConsecutiveErrors = 5;

  // ── Getters ────────────────────────────────────────────────────────
  bool get captionsEnabled => _captionsVisible;
  bool get isSpeaking => _isSpeaking;
  CaptionEntry? get pendingCaption => _pendingCaption;
  List<CaptionEntry> get liveCaptions => List.unmodifiable(_liveCaptions);
  List<CaptionEntry> get fullTranscript => List.unmodifiable(_fullTranscript);

  // ── Load Google credentials ────────────────────────────────────────
  Future<ServiceAccount> _loadServiceAccount() async {
    final jsonString =
    await rootBundle.loadString('assets/google_speech_credentials.json');
    final jsonMap = json.decode(jsonString) as Map<String, dynamic>;
    return ServiceAccount.fromString(json.encode(jsonMap));
  }

  // ── Auto-start recording on meeting join ──────────────────────────
  //
  // Begins saving speech captions to Firestore without showing the overlay.
  // Call once after the meeting session is established. The CC button then
  // only controls overlay visibility — recording is always running.
  Future<void> beginCapture(
      String userId, String meetingId, String userName) async {
    if (_isSpeaking) return;
    _currentUserId    = userId;
    _currentMeetingId = meetingId;
    _currentUserName  = userName;
    _consecutiveErrors = 0;
    debugPrint('▶️ beginCapture: auto-starting speech recording');
    await _startSpeaking();
  }

  // ── CC button pressed — toggles overlay only ───────────────────────
  //
  // Recording is always running (started via beginCapture on join).
  // This only shows/hides the caption overlay for the local user.
  Future<void> handleEnableSpeechCaptioning(
      String userId, String meetingId, String userName) async {
    _currentUserId    = userId;
    _currentMeetingId = meetingId;
    _currentUserName  = userName;

    if (_captionsVisible) {
      _captionsVisible = false;
      notifyListeners();
      debugPrint('🔕 CC overlay hidden (recording continues in background)');
    } else {
      _captionsVisible = true;
      if (!_isSpeaking) {
        _consecutiveErrors = 0;
        await _startSpeaking();
      } else {
        notifyListeners();
      }
      debugPrint('✅ CC overlay shown — meetingId=$_currentMeetingId');
    }
  }

  // ── Called from MeetingView.initState after ZEGO joins ────────────
  void setMeetingId(String meetingId) {
    _currentMeetingId = meetingId;
    debugPrint('📋 setMeetingId: $meetingId');
    _startWatchingFirestore();
  }

  // ── Watch Firestore for any captions updates ───────────────────────
  void _startWatchingFirestore() {
    _captionSub?.cancel();
    if (_currentMeetingId.isEmpty) {
      debugPrint('⚠️ _startWatchingFirestore: meetingId is empty — skipping');
      return;
    }
    debugPrint('👀 Watching Firestore doc: $_currentMeetingId');
    _captionSub = FirebaseFirestore.instance
        .collection(kCaptionsCollection)
        .doc(_currentMeetingId)
        .snapshots()
        .listen((snap) {
      if (!snap.exists) {
        debugPrint('📡 Firestore doc does not exist yet');
        return;
      }
      final data = snap.data() as Map<String, dynamic>;
      final entries = (data['captionsBuffer'] as List<dynamic>? ?? [])
          .map((e) => CaptionEntry.fromMap(e as Map<String, dynamic>))
          .toList();

      // Sort by speech timestamp so concurrent speakers display chronologically.
      entries.sort((a, b) => a.timestamp.compareTo(b.timestamp));

      _fullTranscript
        ..clear()
        ..addAll(entries);

      _liveCaptions
        ..clear()
        ..addAll(entries);

      // Clear pending caption once Firestore confirms it (matched by userId+text).
      final pending = _pendingCaption;
      if (pending != null &&
          _liveCaptions.any(
              (e) => e.userId == pending.userId && e.text == pending.text)) {
        _pendingCaption = null;
      }

      debugPrint('📡 Firestore snapshot: ${entries.length} entries, pending=${_pendingCaption != null}');
      notifyListeners();
    }, onError: (e) {
      debugPrint('❌ Firestore watch error: $e');
    });
  }

  // ── Start speaking: mic + Google Speech ───────────────────────────
  Future<void> _startSpeaking() async {
    // 1. Mic permission
    final micStatus = await Permission.microphone.request();
    if (!micStatus.isGranted) {
      lastError = 'Please grant microphone permission';
      notifyListeners();
      debugPrint('❌ Mic permission denied');
      return;
    }

    // 2. Load credentials
    try {
      final serviceAccount = await _loadServiceAccount();
      _speechToText = SpeechToText.viaServiceAccount(serviceAccount);
      debugPrint('✅ Google credentials loaded');
    } catch (e) {
      lastError = 'Failed to load credentials: $e';
      notifyListeners();
      debugPrint('❌ Failed to load credentials: $e');
      return;
    }

    _isSpeaking = true;
    notifyListeners();

    // 3. Create Firestore doc (merge — never wipe captionsBuffer)
    await FirebaseFirestore.instance
        .collection(kCaptionsCollection)
        .doc(_currentMeetingId)
        .set({
      'meetingId': _currentMeetingId,
      'transcriptionFilePath': '',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'translatedSign': [],
      'isCompleted': false,
      'format': 'pdf',
      'activeSpeakerId': '',
      'attendees': FieldValue.arrayUnion([_currentUserId]),
    }, SetOptions(merge: true));

    // Initialize captionsBuffer only if doc is brand new
    final docSnap = await FirebaseFirestore.instance
        .collection(kCaptionsCollection)
        .doc(_currentMeetingId)
        .get();
    if (!docSnap.exists || docSnap.data()?['captionsBuffer'] == null) {
      await FirebaseFirestore.instance
          .collection(kCaptionsCollection)
          .doc(_currentMeetingId)
          .set({'captionsBuffer': []}, SetOptions(merge: true));
    }

    debugPrint('✅ Firestore doc ready, starting mic stream...');

    // 4. Start mic → Google Speech
    await _startStreaming();
  }

  // ── Stream mic → Google Speech ─────────────────────────────────────
  Future<void> _startStreaming() async {
    if (!_isSpeaking) return;

    // Always tear down the previous session before starting a new one.
    // Failing to stop the recorder causes startStream() to throw on restart.
    final oldSub = _audioStreamSub;
    _audioStreamSub = null;
    await oldSub?.cancel();
    try { await _recorder.stop(); } catch (_) {}

    if (!_isSpeaking) return; // may have been disabled while cleaning up

    try {
      final config = RecognitionConfig(
        encoding: AudioEncoding.LINEAR16,
        sampleRateHertz: 16000,
        languageCode: 'ar-SA',
        enableAutomaticPunctuation: true,
      );

      final audioStream = await _recorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 16000,
          numChannels: 1,
        ),
      );

      final responseStream = _speechToText!.streamingRecognize(
        StreamingRecognitionConfig(
          config: config,
          interimResults: false,
        ),
        audioStream,
      );

      _audioStreamSub = responseStream.listen(
        (response) {
          debugPrint('🎙️ Speech response: ${response.results.length} results');
          for (final result in response.results) {
            debugPrint('🎙️ isFinal=${result.isFinal} text=${result.alternatives.isNotEmpty ? result.alternatives.first.transcript : "empty"}');
            if (result.isFinal) {
              final text = result.alternatives.isNotEmpty
                  ? result.alternatives.first.transcript.trim()
                  : '';
              if (text.isNotEmpty) {
                _consecutiveErrors = 0;
                debugPrint('🎤 [$_currentUserName] recognized: $text');
                updateCaption(text);
              }
            }
          }
        },
        onError: (e) {
          _consecutiveErrors++;
          debugPrint('❌ Speech stream error ($_consecutiveErrors/$_maxConsecutiveErrors): $e');
          if (!_isSpeaking) return;
          if (_consecutiveErrors >= _maxConsecutiveErrors) {
            _isSpeaking = false;
            lastError = 'Speech recognition unavailable — check your internet connection.';
            debugPrint('🛑 Too many consecutive errors — stopping CC');
            notifyListeners();
            return;
          }
          // Exponential backoff: 1s, 2s, 4s, 8s … capped at 30s
          final delay = Duration(seconds: min(1 << (_consecutiveErrors - 1), 30));
          debugPrint('🔁 Retrying in ${delay.inSeconds}s...');
          Future.delayed(delay, _startStreaming);
        },
        onDone: () {
          debugPrint('🔄 Speech stream ended — restarting...');
          if (_isSpeaking) {
            Future.delayed(const Duration(milliseconds: 500), _startStreaming);
          }
        },
        cancelOnError: false,
      );

      debugPrint('✅ Google Speech streaming started for $_currentUserName');
    } catch (e) {
      _consecutiveErrors++;
      lastError = 'Failed to start recording: $e';
      debugPrint('❌ _startStreaming error ($_consecutiveErrors/$_maxConsecutiveErrors): $e');
      notifyListeners();
      if (_isSpeaking && _consecutiveErrors < _maxConsecutiveErrors) {
        final delay = Duration(seconds: min(1 << (_consecutiveErrors - 1), 30));
        Future.delayed(delay, _startStreaming);
      } else if (_consecutiveErrors >= _maxConsecutiveErrors) {
        _isSpeaking = false;
        lastError = 'Speech recognition unavailable — check your internet connection.';
        notifyListeners();
      }
    }
  }

  // ── Stop mic ───────────────────────────────────────────────────────
  Future<void> _stopMic() async {
    _isSpeaking = false; // block any in-flight onDone/onError from restarting
    final sub = _audioStreamSub;
    _audioStreamSub = null;
    try {
      await sub?.cancel().timeout(const Duration(seconds: 5));
    } catch (_) {}
    try {
      await _recorder.stop().timeout(const Duration(seconds: 5));
      debugPrint('🛑 Mic stopped');
    } catch (e) {
      debugPrint('⚠️ _stopMic: recorder stop timed out or failed — $e');
    }
  }

  // ── Push caption to Firestore ──────────────────────────────────────
  Future<void> updateCaption(String newText) async {
    if (newText.trim().isEmpty) return;

    // Check if another speaker is active
    try {
      final doc = await FirebaseFirestore.instance
          .collection(kCaptionsCollection)
          .doc(_currentMeetingId)
          .get();
      if (doc.exists) {
        final activeSpeaker = doc.data()?['activeSpeakerId'] as String? ?? '';
        if (activeSpeaker.isNotEmpty && activeSpeaker != _currentUserId) {
          debugPrint('🔇 Another speaker active — skipping');
          return;
        }
      }
    } catch (_) {}

    // Claim slot
    try {
      await FirebaseFirestore.instance
          .collection(kCaptionsCollection)
          .doc(_currentMeetingId)
          .set({'activeSpeakerId': _currentUserId}, SetOptions(merge: true));
    } catch (_) {}

    final entry = CaptionEntry(
      userId: _currentUserId,
      userName: _currentUserName,
      text: newText.trim(),
      timestamp: DateTime.now(),
    );

    // Show recognized text instantly while the Firestore write is in-flight.
    // The Firestore snapshot clears this once it confirms the entry.
    _pendingCaption = entry;
    notifyListeners();

    try {
      await FirebaseFirestore.instance
          .collection(kCaptionsCollection)
          .doc(_currentMeetingId)
          .set({
        'captionsBuffer': FieldValue.arrayUnion([entry.toMap()]),
        'updatedAt': FieldValue.serverTimestamp(),
        'activeSpeakerId': '',
      }, SetOptions(merge: true));
      debugPrint('✅ Caption pushed: ${entry.text}');
    } catch (e) {
      debugPrint('❌ Failed to push caption: $e');
    }
  }

  // ── Mark meeting transcript complete ──────────────────────────────
  Future<void> completeTranscription() async {
    if (_currentMeetingId.isEmpty) return;
    try {
      await FirebaseFirestore.instance
          .collection(kCaptionsCollection)
          .doc(_currentMeetingId)
          .set({
        'isCompleted': true,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('❌ completeTranscription error: $e');
    }
  }

  // ── Reset after leaving meeting ────────────────────────────────────
  Future<void> resetForNewMeeting() async {
    _isSpeaking = false;
    _captionsVisible = false;
    isMicMuted = true;
    _pendingCaption = null;
    await _stopMic();
    _captionSub?.cancel();
    _captionSub = null;
    _liveCaptions.clear();
    _fullTranscript.clear();
    _currentUserId = '';
    _currentUserName = '';
    _currentMeetingId = '';
    notifyListeners();
    debugPrint('🔄 CaptionController reset');
  }

  void clearCaptions() {
    _liveCaptions.clear();
    _pendingCaption = null;
    notifyListeners();
  }

  String getTranscription() {
    if (_fullTranscript.isEmpty) return 'No transcript available';
    return _fullTranscript
        .map((e) => '[${_formatTime(e.timestamp)}] ${e.userName}:\n${e.text}\n')
        .join('\n');
  }

  String _formatTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:'
          '${dt.minute.toString().padLeft(2, '0')}:'
          '${dt.second.toString().padLeft(2, '0')}';

  // ── Sign captioning bridge ─────────────────────────────────────────
  void attachSignController(dynamic signController) {}
  void detachSignController() {}

  // ── Sign captioning ────────────────────────────────────────────────
  //
  // Called by SignCaptioningController when a sentence is flushed.
  // Bypasses the mic-mute gate so deaf users can caption with mic off.
  Future<void> pushSignCaption(
      String text, String userId, String userName, String meetingId) async {
    if (text.trim().isEmpty || meetingId.isEmpty) return;

    final entry = CaptionEntry(
      userId: userId,
      userName: userName,
      text: text.trim(),
      timestamp: DateTime.now(),
    );

    try {
      // Single write: creates the doc if absent, appends the entry, updates attendees.
      await FirebaseFirestore.instance
          .collection(kCaptionsCollection)
          .doc(meetingId)
          .set({
        'meetingId': meetingId,
        'captionsBuffer': FieldValue.arrayUnion([entry.toMap()]),
        'attendees': FieldValue.arrayUnion([userId]),
        'isCompleted': false,
        'format': 'pdf',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true))
          .timeout(const Duration(seconds: 10));
      debugPrint('🤟 Sign caption pushed: ${entry.text}');
    } catch (e) {
      debugPrint('❌ pushSignCaption error: $e');
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _stopMic();
    _captionSub?.cancel();
    super.dispose();
  }
}