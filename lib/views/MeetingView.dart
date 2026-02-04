import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/MeetingController.dart';
import '../models/UserModel.dart';

class MeetingRoomView extends StatelessWidget {
  final UserModel currentUser;

  const MeetingRoomView({super.key, required this.currentUser});

  @override
  Widget build(BuildContext context) {
    return Consumer<MeetingController>(
      builder: (context, controller, child) {
        final meeting = controller.meeting;

        return Scaffold(
          appBar: AppBar(
            title: Text("Meeting ID: ${meeting.meetingId}"),
          ),
          body: Column(
            children: [
              // -----------------------
              // Participants List
              // -----------------------
              Expanded(
                child: ListView.builder(
                  itemCount: meeting.participants.length,
                  itemBuilder: (context, index) {
                    var user = meeting.participants[index];
                    return ListTile(
                      title: Text(user.name),
                      subtitle: Text(
                          "Mic: ${user.isMicrophoneOn ? "On" : "Muted"} | Camera: ${user.isCameraOn ? "On" : "Off"}"),
                      trailing: user.isHandRaised
                          ? const Icon(Icons.pan_tool, color: Colors.orange)
                          : null,
                    );
                  },
                ),
              ),

              const Divider(),

              // -----------------------
              // Control Bar
              // -----------------------
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Mic button
                  IconButton(
                    icon: Icon(
                      currentUser.isMicrophoneOn ? Icons.mic : Icons.mic_off,
                    ),
                    onPressed: () {
                      controller.toggleMicrophone(currentUser.userId);
                    },
                  ),

                  // Camera button
                  IconButton(
                    icon: Icon(
                      currentUser.isCameraOn
                          ? Icons.videocam
                          : Icons.videocam_off,
                    ),
                    onPressed: () {
                      controller.toggleCamera(currentUser.userId);
                    },
                  ),

                  // Raise hand button
                  IconButton(
                    icon: Icon(
                      Icons.pan_tool,
                      color: currentUser.isHandRaised
                          ? Colors.orange
                          : Colors.grey,
                    ),
                    onPressed: () {
                      if (currentUser.isHandRaised) {
                        controller.lowerHand(currentUser.userId);
                      } else {
                        controller.raiseHand(currentUser.userId);
                      }
                    },
                  ),
                ],
              ),

              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }
}
