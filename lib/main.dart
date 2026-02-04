import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'controllers/MeetingController.dart';
import 'models/UserModel.dart';
import 'views/MeetingView.dart'; // this contains MeetingRoomView

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => MeetingController(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'GP Turjuman Meeting Room',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        ),
        home: const SetupScreen(),
      ),
    );
  }
}

// Temporary setup screen to initialize host & meeting
class SetupScreen extends StatelessWidget {
  const SetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<MeetingController>(context, listen: false);

    // TEMP: create host user
    UserModel host = UserModel(
      userId: "host_1",
      name: "Host",
      email: "host@email.com",
      role: "host",
    );

    // create meeting session
    controller.createMeeting(
      meetingId: "MEET123",
      host: host,
    );

    // navigate directly to meeting room view
    return MeetingRoomView(currentUser: host);
  }
}
