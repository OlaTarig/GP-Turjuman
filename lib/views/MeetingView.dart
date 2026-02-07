import 'package:flutter/material.dart';
import '../models/MeetingModel.dart';

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
              child: const Center(
                child: Text(
                  "Video Area",
                  style: TextStyle(color: Colors.white),
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
                  onPressed: () {
                    setState(() {
                      isCameraOn = !isCameraOn;
                    });
                  },
                ),

                IconButton(
                  icon: Icon(
                    isHandRaised
                        ? Icons.pan_tool
                        : Icons.pan_tool_outlined,
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
