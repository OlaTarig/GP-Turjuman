import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/MeetingModel.dart';
import 'dart:math';

class MeetingController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<MeetingModel?> createMeeting(String title) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      final meetingId = _firestore.collection('Meetings').doc().id;

      final invitationLink = "turjuman://meeting/$meetingId";

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

      await _firestore
          .collection('Meetings')
          .doc(meetingId)
          .set(meeting.toMap());

      return meeting;
    } catch (e) {
      print("Error creating meeting: $e");
      return null;
    }
  }
}
