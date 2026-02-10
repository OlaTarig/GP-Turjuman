import 'package:permission_handler/permission_handler.dart';
import '../models/UserModel.dart';
import '../repositories/user_repository.dart';

class SettingsController {
  final UserRepository _repo;

  SettingsController({UserRepository? repo}) : _repo = repo ?? UserRepository();

  // ===== Enable/Disable Microphone from App Settings =====
  Future<UserModel> setMicrophoneEnabled(UserModel user, bool enable) async {
    // 1) تحديث إعداد التطبيق (UML-like)
    final patch1 = user.updateMicrophoneAccessSettings(enable);

    bool granted = user.getMicrophonePermissionGranted();

    // 2) لو ON اطلب Permission
    if (enable) {
      final st = await Permission.microphone.status;
      if (st.isGranted) {
        granted = true;
      } else {
        final req = await Permission.microphone.request();
        granted = req.isGranted;
      }
    }
    // OFF = soft-disable داخل التطبيق (ما نقدر نسحب إذن النظام)

    // 3) تحديث flag (UML-like)
    final patch2 = user.updateMicrophonePermissionGranted(granted);

    // 4) حفظ
    await _repo.updateUserFields(user.userId, {...patch1, ...patch2});
    return user;
  }

  // ===== Enable/Disable Camera from App Settings =====
  Future<UserModel> setCameraEnabled(UserModel user, bool enable) async {
    final patch1 = user.updateCameraAccessSettings(enable);

    bool granted = user.getCameraPermissionGranted();

    if (enable) {
      final st = await Permission.camera.status;
      if (st.isGranted) {
        granted = true;
      } else {
        final req = await Permission.camera.request();
        granted = req.isGranted;
      }
    }

    final patch2 = user.updateCameraPermissionGranted(granted);

    await _repo.updateUserFields(user.userId, {...patch1, ...patch2});
    return user;
  }

  // ===== Requirement (9)(10): Request if not granted =====
  Future<UserModel> ensureCamMicPermissionsIfEnabled(UserModel user) async {
    Map<String, dynamic> patch = {};

    // Camera
    if (user.cameraAccessSettings) {
      final st = await Permission.camera.status;
      if (!st.isGranted) {
        final req = await Permission.camera.request();
        patch.addAll(user.updateCameraPermissionGranted(req.isGranted));
      } else {
        patch.addAll(user.updateCameraPermissionGranted(true));
      }
    }

    // Microphone
    if (user.micAccessSettings) {
      final st = await Permission.microphone.status;
      if (!st.isGranted) {
        final req = await Permission.microphone.request();
        patch.addAll(user.updateMicrophonePermissionGranted(req.isGranted));
      } else {
        patch.addAll(user.updateMicrophonePermissionGranted(true));
      }
    }

    if (patch.isNotEmpty) {
      await _repo.updateUserFields(user.userId, patch);
    }

    return user;
  }
}