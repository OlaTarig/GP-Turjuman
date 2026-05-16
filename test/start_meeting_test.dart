import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';

import 'package:turjuman/controllers/MeetingController.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late MockFirebaseAuth mockAuth;
  late MeetingController meetingController;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();

    final mockUser = MockUser(
      uid: 'host123',
      email: 'host@gmail.com',
    );

    mockAuth = MockFirebaseAuth(
      mockUser: mockUser,
      signedIn: true,
    );

    meetingController = MeetingController(
      firestore: fakeFirestore,
      auth: mockAuth,
    );
  });

  test('TC13 – Start Meeting – creates a meeting successfully', () async {
    final meeting = await meetingController.createMeeting('Test Meeting');

    expect(meeting, isNotNull);
    expect(meeting!.title, 'Test Meeting');
    expect(meeting.hostId, 'host123');
    expect(meeting.participants, contains('host123'));
    expect(meeting.isActive, true);
    expect(meeting.numOfParticipants, 1);
    expect(meeting.maxCapacity, 100);
    expect(meeting.invitationLink, contains(meeting.meetingId));

    final savedDoc = await fakeFirestore
        .collection('Meetings')
        .doc(meeting.meetingId)
        .get();

    expect(savedDoc.exists, true);

    final savedData = savedDoc.data()!;
    expect(savedData['title'], 'Test Meeting');
    expect(savedData['hostId'], 'host123');
    expect(savedData['isActive'], true);
    expect(savedData['numOfParticipants'], 1);
  });

}