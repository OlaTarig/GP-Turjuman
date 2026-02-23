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
  }
  Future<void> _showJoinDialog() async {
    final controller = TextEditingController();

    final meetingId = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Join Meeting'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Enter Meeting ID',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(context, controller.text.trim()),
            child: const Text('Join'),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Meeting not found')),
      );
      return;
    }

    final data = meetingSnap.data()!;
    final isActive = data['isActive'] as bool? ?? true;

    if (!isActive) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Meeting already ended')),
      );
      return;
    }

    final meeting = MeetingModel.fromMap({
      ...data,
      'meetingId': meetingSnap.id,
    });

    // تحديث عدد المشاركين
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


  Future<void> _startMeeting() async {
    final controller = MeetingController();
    final meeting = await controller.createMeeting("New Meeting");

    if (meeting == null || !mounted) return;

    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) return;

    try {
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
        );
      }

      if (!mounted) return;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MeetingView(meeting: meeting, user: userModel),
        ),
      );

      // ✅ بعد الرجوع من الميتنق حدّث البانر

    } catch (e) {
      debugPrint("Error loading user model: $e");

      final userModel = UserModel(
        userId: firebaseUser.uid,
        name: firebaseUser.displayName ?? 'User',
        email: firebaseUser.email ?? '',
      );

      if (!mounted) return;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MeetingView(meeting: meeting, user: userModel),
        ),
      );

      // ✅ بعد الرجوع من الميتنق حدّث البانر

    }
  }



  // ✅ تعديل بسيط: بدون Navigator.push
  void _onBottomNavTap(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  // ✅ نفس محتوى الهوم حقك (بدون تغيير)
  Widget _homeTab() {
    // ✅ عشان البانر الثابت ما يغطي الهيدر

    return SafeArea(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 20 ),

              // Header with greeting and profile
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Welcome back,',
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

                  // ✅ تم حذف زر اللوق اوت من هنا فقط
                ],
              ),

              const SizedBox(height: 40),

              // Main meeting card
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
                    // Icon
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

                    const Text(
                      'Start a Meeting',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),



                    const SizedBox(height: 8),

                    Text(
                      'Connect with your team instantly',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),

                    const SizedBox(height: 28),

                    // Start button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _startMeeting,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFFFFB382),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.play_arrow_rounded, size: 28),
                            SizedBox(width: 8),
                            Text(
                              'Start Now',
                              style: TextStyle(
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
              const SizedBox(height: 100), // Bottom padding for nav bar
            ],
          ),
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFBF5),
      body: _isLoading
          ? const Center(
        child: CircularProgressIndicator(
          valueColor:
          AlwaysStoppedAnimation<Color>(Color(0xFFFFB382)),
        ),
      )
          :Stack(
        children: [
          IndexedStack(
            index: _currentIndex,
            children: [
              _homeTab(),
              const Center(child: Text('Files page - Coming soon')),
              _userModel == null
                  ? const Center(child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFB382)),
              ))
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

          // ✅ Active Meeting Banner (فوق كل شي)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: AnimatedBuilder(
              animation: MeetingSessionManager.instance,
              builder: (context, _) {
                final mgr = MeetingSessionManager.instance;
                if (!mgr.hasActiveMeeting) return const SizedBox.shrink();

                final meetingTitle = mgr.activeMeeting?.title ?? 'Meeting';
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
                              builder: (_) => MeetingView(meeting: meeting, user: user),
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          child: Row(
                            children: [
                              const Icon(Icons.circle, color: Colors.green, size: 12),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'In meeting: $meetingTitle',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Text(
                                'Return',
                                style: TextStyle(
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

  // تركت الدوال الإضافية زي ما هي عندك (ما لمستها)
  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFB382).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: const Color(0xFFFFB382),
                size: 28,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2D3142),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentMeetingCard({
    required String title,
    required String time,
    required int participants,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFFFB382).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.videocam_rounded,
              color: Color(0xFFFFB382),
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2D2F31),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.access_time_rounded,
                        size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text(
                      time,
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade600),
                    ),
                    const SizedBox(width: 12),
                    Icon(Icons.people_rounded,
                        size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text(
                      '$participants participants',
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
        ],
      ),
    );
  }
}
