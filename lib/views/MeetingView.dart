import 'package:flutter/material.dart';
import '../models/MeetingModel.dart';
import 'package:camera/camera.dart';

class MeetingView extends StatefulWidget {
  final MeetingModel meeting;

  const MeetingView({super.key, required this.meeting});

  @override
  State<MeetingView> createState() => _MeetingScreenState();
}

class _MeetingScreenState extends State<MeetingView> {
  bool isMicOn = false;
  bool isCameraOn = false;
  bool isHandRaised = false;

  CameraController? _cameraController;
  List<CameraDescription>? cameras;
  bool isCameraInitialized = false;

  // ✅ تنظيف الموارد عند الخروج من الصفحة
  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  // ✅ تهيئة الكاميرا (اختيار الأمامية إن وجدت)
  Future<void> _initializeCamera() async {
    cameras ??= await availableCameras();

    final frontCamera = cameras!.firstWhere(
          (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => cameras!.first,
    );

    _cameraController = CameraController(
      frontCamera,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    await _cameraController!.initialize();

    if (!mounted) return;
    setState(() {
      isCameraInitialized = true;
    });
  }

  // ✅ تشغيل / إيقاف الكاميرا عند الضغط على زر الفيديو
  Future<void> _toggleCamera() async {
    if (!isCameraOn) {
      // تشغيل الكاميرا
      await _initializeCamera();
      if (!mounted) return;
      setState(() {
        isCameraOn = true;
      });
    } else {
      // إيقاف الكاميرا
      await _cameraController?.dispose();
      _cameraController = null;

      if (!mounted) return;
      setState(() {
        isCameraOn = false;
        isCameraInitialized = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
              child: (isCameraOn && isCameraInitialized && _cameraController != null)
                  ? CameraPreview(_cameraController!)
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
                    isMicOn ? Icons.mic : Icons.mic_off,
                    color: Colors.white,
                  ),
                  onPressed: () {
                    setState(() {
                      isMicOn = !isMicOn;
                    });
                  },
                ),

                IconButton(
                  icon: Icon(
                    isCameraOn ? Icons.videocam : Icons.videocam_off,
                    color: Colors.white,
                  ),
                  // ✅ بدل ما نقلب المتغير فقط، نستخدم التوغل الحقيقي للكamera
                  onPressed: _toggleCamera,
                ),

                IconButton(
                  icon: Icon(
                    isHandRaised ? Icons.pan_tool : Icons.pan_tool_outlined,
                    color: Colors.orange,
                  ),
                  onPressed: () {
                    setState(() {
                      isHandRaised = !isHandRaised;
                    });
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
