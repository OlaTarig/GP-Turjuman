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
    this.role = "participant",

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

  // ===== Convert UserModel to Firestore Map =====
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'name': name,
      'email': email,
      'role': role,

      'micAccessSettings': micAccessSettings,
      'cameraAccessSettings': cameraAccessSettings,

      'micPermissionGranted': micPermissionGranted,
      'cameraPermissionGranted': cameraPermissionGranted,

      'isMicrophoneOn': isMicrophoneOn,
      'isCameraOn': isCameraOn,
      'isHandRaised': isHandRaised,

      'isSignCaptioningOn': isSignCaptioningOn,
      'isSpeechCaptioningOn': isSpeechCaptioningOn,
      'isHandAvatarOn': isHandAvatarOn,
    };
  }

  // ===== Create UserModel from Firestore Map =====
  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      userId: map['userId'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      role: map['role'] ?? 'participant',

      micAccessSettings: map['micAccessSettings'] ?? true,
      cameraAccessSettings: map['cameraAccessSettings'] ?? true,

      micPermissionGranted: map['micPermissionGranted'] ?? false,
      cameraPermissionGranted: map['cameraPermissionGranted'] ?? false,

      isMicrophoneOn: map['isMicrophoneOn'] ?? false,
      isCameraOn: map['isCameraOn'] ?? false,
      isHandRaised: map['isHandRaised'] ?? false,

      isSignCaptioningOn: map['isSignCaptioningOn'] ?? false,
      isSpeechCaptioningOn: map['isSpeechCaptioningOn'] ?? false,
      isHandAvatarOn: map['isHandAvatarOn'] ?? false,
    );
  }
}
