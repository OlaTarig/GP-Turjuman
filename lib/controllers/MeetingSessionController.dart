import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';

class MeetingSessionController extends ChangeNotifier {
  bool isMicOn = false;
  bool isCameraOn = false;
  bool isHandRaised = false;

  CameraController? cameraController;
  List<CameraDescription>? cameras;
  bool isCameraInitialized = false;

  CameraLensDirection _currentLens = CameraLensDirection.front;

  Future<void> _ensureCameras() async {
    cameras ??= await availableCameras();
  }

  Future<void> _initializeCamera() async {
    await _ensureCameras();

    final selected = cameras!.firstWhere(
          (c) => c.lensDirection == _currentLens,
      orElse: () => cameras!.first,
    );

    cameraController = CameraController(
      selected,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    await cameraController!.initialize();
    isCameraInitialized = true;
  }

  Future<void> toggleCamera() async {
    if (!isCameraOn) {
      await _initializeCamera();
      isCameraOn = true;
    } else {
      await cameraController?.dispose();
      cameraController = null;
      isCameraOn = false;
      isCameraInitialized = false;
    }
    notifyListeners();
  }

  Future<void> flipCamera() async {
    await _ensureCameras();

    final hasFront = cameras!.any((c) => c.lensDirection == CameraLensDirection.front);
    final hasBack = cameras!.any((c) => c.lensDirection == CameraLensDirection.back);

    // لو ما فيه إلا كاميرا وحدة، ما نسوي شيء
    if (!(hasFront && hasBack)) return;

    _currentLens = (_currentLens == CameraLensDirection.front)
        ? CameraLensDirection.back
        : CameraLensDirection.front;

    // إذا الكاميرا شغالة: نعيد تهيئتها
    if (isCameraOn) {
      await cameraController?.dispose();
      cameraController = null;
      isCameraInitialized = false;

      await _initializeCamera();
      isCameraOn = true;
      notifyListeners();
    }
  }

  Future<bool> requestMicPermissionIfNeeded() async {
    final status = await Permission.microphone.status;
    if (status.isGranted) return true;
    if (status.isPermanentlyDenied) return false;

    final requested = await Permission.microphone.request();
    return requested.isGranted;
  }

  Future<void> toggleMic() async {
    if (!isMicOn) {
      final ok = await requestMicPermissionIfNeeded();
      if (!ok) return;
      isMicOn = true;
    } else {
      isMicOn = false;
    }
    notifyListeners();
  }

  void toggleHand() {
    isHandRaised = !isHandRaised;
    notifyListeners();
  }

  Future<void> disposeSession() async {
    await cameraController?.dispose();
    cameraController = null;
  }
}
