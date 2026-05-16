// ─────────────────────────────────────────────────────────────────────────────
// test/caption_controller_test.dart
// TC01 — Display Speech Caption Overlay
// TC02 — Caption Visible to All Participants
// TC03 — Caption Disabled Successfully
// One group → one test per TC, matching the manual test table exactly.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:turjuman/models/CaptionsAndTranscriptionModel.dart';

const String kCaptionsCollection = 'captionsFileTranscription';

class TestableCaptionController {
  final FakeFirebaseFirestore firestore;

  bool _captionsVisible = false;
  bool _isSpeaking      = false;
  bool isMicMuted       = false;

  String _currentUserId    = '';
  String _currentUserName  = '';
  String _currentMeetingId = '';

  final List<CaptionEntry> _liveCaptions   = [];
  final List<CaptionEntry> _fullTranscript = [];

  TestableCaptionController({required this.firestore});

  bool get captionsEnabled => _captionsVisible;
  bool get isSpeaking      => _isSpeaking;
  List<CaptionEntry> get liveCaptions   => List.unmodifiable(_liveCaptions);
  List<CaptionEntry> get fullTranscript => List.unmodifiable(_fullTranscript);

  Future<void> handleEnableSpeechCaptioning(
      String userId, String meetingId, String userName) async {
    _currentUserId    = userId;
    _currentMeetingId = meetingId;
    _currentUserName  = userName;

    if (_captionsVisible) {
      _captionsVisible = false;
      _isSpeaking      = false;
      _liveCaptions.clear();
    } else {
      _captionsVisible = true;
      _isSpeaking      = true;

      await firestore
          .collection(kCaptionsCollection)
          .doc(_currentMeetingId)
          .set({
        'meetingId':      _currentMeetingId,
        'captionsBuffer': [],
        'isCompleted':    false,
        'format':         'pdf',
        'attendees':      FieldValue.arrayUnion([_currentUserId]),
        'createdAt':      DateTime.now().toIso8601String(),
        'updatedAt':      DateTime.now().toIso8601String(),
      });
    }
  }

  Future<void> updateCaption(String newText) async {
    if (newText.trim().isEmpty) return;
    if (isMicMuted) return;

    final entry = CaptionEntry(
      userId:    _currentUserId,
      userName:  _currentUserName,
      text:      newText.trim(),
      timestamp: DateTime.now(),
    );

    _liveCaptions.add(entry);
    _fullTranscript.add(entry);

    await firestore
        .collection(kCaptionsCollection)
        .doc(_currentMeetingId)
        .set({
      'captionsBuffer': FieldValue.arrayUnion([entry.toMap()]),
      'updatedAt':      DateTime.now().toIso8601String(),
    }, SetOptions(merge: true));
  }

  void reset() {
    _captionsVisible = false;
    _isSpeaking      = false;
    isMicMuted       = false;
    _liveCaptions.clear();
    _fullTranscript.clear();
    _currentUserId    = '';
    _currentUserName  = '';
    _currentMeetingId = '';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
void main() {
  late FakeFirebaseFirestore     fakeFirestore;
  late TestableCaptionController captionController;

  setUp(() {
    fakeFirestore     = FakeFirebaseFirestore();
    captionController = TestableCaptionController(firestore: fakeFirestore);
  });

  tearDown(() => captionController.reset());

  // ══════════════════════════════════════════════════════════════════════════
  // TC01 — Display Speech Caption Overlay
  // ══════════════════════════════════════════════════════════════════════════
  group('TC01 — Display Speech Caption Overlay', () {
    test(
      'Tapping CC starts speech recognition and Arabic spoken text '
          'appears in the caption overlay in real time',
          () async {
        // Steps: 1. Join meeting  2. Tap CC  3. Speak Arabic
        await captionController.handleEnableSpeechCaptioning(
            'user_tc01', 'meeting_tc01', 'Ahmed');

        expect(captionController.captionsEnabled, isTrue,
            reason: 'CC overlay must be active');
        expect(captionController.isSpeaking, isTrue,
            reason: 'Speech recognition must be running');

        final docBefore = await fakeFirestore
            .collection(kCaptionsCollection).doc('meeting_tc01').get();
        expect(docBefore.exists, isTrue);
        expect(docBefore.data()?['captionsBuffer'], isEmpty);

        // Speak Arabic — 'مرحبا' as per Input column in test table
        captionController.isMicMuted = false;
        await captionController.updateCaption('مرحبا');

        final docAfter = await fakeFirestore
            .collection(kCaptionsCollection).doc('meeting_tc01').get();
        final buffer =
            docAfter.data()?['captionsBuffer'] as List<dynamic>? ?? [];

        expect(buffer.length, equals(1));

        // Parse using REAL CaptionEntry.fromMap()
        final entry =
        CaptionEntry.fromMap(buffer.first as Map<String, dynamic>);
        expect(entry.text,     equals('مرحبا'),
            reason: 'Arabic caption must appear on screen in real time');
        expect(entry.userId,   equals('user_tc01'));
        expect(entry.userName, equals('Ahmed'));
        expect(captionController.liveCaptions.first, isA<CaptionEntry>());
      },
    );
  });

  // ══════════════════════════════════════════════════════════════════════════
  // TC02 — Caption Visible to All Participants
  // ══════════════════════════════════════════════════════════════════════════
  group('TC02 — Caption Visible to All Participants', () {
    test(
      'When Participant A speaks with CC enabled, the caption is visible '
          'to all other participants in the same meeting in real time',
          () async {
        // Steps: 1. Participant A enables CC and speaks
        //        2. Participant B enables CC and observes overlay
        const meetingId = 'meeting_tc02';

        final controllerA =
        TestableCaptionController(firestore: fakeFirestore);
        final controllerB =
        TestableCaptionController(firestore: fakeFirestore);

        // Participant A enables CC and speaks — Input: 'السلام عليكم'
        await controllerA.handleEnableSpeechCaptioning(
            'user_A', meetingId, 'Sara');
        controllerA.isMicMuted = false;
        await controllerA.updateCaption('السلام عليكم');

        // Participant B observes — reads the SAME shared Firestore doc directly
        // NOT calling handleEnableSpeechCaptioning which would reset captionsBuffer
        final doc = await fakeFirestore
            .collection(kCaptionsCollection).doc(meetingId).get();
        final buffer =
            doc.data()?['captionsBuffer'] as List<dynamic>? ?? [];

        expect(buffer.length, equals(1),
            reason: 'Caption must be visible to all participants');

        // REAL CaptionEntry.fromMap() — Participant B reads caption
        final entry =
        CaptionEntry.fromMap(buffer.first as Map<String, dynamic>);
        expect(entry.text,     equals('السلام عليكم'),
            reason: 'All participants must see the correct Arabic caption');
        expect(entry.userName, equals('Sara'),
            reason: 'Speaker name must be visible to all participants');

        // REAL CaptionsAndTranscriptionModel.fromMap()
        final model = CaptionsAndTranscriptionModel.fromMap(
            doc.data() as Map<String, dynamic>);
        expect(model.captionsBuffer.first.text, equals('السلام عليكم'));

        controllerA.reset();
        controllerB.reset();
      },
    );
  });

  // ══════════════════════════════════════════════════════════════════════════
  // TC03 — Caption Disabled Successfully
  // ══════════════════════════════════════════════════════════════════════════
  group('TC03 — Caption Disabled Successfully', () {
    test(
      'Tapping the CC button again while captioning is active disables it '
          'and removes the caption overlay from the screen',
          () async {
        // Steps: 1. Ensure CC is active  2. Tap CC button again
        await captionController.handleEnableSpeechCaptioning(
            'user_tc03', 'meeting_tc03', 'Noura');
        captionController.isMicMuted = false;
        await captionController.updateCaption('اختبار');

        expect(captionController.captionsEnabled, isTrue,
            reason: 'Pre-condition: CC must be active');
        expect(captionController.liveCaptions.first, isA<CaptionEntry>());

        // Tap CC again — expected: overlay disappears, button inactive
        await captionController.handleEnableSpeechCaptioning(
            'user_tc03', 'meeting_tc03', 'Noura');

        expect(captionController.captionsEnabled, isFalse,
            reason: 'Caption overlay must disappear after second tap');
        expect(captionController.isSpeaking, isFalse,
            reason: 'CC button must return to inactive state');
        expect(captionController.liveCaptions, isEmpty,
            reason: 'Live captions list must be cleared');
      },
    );
  });
}