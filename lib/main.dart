import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import '../views/GUI.dart';
import 'services/deep_link_service.dart';
import 'views/JoinMeetingView.dart';
// ✅ نافيقيتور كي عشان نقدر نوجه من الـ deep link حتى لو ما عندك context
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

late final DeepLinkService deepLinkService;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // ✅ شغلي خدمة استقبال الروابط
  deepLinkService = DeepLinkService(navigatorKey);

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    // ✅ ابدأ الاستماع للروابط
    deepLinkService.start();
  }

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

      // ✅ نفس الشي ما تغير: الهوم WelcomeScreen
      home: const WelcomeScreen(),

      // ✅ عشان ما يخرب إذا راح /joinMeeting وما عندك routes جاهزة
      onGenerateRoute: (settings) {
        if (settings.name == '/joinMeeting') {
          final meetingId = settings.arguments as String?;

          // إذا ما وصل meetingId لأي سبب، نرجع للهوم
          if (meetingId == null || meetingId.isEmpty) {
            return MaterialPageRoute(builder: (_) => const WelcomeScreen());
          }

          // 🔁 هنا حطي شاشة join الحقيقية عندك
          // إذا ما عندك JoinMeetingView جاهزة، خلّيها مؤقتًا WelcomeScreen
          // وانا أركب لك JoinMeetingView بعدين.
          return MaterialPageRoute(
            builder: (_) => JoinMeetingScreen(meetingId: meetingId),
          );
        }

        // الافتراضي
        return MaterialPageRoute(builder: (_) => const WelcomeScreen());
      },
    );
  }
}
