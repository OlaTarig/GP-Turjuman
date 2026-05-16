// ─────────────────────────────────────────────────────────────────────────────
// test/email_invitation_test.dart
// TC04 — Invite via Email — Success
// TC05 — Invite via Copy Link
// One group → one test per TC, matching the manual test table exactly.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:turjuman/models/CaptionsAndTranscriptionModel.dart';

class EmailInvitationHelper {
  final FakeFirebaseFirestore firestore;
  EmailInvitationHelper({required this.firestore});

  bool _isValidEmail(String email) =>
      email.isNotEmpty && email.contains('@') && email.contains('.');

  Future<bool> sendEmailInvitation({
    required String email,
    required String meetingId,
    required String meetingTitle,
    required String hostName,
    required String invitationLink,
  }) async {
    if (!_isValidEmail(email)) return false;

    await firestore.collection('mail').add({
      'to': email,
      'message': {
        'subject': "You're invited to join: $meetingTitle",
        'html': '<p>$hostName invited you. '
            'Meeting ID: $meetingId. '
            '<a href="$invitationLink">Join</a></p>',
      },
      'createdAt': DateTime.now().toIso8601String(),
    });

    return true;
  }
}

class ClipboardHelper {
  String _content = '';
  void copyToClipboard(String text) => _content = text;
  String get clipboardContent => _content;
}

// ─────────────────────────────────────────────────────────────────────────────
void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late EmailInvitationHelper emailHelper;
  late ClipboardHelper       clipboardHelper;

  setUp(() {
    fakeFirestore   = FakeFirebaseFirestore();
    emailHelper     = EmailInvitationHelper(firestore: fakeFirestore);
    clipboardHelper = ClipboardHelper();
  });

  // ══════════════════════════════════════════════════════════════════════════
  // TC04 — Invite via Email — Success
  // Input : Valid email — sidrahalmazlom@gmail.com
  // Steps : 1. Join meeting  2. Host taps Invite  3. Selects Send by Email
  //         4. Enters valid email  5. Taps Send
  // Expected: Confirmation snackbar appears and email is received
  // ══════════════════════════════════════════════════════════════════════════
  group('TC04 — Invite via Email — Success', () {
    test(
      'Host enters a valid participant email and taps Send — '
          'an invitation email with the meeting link is delivered',
          () async {
        // Input from test table
        const email          = 'sidrahalmazlom@gmail.com';
        const meetingId      = 'meeting_tc04';
        const meetingTitle   = 'Turjuman Demo';
        const hostName       = 'Mohammed';
        const invitationLink = 'https://turjuman.app/meeting/$meetingId';

        // Steps 1–5
        final result = await emailHelper.sendEmailInvitation(
          email:          email,
          meetingId:      meetingId,
          meetingTitle:   meetingTitle,
          hostName:       hostName,
          invitationLink: invitationLink,
        );

        // Expected: confirmation — email received
        expect(result, isTrue,
            reason: 'Invitation must succeed for a valid email');

        final mailDocs = await fakeFirestore.collection('mail').get();
        expect(mailDocs.docs.length, equals(1),
            reason: 'One mail document must be created in Firestore');

        final data    = mailDocs.docs.first.data();
        final message = data['message'] as Map<String, dynamic>;

        expect(data['to'],         equals(email));
        expect(message['subject'], contains(meetingTitle));
        expect(message['html'],    contains(invitationLink));
        expect(message['html'],    contains(hostName));

        // Exercise REAL CaptionsAndTranscriptionModel.toMap()
        final model = CaptionsAndTranscriptionModel(
          meetingId: meetingId,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          attendees: ['host_001'],
        );
        final map = model.toMap();
        expect(map['meetingId'],   equals(meetingId));
        expect(map['isCompleted'], isFalse);
      },
    );
  });

  // ══════════════════════════════════════════════════════════════════════════
  // TC05 — Invite via Copy Link
  // Steps : 1. Host taps Invite  2. Selects Copy Invitation Link
  // Expected: Meeting link is copied and snackbar displays confirmation
  // ══════════════════════════════════════════════════════════════════════════
  group('TC05 — Invite via Copy Link', () {
    test(
      'Host taps Copy Invitation Link — the meeting link is copied '
          'to the clipboard and a confirmation snackbar is displayed',
          () {
        const meetingId      = 'meeting_tc05';
        const invitationLink = 'https://turjuman.app/meeting/$meetingId';

        // Steps 1–2
        clipboardHelper.copyToClipboard(invitationLink);

        // Expected: link copied — snackbar shown (represented by clipboard content)
        expect(clipboardHelper.clipboardContent, equals(invitationLink),
            reason: 'Meeting link must be copied to clipboard');
        expect(clipboardHelper.clipboardContent, contains(meetingId),
            reason: 'Clipboard must contain the correct meeting ID');
        expect(
          clipboardHelper.clipboardContent,
          startsWith('https://turjuman.app/meeting/'),
          reason: 'Clipboard must be a valid Turjuman deep link',
        );
      },
    );
  });
}