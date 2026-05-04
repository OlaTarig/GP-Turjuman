import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:zego_express_engine/zego_express_engine.dart';

class ZegoSessionController extends ChangeNotifier {
  static const int    appID   = 1007373030;
  static const String appSign =
      '98d7d6323f1cad29be6727e77b8622e847660a4d1999846367d450ee7f976606';

  bool isInitialized = false;

  bool isMicOn       = false;
  bool isCameraOn    = false;
  bool isFrontCamera = true;

  bool isScreenSharing = false;

  String? currentRoomId;
  String? currentUserId;
  String? currentUserName;

  Widget? localViewWidget;
  int?    _localViewID;

  Widget? remoteViewWidget;
  int?    _remoteViewID;

  String? _playingRemoteStreamId;
  String? _playingRemoteUserId;

  String? _myStreamId;
  String? _myScreenStreamId;

  Widget? remoteScreenWidget;
  int?    _remoteScreenViewID;
  String? _playingRemoteScreenStreamId;

  // ──────────────────────────────────────────────────────────────────

  Future<bool> ensurePermissions({
    required bool needMic,
    required bool needCamera,
  }) async {
    if (needMic) {
      final mic = await Permission.microphone.request();
      if (!mic.isGranted) return false;
    }
    if (needCamera) {
      final cam = await Permission.camera.request();
      if (!cam.isGranted) return false;
    }
    return true;
  }

  Future<void> initialize() async {
    if (isInitialized) return;

    ZegoExpressEngine.onPublisherStateUpdate =
        (String streamID, ZegoPublisherState state, int errorCode,
        Map<String, dynamic> ext) {
      debugPrint(
          "PUBLISH stream=$streamID state=$state error=$errorCode");
    };

    ZegoExpressEngine.onPlayerStateUpdate =
        (String streamID, ZegoPlayerState state, int errorCode,
        Map<String, dynamic> ext) {
      debugPrint("PLAY stream=$streamID state=$state error=$errorCode");
    };

    ZegoExpressEngine.onRoomStateUpdate =
        (String roomID, ZegoRoomState state, int errorCode,
        Map<String, dynamic> ext) {
      debugPrint("ROOM room=$roomID state=$state error=$errorCode");
    };

    await ZegoExpressEngine.createEngineWithProfile(
      ZegoEngineProfile(
        appID,
        ZegoScenario.General,
        appSign: appSign,
      ),
    );

    final v = ZegoVideoConfig.preset(ZegoVideoConfigPreset.Preset720P);
    v.fps     = 15;
    v.bitrate = 2200;
    await ZegoExpressEngine.instance.setVideoConfig(v);

    ZegoExpressEngine.instance.setAudioConfig(
      ZegoAudioConfig.preset(ZegoAudioConfigPreset.StandardQualityStereo),
    );
    ZegoExpressEngine.instance.enableAEC(true);
    ZegoExpressEngine.instance.enableAGC(true);
    ZegoExpressEngine.instance.enableANS(true);

    ZegoExpressEngine.instance.muteMicrophone(true);
    ZegoExpressEngine.instance.enableCamera(false);
    isMicOn    = false;
    isCameraOn = false;

    ZegoExpressEngine.onRoomStreamUpdate =
        (String roomID, ZegoUpdateType updateType,
        List<ZegoStream> streamList,
        Map<String, dynamic> extendedData) async {
      debugPrint(
          "STREAM_UPDATE room=$roomID type=$updateType streams=${streamList.map((s) => '${s.streamID}/${s.user.userID}').toList()}");

      if (roomID != currentRoomId) return;

      if (updateType == ZegoUpdateType.Add) {
        for (final s in streamList) {
          if (s.user.userID == currentUserId) continue;

          if (s.streamID.endsWith('_screen')) {
            if (_playingRemoteScreenStreamId == null) {
              await _startPlayingRemoteScreen(streamId: s.streamID);
            }
          } else {
            if (_playingRemoteStreamId == null) {
              await startPlayingRemote(
                streamId:     s.streamID,
                remoteUserId: s.user.userID,
              );
            }
          }
        }
      } else if (updateType == ZegoUpdateType.Delete) {
        for (final s in streamList) {
          if (s.streamID == _playingRemoteStreamId) stopPlayingRemote();
          if (s.streamID == _playingRemoteScreenStreamId) {
            _stopPlayingRemoteScreen();
          }
        }
      }
    };

    isInitialized = true;
    notifyListeners();
  }

  Future<void> loginRoom({
    required String roomId,
    required String userId,
    required String userName,
  }) async {
    if (!isInitialized) await initialize();

    currentRoomId   = roomId;
    currentUserId   = userId;
    currentUserName = userName;

    _myStreamId =
    'stream_${userId}_${DateTime.now().millisecondsSinceEpoch}';
    _myScreenStreamId = '${_myStreamId}_screen';

    final user = ZegoUser(userId, userName);

    await ZegoExpressEngine.instance.loginRoom(
      roomId,
      user,
      config: ZegoRoomConfig.defaultConfig()..isUserStatusNotify = true,
    );

    notifyListeners();
  }

  Future<void> logoutRoom() async {
    final roomId = currentRoomId;
    if (roomId == null) return;

    if (isScreenSharing) await stopScreenShare();

    stopPlayingRemote();
    _stopPlayingRemoteScreen();

    ZegoExpressEngine.instance.stopPublishingStream();
    ZegoExpressEngine.instance.stopPreview();

    await ZegoExpressEngine.instance.logoutRoom(roomId);

    currentRoomId     = null;
    currentUserId     = null;
    currentUserName   = null;
    _myStreamId       = null;
    _myScreenStreamId = null;

    notifyListeners();
  }

  Future<void> startPublishing() async {
    final uid = currentUserId;
    if (uid == null) return;

    localViewWidget ??=
    await ZegoExpressEngine.instance.createCanvasView((viewID) {
      _localViewID = viewID;
      final canvas = ZegoCanvas.view(viewID);
      ZegoExpressEngine.instance.startPreview(canvas: canvas);
    });

    final streamId = _myStreamId ?? 'stream_$uid';
    ZegoExpressEngine.instance.startPublishingStream(streamId);

    notifyListeners();
  }

  Future<void> startPlayingRemote({
    required String streamId,
    required String remoteUserId,
  }) async {
    if (_playingRemoteStreamId == streamId && remoteViewWidget != null) {
      return;
    }

    stopPlayingRemote();

    _playingRemoteStreamId = streamId;
    _playingRemoteUserId   = remoteUserId;

    remoteViewWidget =
    await ZegoExpressEngine.instance.createCanvasView((viewID) {
      _remoteViewID = viewID;
      final canvas  = ZegoCanvas.view(viewID);
      ZegoExpressEngine.instance.startPlayingStream(streamId,
          canvas: canvas);
    });

    notifyListeners();
  }

  void stopPlayingRemote() {
    if (_playingRemoteStreamId != null) {
      ZegoExpressEngine.instance
          .stopPlayingStream(_playingRemoteStreamId!);
    }
    _playingRemoteStreamId = null;
    _playingRemoteUserId   = null;
    remoteViewWidget       = null;
    _remoteViewID          = null;
    notifyListeners();
  }

  // ─── Screen Share ─────────────────────────────────────────────────

  ZegoScreenCaptureSource? _screenCaptureSource;

  Future<bool> startScreenShare() async {
    if (isScreenSharing) return true;
    if (_myScreenStreamId == null) return false;

    try {
      _screenCaptureSource =
      await ZegoExpressEngine.instance.createScreenCaptureSource();

      if (_screenCaptureSource == null) {
        debugPrint('❌ Failed to create screen capture source');
        return false;
      }

      await ZegoExpressEngine.instance.setVideoSource(
        ZegoVideoSourceType.ScreenCapture,
        channel: ZegoPublishChannel.Aux,
      );

      await _screenCaptureSource!.startCapture();

      await ZegoExpressEngine.instance.startPublishingStream(
        _myScreenStreamId!,
        channel: ZegoPublishChannel.Aux,
      );

      isScreenSharing = true;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('❌ startScreenShare error: $e');
      await _cleanupScreenCapture();
      return false;
    }
  }

  Future<void> stopScreenShare() async {
    if (!isScreenSharing) return;
    await _cleanupScreenCapture();
    isScreenSharing = false;
    notifyListeners();
  }

  Future<void> _cleanupScreenCapture() async {
    try {
      await _screenCaptureSource?.stopCapture();
      await ZegoExpressEngine.instance
          .destroyScreenCaptureSource(_screenCaptureSource!);
      _screenCaptureSource = null;
    } catch (_) {}

    try {
      ZegoExpressEngine.instance
          .stopPublishingStream(channel: ZegoPublishChannel.Aux);
    } catch (_) {}

    try {
      await ZegoExpressEngine.instance.setVideoSource(
        ZegoVideoSourceType.Camera,
        channel: ZegoPublishChannel.Aux,
      );
    } catch (_) {}
  }

  Future<bool> toggleScreenShare() async {
    if (isScreenSharing) {
      await stopScreenShare();
      return true;
    } else {
      return await startScreenShare();
    }
  }

  // ─── Remote screen share playback ────────────────────────────────

  Future<void> _startPlayingRemoteScreen(
      {required String streamId}) async {
    if (_playingRemoteScreenStreamId == streamId &&
        remoteScreenWidget != null) return;

    _stopPlayingRemoteScreen();
    _playingRemoteScreenStreamId = streamId;

    remoteScreenWidget =
    await ZegoExpressEngine.instance.createCanvasView((viewID) {
      _remoteScreenViewID = viewID;
      final canvas        = ZegoCanvas.view(viewID);
      ZegoExpressEngine.instance.startPlayingStream(streamId,
          canvas: canvas);
    });

    notifyListeners();
  }

  void _stopPlayingRemoteScreen() {
    if (_playingRemoteScreenStreamId != null) {
      ZegoExpressEngine.instance
          .stopPlayingStream(_playingRemoteScreenStreamId!);
    }
    _playingRemoteScreenStreamId = null;
    remoteScreenWidget           = null;
    _remoteScreenViewID          = null;
    notifyListeners();
  }

  // ─── Mic / Camera / Flip ─────────────────────────────────────────

  Future<bool> toggleMicWithPermission() async {
    if (!isMicOn) {
      final st = await Permission.microphone.status;
      if (!st.isGranted) {
        final req = await Permission.microphone.request();
        if (!req.isGranted) return false;
      }
    }
    isMicOn = !isMicOn;
    ZegoExpressEngine.instance.muteMicrophone(!isMicOn);
    notifyListeners();
    return true;
  }

  Future<bool> toggleCameraWithPermission() async {
    if (!isCameraOn) {
      final st = await Permission.camera.status;
      if (!st.isGranted) {
        final req = await Permission.camera.request();
        if (!req.isGranted) return false;
      }
    }

    isCameraOn = !isCameraOn;
    await ZegoExpressEngine.instance.enableCamera(isCameraOn);

    if (!isCameraOn) {
      await ZegoExpressEngine.instance.stopPreview();
    } else {
      if (_localViewID != null) {
        final canvas = ZegoCanvas.view(_localViewID!);
        ZegoExpressEngine.instance.startPreview(canvas: canvas);
      }
    }

    notifyListeners();
    return true;
  }

  Future<void> flipCamera() async {
    if (!isCameraOn) return;
    isFrontCamera = !isFrontCamera;
    await ZegoExpressEngine.instance.useFrontCamera(isFrontCamera);
    notifyListeners();
  }

  /// ✅ يستخدم لما الهوست يسحب الصلاحية
  Future<void> forceMicOff() async {
    if (!isMicOn) return;

    isMicOn = false;

    try {
      ZegoExpressEngine.instance.muteMicrophone(true);
    } catch (_) {}

    notifyListeners();
  }

  /// ✅ يستخدم لما الهوست يسحب صلاحية الكاميرا
  Future<void> forceCameraOff() async {
    if (!isCameraOn) return;

    isCameraOn = false;

    try {
      await ZegoExpressEngine.instance.enableCamera(false);
      await ZegoExpressEngine.instance.stopPreview();
    } catch (_) {}

    notifyListeners();
  }

  Future<void> disposeSession() async {
    try {
      await logoutRoom();
    } catch (_) {}

    await _cleanupScreenCapture();

    localViewWidget     = null;
    remoteViewWidget    = null;
    remoteScreenWidget  = null;
    _localViewID        = null;
    _remoteViewID       = null;
    _remoteScreenViewID = null;

    if (isInitialized) {
      await ZegoExpressEngine.destroyEngine();
      isInitialized = false;
    }

    notifyListeners();
  }
}
