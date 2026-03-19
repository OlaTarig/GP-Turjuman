import 'dart:async';
import 'dart:convert';
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

  // Whether THIS device's mic is actively recording and pushing captions
  bool _isSpeaking = false;
  bool isMicMuted = true; // starts muted — MeetingView syncs real state in initState

  // Whether captions overlay is visible (either speaking or viewing)
  bool _captionsVisible = false;

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

  // ── Getters ────────────────────────────────────────────────────────
  bool get captionsEnabled => _captionsVisible;
  bool get isSpeaking => _isSpeaking;
  List<CaptionEntry> get liveCaptions => List.unmodifiable(_liveCaptions);
  List<CaptionEntry> get fullTranscript => List.unmodifiable(_fullTranscript);

  // ── Load Google credentials ────────────────────────────────────────
  Future<ServiceAccount> _loadServiceAccount() async {
    final jsonString =
    await rootBundle.loadString('assets/google_speech_credentials.json');
    final jsonMap = json.decode(jsonString) as Map<String, dynamic>;
    return ServiceAccount.fromString(json.encode(jsonMap));
  }

  // ── Toggle MY mic (speaking mode) ─────────────────────────────────
  // Only call this when the CC button is pressed by THIS user
  Future<void> handleEnableSpeechCaptioning(
      String userId, String meetingId, String userName) async {
    _currentUserId = userId;
    _currentMeetingId = meetingId;
    _currentUserName = userName;

    if (_captionsVisible) {
      // Turn OFF — stop mic and hide overlay
      await _stopMic();
      _isSpeaking = false;
      _captionsVisible = false;
      _liveCaptions.clear();
      notifyListeners();
    } else {
      await _startSpeaking();
    }
  }

  // ── Store meeting ID and watch if anyone enables CC ─────────────────
  // When any participant enables CC, everyone starts seeing captions
  void setMeetingId(String meetingId) {
    _currentMeetingId = meetingId;
    _watchForCaptionsEnabled();
  }

  // Watches Firestore — if captionsBuffer gets entries, show overlay
  void _watchForCaptionsEnabled() {
    _captionSub?.cancel();
    _captionSub = FirebaseFirestore.instance
        .collection(kCaptionsCollection)
        .doc(_currentMeetingId)
        .snapshots()
        .listen((snap) {
      if (!snap.exists) return;
      final data = snap.data() as Map<String, dynamic>;
      final entries = (data['captionsBuffer'] as List<dynamic>? ?? [])
          .map((e) => CaptionEntry.fromMap(e as Map<String, dynamic>))
          .toList();

      // Always keep full transcript
      _fullTranscript
        ..clear()
        ..addAll(entries);

      // ✅ Only show live overlay if CC is actively ON for this user
      if (_captionsVisible && entries.isNotEmpty) {
        _liveCaptions
          ..clear()
          ..addAll(entries.length > 3
              ? entries.sublist(entries.length - 3)
              : entries);
        notifyListeners();
      }
    });
  }

  // ── Start speaking (mic on + push to Firestore) ────────────────────
  Future<void> _startSpeaking() async {
    // 1. Mic permission
    final micStatus = await Permission.microphone.request();
    if (!micStatus.isGranted) {
      lastError = 'Please grant microphone permission';
      notifyListeners();
      return;
    }

    // 2. Load credentials
    try {
      final serviceAccount = await _loadServiceAccount();
      _speechToText = SpeechToText.viaServiceAccount(serviceAccount);
    } catch (e) {
      lastError = 'Failed to load credentials: $e';
      notifyListeners();
      debugPrint('❌ Failed to load credentials: $e');
      return;
    }

    _isSpeaking = true;
    _captionsVisible = true;
    notifyListeners();

    // 3. Create/update Firestore doc — add this user to attendees list
    await FirebaseFirestore.instance
        .collection(kCaptionsCollection)
        .doc(_currentMeetingId)
        .set({
      'meetingId': _currentMeetingId,
      'transcriptionFilePath': '',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'translatedSign': [],
      'captionsBuffer': [],
      'isCompleted': false,
      'format': 'pdf',
      'activeSpeakerId': '',
      // ✅ Track every user who enabled CC — survives meeting end
      'attendees': FieldValue.arrayUnion([_currentUserId]),
    }, SetOptions(merge: true));

    // 4. Start mic stream → Google Speech
    await _startStreaming();
  }

  // ── Listen to Firestore captions (no mic) ─────────────────────────
  void _listenToFirestore() {
    _captionSub?.cancel();
    _captionSub = FirebaseFirestore.instance
        .collection(kCaptionsCollection)
        .doc(_currentMeetingId)
        .snapshots()
        .listen((snap) {
      if (!snap.exists) return;
      final data = snap.data() as Map<String, dynamic>;
      final entries = (data['captionsBuffer'] as List<dynamic>? ?? [])
          .map((e) => CaptionEntry.fromMap(e as Map<String, dynamic>))
          .toList();

      // Always keep full transcript updated for PDF
      _fullTranscript
        ..clear()
        ..addAll(entries);

      // ✅ Only update live overlay if user explicitly enabled CC
      if (_captionsVisible) {
        _liveCaptions
          ..clear()
          ..addAll(entries.length > 3
              ? entries.sublist(entries.length - 3)
              : entries);
        notifyListeners();
      }
    });
  }

  // ── Stream mic → Google Speech API ────────────────────────────────
  Future<void> _startStreaming() async {
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
          for (final result in response.results) {
            if (result.isFinal) {
              final text = result.alternatives.first.transcript.trim();
              if (text.isNotEmpty) {
                // ✅ Only push caption if mic is NOT muted
                if (!isMicMuted) {
                  debugPrint('🎤 [$_currentUserName] recognized: $text');
                  updateCaption(text);
                } else {
                  debugPrint('🔇 Mic muted — caption suppressed');
                }
              }
            }
          }
        },
        onError: (e) {
          debugPrint('❌ Speech stream error: $e');
          if (_isSpeaking) {
            Future.delayed(const Duration(seconds: 1), _startStreaming);
          }
        },
        onDone: () {
          debugPrint('🔄 Speech stream ended — restarting...');
          if (_isSpeaking) {
            Future.delayed(
                const Duration(milliseconds: 500), _startStreaming);
          }
        },
      );

      debugPrint('✅ Google Speech streaming started for $_currentUserName');
    } catch (e) {
      lastError = 'Failed to start recording: $e';
      debugPrint('❌ _startStreaming error: $e');
      notifyListeners();
    }
  }

  // ── Stop mic only ──────────────────────────────────────────────────
  Future<void> _stopMic() async {
    try {
      await _audioStreamSub?.cancel();
      _audioStreamSub = null;
      await _recorder.stop();
    } catch (e) {
      debugPrint('❌ _stopMic error: $e');
    }
  }

  // ── Claim the mic slot in Firestore ───────────────────────────────
  // Sets activeSpeakerId so other devices know someone is speaking
  Future<void> _claimSpeakerSlot() async {
    try {
      await FirebaseFirestore.instance
          .collection(kCaptionsCollection)
          .doc(_currentMeetingId)
          .update({'activeSpeakerId': _currentUserId});
    } catch (_) {}
  }

  Future<void> _releaseSpeakerSlot() async {
    try {
      await FirebaseFirestore.instance
          .collection(kCaptionsCollection)
          .doc(_currentMeetingId)
          .update({'activeSpeakerId': ''});
    } catch (_) {}
  }

  // ── Push recognized text to Firestore ─────────────────────────────
  // Checks activeSpeakerId to prevent two devices pushing at same time
  Future<void> updateCaption(String newText) async {
    if (newText.trim().isEmpty) return;
    if (isMicMuted) return;

    // ✅ Check if another user is already the active speaker
    try {
      final doc = await FirebaseFirestore.instance
          .collection(kCaptionsCollection)
          .doc(_currentMeetingId)
          .get();

      if (doc.exists) {
        final activeSpeaker = doc.data()?['activeSpeakerId'] as String? ?? '';
        // If someone else claimed the slot, don't push
        if (activeSpeaker.isNotEmpty && activeSpeaker != _currentUserId) {
          debugPrint('🔇 Another speaker active — skipping');
          return;
        }
      }
    } catch (_) {}

    // Claim the slot
    await _claimSpeakerSlot();

    final entry = CaptionEntry(
      userId: _currentUserId,
      userName: _currentUserName,
      text: newText.trim(),
      timestamp: DateTime.now(),
    );

    try {
      await FirebaseFirestore.instance
          .collection(kCaptionsCollection)
          .doc(_currentMeetingId)
          .update({
        'captionsBuffer': FieldValue.arrayUnion([entry.toMap()]),
        'updatedAt': FieldValue.serverTimestamp(),
        'activeSpeakerId': '', // release slot after pushing
      });
    } catch (e) {
      debugPrint('❌ Failed to push caption: $e');
    }

    notifyListeners();
  }

  // ── Clear live overlay ─────────────────────────────────────────────
  void clearCaptions() {
    _liveCaptions.clear();
    notifyListeners();
  }

  // ── Full text for PDF ──────────────────────────────────────────────
  String getTranscription() {
    if (_fullTranscript.isEmpty) return 'No transcript available';
    return _fullTranscript
        .map((e) =>
    '[${_formatTime(e.timestamp)}] ${e.userName}:\n${e.text}\n')
        .join('\n');
  }

  // ── Mark complete ──────────────────────────────────────────────────
  Future<void> completeTranscription() async {
    if (_currentMeetingId.isEmpty) return;
    try {
      // Use set+merge so this is a no-op if CC was never enabled (doc doesn't exist)
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

  // ── Call when leaving meeting ──────────────────────────────────────
  Future<void> resetForNewMeeting() async {
    _isSpeaking = false;
    _captionsVisible = false;
    await _stopMic();
    _captionSub?.cancel();
    _liveCaptions.clear();
    _fullTranscript.clear();
    _currentUserId = '';
    _currentUserName = '';
    _currentMeetingId = '';
    notifyListeners();
  }

  String _formatTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:'
          '${dt.minute.toString().padLeft(2, '0')}:'
          '${dt.second.toString().padLeft(2, '0')}';

  @override
  void dispose() {
    _stopMic();
    _captionSub?.cancel();
    super.dispose();
  }
}