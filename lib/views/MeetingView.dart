import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:shared_preferences/shared_preferences.dart';
import '../models/MeetingModel.dart';
import '../models/UserModel.dart';
import '../controllers/MeetingController.dart';
import '../controllers/ZegoSessionController.dart';
import '../controllers/MeetingSessionManager.dart';
import '../controllers/CaptionController.dart';
import '../controllers/SignCaptioningController.dart';
import '../controllers/sign_recognition_controller.dart';
import '../models/CaptionsAndTranscriptionModel.dart';
import '../features/sign_language/sign_language_module.dart';
import 'widgets/sign_captioning_overlay.dart';
import 'widgets/sign_recognition_overlay.dart';
import 'HomePage.dart';

class MeetingView extends StatefulWidget {
  final MeetingModel meeting;
  final UserModel user;

  const MeetingView({super.key, required this.meeting, required this.user});

  @override
  State<MeetingView> createState() => _MeetingScreenState();
}

class _MeetingScreenState extends State<MeetingView> {
  // ── Unified brand orange used everywhere in this screen ──────────────
  static const Color primaryOrange   = Color(0xFFFFB382);
  static const Color orangeLight     = Color(0xFFFFD98F);   // lighter tint
  static const Color orangeDark      = Color(0xFFE8955A);   // pressed / darker
  static const Color darkBg          = Color(0xFF2D2F31);

  late final MeetingSessionManager mgr;
  ZegoSessionController get session => mgr.session;

  StreamSubscription<DocumentSnapshot>? _meetingSub;
  StreamSubscription<DocumentSnapshot>? _userSub;

  bool _endedDialogShown      = false;
  bool _screenShareAllowedForAll = false;
  bool _signAvatarEnabled     = false;

  // FIX #1 – guard so the Firestore listener cannot kill streams
  // before the Zego session has finished initialising.
  bool _sessionReady = false;

  final CaptionController    _captionController = CaptionController.instance;
  final SignLanguageModule    _signLang          = SignLanguageModule.instance;

  SignCaptioningController  get _signing     => mgr.signing;
  SignRecognitionController get _recognition => mgr.recognition;

  String get _currentUid =>
      FirebaseAuth.instance.currentUser?.uid ?? widget.user.userId;

  bool get _isHost {
    final fbUid = FirebaseAuth.instance.currentUser?.uid;
    return (fbUid != null && fbUid == widget.meeting.hostId) ||
        widget.user.userId == widget.meeting.hostId;
  }

  bool get _isAllowedToShare => _isHost || _screenShareAllowedForAll;

  void _cancelMeetingListener() {
    _meetingSub?.cancel();
    _meetingSub = null;
  }

  static const _windowChannel =
  MethodChannel('com.example.turjuman/window_flags');

  Future<void> _enableSecureScreen() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool('secure_screen_enabled') ?? true;
    if (enabled) {
      await _windowChannel.invokeMethod('addSecureFlag');
    }
  }

  Future<void> _disableSecureScreen() async {
    await _windowChannel.invokeMethod('clearSecureFlag');
  }

  @override
  void initState() {
    super.initState();

    _enableSecureScreen();

    mgr = MeetingSessionManager.instance;
    mgr.addListener(_onSessionChanged);
    _captionController.addListener(_onSessionChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _signing.addListener(_onSessionChanged);
      _recognition.addListener(_onSessionChanged);
    });

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      _userSub = FirebaseFirestore.instance
          .collection('User')
          .doc(uid)
          .snapshots()
          .listen((snap) async {
        // FIX #1 – do not touch mic/camera until the Zego session is ready.
        // Without this guard the listener fires immediately on join and kills
        // the streams before Zego has a chance to establish them.
        if (!_sessionReady) return;

        final data = snap.data() as Map<String, dynamic>? ?? {};
        final micGranted = data['micPermissionGranted'] == true;
        final camGranted = data['cameraPermissionGranted'] == true;

        if (!(micGranted && camGranted)) {
          if (session.isMicOn) {
            await session.forceMicOff();
          }
          if (session.isCameraOn) {
            await session.forceCameraOff();
          }
          if (mounted) setState(() {});
        }
      });
    }

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _checkAccessSettingsOnEntry();

      final meetingController = MeetingController();
      await meetingController.initializeUserMeetingSession(
        meetingId: widget.meeting.meetingId,
        hostId:    widget.meeting.hostId,
      );

      try {
        await mgr.startOrJoin(meeting: widget.meeting, user: widget.user);

        // FIX #3 – Host automatically gets mic & camera permission flags set
        // in Firestore so they are never blocked by the permission-flag check.
        if (_isHost) {
          final hostUid = FirebaseAuth.instance.currentUser?.uid;
          if (hostUid != null) {
            await FirebaseFirestore.instance
                .collection('User')
                .doc(hostUid)
                .set({
              'micPermissionGranted':    true,
              'cameraPermissionGranted': true,
            }, SetOptions(merge: true));
          }
        }

        // FIX #1 – Mark session as ready AFTER startOrJoin completes so the
        // Firestore listener can now safely manage mic/camera state.
        _sessionReady = true;

        _captionController.setMeetingId(widget.meeting.meetingId);
        _captionController.isMicMuted = !session.isMicOn;
        _signing.attachCaptionController(
          _captionController,
          _currentUid,
          widget.user.name,
          widget.meeting.meetingId,
        );

        // FIX #4 – Log beginCapture errors instead of silently ignoring them.
        _captionController.beginCapture(
          _currentUid,
          widget.meeting.meetingId,
          widget.user.name,
        ).catchError((e) {
          debugPrint('⚠️ beginCapture error: $e');
        });

        await _signLang.initialize();
        _signLang.handController.addListener(_onSessionChanged);
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Camera/Microphone permission is required'),
            action: SnackBarAction(
              label: 'Settings',
              onPressed: openAppSettings,
            ),
          ),
        );
      }
    });

    _meetingSub = FirebaseFirestore.instance
        .collection('Meetings')
        .doc(widget.meeting.meetingId)
        .snapshots()
        .listen((snap) async {
      if (!snap.exists) return;

      final data = snap.data() as Map<String, dynamic>?;
      if (data == null) return;

      final allowed = data['screenShareAllowed'] as bool? ?? false;
      if (mounted) {
        setState(() => _screenShareAllowedForAll = allowed);
      }

      final isActive = data['isActive'] as bool? ?? true;
      if (!isActive && mounted && !_endedDialogShown) {
        _endedDialogShown = true;

        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            title: const Text('Meeting ended'),
            content: const Text('The host has ended the meeting.'),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryOrange,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );

        try {
          await session.disposeSession();
        } catch (_) {}

        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomePage()),
              (route) => false,
        );
      }
    });
  }

  void _onSessionChanged() {
    if (!mounted) return;
    setState(() {});
    final err = _captionController.lastError;
    if (err != null) {
      _captionController.lastError = null;
      _showSnackBar(err, Colors.redAccent, Icons.mic_off);
    }
  }

  void _checkAccessSettingsOnEntry() {
    final micOff = widget.user.micAccessSettings == false;
    final camOff = widget.user.cameraAccessSettings == false;

    if (micOff || camOff) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Access Required'),
          content: Text(
            micOff && camOff
                ? 'Microphone and Camera access are disabled in your settings. Please enable them to use meeting features.'
                : micOff
                ? 'Microphone access is disabled in your settings. Please enable it to use audio.'
                : 'Camera access is disabled in your settings. Please enable it to use video.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Later',
                  style: TextStyle(color: primaryOrange)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryOrange,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(context);
                openAppSettings();
              },
              child: const Text('Open Settings'),
            ),
          ],
        ),
      );
    }
  }

  @override
  void dispose() {
    _disableSecureScreen();

    _meetingSub?.cancel();
    _userSub?.cancel();
    mgr.removeListener(_onSessionChanged);
    _captionController.removeListener(_onSessionChanged);
    _signing.removeListener(_onSessionChanged);
    _recognition.removeListener(_onSessionChanged);
    _recognition.disable();
    if (_signLang.isInitialized) {
      _signLang.handController.removeListener(_onSessionChanged);
      _signLang.detachFromCaption(_captionController);
      _signLang.stopPlayback();
    }
    super.dispose();
  }

  Future<Map<String, bool>> _getHostPermissionFlags() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return {'mic': false, 'cam': false};

    final snap =
    await FirebaseFirestore.instance.collection('User').doc(uid).get();
    final data = snap.data() ?? {};

    final micGranted = data['micPermissionGranted'] == true;
    final camGranted = data['cameraPermissionGranted'] == true;

    return {'mic': micGranted, 'cam': camGranted};
  }

  void _showSnackBar(String message, Color color, IconData icon) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {},
        ),
      ),
    );
  }

  // ── FIX #2 – mic and camera permission checks are now independent ─────
  Future<void> _onMicPressed() async {
    if (!widget.user.micAccessSettings) {
      _showSnackBar(
          'Microphone is disabled in settings', primaryOrange, Icons.mic_off);
      return;
    }

    // FIX #3 – host bypasses Firestore permission flag entirely.
    if (!_isHost) {
      final flags = await _getHostPermissionFlags();
      // FIX #2 – only check the mic flag, not cam.
      if (flags['mic'] != true) {
        _showSnackBar(
          'Raise hand to request host permission',
          primaryOrange,
          Icons.pan_tool_outlined,
        );
        return;
      }
    }

    final ok = await session.toggleMicWithPermission();
    if (!ok && mounted) {
      _showSnackBar(
          'Microphone permission is required', Colors.redAccent, Icons.mic_off);
    }
    _captionController.isMicMuted = !session.isMicOn;
  }

  // FIX #2 – camera check is now independent of mic flag.
  Future<void> _onCameraPressed() async {
    if (!widget.user.cameraAccessSettings) {
      _showSnackBar(
          'Camera is disabled in settings', primaryOrange, Icons.videocam_off);
      return;
    }

    // FIX #3 – host bypasses Firestore permission flag entirely.
    if (!_isHost) {
      final flags = await _getHostPermissionFlags();
      // FIX #2 – only check the cam flag, not mic.
      if (flags['cam'] != true) {
        _showSnackBar(
          'Raise hand to request host permission',
          primaryOrange,
          Icons.pan_tool_outlined,
        );
        return;
      }
    }

    final ok = await session.toggleCameraWithPermission();
    if (!ok && mounted) {
      _showSnackBar('Camera permission is required', Colors.redAccent,
          Icons.videocam_off);
    }
  }

  Future<void> _onFlipPressed() async {
    if (!session.isCameraOn) {
      _showSnackBar('Turn on camera first', primaryOrange, Icons.cameraswitch);
      return;
    }
    await session.flipCamera();
  }

  Future<void> _onCaptionsPressed() async {
    await _captionController.handleEnableSpeechCaptioning(
      _currentUid,
      widget.meeting.meetingId,
      widget.user.name,
    );
  }

  Future<void> _onSignPressed() async {
    if (_signing.isEnabled) {
      await _signing.disable();
      await _recognition.disable();
    } else {
      if (!session.isCameraOn) {
        _showSnackBar(
          'Turn on your camera first — sign recognition needs camera access',
          primaryOrange,
          Icons.videocam_off,
        );
        return;
      }
      await _signing.startCapture();
      await _recognition.enable();
    }
  }

  void _onSignAvatarPressed() {
    if (!_signAvatarEnabled) {
      setState(() => _signAvatarEnabled = true);
      _signLang.attachToCaption(_captionController);
      _showSnackBar(
        'Sign avatar enabled — captions will be translated to sign language',
        primaryOrange,
        Icons.interpreter_mode,
      );
    } else {
      _signLang.detachFromCaption(_captionController);
      _signLang.stopPlayback();
      setState(() => _signAvatarEnabled = false);
      _showSnackBar(
        'Sign avatar disabled',
        Colors.grey,
        Icons.interpreter_mode,
      );
    }
  }

  Future<void> _onHandPressed() async {
    final meetingController = MeetingController();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final snap =
    await FirebaseFirestore.instance.collection('User').doc(uid).get();
    final data = snap.data() ?? {};
    final isRaised = data['isHandRaised'] == true;

    if (isRaised) {
      await meetingController.lowerHand();
      if (!mounted) return;
      _showSnackBar('Hand lowered', primaryOrange, Icons.pan_tool_outlined);
    } else {
      await meetingController.raiseHand(widget.meeting.meetingId);
      if (!mounted) return;
      _showSnackBar('Hand raised', Colors.green, Icons.pan_tool_outlined);
    }
  }

  Future<void> _onShareScreenPressed() async {
    if (_isHost) {
      if (session.isScreenSharing) {
        await session.stopScreenShare();
        _showSnackBar(
            'Screen sharing stopped', primaryOrange, Icons.stop_screen_share);
        return;
      }
      _showHostShareOptions();
      return;
    }

    if (!_isAllowedToShare) {
      _showSnackBar(
        'You are not allowed to share screen.\nAsk the host to grant permission.',
        Colors.redAccent,
        Icons.stop_screen_share,
      );
      return;
    }

    if (session.isScreenSharing) {
      await session.stopScreenShare();
      _showSnackBar(
          'Screen sharing stopped', primaryOrange, Icons.stop_screen_share);
      return;
    }

    await _startMyScreenShare();
  }

  void _showHostShareOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(99)),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Screen Share',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 20),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.green.shade700,
                    child: const Icon(Icons.screen_share, color: Colors.white),
                  ),
                  title: const Text('Share My Screen',
                      style: TextStyle(color: Colors.white, fontSize: 16)),
                  subtitle: const Text(
                      'Broadcast your screen to all participants',
                      style: TextStyle(color: Colors.white54, fontSize: 13)),
                  onTap: () {
                    Navigator.pop(context);
                    _startMyScreenShare();
                  },
                ),
                const Divider(
                    color: Colors.white12,
                    height: 1,
                    indent: 16,
                    endIndent: 16),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _screenShareAllowedForAll
                        ? Colors.red.shade700
                        : primaryOrange,
                    child: Icon(
                      _screenShareAllowedForAll
                          ? Icons.stop_screen_share
                          : Icons.people,
                      color: Colors.white,
                    ),
                  ),
                  title: Text(
                    _screenShareAllowedForAll
                        ? 'Disallow Participants to Share'
                        : 'Allow All Participants to Share',
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  subtitle: Text(
                    _screenShareAllowedForAll
                        ? 'Participants can currently share their screen'
                        : 'Let all participants share their screen',
                    style:
                    const TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    await _toggleAllParticipantsSharePermission();
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _toggleAllParticipantsSharePermission() async {
    final newValue = !_screenShareAllowedForAll;
    try {
      await FirebaseFirestore.instance
          .collection('Meetings')
          .doc(widget.meeting.meetingId)
          .update({'screenShareAllowed': newValue});

      _showSnackBar(
        newValue
            ? 'All participants can now share their screen'
            : 'Screen sharing disabled for participants',
        newValue ? Colors.green : primaryOrange,
        newValue ? Icons.screen_share : Icons.stop_screen_share,
      );
    } catch (e) {
      _showSnackBar(
          'Failed to update permission', Colors.redAccent, Icons.error_outline);
    }
  }

  Future<void> _startMyScreenShare() async {
    _showSnackBar(
        'Starting screen share...', primaryOrange, Icons.screen_share);

    final ok = await session.toggleScreenShare();
    if (!mounted) return;

    if (ok) {
      _showSnackBar(
          'Screen sharing started', Colors.green, Icons.screen_share);
    } else {
      _showSnackBar(
          'Failed to start screen share', Colors.redAccent, Icons.error_outline);
    }
  }

  void _copyInvitationLink() {
    final link = widget.meeting.invitationLink;
    Clipboard.setData(ClipboardData(text: link));
    if (!mounted) return;
    _showSnackBar('Invitation link copied to clipboard!', Colors.green,
        Icons.check_circle_outline);
  }

  Future<void> _showSendEmailDialog() async {
    final TextEditingController emailController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isSending = false;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              title: const Text(
                'Send Email Invitation',
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E)),
              ),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Enter the participant\'s email address. An invitation will be sent to them automatically.',
                      style: TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter an email address';
                        }
                        if (!value.contains('@') || !value.contains('.')) {
                          return 'Please enter a valid email address';
                        }
                        return null;
                      },
                      decoration: InputDecoration(
                        hintText: 'participant@mail.com',
                        hintStyle: TextStyle(
                            color: Colors.grey.shade400, fontSize: 14),
                        filled: true,
                        fillColor: const Color(0xFFF8F9FA),
                        // unified orange prefix icon
                        prefixIcon: const Icon(Icons.email_outlined,
                            color: primaryOrange),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide:
                          const BorderSide(color: primaryOrange, width: 1.5),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: const BorderSide(
                              color: Colors.redAccent, width: 1.5),
                        ),
                        focusedErrorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: const BorderSide(
                              color: Colors.redAccent, width: 1.5),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 15),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed:
                  isSending ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Cancel',
                      style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: isSending
                      ? null
                      : () async {
                    if (!formKey.currentState!.validate()) return;
                    setDialogState(() => isSending = true);

                    final recipientEmail = emailController.text.trim();
                    final link = widget.meeting.invitationLink;
                    final meetingTitle = widget.meeting.title;
                    final meetingId = widget.meeting.meetingId;
                    final hostName = widget.user.name;

                    try {
                      await FirebaseFirestore.instance
                          .collection('mail')
                          .add({
                        'to': recipientEmail,
                        'message': {
                          'subject':
                          'You\'re invited to join: $meetingTitle',
                          'html': '''
<div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
  <div style="background: linear-gradient(135deg, #FFF9E3, #FFD98F, #FFB382); padding: 30px; border-radius: 16px; text-align: center;">
    <h1 style="color: #1A1A2E; margin: 0;">Meeting Invitation</h1>
  </div>
  <div style="padding: 30px 20px;">
    <p style="font-size: 16px; color: #333;">Hi,</p>
    <p style="font-size: 16px; color: #333;"><strong>$hostName</strong> has invited you to join the meeting:</p>
    <div style="background: #F8F9FA; border-radius: 12px; padding: 20px; margin: 20px 0; border-left: 4px solid #FFB382;">
      <p style="margin: 0 0 8px 0; font-size: 18px; font-weight: bold; color: #1A1A2E;">$meetingTitle</p>
      <p style="margin: 0; font-size: 14px; color: #666;">Meeting ID: $meetingId</p>
    </div>
    <div style="text-align: center; margin: 30px 0;">
      <a href="$link" style="background: linear-gradient(135deg, #FFB382, #FFD98F); color: white; padding: 14px 40px; border-radius: 25px; text-decoration: none; font-size: 16px; font-weight: bold; display: inline-block;">Join Meeting</a>
    </div>
    <p style="font-size: 14px; color: #999; text-align: center;">Or copy this link: <br/><a href="$link" style="color: #FFB382;">$link</a></p>
  </div>
  <div style="border-top: 1px solid #eee; padding-top: 20px; text-align: center;">
    <p style="font-size: 12px; color: #999;">This invitation was sent from Turjuman Meeting App.</p>
  </div>
</div>''',
                        },
                        'createdAt': FieldValue.serverTimestamp(),
                      });

                      if (!context.mounted) return;
                      Navigator.pop(dialogContext);
                      _showSnackBar(
                          'Invitation sent to $recipientEmail',
                          Colors.green,
                          Icons.mark_email_read_outlined);
                    } catch (e) {
                      debugPrint('❌ Error sending email: $e');
                      setDialogState(() => isSending = false);
                      if (!context.mounted) return;
                      Navigator.pop(dialogContext);
                      _showSnackBar(
                          'Failed to send invitation. Please try again.',
                          Colors.redAccent,
                          Icons.error_outline);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryOrange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: isSending
                      ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                      : const Text('Send'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showInviteOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(99)),
                ),
                const SizedBox(height: 16),
                const Text('Invite Participant',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 20),
                ListTile(
                  leading: CircleAvatar(
                      backgroundColor: primaryOrange,
                      child: const Icon(Icons.copy, color: Colors.white)),
                  title: const Text('Copy Invitation Link',
                      style: TextStyle(color: Colors.white, fontSize: 16)),
                  subtitle: const Text('Copy the link and share it manually',
                      style: TextStyle(color: Colors.white54, fontSize: 13)),
                  onTap: () {
                    Navigator.pop(context);
                    _copyInvitationLink();
                  },
                ),
                const Divider(
                    color: Colors.white12,
                    height: 1,
                    indent: 16,
                    endIndent: 16),
                ListTile(
                  leading: CircleAvatar(
                      backgroundColor: primaryOrange,
                      child: const Icon(Icons.email_outlined,
                          color: Colors.white)),
                  title: const Text('Send Invitation by Email',
                      style: TextStyle(color: Colors.white, fontSize: 16)),
                  subtitle: const Text(
                      'Send the invitation directly to their inbox',
                      style: TextStyle(color: Colors.white54, fontSize: 13)),
                  onTap: () {
                    Navigator.pop(context);
                    _showSendEmailDialog();
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _onLeaveOrEndPressed() async {
    final meetingId = widget.meeting.meetingId;
    final meetingController = MeetingController();

    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (_isHost) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('End Meeting'),
          content: const Text(
              'Are you sure you want to end the meeting for everyone?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel',
                  style: TextStyle(color: primaryOrange)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red, foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('End Meeting'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;

      _endedDialogShown = true;
      _meetingSub?.cancel();

      await _runWithTimeout(meetingController.endMeeting(meetingId));
      if (uid != null) {
        await _runWithTimeout(
          FirebaseFirestore.instance.collection('User').doc(uid).set({
            'micPermissionGranted':    false,
            'cameraPermissionGranted': false,
            'isHandRaised':            false,
            'handRaisedAt':            null,
            'currentMeetingId':        null,
          }, SetOptions(merge: true)),
        );
      }
      await _runWithTimeout(mgr.endAndDispose());
      await _runWithTimeout(_captionController.completeTranscription());
      await _runWithTimeout(_captionController.resetForNewMeeting());

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomePage()),
            (route) => false,
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Leave Meeting'),
        content: const Text('Leave meeting?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel',
                style: TextStyle(color: primaryOrange)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: primaryOrange, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await _runWithTimeout(meetingController.leaveMeeting(meetingId));
    if (uid != null) {
      await _runWithTimeout(
        FirebaseFirestore.instance.collection('User').doc(uid).set({
          'micPermissionGranted':    false,
          'cameraPermissionGranted': false,
          'isHandRaised':            false,
          'handRaisedAt':            null,
          'currentMeetingId':        null,
        }, SetOptions(merge: true)),
      );
    }
    await _runWithTimeout(mgr.endAndDispose());
    await _runWithTimeout(_captionController.resetForNewMeeting());

    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomePage()),
          (route) => false,
    );
  }

  Future<void> _runWithTimeout(Future<void> future) async {
    try {
      await future.timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('⚠️ _runWithTimeout: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasRemote       = session.remoteViewWidget != null;
    final hasRemoteScreen = session.remoteScreenWidget != null;
    final isSharingMyScreen = session.isScreenSharing;

    return PopScope(
      canPop: true,
      onPopInvoked: (_) async {},
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.grey[900],
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(widget.meeting.title,
                  style: const TextStyle(color: Colors.white)),
              Text("ID: ${widget.meeting.meetingId}",
                  style:
                  const TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            if (isSharingMyScreen)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Chip(
                  label: const Text('Sharing',
                      style: TextStyle(color: Colors.white, fontSize: 11)),
                  backgroundColor: Colors.green.shade700,
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            IconButton(
              icon: const Icon(Icons.people, color: Colors.white),
              onPressed: _showParticipantsSheet,
            ),
            if (_isHost)
              IconButton(
                icon: const Icon(Icons.link, color: primaryOrange),
                onPressed: _copyInvitationLink,
              ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    color: Colors.black,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: hasRemoteScreen
                              ? _buildScreenShareView(
                              session.remoteScreenWidget!)
                              : hasRemote
                              ? session.remoteViewWidget!
                              : Center(
                            child: CircleAvatar(
                              radius: 42,
                              backgroundColor: primaryOrange,
                              child: Text(
                                (widget.user.name.isNotEmpty
                                    ? widget.user.name[0]
                                    : 'U')
                                    .toUpperCase(),
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 12,
                          right: 12,
                          width: 120,
                          height: 160,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              color: Colors.black,
                              child: session.localViewWidget == null
                                  ? const Center(
                                  child: CircularProgressIndicator(
                                      color: primaryOrange))
                                  : session.localViewWidget!,
                            ),
                          ),
                        ),
                        if (isSharingMyScreen)
                          Positioned(
                            top: 12,
                            left: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.green.shade700.withOpacity(0.9),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.screen_share,
                                      color: Colors.white, size: 14),
                                  SizedBox(width: 6),
                                  Text('You are sharing',
                                      style: TextStyle(
                                          color: Colors.white, fontSize: 12)),
                                ],
                              ),
                            ),
                          ),
                        if (hasRemoteScreen && !isSharingMyScreen)
                          Positioned(
                            top: 12,
                            left: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.blueGrey.withOpacity(0.85),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.screen_share,
                                      color: Colors.white, size: 14),
                                  SizedBox(width: 6),
                                  Text('Screen share',
                                      style: TextStyle(
                                          color: Colors.white, fontSize: 12)),
                                ],
                              ),
                            ),
                          ),

                        // ── Caption overlay ──────────────────────────────
                        if (_captionController.captionsEnabled ||
                            _signing.isEnabled)
                          Positioned(
                            bottom: 60,
                            left: 12,
                            right: 12,
                            child: AnimatedBuilder(
                              animation: _captionController,
                              builder: (context, _) {
                                final live    = _captionController.liveCaptions;
                                final pending = _captionController.pendingCaption;
                                final allEntries = [
                                  ...live,
                                  if (pending != null &&
                                      !live.any((e) =>
                                      e.userId == pending.userId &&
                                          e.text == pending.text))
                                    pending,
                                ];
                                allEntries.sort((a, b) =>
                                    a.timestamp.compareTo(b.timestamp));
                                if (allEntries.isEmpty) {
                                  return const SizedBox.shrink();
                                }
                                final entries = allEntries.length > 3
                                    ? allEntries.sublist(allEntries.length - 3)
                                    : allEntries;
                                return Column(
                                  crossAxisAlignment:
                                  CrossAxisAlignment.stretch,
                                  children: entries
                                      .map(
                                        (entry) => Container(
                                      margin: const EdgeInsets.only(
                                          bottom: 4),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: Colors.black
                                            .withOpacity(0.75),
                                        borderRadius:
                                        BorderRadius.circular(10),
                                      ),
                                      child: RichText(
                                        textDirection: TextDirection.rtl,
                                        text: TextSpan(
                                          children: [
                                            TextSpan(
                                              text:
                                              '${entry.userName}: ',
                                              style: const TextStyle(
                                                color: primaryOrange,
                                                fontWeight:
                                                FontWeight.bold,
                                                fontSize: 13,
                                              ),
                                            ),
                                            TextSpan(
                                              text: entry.text,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  )
                                      .toList(),
                                );
                              },
                            ),
                          ),

                        // ── Sign captioning overlays ─────────────────────
                        Positioned.fill(
                          child: SignCaptioningOverlay(signing: _signing),
                        ),

                        // ── Sign recognition overlays ────────────────────
                        Positioned.fill(
                          child: SignRecognitionOverlay(
                              controller: _recognition),
                        ),

                        Positioned(
                          bottom: 12,
                          left: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _isHost
                                  ? '${widget.user.name} (Host)'
                                  : widget.user.name,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 12),
                            ),
                          ),
                        ),

                        // ── Sign language avatar overlay ──────────────────
                        if (_signAvatarEnabled && _signLang.isInitialized)
                          SignOverlayWidget(
                            controller: _signLang.handController,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // ── Bottom control bar ────────────────────────────────────────
            Container(
              decoration: const BoxDecoration(
                color: darkBg,
                borderRadius: BorderRadius.only(
                  topLeft:  Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 10),
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  ShaderMask(
                    shaderCallback: (rect) => const LinearGradient(
                      colors: [
                        Colors.transparent,
                        Colors.white,
                        Colors.white,
                        Colors.transparent,
                      ],
                      stops: [0.0, 0.06, 0.94, 1.0],
                    ).createShader(rect),
                    blendMode: BlendMode.dstIn,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      child: Row(
                        children: [
                          _meetingIcon(
                            icon: Icons.call_end,
                            label: _isHost ? 'End' : 'Leave',
                            isActive: true,
                            activeColor: Colors.red,
                            onTap: _onLeaveOrEndPressed,
                          ),
                          const SizedBox(width: 16),
                          _meetingIcon(
                            icon: session.isMicOn
                                ? Icons.mic
                                : Icons.mic_off,
                            label: 'Mic',
                            isActive: session.isMicOn,
                            activeColor: primaryOrange,
                            onTap: _onMicPressed,
                          ),
                          const SizedBox(width: 16),
                          _meetingIcon(
                            icon: session.isCameraOn
                                ? Icons.videocam
                                : Icons.videocam_off,
                            label: 'Camera',
                            isActive: session.isCameraOn,
                            activeColor: primaryOrange,
                            onTap: _onCameraPressed,
                          ),
                          const SizedBox(width: 16),
                          _meetingIcon(
                            icon: Icons.cameraswitch,
                            label: 'Flip',
                            onTap: _onFlipPressed,
                          ),
                          const SizedBox(width: 16),
                          _meetingIcon(
                            icon: Icons.pan_tool_outlined,
                            label: 'Hand',
                            onTap: _onHandPressed,
                          ),
                          const SizedBox(width: 16),
                          _meetingIcon(
                            icon: Icons.closed_caption,
                            label: 'CC',
                            isActive: _captionController.captionsEnabled,
                            activeColor: primaryOrange,
                            onTap: _onCaptionsPressed,
                          ),
                          const SizedBox(width: 16),
                          _meetingIcon(
                            icon: Icons.sign_language,
                            label: 'Sign',
                            isActive: _signing.isEnabled,
                            activeColor: primaryOrange,
                            onTap: _onSignPressed,
                          ),
                          const SizedBox(width: 16),
                          _meetingIcon(
                            icon: Icons.interpreter_mode,
                            label: 'Avatar',
                            isActive: _signAvatarEnabled,
                            activeColor: primaryOrange,
                            onTap: _onSignAvatarPressed,
                          ),
                          const SizedBox(width: 16),
                          _meetingIcon(
                            icon: session.isScreenSharing
                                ? Icons.stop_screen_share
                                : Icons.screen_share,
                            label: session.isScreenSharing ? 'Stop' : 'Share',
                            isActive: session.isScreenSharing,
                            activeColor: Colors.green,
                            onTap: _onShareScreenPressed,
                            locked: !_isAllowedToShare,
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: MediaQuery.of(context).padding.bottom),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScreenShareView(Widget screenWidget) {
    return Stack(
      children: [
        Positioned.fill(child: screenWidget),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            color: Colors.black.withOpacity(0.4),
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.screen_share, color: Colors.white, size: 16),
                SizedBox(width: 8),
                Text('Screen Share',
                    style:
                    TextStyle(color: Colors.white, fontSize: 13)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _meetingIcon({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
    bool isActive = false,
    Color? activeColor,
    bool locked = false,
  }) {
    final bg =
    isActive ? (activeColor ?? primaryOrange) : Colors.grey.shade800;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: bg,
                child: Icon(icon, color: Colors.white, size: 22),
              ),
              if (locked)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                        color: Colors.red, shape: BoxShape.circle),
                    child: const Icon(Icons.lock,
                        color: Colors.white, size: 10),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(color: Colors.white, fontSize: 12)),
        ],
      ),
    );
  }

  void _showParticipantsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) {
        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('Meetings')
              .doc(widget.meeting.meetingId)
              .snapshots(),
          builder: (context, snap) {
            if (!snap.hasData || !snap.data!.exists) {
              return const SizedBox(
                  height: 220,
                  child: Center(
                      child: CircularProgressIndicator(
                          color: primaryOrange)));
            }

            final data = snap.data!.data() as Map<String, dynamic>;
            final ids =
            List<String>.from((data['participants'] as List?) ?? []);
            final screenShareAllowed =
                data['screenShareAllowed'] as bool? ?? false;

            return SizedBox(
              height: 460,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(99)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Participants (${ids.length})',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700),
                        ),
                        if (_isHost)
                          GestureDetector(
                            onTap: () {
                              Navigator.pop(context);
                              _showInviteOptions();
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                  color: primaryOrange,
                                  borderRadius: BorderRadius.circular(20)),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(Icons.person_add,
                                      color: Colors.white, size: 18),
                                  SizedBox(width: 6),
                                  Text('Invite',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: screenShareAllowed
                            ? Colors.green.shade900
                            : Colors.grey.shade800,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            screenShareAllowed
                                ? Icons.screen_share
                                : Icons.stop_screen_share,
                            color: screenShareAllowed
                                ? Colors.greenAccent
                                : Colors.white54,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            screenShareAllowed
                                ? 'Screen sharing is ON for all participants'
                                : 'Screen sharing is OFF for participants',
                            style: TextStyle(
                              color: screenShareAllowed
                                  ? Colors.greenAccent
                                  : Colors.white54,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('Meetings')
                        .doc(widget.meeting.meetingId)
                        .collection('permissionRequests')
                        .where('status', isEqualTo: 'pending')
                        .orderBy('createdAt', descending: false)
                        .snapshots(),
                    builder: (context, handsSnap) {
                      if (!handsSnap.hasData) return const SizedBox();

                      final docs = handsSnap.data!.docs;
                      if (docs.isEmpty) return const SizedBox();

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding:
                            EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              'Raised Hands',
                              style: TextStyle(
                                color: primaryOrange,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          ...docs.map((d) {
                            final requestData = d.data();
                            final uid = requestData['uid'] ?? d.id;
                            final name = requestData['name'] ?? uid;

                            return ListTile(
                              dense: true,
                              leading: const Icon(Icons.pan_tool_outlined,
                                  color: primaryOrange),
                              title: Text(
                                name,
                                style:
                                const TextStyle(color: Colors.white),
                              ),
                              trailing: _isHost
                                  ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  TextButton(
                                    onPressed: () async {
                                      await MeetingController()
                                          .approveMicCam(
                                        meetingId:
                                        widget.meeting.meetingId,
                                        targetUid: uid,
                                      );
                                    },
                                    style: TextButton.styleFrom(
                                        foregroundColor: primaryOrange),
                                    child: const Text('Approve'),
                                  ),
                                  TextButton(
                                    onPressed: () async {
                                      await MeetingController()
                                          .rejectHand(
                                        meetingId:
                                        widget.meeting.meetingId,
                                        targetUid: uid,
                                      );
                                    },
                                    style: TextButton.styleFrom(
                                        foregroundColor: Colors.redAccent),
                                    child: const Text('Reject'),
                                  ),
                                ],
                              )
                                  : null,
                            );
                          }).toList(),
                          const Divider(color: Colors.white12),
                        ],
                      );
                    },
                  ),

                  Expanded(
                    child: ListView.separated(
                      itemCount: ids.length,
                      separatorBuilder: (_, __) =>
                      const Divider(color: Colors.white12, height: 1),
                      itemBuilder: (context, i) {
                        final uid = ids[i];
                        final isMe = uid == widget.user.userId ||
                            uid ==
                                FirebaseAuth.instance.currentUser?.uid;
                        final isHostUid = uid == widget.meeting.hostId;

                        return FutureBuilder<DocumentSnapshot>(
                          future: FirebaseFirestore.instance
                              .collection('User')
                              .doc(uid)
                              .get(),
                          builder: (context, userSnap) {
                            String displayName = uid;
                            if (userSnap.hasData &&
                                userSnap.data!.exists) {
                              final userData = userSnap.data!.data()
                              as Map<String, dynamic>?;
                              displayName = userData?['name'] ?? uid;
                            }

                            return ListTile(
                              leading: CircleAvatar(
                                // host gets a slightly darker orange,
                                // participants get primaryOrange
                                backgroundColor: isHostUid
                                    ? orangeDark
                                    : primaryOrange,
                                child: Text(
                                  displayName.isNotEmpty
                                      ? displayName[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                      color: Colors.white),
                                ),
                              ),
                              title: Text(
                                isMe
                                    ? '$displayName (You)'
                                    : displayName,
                                style:
                                const TextStyle(color: Colors.white),
                              ),
                              subtitle: Text(
                                isHostUid ? 'Host' : 'Participant',
                                style: const TextStyle(
                                    color: Colors.white70),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
