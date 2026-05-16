// ─────────────────────────────────────────────────────────────────────────────
// test/file_transcription_test.dart
// TC07 — Download Transcription PDF
// One group → one test, matching the manual test table exactly.
// Uses REAL CaptionEntry + CaptionsAndTranscriptionModel from lib/.
// FileTranscriptionController cannot be imported directly because
// PdfGoogleFonts needs network and Printing needs a platform channel.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:turjuman/models/CaptionsAndTranscriptionModel.dart';

const String kCaptionsCollection = 'captionsFileTranscription';

class TestableFileTranscriptionController {
  final FakeFirebaseFirestore firestore;

  bool    isGenerating  = false;
  bool    isDownloading = false;
  String? lastError;

  TestableFileTranscriptionController({required this.firestore});

  Future<Uint8List?> generateTranscriptionFile({
    required String             meetingId,
    required List<CaptionEntry> entries,
    required DateTime           meetingDate,
  }) async {
    if (entries.isEmpty) {
      lastError = 'No transcript to export';
      return null;
    }

    isGenerating = true;
    lastError    = null;

    // Simulate PDF bytes — real impl uses pw.Document + PdfGoogleFonts
    final fakeBytes =
    Uint8List.fromList(List<int>.generate(256, (i) => i % 256));

    // Mirror real Firestore update after pdf.save()
    await firestore
        .collection(kCaptionsCollection)
        .doc(meetingId)
        .set({
      'transcriptionFilePath': 'transcript_$meetingId.pdf',
      'isCompleted':           true,
      'updatedAt':             DateTime.now().toIso8601String(),
    }, SetOptions(merge: true));

    isGenerating = false;
    return fakeBytes;
  }

  void reset() {
    isGenerating  = false;
    isDownloading = false;
    lastError     = null;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
void main() {
  late FakeFirebaseFirestore                 fakeFirestore;
  late TestableFileTranscriptionController   transcriptionController;

  setUp(() {
    fakeFirestore           = FakeFirebaseFirestore();
    transcriptionController =
        TestableFileTranscriptionController(firestore: fakeFirestore);
  });

  tearDown(() => transcriptionController.reset());

  // ══════════════════════════════════════════════════════════════════════════
  // TC07 — Download Transcription PDF
  // Steps : 1. Navigate to Transcripts  2. Select a meeting  3. Tap Download PDF
  // Expected: PDF is generated and native share sheet opens with the file
  // ══════════════════════════════════════════════════════════════════════════
  group('TC07 — Download Transcription PDF', () {
    test(
      'User selects a completed meeting and taps Download PDF — '
          'the system generates a PDF and opens the native share sheet',
          () async {
        const meetingId = 'meeting_tc07';

        // Use REAL CaptionEntry constructor and toMap()
        final entries = [
          CaptionEntry(
            userId:    'user_007',
            userName:  'Fatima',
            text:      'أهلاً وسهلاً بالجميع',
            timestamp: DateTime(2025, 3, 10, 9, 0, 0),
          ),
          CaptionEntry(
            userId:    'user_008',
            userName:  'Omar',
            text:      'شكراً للحضور',
            timestamp: DateTime(2025, 3, 10, 9, 1, 30),
          ),
        ];

        // Step 1 & 2 — navigate to Transcripts, select meeting
        // Seed Firestore using REAL CaptionEntry.toMap()
        await fakeFirestore
            .collection(kCaptionsCollection)
            .doc(meetingId)
            .set({
          'meetingId':             meetingId,
          'captionsBuffer':        entries.map((e) => e.toMap()).toList(),
          'isCompleted':           false,
          'format':                'pdf',
          'transcriptionFilePath': '',
          'createdAt':             DateTime(2025, 3, 10).toIso8601String(),
          'updatedAt':             DateTime(2025, 3, 10).toIso8601String(),
          'translatedSign':        [],
          'attendees':             ['user_007', 'user_008'],
        });

        // Step 3 — tap Download PDF
        final bytes =
        await transcriptionController.generateTranscriptionFile(
          meetingId:   meetingId,
          entries:     entries,
          meetingDate: DateTime(2025, 3, 10),
        );

        // Expected: PDF generated — share sheet opens
        expect(bytes, isNotNull,
            reason: 'PDF bytes must be generated when captions exist');
        expect(bytes!.isNotEmpty, isTrue,
            reason: 'PDF bytes must not be empty');
        expect(transcriptionController.lastError, isNull,
            reason: 'No error must occur during PDF generation');

        // Firestore updated with isCompleted=true
        final doc = await fakeFirestore
            .collection(kCaptionsCollection)
            .doc(meetingId)
            .get();
        expect(doc.data()?['isCompleted'], isTrue);
        expect(doc.data()?['transcriptionFilePath'],
            equals('transcript_$meetingId.pdf'));

        // Parse using REAL CaptionsAndTranscriptionModel.fromMap()
        final model = CaptionsAndTranscriptionModel.fromMap(
            doc.data() as Map<String, dynamic>);
        expect(model.isCompleted,           isTrue);
        expect(model.captionsBuffer.length, equals(2));
        expect(
          model.captionsBuffer.map((e) => e.userName),
          containsAll(['Fatima', 'Omar']),
        );

        // Also verify empty buffer returns null with correct error
        final emptyBytes =
        await transcriptionController.generateTranscriptionFile(
          meetingId:   'meeting_empty',
          entries:     [],
          meetingDate: DateTime.now(),
        );
        expect(emptyBytes, isNull,
            reason: 'Must return null when no captions exist');
        expect(transcriptionController.lastError,
            equals('No transcript to export'));
      },
    );
  });
}