import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_speech/google_speech.dart';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/CaptionsAndTranscriptionModel.dart';

// Firestore collection name
const String kCaptionsCollection = 'captionsFileTranscription';

class CaptionController extends ChangeNotifier {
  // ── Singleton ──────────────────────────────────────────────────────
  static final CaptionController instance = CaptionController._internal();
  CaptionController._internal();

  // ── State ──────────────────────────────────────────────────────────
  bool _captionsEnabled = false;
  bool _isListening = false;
  String? lastError;

  // Full transcript — never trimmed, used for PDF
  final List<CaptionEntry> _fullTranscript = [];

  // Live captions — last 3 shown on screen
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
  bool get captionsEnabled => _captionsEnabled;
  bool get isListening => _isListening;
  List<CaptionEntry> get liveCaptions => List.unmodifiable(_liveCaptions);
  List<CaptionEntry> get fullTranscript => List.unmodifiable(_fullTranscript);

  // ── Load credentials from assets/google_speech_credentials.json ───
  Future<ServiceAccount> _loadServiceAccount() async {
    final jsonString =
    await rootBundle.loadString('assets/google_speech_credentials.json');
    final jsonMap = json.decode(jsonString) as Map<String, dynamic>;
    return ServiceAccount.fromString(json.encode(jsonMap));
  }

  // ── Toggle captions ON / OFF ───────────────────────────────────────
  Future<void> handleEnableSpeechCaptioning(
      String userId, String meetingId, String userName) async {
    _currentUserId = userId;
    _currentMeetingId = meetingId;
    _currentUserName = userName;

    if (_captionsEnabled) {
      await _disableCaptions();
    } else {
      await _enableCaptions();
    }
  }

  // ── Enable ─────────────────────────────────────────────────────────
  Future<void> _enableCaptions() async {
    // 1. Microphone permission
    final micStatus = await Permission.microphone.request();
    if (!micStatus.isGranted) {
      lastError = 'يرجى منح إذن الميكروفون';
      notifyListeners();
      return;
    }

    // 2. Load Google Cloud credentials
    try {
      final serviceAccount = await _loadServiceAccount();
      _speechToText = SpeechToText.viaServiceAccount(serviceAccount);
    } catch (e) {
      lastError = 'فشل تحميل بيانات الاعتماد: $e';
      notifyListeners();
      debugPrint('❌ Failed to load credentials: $e');
      return;
    }

    _captionsEnabled = true;
    _isListening = true;
    notifyListeners();

    // 3. Create Firestore document for this meeting
    //    Collection: captionsFileTranscription
    //    Fields: meetingId, transcriptionFilePath, createdAt, translatedSign,
    //            captionsBuffer, isCompleted, updatedAt, format
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
    }, SetOptions(merge: true));

    // 4. Listen to Firestore — all participants see each other's captions
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

      if (entries.isNotEmpty) {
        _liveCaptions
          ..clear()
          ..addAll(entries.length > 3
              ? entries.sublist(entries.length - 3)
              : entries);
        notifyListeners();
      }
    });

    // 5. Start streaming mic to Google Speech API
    await _startStreaming();
  }

  // ── Disable ────────────────────────────────────────────────────────
  Future<void> _disableCaptions() async {
    _captionsEnabled = false;
    _isListening = false;

    await _stopStreaming();
    _captionSub?.cancel();
    _liveCaptions.clear();

    notifyListeners();
    debugPrint('✅ Captions disabled');
  }

  // ── Stream mic audio → Google Speech API ──────────────────────────
  Future<void> _startStreaming() async {
    try {
      final config = RecognitionConfig(
        encoding: AudioEncoding.LINEAR16,
        sampleRateHertz: 16000,
        languageCode: 'ar-SA', // ✅ Arabic
        enableAutomaticPunctuation: true,
        // model removed - not needed in v5
      );

      // Start recording as raw PCM stream
      final audioStream = await _recorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 16000,
          numChannels: 1,
        ),
      );

      // Send to Google Speech API
      final responseStream = _speechToText!.streamingRecognize(
        StreamingRecognitionConfig(
          config: config,
          interimResults: false, // only final results
        ),
        audioStream,
      );

      _audioStreamSub = responseStream.listen(
            (response) {
          for (final result in response.results) {
            if (result.isFinal) {
              final text = result.alternatives.first.transcript.trim();
              if (text.isNotEmpty) {
                debugPrint('🎤 Recognized: $text');
                updateCaption(text);
              }
            }
          }
        },
        onError: (e) {
          debugPrint('❌ Speech stream error: $e');
          if (_captionsEnabled) {
            Future.delayed(const Duration(seconds: 1), _startStreaming);
          }
        },
        onDone: () {
          // Google closes the stream every ~5 min — restart automatically
          debugPrint('🔄 Speech stream ended — restarting...');
          if (_captionsEnabled) {
            Future.delayed(
                const Duration(milliseconds: 500), _startStreaming);
          }
        },
      );

      debugPrint('✅ Google Speech streaming started');
    } catch (e) {
      lastError = 'فشل بدء التسجيل: $e';
      debugPrint('❌ _startStreaming error: $e');
      notifyListeners();
    }
  }

  // ── Stop streaming ─────────────────────────────────────────────────
  Future<void> _stopStreaming() async {
    try {
      await _audioStreamSub?.cancel();
      _audioStreamSub = null;
      await _recorder.stop();
    } catch (e) {
      debugPrint('❌ _stopStreaming error: $e');
    }
  }

  // ── Push recognized text to Firestore ─────────────────────────────
  Future<void> updateCaption(String newText) async {
    if (newText.trim().isEmpty) return;

    final entry = CaptionEntry(
      userId: _currentUserId,
      userName: _currentUserName,
      text: newText.trim(),
      timestamp: DateTime.now(),
    );

    // Add to full local transcript for PDF
    _fullTranscript.add(entry);

    // Push to Firestore captionsBuffer array
    try {
      await FirebaseFirestore.instance
          .collection(kCaptionsCollection)
          .doc(_currentMeetingId)
          .update({
        'captionsBuffer': FieldValue.arrayUnion([entry.toMap()]),
        'updatedAt': FieldValue.serverTimestamp(),
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
    if (_fullTranscript.isEmpty) return 'لا يوجد نص متاح';
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
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('❌ completeTranscription error: $e');
    }
  }

  // ── Call when leaving meeting ──────────────────────────────────────
  Future<void> resetForNewMeeting() async {
    await _disableCaptions();
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
    _stopStreaming();
    _captionSub?.cancel();
    super.dispose();
  }
}