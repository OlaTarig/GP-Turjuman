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
      );

      await _firestore.collection('Meetings').doc(meetingId).set(meeting.toMap());

      return meeting;
    } catch (e) {
      print("Error creating meeting: $e");
      return null;
    }
  }

  /// ✅ Participant leaves: remove from participants + decrement count
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

        final currentNum = (data['numOfParticipants'] as int?) ?? participants.length;
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

  /// ✅ Host ends meeting: set isActive=false + endTime + clear participants + reset count
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

        // فقط الهوست يقدر ينهي الاجتماع
        if (hostId == null || hostId != user.uid) return;

        tx.update(ref, {
          'isActive': false,
          'endTime': Timestamp.now(),
          'participants': <String>[],
          'numOfParticipants': 0,
        });
      });
    } catch (e) {
      print("Error ending meeting: $e");
    }
  }
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
      'micPermissionGranted': isHost,     // host=true participant=false
      'cameraPermissionGranted': isHost,  // host=true participant=false
    }, SetOptions(merge: true));
  }

  /// ✅ Req (19): Raise hand
  Future<void> raiseHand(String meetingId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _firestore.collection('User').doc(user.uid).set({
      'currentMeetingId': meetingId,
      'isHandRaised': true,
      'handRaisedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// ✅ Req (20): Lower hand
  Future<void> lowerHand() async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _firestore.collection('User').doc(user.uid).set({
      'isHandRaised': false,
      'handRaisedAt': null,
    }, SetOptions(merge: true));
  }

  /// ✅ Req (21): Ordered raised hands list (for this meeting)
  Stream<QuerySnapshot<Map<String, dynamic>>> raisedHandsStream(String meetingId) {
    return _firestore
        .collection('User')
        .where('currentMeetingId', isEqualTo: meetingId)
        .where('isHandRaised', isEqualTo: true)
        .orderBy('handRaisedAt', descending: false)
        .snapshots();
  }

  /// ✅ Host approves Mic+Cam (يعطي الصلاحية)
  Future<void> approveMicCam({
    required String meetingId,
    required String targetUid,
  }) async {
    final host = _auth.currentUser;
    if (host == null) return;

    // safety: تأكد انه داخل نفس الميتنق قبل الموافقة
    final snap = await _firestore.collection('User').doc(targetUid).get();
    final data = snap.data() ?? {};
    if (data['currentMeetingId'] != meetingId) return;

    await _firestore.collection('User').doc(targetUid).set({
      'micPermissionGranted': true,
      'cameraPermissionGranted': true,
      'isHandRaised': false,
      'handRaisedAt': null,
    }, SetOptions(merge: true));
  }

  /// ✅ Host rejects (بس ينزل اليد)
  Future<void> rejectHand({required String targetUid}) async {
    await _firestore.collection('User').doc(targetUid).set({
      'isHandRaised': false,
      'handRaisedAt': null,
    }, SetOptions(merge: true));
  }
}
