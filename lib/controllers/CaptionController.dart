import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_speech/google_speech.dart';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/CaptionsAndTranscriptionModel.dart';
import 'SignCaptioningController.dart';

const String kCaptionsCollection = 'captionsFileTranscription';

class CaptionController extends ChangeNotifier {
  // ── Singleton ──────────────────────────────────────────────────────
  static final CaptionController instance = CaptionController._internal();
  CaptionController._internal();

  // ── State ──────────────────────────────────────────────────────────
  bool _isSpeaking     = false;
  bool isMicMuted      = false;
  bool _captionsVisible = false;

  // ── Translate (sign) state ─────────────────────────────────────────
  bool _translateActive = false;
  bool get translateActive => _translateActive;

  String? lastError;

  final List<CaptionEntry> _fullTranscript = [];
  final List<CaptionEntry> _liveCaptions   = [];

  String _currentUserId    = '';
  String _currentUserName  = '';
  String _currentMeetingId = '';

  // ── Google Speech ──────────────────────────────────────────────────
  SpeechToText?  _speechToText;
  final AudioRecorder _recorder = AudioRecorder();
  StreamSubscription? _audioStreamSub;
  StreamSubscription<DocumentSnapshot>? _captionSub;

  // ── Sign controller reference ──────────────────────────────────────
  SignCaptioningController? _signController;

  // ── Getters ────────────────────────────────────────────────────────
  bool get captionsEnabled => _captionsVisible;
  bool get isSpeaking      => _isSpeaking;
  List<CaptionEntry> get liveCaptions   => List.unmodifiable(_liveCaptions);
  List<CaptionEntry> get fullTranscript => List.unmodifiable(_fullTranscript);

  // ── Sign controller attach / detach ───────────────────────────────

  void attachSignController(SignCaptioningController controller) {
    _signController = controller;
    _signController!.addListener(_onSignLabel);
  }

  void detachSignController() {
    _signController?.removeListener(_onSignLabel);
    _signController = null;
  }

  /// Fires every time SignCaptioningController produces a new label.
  /// Feeds the SAME captionsBuffer as speech — same overlay, same Firestore.
  void _onSignLabel() {
    if (!_translateActive) return;
    final sign = _signController?.currentArabicSign;
    if (sign == null || sign.isEmpty) return;
    updateCaption(sign);
  }

  // ── Toggle Translate (sign captioning) ────────────────────────────

  Future<void> handleEnableSignCaptioning(
      String userId, String meetingId, String userName) async {
    _currentUserId    = userId;
    _currentMeetingId = meetingId;
    _currentUserName  = userName;

    if (_translateActive) {
      await _signController?.disable();
      _translateActive = false;
      notifyListeners();
    } else {
      await _ensureFirestoreDoc();
      await _signController?.enable();
      _translateActive = true;

      // Also open the Firestore listener so the overlay becomes visible
      if (!_captionsVisible) {
        _captionsVisible = true;
        _watchForCaptionsEnabled();
      }

      notifyListeners();
    }
  }

  // ── Load Google credentials ────────────────────────────────────────
  Future<ServiceAccount> _loadServiceAccount() async {
    final jsonString = await rootBundle
        .loadString('assets/google_speech_credentials.json');
    final jsonMap = json.decode(jsonString) as Map<String, dynamic>;
    return ServiceAccount.fromString(json.encode(jsonMap));
  }

  // ── Toggle CC (speech captioning) ─────────────────────────────────
  Future<void> handleEnableSpeechCaptioning(
      String userId, String meetingId, String userName) async {
    _currentUserId    = userId;
    _currentMeetingId = meetingId;
    _currentUserName  = userName;

    if (_captionsVisible) {
      await _stopMic();
      _isSpeaking      = false;
      _captionsVisible = false;
      _liveCaptions.clear();
      notifyListeners();
    } else {
      await _startSpeaking();
    }
  }

  // ── Store meeting ID ───────────────────────────────────────────────
  void setMeetingId(String meetingId) {
    _currentMeetingId = meetingId;
    _watchForCaptionsEnabled();
  }

  void _watchForCaptionsEnabled() {
    _captionSub?.cancel();
    _captionSub = FirebaseFirestore.instance
        .collection(kCaptionsCollection)
        .doc(_currentMeetingId)
        .snapshots()
        .listen((snap) {
      if (!snap.exists) return;
      final data    = snap.data() as Map<String, dynamic>;
      final entries = (data['captionsBuffer'] as List<dynamic>? ?? [])
          .map((e) => CaptionEntry.fromMap(e as Map<String, dynamic>))
          .toList();

      _fullTranscript
        ..clear()
        ..addAll(entries);

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

  // ── Start speaking ─────────────────────────────────────────────────
  Future<void> _startSpeaking() async {
    final micStatus = await Permission.microphone.request();
    if (!micStatus.isGranted) {
      lastError = 'Please grant microphone permission';
      notifyListeners();
      return;
    }

    try {
      final serviceAccount = await _loadServiceAccount();
      _speechToText = SpeechToText.viaServiceAccount(serviceAccount);
    } catch (e) {
      lastError = 'Failed to load credentials: $e';
      notifyListeners();
      debugPrint('❌ Failed to load credentials: $e');
      return;
    }

    _isSpeaking      = true;
    _captionsVisible = true;
    notifyListeners();

    await _ensureFirestoreDoc();
    await _startStreaming();
  }

  // ── Ensure Firestore doc exists (shared by speech + sign) ─────────
  Future<void> _ensureFirestoreDoc() async {
    await FirebaseFirestore.instance
        .collection(kCaptionsCollection)
        .doc(_currentMeetingId)
        .set({
      'meetingId':             _currentMeetingId,
      'transcriptionFilePath': '',
      'createdAt':             FieldValue.serverTimestamp(),
      'updatedAt':             FieldValue.serverTimestamp(),
      'translatedSign':        [],
      'captionsBuffer':        [],
      'isCompleted':           false,
      'format':                'pdf',
      'activeSpeakerId':       '',
    }, SetOptions(merge: true));
  }

  // ── Stream mic → Google Speech API ────────────────────────────────
  Future<void> _startStreaming() async {
    try {
      final config = RecognitionConfig(
        encoding:                   AudioEncoding.LINEAR16,
        sampleRateHertz:            16000,
        languageCode:               'ar-SA',
        enableAutomaticPunctuation: true,
      );

      final audioStream = await _recorder.startStream(
        const RecordConfig(
          encoder:     AudioEncoder.pcm16bits,
          sampleRate:  16000,
          numChannels: 1,
        ),
      );

      final responseStream = _speechToText!.streamingRecognize(
        StreamingRecognitionConfig(
          config:         config,
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

  // ── Stop mic ───────────────────────────────────────────────────────
  Future<void> _stopMic() async {
    try {
      await _audioStreamSub?.cancel();
      _audioStreamSub = null;
      await _recorder.stop();
    } catch (e) {
      debugPrint('❌ _stopMic error: $e');
    }
  }

  // ── Speaker slot management ────────────────────────────────────────
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

  // ── Push caption to Firestore ──────────────────────────────────────
  // Used by BOTH speech and sign — single path, same captionsBuffer.
  Future<void> updateCaption(String newText) async {
    if (newText.trim().isEmpty) return;
    if (isMicMuted) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection(kCaptionsCollection)
          .doc(_currentMeetingId)
          .get();

      if (doc.exists) {
        final activeSpeaker =
            doc.data()?['activeSpeakerId'] as String? ?? '';
        if (activeSpeaker.isNotEmpty &&
            activeSpeaker != _currentUserId) {
          debugPrint('🔇 Another speaker active — skipping');
          return;
        }
      }
    } catch (_) {}

    await _claimSpeakerSlot();

    final entry = CaptionEntry(
      userId:    _currentUserId,
      userName:  _currentUserName,
      text:      newText.trim(),
      timestamp: DateTime.now(),
    );

    try {
      await FirebaseFirestore.instance
          .collection(kCaptionsCollection)
          .doc(_currentMeetingId)
          .update({
        'captionsBuffer':  FieldValue.arrayUnion([entry.toMap()]),
        'updatedAt':       FieldValue.serverTimestamp(),
        'activeSpeakerId': '',
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
      await FirebaseFirestore.instance
          .collection(kCaptionsCollection)
          .doc(_currentMeetingId)
          .update({
        'isCompleted': true,
        'updatedAt':   FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('❌ completeTranscription error: $e');
    }
  }

  // ── Reset on meeting leave ─────────────────────────────────────────
  Future<void> resetForNewMeeting() async {
    if (_translateActive) {
      await _signController?.disable();
      _translateActive = false;
    }
    detachSignController();

    _isSpeaking      = false;
    _captionsVisible = false;
    await _stopMic();
    _captionSub?.cancel();
    _liveCaptions.clear();
    _fullTranscript.clear();
    _currentUserId    = '';
    _currentUserName  = '';
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
    detachSignController();
    super.dispose();
  }
}