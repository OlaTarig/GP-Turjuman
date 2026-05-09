import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/MeetingModel.dart';

class MeetingController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<MeetingModel?> createMeeting(String title) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      final meetingId = _firestore.collection('Meetings').doc().id;

      final invitationLink =
          "https://turjuman-63e17.web.app/meeting/$meetingId";

      final meeting = MeetingModel(
        meetingId: meetingId,
        title: title,
        startTime: DateTime.now(),
        endTime: null,
        hostId: user.uid,
        participants: [user.uid],
        isActive: true,
        maxCapacity: 100,
        numOfParticipants: 1,
        invitationLink: invitationLink,
        screenShareAllowed: false,
      );

      await _firestore
          .collection('Meetings')
          .doc(meetingId)
          .set(meeting.toMap())
          .timeout(const Duration(seconds: 15));

      return meeting;
    } on TimeoutException {
      print("createMeeting timed out — check internet connection");
      return null;
    } catch (e) {
      print("Error creating meeting: $e");
      return null;
    }
  }

  Future<void> leaveMeeting(String meetingId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final ref = _firestore.collection('Meetings').doc(meetingId);

    try {
      await _firestore.runTransaction((tx) async {
        final snap = await tx.get(ref);
        if (!snap.exists) return;

        final data = snap.data() as Map<String, dynamic>;

        final participants =
        List<String>.from((data['participants'] as List?) ?? []);
        if (!participants.contains(user.uid)) return;

        final currentNum =
            (data['numOfParticipants'] as int?) ?? participants.length;
        final nextNum = (currentNum - 1) < 0 ? 0 : (currentNum - 1);

        tx.update(ref, {
          'participants': FieldValue.arrayRemove([user.uid]),
          'numOfParticipants': nextNum,
        });
      });
    } catch (e) {
      print("Error leaving meeting: $e");
    }
  }

  Future<void> endMeeting(String meetingId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final ref = _firestore.collection('Meetings').doc(meetingId);

    try {
      await _firestore.runTransaction((tx) async {
        final snap = await tx.get(ref);
        if (!snap.exists) return;

        final data = snap.data() as Map<String, dynamic>;
        final hostId = data['hostId'] as String?;

        if (hostId == null || hostId != user.uid) return;

        final currentParticipants = List<String>.from(
            (data['participants'] as List?) ?? []);

        tx.update(ref, {
          'isActive': false,
          'endTime': Timestamp.now(),
          'allParticipants': currentParticipants,
          'participants': <String>[],
          'numOfParticipants': 0,
          'screenShareAllowed': false,
        });
      }).timeout(const Duration(seconds: 15));
    } on TimeoutException {
      print("endMeeting timed out — proceeding anyway");
    } catch (e) {
      print("Error ending meeting: $e");
    }
  }

  // ✅ مهم — لا ينحذف
  Future<void> initializeUserMeetingSession({
    required String meetingId,
    required String hostId,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final isHost = user.uid == hostId;

    await _firestore.collection('User').doc(user.uid).set({
      'currentMeetingId': meetingId,
      'isHandRaised': false,
      'handRaisedAt': null,
      'micPermissionGranted': isHost,
      'cameraPermissionGranted': isHost,
    }, SetOptions(merge: true));
  }

  Future<void> raiseHand(String meetingId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final userSnap = await _firestore.collection('User').doc(user.uid).get();
    final userName = userSnap.data()?['name'] ?? user.email ?? user.uid;

    await _firestore.collection('User').doc(user.uid).set({
      'currentMeetingId': meetingId,
      'isHandRaised': true,
      'handRaisedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await _firestore
        .collection('Meetings')
        .doc(meetingId)
        .collection('permissionRequests')
        .doc(user.uid)
        .set({
      'uid': user.uid,
      'name': userName,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> lowerHand() async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _firestore.collection('User').doc(user.uid).set({
      'isHandRaised': false,
      'handRaisedAt': null,
    }, SetOptions(merge: true));
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> raisedHandsStream(
      String meetingId) {
    return _firestore
        .collection('User')
        .where('currentMeetingId', isEqualTo: meetingId)
        .where('isHandRaised', isEqualTo: true)
        .orderBy('handRaisedAt', descending: false)
        .snapshots();
  }

  Future<void> approveMicCam({
    required String meetingId,
    required String targetUid,
  }) async {
    final host = _auth.currentUser;
    if (host == null) return;

    final snap = await _firestore.collection('User').doc(targetUid).get();
    final data = snap.data() ?? {};
    if (data['currentMeetingId'] != meetingId) return;

    await _firestore.collection('User').doc(targetUid).set({
      'micPermissionGranted': true,
      'cameraPermissionGranted': true,
      'isHandRaised': false,
      'handRaisedAt': null,
    }, SetOptions(merge: true));

    await _firestore
        .collection('Meetings')
        .doc(meetingId)
        .collection('permissionRequests')
        .doc(targetUid)
        .delete();
  }

  Future<void> rejectHand({
    required String meetingId,
    required String targetUid,
  }) async {
    await _firestore.collection('User').doc(targetUid).set({
      'isHandRaised': false,
      'handRaisedAt': null,
    }, SetOptions(merge: true));

    await _firestore
        .collection('Meetings')
        .doc(meetingId)
        .collection('permissionRequests')
        .doc(targetUid)
        .delete();
  }
}