import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import '../views/GUI.dart';
import 'services/deep_link_service.dart';
import 'views/JoinMeetingView.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
late final DeepLinkService deepLinkService;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  deepLinkService = DeepLinkService(navigatorKey);

  // ✅ ONLY change: start() moved here BEFORE runApp
  // so cold start link is captured before the app builds
  await deepLinkService.start();

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void dispose() {
    deepLinkService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      home: const WelcomeScreen(),
      onGenerateRoute: (settings) {
        if (settings.name == '/joinMeeting') {
          final meetingId = settings.arguments as String?;

          if (meetingId == null || meetingId.isEmpty) {
            return MaterialPageRoute(builder: (_) => const WelcomeScreen());
          }

          return MaterialPageRoute(
            builder: (_) => JoinMeetingScreen(meetingId: meetingId),
          );
        }

        return MaterialPageRoute(builder: (_) => const WelcomeScreen());
      },
    );
  }
}