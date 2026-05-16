import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';

import 'package:turjuman/controllers/MeetingController.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late MockFirebaseAuth mockAuth;
  late MeetingController meetingController;

  setUp(() async {
    fakeFirestore = FakeFirebaseFirestore();

    final hostUser = MockUser(
      uid: 'host123',
      email: 'host@gmail.com',
    );

    mockAuth = MockFirebaseAuth(
      mockUser: hostUser,
      signedIn: true,
    );

    meetingController = MeetingController(
      firestore: fakeFirestore,
      auth: mockAuth,
    );

    await fakeFirestore.collection('User').doc('participant123').set({
      'currentMeetingId': 'meeting123',
      'isHandRaised': true,
      'micPermissionGranted': false,
      'cameraPermissionGranted': false,
    });

    await fakeFirestore
        .collection('Meetings')
        .doc('meeting123')
        .collection('permissionRequests')
        .doc('participant123')
        .set({
      'uid': 'participant123',
      'name': 'Participant',
      'status': 'pending',
    });
  });

  test('TC14 – Grant Permission – approves microphone and camera access', () async {
    await meetingController.approveMicCam(
      meetingId: 'meeting123',
      targetUid: 'participant123',
    );

    final userDoc =
    await fakeFirestore.collection('User').doc('participant123').get();

    final data = userDoc.data()!;

    expect(data['micPermissionGranted'], true);
    expect(data['cameraPermissionGranted'], true);
    expect(data['isHandRaised'], false);
    expect(data['handRaisedAt'], null);
  });

  test('TC15 – Grant Permission – deletes pending permission request', () async {
    await meetingController.approveMicCam(
      meetingId: 'meeting123',
      targetUid: 'participant123',
    );

    final requestDoc = await fakeFirestore
        .collection('Meetings')
        .doc('meeting123')
        .collection('permissionRequests')
        .doc('participant123')
        .get();

    expect(requestDoc.exists, false);
  });

  test('TC16 – Grant Permission – rejects participant permission request', () async {
    await meetingController.rejectHand(
      meetingId: 'meeting123',
      targetUid: 'participant123',
    );

    final userDoc =
    await fakeFirestore.collection('User').doc('participant123').get();

    final data = userDoc.data()!;

    expect(data['isHandRaised'], false);
    expect(data['handRaisedAt'], null);

    final requestDoc = await fakeFirestore
        .collection('Meetings')
        .doc('meeting123')
        .collection('permissionRequests')
        .doc('participant123')
        .get();

    expect(requestDoc.exists, false);
  });
}