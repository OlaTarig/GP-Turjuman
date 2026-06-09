import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/UserModel.dart';

class SettingsController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ===== Enable/Disable Microphone =====
  Future<UserModel> setMicrophoneEnabled(UserModel user, bool enable) async {
    user.micAccessSettings = enable;

    if (enable) {
      final st = await Permission.microphone.status;
      if (!st.isGranted) {
        await Permission.microphone.request();
      }
    }

    final uid = FirebaseAuth.instance.currentUser!.uid;

    await _firestore
        .collection('User')
        .doc(uid)
        .update({'micAccessSettings': enable});

    return user;
  }

  // ===== Enable/Disable Camera =====
  Future<UserModel> setCameraEnabled(UserModel user, bool enable) async {
    user.cameraAccessSettings = enable;

    if (enable) {
      final st = await Permission.camera.status;
      if (!st.isGranted) {
        await Permission.camera.request();
      }
    }

    final uid = FirebaseAuth.instance.currentUser!.uid;

    await _firestore
        .collection('User')
        .doc(uid)
        .update({'cameraAccessSettings': enable});

    return user;
  }
}