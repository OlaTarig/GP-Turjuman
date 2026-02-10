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
}
