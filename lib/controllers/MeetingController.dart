import 'package:flutter/material.dart';
import '../models/MeetingModel.dart';
import '../models/UserModel.dart';

class MeetingController extends ChangeNotifier {

  MeetingModel meeting = MeetingModel(
    meetingId: 'm1',
    hostId: 'u1',
    maxCapacity: 100,
    isActive: true,
    participants: [],
  );

  // =========================================================
  // SESSION MANAGEMENT
  // =========================================================

  void createMeeting({
    required String meetingId,
    required UserModel host,
  }) {
    meeting = MeetingModel(
      meetingId: meetingId,
      hostId: host.userId,
    );

    meeting.addParticipant(host);
    notifyListeners();
  }

  bool joinMeeting(UserModel user) {
    if (!meeting.isActive) return false;

    bool success = meeting.addParticipant(user);

    if (success) {
      notifyListeners();
    }

    return success;
  }

  void leaveMeeting(String userId) {
    meeting.removeParticipant(userId);
    notifyListeners();
  }

  void endMeeting(String hostId) {
    if (hostId == meeting.hostId) {
      meeting.endMeeting();
      notifyListeners();
    }
  }

  // =========================================================
  // PARTICIPANT HELPERS
  // =========================================================

  UserModel _getUser(String userId) {
    return meeting.participants
        .firstWhere((u) => u.userId == userId);
  }

  List<UserModel> get participants => meeting.participants;

  int get participantCount => meeting.participants.length;

  // =========================================================
  // HOST CONTROLS (Permissions)
  // =========================================================

  void grantMicrophonePermission(String userId) {
    var user = _getUser(userId);
    user.micPermissionGranted = true;
    notifyListeners();
  }

  void revokeMicrophonePermission(String userId) {
    var user = _getUser(userId);
    user.micPermissionGranted = false;
    user.isMicrophoneOn = false;
    notifyListeners();
  }

  void grantCameraPermission(String userId) {
    var user = _getUser(userId);
    user.cameraPermissionGranted = true;
    notifyListeners();
  }

  void revokeCameraPermission(String userId) {
    var user = _getUser(userId);
    user.cameraPermissionGranted = false;
    user.isCameraOn = false;
    notifyListeners();
  }

  void removeParticipant(String userId) {
    meeting.removeParticipant(userId);
    notifyListeners();
  }

  // =========================================================
  // MICROPHONE & CAMERA
  // =========================================================

  void toggleMicrophone(String userId) {
    var user = _getUser(userId);

    if (user.micAccessSettings &&
        user.micPermissionGranted) {
      user.isMicrophoneOn = !user.isMicrophoneOn;
      notifyListeners();
    }
  }

  void toggleCamera(String userId) {
    var user = _getUser(userId);

    if (user.cameraAccessSettings &&
        user.cameraPermissionGranted) {
      user.isCameraOn = !user.isCameraOn;
      notifyListeners();
    }
  }

  void flipCamera(String userId) {
    // UI / WebRTC layer will handle actual flip
    notifyListeners();
  }

  // =========================================================
  // RAISE HAND
  // =========================================================

  void raiseHand(String userId) {
    var user = _getUser(userId);
    user.isHandRaised = true;
    notifyListeners();
  }

  void lowerHand(String userId) {
    var user = _getUser(userId);
    user.isHandRaised = false;
    notifyListeners();
  }

  List<UserModel> get raisedHands {
    return meeting.participants
        .where((u) => u.isHandRaised)
        .toList();
  }

  // =========================================================
  // SCREEN SHARING
  // =========================================================

  void shareScreen(String userId) {
    var user = _getUser(userId);

    if (user.cameraPermissionGranted) {
      // actual screen share handled in service layer
      notifyListeners();
    }
  }

  // =========================================================
  // ACCESSIBILITY FEATURES
  // =========================================================

  void toggleSignCaption(String userId) {
    var user = _getUser(userId);
    user.isSignCaptioningOn = !user.isSignCaptioningOn;
    notifyListeners();
  }

  void toggleSpeechCaption(String userId) {
    var user = _getUser(userId);
    user.isSpeechCaptioningOn = !user.isSpeechCaptioningOn;
    notifyListeners();
  }

  void toggleHandAvatar(String userId) {
    var user = _getUser(userId);
    user.isHandAvatarOn = !user.isHandAvatarOn;
    notifyListeners();
  }

  // =========================================================
  // BACKGROUND BLUR
  // =========================================================

  void applyBackgroundBlur(String userId) {
    // actual blur handled in video service
    notifyListeners();
  }

// =========================================================
// TRANSCRIPTION
// =========================================================
}