class UserModel {
  // ===== Account Info =====
  final String userId;
  String name;
  String email;

  String role; // "host" or "participant"


  // ===== App Settings (persistent) =====
  bool micAccessSettings;
  bool cameraAccessSettings;

  // ===== Meeting Permissions (controlled by host) =====
  bool micPermissionGranted;
  bool cameraPermissionGranted;

  // ===== Live Meeting State =====
  bool isMicrophoneOn;
  bool isCameraOn;
  bool isHandRaised;

  // ===== Accessibility Features =====
  bool isSignCaptioningOn;
  bool isSpeechCaptioningOn;
  bool isHandAvatarOn;

  UserModel({
    required this.userId,
    required this.name,
    required this.email,
    this.role = "participant", // default to participant


    this.micAccessSettings = true,
    this.cameraAccessSettings = true,

    this.micPermissionGranted = false,
    this.cameraPermissionGranted = false,

    this.isMicrophoneOn = false,
    this.isCameraOn = false,
    this.isHandRaised = false,

    this.isSignCaptioningOn = false,
    this.isSpeechCaptioningOn = false,
    this.isHandAvatarOn = false,
  });
}
