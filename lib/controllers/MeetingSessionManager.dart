import 'package:flutter/foundation.dart';
import '../controllers/ZegoSessionController.dart';
import '../controllers/SignCaptioningController.dart';
import '../controllers/CaptionController.dart';
import '../models/MeetingModel.dart';
import '../models/UserModel.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MeetingSessionManager extends ChangeNotifier {
  MeetingSessionManager._();
  static final MeetingSessionManager instance = MeetingSessionManager._();

  final ZegoSessionController    session = ZegoSessionController();
  final SignCaptioningController signing = SignCaptioningController();

  StreamSubscription<DocumentSnapshot>? _meetingSub;

  MeetingModel? activeMeeting;
  UserModel?    activeUser;

  bool get hasActiveMeeting => activeMeeting != null;
  bool get isInMeeting      => hasActiveMeeting;

  void _cancelMeetingListener() {
    _meetingSub?.cancel();
    _meetingSub = null;
  }

  Future<void> startOrJoin({
    required MeetingModel meeting,
    required UserModel    user,
  }) async {
    if (activeMeeting?.meetingId == meeting.meetingId &&
        session.isInitialized) {
      activeMeeting = meeting;
      activeUser    = user;
      notifyListeners();
      return;
    }

    activeMeeting = meeting;
    activeUser    = user;

    session.removeListener(_forward);
    session.addListener(_forward);

    final ok = await session.ensurePermissions(
      needMic:    user.micAccessSettings,
      needCamera: user.cameraAccessSettings,
    );

    if (!ok) throw Exception('Permissions not granted');

    await session.initialize();

    final fbUid = FirebaseAuth.instance.currentUser?.uid;
    if (fbUid == null) throw Exception('No Firebase user');

    // ── Wire sign captioning ──────────────────────────────────────────
    await signing.initialize();
    signing.attachZegoController(session);               // ML camera control
    session.signController = signing;                    // frame forwarding
    CaptionController.instance.attachSignController(signing); // label bridge
    // ─────────────────────────────────────────────────────────────────

    await session.loginRoom(
      roomId:   meeting.meetingId,
      userId:   fbUid,
      userName: user.name.isNotEmpty ? user.name : fbUid,
    );

    await session.startPublishing();
    _cancelMeetingListener();

    _meetingSub = FirebaseFirestore.instance
        .collection('Meetings')
        .doc(meeting.meetingId)
        .snapshots()
        .listen((snap) async {
      if (!snap.exists) return;
      final data = snap.data() as Map<String, dynamic>?;
      if (data == null) return;
      final isActive = data['isActive'] as bool? ?? true;
      if (!isActive) await endAndDispose();
    });

    notifyListeners();
  }

  void detachUIOnly() {
    notifyListeners();
  }

  Future<void> endAndDispose() async {
    _cancelMeetingListener();
    session.removeListener(_forward);

    // ── Tear down sign captioning ─────────────────────────────────────
    await signing.disable();
    CaptionController.instance.detachSignController();
    session.signController = null;
    // ─────────────────────────────────────────────────────────────────

    await session.disposeSession();
    activeMeeting = null;
    activeUser    = null;
    notifyListeners();
  }

  void _forward() => notifyListeners();
}