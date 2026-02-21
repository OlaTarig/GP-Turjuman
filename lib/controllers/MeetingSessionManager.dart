import 'package:flutter/foundation.dart';
import '../controllers/ZegoSessionController.dart';
import '../models/MeetingModel.dart';
import '../models/UserModel.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

class MeetingSessionManager extends ChangeNotifier {
  MeetingSessionManager._();
  static final MeetingSessionManager instance = MeetingSessionManager._();

  final ZegoSessionController session = ZegoSessionController();
  StreamSubscription<DocumentSnapshot>? _meetingSub;

  MeetingModel? activeMeeting;
  UserModel? activeUser;

  bool get hasActiveMeeting => activeMeeting != null;

  /// اذا تبين تستخدمينه للبانر/الـmini preview
  bool get isInMeeting => hasActiveMeeting;

  /// ابدأ/ادخل ميتنق (Host أو Participant)
  void _cancelMeetingListener() {
    _meetingSub?.cancel();
    _meetingSub = null;
  }
  Future<void> startOrJoin({
    required MeetingModel meeting,
    required UserModel user,
  }) async {
    // اذا نفس الميتنق شغال بالفعل، لا تعيدين تسجيل
    if (activeMeeting?.meetingId == meeting.meetingId && session.isInitialized) {
      activeMeeting = meeting;
      activeUser = user;
      notifyListeners();
      return;
    }

    activeMeeting = meeting;
    activeUser = user;

    session.removeListener(_forward);
    session.addListener(_forward);

    // permissions حسب إعدادات المستخدم
    final ok = await session.ensurePermissions(
      needMic: user.micAccessSettings,
      needCamera: user.cameraAccessSettings,
    );

    if (!ok) {
      // خليه يرجع false عبر Exception (عشان تعرضين SnackBar من UI)
      throw Exception('Permissions not granted');
    }

    await session.initialize();

    // مهم: userId المستخدم داخل room لازم يكون Firebase uid (زي ما سويتي)
    await session.loginRoom(
      roomId: meeting.meetingId,
      userId: user.userId,
      userName: user.name.isNotEmpty ? user.name : user.userId,
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
      if (!isActive) {
        // ✅ الاجتماع انتهى -> اقفلي الجلسة وشيلي البانر
        await endAndDispose();
      }
    });

    notifyListeners();
  }

  /// خروج "من الصفحة" فقط: لا يطفي الجلسة
  void detachUIOnly() {
    // ما نسوي شيء هنا، بس موجودة كفكرة
    notifyListeners();
  }

  /// انهاء فعلي للميتنق (اذا host) أو leave (اذا participant) بيجي بالخطوات الجاية
  Future<void> endAndDispose() async {
    _cancelMeetingListener();
    session.removeListener(_forward);
    await session.disposeSession();
    activeMeeting = null;
    activeUser = null;
    notifyListeners();
  }

  void _forward() => notifyListeners();
}