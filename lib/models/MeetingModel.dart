import 'package:cloud_firestore/cloud_firestore.dart';

class MeetingModel {
  final String meetingId;
  final String title;
  final DateTime startTime;
  final DateTime? endTime;
  final String hostId;
  final List<String> participants;
  final bool isActive;
  final int maxCapacity;
  final int numOfParticipants;
  final String invitationLink;

  MeetingModel({
    required this.meetingId,
    required this.title,
    required this.startTime,
    this.endTime,
    required this.hostId,
    required this.participants,
    required this.isActive,
    required this.maxCapacity,
    required this.numOfParticipants,
    required this.invitationLink,
  });

  // Convert model to Firestore map
  Map<String, dynamic> toMap() {
    return {
      'meetingId': meetingId,
      'title': title,
      'startTime': Timestamp.fromDate(startTime),
      'endTime': endTime != null ? Timestamp.fromDate(endTime!) : null,
      'hostId': hostId,
      'participants': participants,
      'isActive': isActive,
      'maxCapacity': maxCapacity,
      'numOfParticipants': numOfParticipants,
      'invitationLink': invitationLink,
    };
  }

  // Create model from Firestore
  factory MeetingModel.fromMap(Map<String, dynamic> map) {
    return MeetingModel(
      meetingId: map['meetingId'],
      title: map['title'],
      startTime: (map['startTime'] as Timestamp).toDate(),
      endTime: map['endTime'] != null
          ? (map['endTime'] as Timestamp).toDate()
          : null,
      hostId: map['hostId'],
      participants: List<String>.from(map['participants']),
      isActive: map['isActive'],
      maxCapacity: map['maxCapacity'],
      numOfParticipants: map['numOfParticipants'],
      invitationLink: map['invitationLink'],
    );
  }
}
