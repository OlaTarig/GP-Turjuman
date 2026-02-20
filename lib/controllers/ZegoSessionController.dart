import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:zego_express_engine/zego_express_engine.dart';

class ZegoSessionController extends ChangeNotifier {
  // ✅ بياناتك من Zego Console
  static const int appID = 2074378114;
  static const String appSign =
      'bc7513ea95f678cdf0f6647bb845f230095caaa0d236ec0e28b375cce7137048';

  bool isInitialized = false;

  bool isMicOn = false;
  bool isCameraOn = false;

  bool isFrontCamera = true;

  String? currentRoomId;
  String? currentUserId;
  String? currentUserName;

  // Canvas Widgets
  Widget? localViewWidget;
  int? _localViewID;

  Widget? remoteViewWidget;
  int? _remoteViewID;

  String? _playingRemoteStreamId;
  String? _playingRemoteUserId;

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
        (String streamID, ZegoPublisherState state, int errorCode, Map<String, dynamic> ext) {
      debugPrint("PUBLISH stream=$streamID state=$state error=$errorCode");
    };

    ZegoExpressEngine.onPlayerStateUpdate =
        (String streamID, ZegoPlayerState state, int errorCode, Map<String, dynamic> ext) {
      debugPrint("PLAY stream=$streamID state=$state error=$errorCode");
    };

    ZegoExpressEngine.onRoomStateUpdate =
        (String roomID, ZegoRoomState state, int errorCode, Map<String, dynamic> ext) {
      debugPrint("ROOM room=$roomID state=$state error=$errorCode");
    };

    ZegoExpressEngine.onRoomStreamUpdate =
        (String roomID, ZegoUpdateType updateType, List<ZegoStream> streamList, Map<String, dynamic> ext) {
      debugPrint("STREAM_UPDATE room=$roomID type=$updateType streams=${streamList.map((s)=>'${s.streamID}/${s.user.userID}').toList()}");
      // خلي كودك الحالي بعدها
    };

    await ZegoExpressEngine.createEngineWithProfile(
      ZegoEngineProfile(
        appID,
        ZegoScenario.General,
        appSign: appSign,
      ),
    );

    // ✅ افتراضيًا OFF حسب متطلباتكم
    ZegoExpressEngine.instance.muteMicrophone(true);
    ZegoExpressEngine.instance.enableCamera(false);
    isMicOn = false;
    isCameraOn = false;

    // ✅ تشغيل ريموت تلقائيًا (أول ستريم فقط)
    ZegoExpressEngine.onRoomStreamUpdate =
        (String roomID, ZegoUpdateType updateType, List<ZegoStream> streamList,
        Map<String, dynamic> extendedData) async {
      if (roomID != currentRoomId) return;

      if (updateType == ZegoUpdateType.Add) {
        for (final s in streamList) {
          if (s.user.userID == currentUserId) continue;

          if (_playingRemoteStreamId == null) {
            await startPlayingRemote(
              streamId: s.streamID,
              remoteUserId: s.user.userID,
            );
            break;
          }
        }
      } else if (updateType == ZegoUpdateType.Delete) {
        for (final s in streamList) {
          if (s.streamID == _playingRemoteStreamId) {
            stopPlayingRemote();
            break;
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
    if (!isInitialized) {
      await initialize();
    }

    currentRoomId = roomId;
    currentUserId = userId;
    currentUserName = userName;

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

    stopPlayingRemote();

    ZegoExpressEngine.instance.stopPublishingStream();
    ZegoExpressEngine.instance.stopPreview();

    await ZegoExpressEngine.instance.logoutRoom(roomId);

    currentRoomId = null;
    currentUserId = null;
    currentUserName = null;

    notifyListeners();
  }

  /// ✅ local preview + publish
  Future<void> startPublishing() async {
    final uid = currentUserId;
    if (uid == null) return;

    // جهزي local canvas view مرة وحدة
    localViewWidget ??=
    await ZegoExpressEngine.instance.createCanvasView((viewID) {
      _localViewID = viewID;

      // preview على canvas
      final canvas = ZegoCanvas.view(viewID);
      ZegoExpressEngine.instance.startPreview(canvas: canvas);
    });

    // publish stream
    final streamId = _streamIdFor(uid);
    ZegoExpressEngine.instance.startPublishingStream(streamId);

    notifyListeners();
  }

  /// ✅ play remote
  Future<void> startPlayingRemote({
    required String streamId,
    required String remoteUserId,
  }) async {
    if (_playingRemoteStreamId == streamId && remoteViewWidget != null) return;

    stopPlayingRemote();

    _playingRemoteStreamId = streamId;
    _playingRemoteUserId = remoteUserId;

    remoteViewWidget =
    await ZegoExpressEngine.instance.createCanvasView((viewID) {
      _remoteViewID = viewID;

      final canvas = ZegoCanvas.view(viewID);
      ZegoExpressEngine.instance.startPlayingStream(streamId, canvas: canvas);
    });

    notifyListeners();
  }

  void stopPlayingRemote() {
    if (_playingRemoteStreamId != null) {
      ZegoExpressEngine.instance.stopPlayingStream(_playingRemoteStreamId!);
    }
    _playingRemoteStreamId = null;
    _playingRemoteUserId = null;

    remoteViewWidget = null;
    _remoteViewID = null;

    notifyListeners();
  }

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

  /// ✅ يحل مشكلة "تعليق آخر فريم" + يرجع preview عند التشغيل
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
      // ✅ وقف preview عشان ما يعلق آخر فريم
      await ZegoExpressEngine.instance.stopPreview();
    } else {
      // ✅ رجع preview على نفس canvas
      if (_localViewID != null) {
        final canvas = ZegoCanvas.view(_localViewID!);
        ZegoExpressEngine.instance.startPreview(canvas: canvas);
      }
    }

    notifyListeners();
    return true;
  }

  /// ✅ Flip camera (front/back)
  Future<void> flipCamera() async {
    if (!isCameraOn) return;

    isFrontCamera = !isFrontCamera;
    await ZegoExpressEngine.instance.useFrontCamera(isFrontCamera);

    notifyListeners();
  }

  Future<void> disposeSession() async {
    try {
      await logoutRoom();
    } catch (_) {}

    localViewWidget = null;
    remoteViewWidget = null;
    _localViewID = null;
    _remoteViewID = null;

    if (isInitialized) {
      await ZegoExpressEngine.destroyEngine();
      isInitialized = false;
    }

    notifyListeners();
  }

  String _streamIdFor(String userId) => 'stream_$userId';
}