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
  // ===== UML-like getters =====
  bool getMicrophoneAccessSettings() => micAccessSettings;
  bool getCameraAccessSettings() => cameraAccessSettings;

  bool getMicrophonePermissionGranted() => micPermissionGranted;
  bool getCameraPermissionGranted() => cameraPermissionGranted;

  // ===== UML-like update methods (تعدل + ترجع Patch لفايرستور) =====
  Map<String, dynamic> updateMicrophoneAccessSettings(bool enabled) {
    micAccessSettings = enabled;
    return {'micAccessSettings': micAccessSettings};
  }

  Map<String, dynamic> updateCameraAccessSettings(bool enabled) {
    cameraAccessSettings = enabled;
    return {'cameraAccessSettings': cameraAccessSettings};
  }

  Map<String, dynamic> updateMicrophonePermissionGranted(bool granted) {
    micPermissionGranted = granted;
    return {'micPermissionGranted': micPermissionGranted};
  }

  Map<String, dynamic> updateCameraPermissionGranted(bool granted) {
    cameraPermissionGranted = granted;
    return {'cameraPermissionGranted': cameraPermissionGranted};
  }

  // ===== Helper checks (اختياري لكنه مفيد للـMeetingView) =====
  bool canUseMic() => micAccessSettings && micPermissionGranted;
  bool canUseCamera() => cameraAccessSettings && cameraPermissionGranted;

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
