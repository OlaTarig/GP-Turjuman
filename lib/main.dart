import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'views/GUI.dart';
import 'services/deep_link_service.dart';
import 'views/JoinMeetingView.dart';
import 'views/HomePage.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
late final DeepLinkService deepLinkService;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  deepLinkService = DeepLinkService(navigatorKey);
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
      home: const _AppEntry(),
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

class _AppEntry extends StatefulWidget {
  const _AppEntry();

  @override
  State<_AppEntry> createState() => _AppEntryState();
}

class _AppEntryState extends State<_AppEntry> {
  String? _pendingMeetingId;
  bool _deepLinkHandled = false;
  // Stay on splash until BOTH auth AND deep-link check are done
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    // 1. Grab whatever the service already captured (fast path)
    _pendingMeetingId = deepLinkService.consumePendingLink();
    debugPrint('🔗 consumePendingLink() = $_pendingMeetingId');

    // 2. If nothing yet, do one more getInitialLink() attempt.
    //    On some Android devices the link arrives slightly after startup.
    if (_pendingMeetingId == null) {
      _pendingMeetingId = await deepLinkService.retryInitialLink();
      debugPrint('🔗 retryInitialLink() = $_pendingMeetingId');
    }

    if (mounted) setState(() => _ready = true);
  }

  @override
  Widget build(BuildContext context) {
    // Hold on splash until we know whether there's a link
    if (!_ready) return _splash();

    debugPrint('🔗 _pendingMeetingId = $_pendingMeetingId');

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        debugPrint(
            '🔥 Auth state: ${snapshot.connectionState}, user: ${snapshot.data?.uid}');

        if (snapshot.connectionState == ConnectionState.waiting) {
          debugPrint('⏳ Waiting for auth...');
          return _splash();
        }

        final user = snapshot.data;
        final hasPendingLink =
            _pendingMeetingId != null && _pendingMeetingId!.isNotEmpty;

        debugPrint(
            '👤 user=${user?.uid} | hasPendingLink=$hasPendingLink | handled=$_deepLinkHandled');

        // Deep link + logged in → push imperatively ONCE
        if (hasPendingLink && user != null && !_deepLinkHandled) {
          _deepLinkHandled = true;
          debugPrint('✅ Navigating to JoinMeetingScreen: $_pendingMeetingId');
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) =>
                    JoinMeetingScreen(meetingId: _pendingMeetingId!),
              ),
            );
          });
          // Render HomePage as the base (no WelcomeScreen flash)
          return const HomePage();
        }

        // Deep link + NOT logged in → WelcomeScreen to log in first
        if (hasPendingLink && user == null) {
          debugPrint('⚠️ Has pending link but not logged in');
          return const WelcomeScreen();
        }

        // Normal flow
        debugPrint('🏠 Normal flow: user=${user?.uid}');
        return user != null ? const HomePage() : const WelcomeScreen();
      },
    );
  }

  Widget _splash() {
    return const Scaffold(
      backgroundColor: Color(0xFFFFF9E3),
      body: Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFB382)),
        ),
      ),
    );
  }
}