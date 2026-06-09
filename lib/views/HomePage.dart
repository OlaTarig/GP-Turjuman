import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../views/widgets/AppBar.dart';
import '../controllers/MeetingController.dart';
import '../views/MeetingView.dart';
import '../models/UserModel.dart';
import '../views/SettingsView.dart';
import '../models/MeetingModel.dart';
import '../controllers/MeetingSessionManager.dart';
import 'package:turjuman/main.dart';
import 'JoinMeetingView.dart';
import 'FileTranscriptionView.dart';
import '../l10n/l10n.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _userName = '';
  bool _isLoading = true;
  int _currentIndex = 0;

  UserModel? _userModel;

  @override
  void initState() {
    super.initState();
    // Deep link consumption is handled at the END of _loadUserData(),
    // after the user is confirmed loaded. Do NOT call consumePendingLink() here.
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        setState(() {
          _userName = user.displayName ?? 'User';
          _isLoading = false;
        });

        try {
          final userDoc = await FirebaseFirestore.instance
              .collection('User')
              .doc(user.uid)
              .get();

          final data = userDoc.data();
          if (data != null) {
            _userModel = UserModel.fromMap(data);
          }

          if (userDoc.exists && mounted) {
            final firestoreName = userDoc.data()?['name'];
            if (firestoreName != null && firestoreName.isNotEmpty) {
              setState(() {
                _userName = firestoreName;
              });
            }
          }
        } catch (e) {
          debugPrint("Error fetching Firestore data: $e");
        }
      } else {
        setState(() {
          _userName = 'User';
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading user data: $e");
      setState(() {
        _userName = 'User';
        _isLoading = false;
      });
    }

    // ✅ Deep link check — runs AFTER user data is loaded, so _userModel is ready.
    // addPostFrameCallback ensures the widget tree is fully built before navigating.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final meetingId = deepLinkService.consumePendingLink();
      if (meetingId != null && meetingId.isNotEmpty) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => JoinMeetingScreen(meetingId: meetingId),
          ),
        );
      }
    });
  }

  Future<void> _showJoinDialog() async {
    final controller = TextEditingController();
    final l10n = context.l10n;

    final meetingId = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l10n.joinMeeting),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: l10n.enterMeetingId,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text(l10n.joinMeeting),
          ),
        ],
      ),
    );

    if (meetingId == null || meetingId.isEmpty) return;

    await _joinMeetingById(meetingId);
  }

  Future<void> _joinMeetingById(String meetingId) async {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) return;

    final meetingSnap = await FirebaseFirestore.instance
        .collection('Meetings')
        .doc(meetingId)
        .get();

    if (!meetingSnap.exists) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.meetingNotFound)),
      );
      return;
    }

    final data = meetingSnap.data()!;
    final isActive = data['isActive'] as bool? ?? true;

    if (!isActive) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.meetingAlreadyEnded)),
      );
      return;
    }
    final int numOfParticipants = (data['numOfParticipants'] as int?) ?? 0;
    final int maxCapacity = (data['maxCapacity'] as int?) ?? 100;

    if (numOfParticipants >= maxCapacity) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.meetingFull)),
      );
      return;
    }

    final meeting = MeetingModel.fromMap({
      ...data,
      'meetingId': meetingSnap.id,
    });

    await FirebaseFirestore.instance
        .collection('Meetings')
        .doc(meetingId)
        .update({
      'participants': FieldValue.arrayUnion([firebaseUser.uid]),
      'numOfParticipants': FieldValue.increment(1),
    });

    final userDoc = await FirebaseFirestore.instance
        .collection('User')
        .doc(firebaseUser.uid)
        .get();

    UserModel userModel;

    if (userDoc.exists && userDoc.data() != null) {
      userModel = UserModel.fromMap(userDoc.data()!);
    } else {
      userModel = UserModel(
        userId: firebaseUser.uid,
        name: firebaseUser.displayName ?? 'User',
        email: firebaseUser.email ?? '',
        role: 'participant',
      );
    }

    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MeetingView(
          meeting: meeting,
          user: userModel,
        ),
      ),
    );
  }

  bool _startingMeeting = false;

  Future<void> _startMeeting() async {
    if (_startingMeeting) return;
    setState(() => _startingMeeting = true);

    try {
      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser == null) {
        _showError(context.l10n.pleaseSignIn);
        return;
      }

      final meeting = await MeetingController().createMeeting("New Meeting");

      if (!mounted) return;
      if (meeting == null) {
        _showError(context.l10n.couldNotCreateMeeting);
        return;
      }

      UserModel userModel;
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('User')
            .doc(firebaseUser.uid)
            .get();
        if (userDoc.exists && userDoc.data() != null) {
          userModel = UserModel.fromMap(userDoc.data()!);
        } else {
          userModel = UserModel(
            userId: firebaseUser.uid,
            name: firebaseUser.displayName ?? 'User',
            email: firebaseUser.email ?? '',
          );
        }
      } catch (_) {
        userModel = UserModel(
          userId: firebaseUser.uid,
          name: firebaseUser.displayName ?? 'User',
          email: firebaseUser.email ?? '',
        );
      }

      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MeetingView(meeting: meeting, user: userModel),
        ),
      );
    } finally {
      if (mounted) setState(() => _startingMeeting = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _onBottomNavTap(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  Widget _homeTab() {
    final l10n = context.l10n;
    return SafeArea(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.welcomeBack,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _userName,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2D3142),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 40),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFB382), Color(0xFFFFD0A0)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFFB382).withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.videocam_rounded,
                        size: 50,
                        color: Colors.white,
                      ),
                    ),

                    const SizedBox(height: 24),

                    Text(
                      l10n.startMeeting,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),

                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: OutlinedButton(
                        onPressed: _showJoinDialog,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.white),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          l10n.joinMeeting,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      l10n.connectInstantly,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),

                    const SizedBox(height: 28),

                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _startingMeeting ? null : _startMeeting,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFFFFB382),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: _startingMeeting
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Color(0xFFFFB382)),
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.play_arrow_rounded, size: 28),
                                  const SizedBox(width: 8),
                                  Text(
                                    l10n.startNow,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: const Color(0xFFFFFBF5),
      body: _isLoading
          ? const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFB382)),
        ),
      )
          : Stack(
        children: [
          IndexedStack(
            index: _currentIndex,
            children: [
              _homeTab(),
              const FileTranscriptionView(),
              _userModel == null
                  ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                      Color(0xFFFFB382)),
                ),
              )
                  : SettingsView(
                user: _userModel!,
                onUserUpdated: (updatedUser) {
                  setState(() {
                    _userModel = updatedUser;
                    _userName = updatedUser.name;
                  });
                },
              ),
            ],
          ),

          // ✅ Active Meeting Banner
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: AnimatedBuilder(
              animation: MeetingSessionManager.instance,
              builder: (context, _) {
                final mgr = MeetingSessionManager.instance;
                if (!mgr.hasActiveMeeting) return const SizedBox.shrink();

                final meetingTitle =
                    mgr.activeMeeting?.title ?? 'Meeting';
                return SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                    child: Material(
                      elevation: 6,
                      borderRadius: BorderRadius.circular(14),
                      color: const Color(0xFF2D2F31),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () async {
                          final meeting = mgr.activeMeeting!;
                          final user = mgr.activeUser!;
                          if (!mounted) return;
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => MeetingView(
                                  meeting: meeting, user: user),
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          child: Row(
                            children: [
                              const Icon(Icons.circle,
                                  color: Colors.green, size: 12),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  l10n.inMeeting(meetingTitle),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                l10n.returnToMeeting,
                                style: const TextStyle(
                                  color: Color(0xFFFFB382),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(Icons.arrow_forward_ios,
                                  size: 14, color: Color(0xFFFFB382)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),

      bottomNavigationBar: BottomBar(
        currentIndex: _currentIndex,
        onTap: _onBottomNavTap,
      ),
    );
  }
}
