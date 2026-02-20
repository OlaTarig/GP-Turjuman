import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:zego_express_engine/zego_express_engine.dart';

class ZegoSessionController extends ChangeNotifier {
  // ✅ غيّريها بقيمك من Zego Console
  static const int appID = 802433530; // مثال: 123456789
  static const String appSign = '2b558d4663aee85fd1be1f7b5329a007429f46d46fde51811fca1f5d05f9930b';

  bool isInitialized = false;

  bool isMicOn = false;
  bool isCameraOn = false;

  String? currentRoomId;
  String? currentUserId;
  String? currentUserName;

  // Canvas Widgets
  Widget? localViewWidget;
  int? _localViewID;

  // أول ريموت فقط (لأن واجهتك الحالية تعرض remote واحد)
  Widget? remoteViewWidget;
  int? _remoteViewID;

  String? _playingRemoteStreamId;
  String? _playingRemoteUserId;

  StreamSubscription? _roomStreamUpdateSub;

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

    await ZegoExpressEngine.createEngineWithProfile(
      ZegoEngineProfile(
        appID,
        ZegoScenario.General,
        appSign: appSign,
      ),
    );

    // ✅ افتراضيًا OFF (حسب متطلباتكم)
    ZegoExpressEngine.instance.muteMicrophone(true);
    ZegoExpressEngine.instance.enableCamera(false);
    isMicOn = false;
    isCameraOn = false;

    // ✅ Event Handler: لما أحد ينشر/يوقف ستريم داخل الغرفة
    ZegoExpressEngine.onRoomStreamUpdate =
        (String roomID, ZegoUpdateType updateType, List<ZegoStream> streamList, Map<String, dynamic> extendedData) async {
      if (roomID != currentRoomId) return;

      if (updateType == ZegoUpdateType.Add) {
        // شغّل أول ستريم ريموت مو ستريمك
        for (final s in streamList) {
          // تجاهل ستريمك
          if (s.user.userID == currentUserId) continue;

          // لو ما عندنا ريموت شغال، شغله
          if (_playingRemoteStreamId == null) {
            await startPlayingRemote(streamId: s.streamID, remoteUserId: s.user.userID);
            break;
          }
        }
      } else if (updateType == ZegoUpdateType.Delete) {
        // لو الستريم اللي شغال انحذف، أوقفه
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

  /// ✅ ينشئ preview محلي + ينشر الستريم
  Future<void> startPublishing() async {
    final uid = currentUserId;
    if (uid == null) return;

    // جهزي local canvas widget مرة وحدة
    localViewWidget ??= await ZegoExpressEngine.instance.createCanvasView((viewID) {
      _localViewID = viewID;

      final canvas = ZegoCanvas.view(viewID);
      ZegoExpressEngine.instance.startPreview(canvas: canvas);
    });

    // انشر ستريمك (streamID ثابت)
    final streamId = _streamIdFor(uid);
    ZegoExpressEngine.instance.startPublishingStream(streamId);

    notifyListeners();
  }

  /// ✅ تشغيل ريموت (streamId يأتي من onRoomStreamUpdate)
  Future<void> startPlayingRemote({
    required String streamId,
    required String remoteUserId,
  }) async {
    // لو نفس الستريم شغال خلاص
    if (_playingRemoteStreamId == streamId && remoteViewWidget != null) return;

    // لو فيه ريموت شغال، وقفه أول
    stopPlayingRemote();

    _playingRemoteStreamId = streamId;
    _playingRemoteUserId = remoteUserId;

    remoteViewWidget = await ZegoExpressEngine.instance.createCanvasView((viewID) {
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

  Future<bool> toggleCameraWithPermission() async {
    if (!isCameraOn) {
      final st = await Permission.camera.status;
      if (!st.isGranted) {
        final req = await Permission.camera.request();
        if (!req.isGranted) return false;
      }
    }

    isCameraOn = !isCameraOn;
    ZegoExpressEngine.instance.enableCamera(isCameraOn);
    notifyListeners();
    return true;
  }

  Future<void> disposeSession() async {
    _roomStreamUpdateSub?.cancel();
    _roomStreamUpdateSub = null;

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