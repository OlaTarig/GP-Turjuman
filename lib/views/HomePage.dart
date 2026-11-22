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
import '../theme/turjuman_theme.dart';
import 'widgets/glass.dart';
import 'widgets/sign_letters.dart';

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

  final TextEditingController _joinController = TextEditingController();
  bool _joining = false;

  @override
  void dispose() {
    _joinController.dispose();
    super.dispose();
  }

  Future<void> _joinFromField() async {
    final meetingId = _joinController.text.trim();
    if (meetingId.isEmpty || _joining) return;
    FocusScope.of(context).unfocus();
    setState(() => _joining = true);
    try {
      await _joinMeetingById(meetingId);
    } finally {
      if (mounted) setState(() => _joining = false);
    }
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
    final initial = _userName.trim().isEmpty ? '?' : _userName.trim().characters.first;
    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.fromLTRB(20, 20, 20, BottomBar.height + 48),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Greeting ────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.welcomeBack,
                          style: const TextStyle(fontSize: 15, color: TColors.inkSoft)),
                      const SizedBox(height: 2),
                      Text(
                        _userName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: TColors.ink),
                      ),
                    ],
                  ),
                ),
                Semantics(
                  button: true,
                  label: l10n.settingsTab,
                  child: InkWell(
                    onTap: () => _onBottomNavTap(2),
                    customBorder: const CircleBorder(),
                    child: Container(
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: TColors.soft,
                        border: Border.all(color: const Color(0xFFF0E6DE)),
                      ),
                      child: Text(initial,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: TColors.accent)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── Hero: start a meeting ───────────────────────────────
            RiseIn(
              child: Container(
                padding: const EdgeInsets.fromLTRB(22, 26, 22, 24),
                decoration: BoxDecoration(
                  gradient: TGradients.hero,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF8C50).withValues(alpha: 0.28),
                      blurRadius: 40,
                      offset: const Offset(0, 18),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.heroTitle,
                        style: const TextStyle(
                            fontSize: 26, height: 1.3, fontWeight: FontWeight.w700, color: TColors.ink)),
                    const SizedBox(height: 6),
                    Text(l10n.heroSubtitle,
                        style: const TextStyle(fontSize: 15, height: 1.6, color: Color(0xFF4A3428))),
                    const SizedBox(height: 18),
                    GradientButton(
                      white: true,
                      height: 52,
                      icon: Icons.videocam_rounded,
                      label: l10n.openNewMeeting,
                      loading: _startingMeeting,
                      onPressed: _startingMeeting ? null : _startMeeting,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ── Join by ID ──────────────────────────────────────────
            RiseIn(
              delay: const Duration(milliseconds: 80),
              child: _whiteCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _iconTile(Icons.login_rounded),
                        const SizedBox(width: 12),
                        Text(l10n.joinMeeting,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: TColors.ink)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(l10n.meetingIdLabel, style: const TextStyle(fontSize: 13, color: TColors.inkSoft)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _joinController,
                            textInputAction: TextInputAction.go,
                            onSubmitted: (_) => _joinFromField(),
                            decoration: InputDecoration(hintText: l10n.enterMeetingId),
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          width: 104,
                          child: GradientButton(
                            height: 52,
                            label: l10n.joinShort,
                            loading: _joining,
                            onPressed: _joinFromField,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 22),

            // ── Features ────────────────────────────────────────────
            Text(l10n.whatTurjumanOffers,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: TColors.ink)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _featureTile(Icons.center_focus_strong_rounded, l10n.featureSignToText)),
                const SizedBox(width: 10),
                Expanded(child: _featureTile(Icons.closed_caption_rounded, l10n.featureSpeechToText)),
                const SizedBox(width: 10),
                Expanded(child: _featureTile(Icons.person_rounded, l10n.featureAvatar)),
              ],
            ),
            const SizedBox(height: 22),

            // ── Letter of the day ───────────────────────────────────
            const RiseIn(delay: Duration(milliseconds: 160), child: LetterOfTheDayCard()),
          ],
        ),
      ),
    );
  }

  Widget _whiteCard({required Widget child}) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: TColors.card,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: TColors.line),
          boxShadow: [
            BoxShadow(color: TColors.ink.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, 6)),
          ],
        ),
        child: child,
      );

  Widget _iconTile(IconData icon) => Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(color: TColors.soft, borderRadius: BorderRadius.circular(14)),
        child: Icon(icon, color: TColors.accent, size: 22),
      );

  Widget _featureTile(IconData icon, String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
        decoration: BoxDecoration(
          color: TColors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: TColors.line),
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: TColors.soft, borderRadius: BorderRadius.circular(13)),
              child: Icon(icon, color: TColors.accent, size: 22),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, height: 1.35, fontWeight: FontWeight.w500, color: TColors.ink),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: TColors.page,
      extendBody: true,
      body: _isLoading
          ? const Center(
        child: CircularProgressIndicator(color: TColors.ember),
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
                    child: Glass(
                      borderRadius: BorderRadius.circular(22),
                      tint: const Color(0xD9FFFFFF),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(22),
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
                                  color: TColors.success, size: 12),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  l10n.inMeeting(meetingTitle),
                                  style: const TextStyle(
                                    color: TColors.ink,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                l10n.returnToMeeting,
                                style: const TextStyle(
                                  color: TColors.accent,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(Icons.arrow_forward_ios_rounded,
                                  size: 14, color: TColors.accent),
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
