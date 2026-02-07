import 'package:flutter/material.dart';
import '../models/MeetingModel.dart';
import '../models/UserModel.dart';
import '../controllers/MeetingSessionController.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';

class MeetingView extends StatefulWidget {
  final MeetingModel meeting;
  final UserModel user;

  const MeetingView({super.key, required this.meeting, required this.user});

  @override
  State<MeetingView> createState() => _MeetingScreenState();
}

class _MeetingScreenState extends State<MeetingView> {
  // نفس ألوان الهوم بيج
  static const Color primaryOrange = Color(0xFFFFB382);
  static const Color darkBg = Color(0xFF2D2F31);

  late final MeetingSessionController session;

  @override
  void initState() {
    super.initState();
    session = MeetingSessionController();
    session.addListener(_onSessionChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAccessSettingsOnEntry();
    });
  }

  void _onSessionChanged() {
    if (!mounted) return;
    setState(() {});
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
              child: const Text('Later'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                openAppSettings(); // مؤقتًا لين تسوين Settings داخل التطبيق
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
    session.removeListener(_onSessionChanged);
    session.disposeSession();
    super.dispose();
  }

  bool get _isHost => widget.user.role.toLowerCase() == 'host';

  Future<void> _onMicPressed() async {
    if (!widget.user.micAccessSettings) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Microphone is disabled in settings'),
          action: SnackBarAction(label: 'Settings', onPressed: openAppSettings),
        ),
      );
      return;
    }

    final before = session.isMicOn;
    await session.toggleMic();

    if (!before && !session.isMicOn) {
      final st = await Permission.microphone.status;
      if (st.isPermanentlyDenied && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Microphone permission is permanently denied. Enable it from settings.'),
            action: SnackBarAction(label: 'Settings', onPressed: openAppSettings),
          ),
        );
      }
    }
  }

  Future<void> _onCameraPressed() async {
    if (!widget.user.cameraAccessSettings) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Camera is disabled in settings'),
          action: SnackBarAction(label: 'Settings', onPressed: openAppSettings),
        ),
      );
      return;
    }
    await session.toggleCamera();
  }

  Future<void> _onFlipPressed() async {
    if (!session.isCameraOn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Turn on camera first')),
      );
      return;
    }
    await session.flipCamera();
  }

  void _onShareScreenPressed() {
    // UI فقط حالياً — ربط المشاركة فعلياً يحتاج SDK
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Share screen: Coming soon')),
    );
  }

  Future<void> _onLeaveOrEndPressed() async {
    final actionText = _isHost ? 'End meeting for everyone?' : 'Leave meeting?';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(_isHost ? 'End Meeting' : 'Leave Meeting'),
        content: Text(actionText),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _isHost ? Colors.red : primaryOrange,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(_isHost ? 'End' : 'Leave'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // هنا لاحقًا: إذا Host ننادي MeetingController.endMeeting()
    // وإذا Participant ننادي MeetingController.leaveMeeting()
    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final camReady = session.isCameraOn &&
        session.isCameraInitialized &&
        session.cameraController != null;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.grey[900],
        title: Text(widget.meeting.title),
        actions: [
          TextButton(
            onPressed: _onLeaveOrEndPressed,
            child: Text(
              _isHost ? 'End Meeting' : 'Leave Meeting',
              style: TextStyle(
                color: _isHost ? Colors.redAccent : Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.people),
            onPressed: () {
              // later: participants panel
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 🎥 Video Area
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
                        child: camReady
                            ? CameraPreview(session.cameraController!)
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
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 12,
                        left: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _isHost ? '${widget.user.name} (Host)' : widget.user.name,
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 🎛 Bottom Controls (فقط اللي طلبتيه)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
            decoration: const BoxDecoration(
              color: darkBg,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _meetingIcon(
                  icon: session.isMicOn ? Icons.mic : Icons.mic_off,
                  label: 'Mic',
                  isActive: session.isMicOn,
                  onTap: _onMicPressed,
                ),
                _meetingIcon(
                  icon: session.isCameraOn ? Icons.videocam : Icons.videocam_off,
                  label: 'Camera',
                  isActive: session.isCameraOn,
                  onTap: _onCameraPressed,
                ),
                _meetingIcon(
                  icon: Icons.cameraswitch,
                  label: 'Flip',
                  onTap: _onFlipPressed,
                ),
                _meetingIcon(
                  icon: session.isHandRaised ? Icons.pan_tool : Icons.pan_tool_outlined,
                  label: 'Hand',
                  isActive: session.isHandRaised,
                  activeColor: Colors.orange,
                  onTap: session.toggleHand,
                ),
                _meetingIcon(
                  icon: Icons.screen_share,
                  label: 'Share',
                  onTap: _onShareScreenPressed,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _meetingIcon({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
    bool isActive = false,
    Color? activeColor,
  }) {
    final bg = isActive ? (activeColor ?? primaryOrange) : Colors.grey.shade800;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: bg,
            child: Icon(icon, color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
