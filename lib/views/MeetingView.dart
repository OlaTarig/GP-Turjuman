import 'package:flutter/material.dart';
import '../models/MeetingModel.dart';
import '../models/UserModel.dart';
import '../controllers/MeetingSessionController.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import '../controllers/MeetingSessionController.dart';


class MeetingView extends StatefulWidget {
  final MeetingModel meeting;
  final UserModel user;

  const MeetingView({super.key, required this.meeting, required this.user});

  @override
  State<MeetingView> createState() => _MeetingScreenState();
}

class _MeetingScreenState extends State<MeetingView> {
  late final MeetingSessionController session;

  @override
  void initState() {
    super.initState();

    session = MeetingSessionController();
    session.addListener(_onSessionChanged);

    // Popup بعد ما الصفحة تترسم
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
                // مؤقتًا نفتح إعدادات الجهاز لين تبنين صفحة Settings داخل التطبيق
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
    session.removeListener(_onSessionChanged);
    session.disposeSession();
    super.dispose();
  }

  Future<void> _onCameraPressed() async {
    // بوابة إعدادات المستخدم
    if (!widget.user.cameraAccessSettings) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Camera is disabled in settings'),
          action: SnackBarAction(
            label: 'Settings',
            onPressed: openAppSettings,
          ),
        ),
      );
      return;
    }

    await session.toggleCamera();
  }

  Future<void> _onMicPressed() async {
    // بوابة إعدادات المستخدم
    if (!widget.user.micAccessSettings) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Microphone is disabled in settings'),
          action: SnackBarAction(
            label: 'Settings',
            onPressed: openAppSettings,
          ),
        ),
      );
      return;
    }

    // نخلي الكنترولر يطلب إذن المايك
    final before = session.isMicOn;
    await session.toggleMic();

    // إذا ما تغيّرت الحالة، غالبًا permission مرفوض (خصوصًا permanentlyDenied)
    if (!before && !session.isMicOn) {
      final st = await Permission.microphone.status;
      if (st.isPermanentlyDenied && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Microphone permission is permanently denied. Enable it from settings.'),
            action: SnackBarAction(
              label: 'Settings',
              onPressed: openAppSettings,
            ),
          ),
        );
      }
    }
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
          IconButton(
            icon: const Icon(Icons.people),
            onPressed: () {
              // later: open participants panel
            },
          )
        ],
      ),
      body: Column(
        children: [
          // 🎥 Video Area
          Expanded(
            child: Container(
              width: double.infinity,
              color: Colors.black,
              child: camReady
                  ? CameraPreview(session.cameraController!)
                  : const Center(
                child: Icon(
                  Icons.videocam_off,
                  color: Colors.white54,
                  size: 80,
                ),
              ),
            ),
          ),

          // 🎛 Bottom Controls
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            color: Colors.grey[900],
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: Icon(
                    session.isMicOn ? Icons.mic : Icons.mic_off,
                    color: Colors.white,
                  ),
                  onPressed: _onMicPressed,
                ),

                IconButton(
                  icon: Icon(
                    session.isCameraOn ? Icons.videocam : Icons.videocam_off,
                    color: Colors.white,
                  ),
                  onPressed: _onCameraPressed,
                ),

                IconButton(
                  icon: Icon(
                    session.isHandRaised ? Icons.pan_tool : Icons.pan_tool_outlined,
                    color: Colors.orange,
                  ),
                  onPressed: session.toggleHand,
                ),
                IconButton(
                  icon: const Icon(Icons.cameraswitch, color: Colors.white),
                  onPressed: () async {
                    if (!session.isCameraOn) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Turn on camera first')),
                      );
                      return;
                    }
                    await session.flipCamera();
                  },
                ),


                IconButton(
                  icon: const Icon(Icons.call_end, color: Colors.red),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

