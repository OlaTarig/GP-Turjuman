import 'UserModel.dart';

class MeetingModel {
  final String meetingId;
  final String hostId;
  final int maxCapacity;

  bool isActive;
  List<UserModel> participants;

  MeetingModel({
    required this.meetingId,
    required this.hostId,
    this.maxCapacity = 100,
    this.isActive = true,
    List<UserModel>? participants,
  }) : participants = participants ?? [];

  int getNumOfParticipants() {
    return participants.length;
  }

  bool addParticipant(UserModel user) {
    if (participants.length >= maxCapacity) {
      return false;
    }
    participants.add(user);
    return true;
  }

  void removeParticipant(String userId) {
    participants.removeWhere((user) => user.userId == userId);
  }

  void endMeeting() {
    isActive = false;
  }
}
