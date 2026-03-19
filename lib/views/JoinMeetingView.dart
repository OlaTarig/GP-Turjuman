import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/MeetingModel.dart';
import '../models/UserModel.dart';
import 'MeetingView.dart';
import 'HomePage.dart';

class JoinMeetingScreen extends StatefulWidget {
  final String meetingId;

  const JoinMeetingScreen({super.key, required this.meetingId});

  @override
  State<JoinMeetingScreen> createState() => _JoinMeetingScreenState();
}

class _JoinMeetingScreenState extends State<JoinMeetingScreen> {
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _joinMeeting();
  }

  // Always go to HomePage — never check currentUser here because
  // Firebase Auth may not have restored the session yet on cold start
  void _goBack() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomePage()),
          (route) => false,
    );
  }

  Future<void> _joinMeeting() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    await Future.delayed(const Duration(milliseconds: 600));

    const maxAttempts = 3;
    int attempts = 0;

    while (attempts < maxAttempts) {
      try {
        attempts++;
        debugPrint('🔄 Join attempt $attempts of $maxAttempts...');
        await _tryJoin();
        return;
      } catch (e) {
        debugPrint('❌ Join attempt $attempts failed: $e');

        if (!mounted) return;

        if (attempts >= maxAttempts) {
          setState(() {
            _isLoading = false;
            _errorMessage =
            'Network error. Please check your connection and tap Retry.';
          });
          return;
        }

        await Future.delayed(Duration(seconds: attempts * 2));
      }
    }
  }

  Future<void> _tryJoin() async {
    // ── Step 1: Check if user is logged in ──
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'You need to log in first to join a meeting.';
        });
      }
      return;
    }

    final uid = currentUser.uid;

    // ── Step 2: Fetch the meeting document ──
    final meetingDoc = await FirebaseFirestore.instance
        .collection('Meetings')
        .doc(widget.meetingId)
        .get();

    if (!meetingDoc.exists) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage =
          'Meeting not found. The link may be invalid or expired.';
        });
      }
      return;
    }

    final meetingData = {
      ...meetingDoc.data() as Map<String, dynamic>,
      'meetingId': meetingDoc.id,
    };
    final meeting = MeetingModel.fromMap(meetingData);

    // ── Step 3: Check if meeting is still active ──
    if (!meeting.isActive) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'This meeting has already ended.';
        });
      }
      return;
    }

    // ── Step 4: Check capacity ──
    if (meeting.numOfParticipants >= meeting.maxCapacity) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'This meeting is full. Maximum capacity reached.';
        });
      }
      return;
    }

    // ── Step 5: Add user to participants (if not already in) ──
    final meetingRef = FirebaseFirestore.instance
        .collection('Meetings')
        .doc(widget.meetingId);

    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(meetingRef);
      if (!snap.exists) return;

      final data = snap.data() as Map<String, dynamic>;
      final participants =
      List<String>.from((data['participants'] as List?) ?? []);

      if (!participants.contains(uid)) {
        final currentNum =
            (data['numOfParticipants'] as int?) ?? participants.length;
        tx.update(meetingRef, {
          'participants': FieldValue.arrayUnion([uid]),
          'numOfParticipants': currentNum + 1,
        });
      }
    });

    // ── Step 6: Fetch user data ──
    final userDoc = await FirebaseFirestore.instance
        .collection('User')
        .doc(uid)
        .get();

    if (!userDoc.exists) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage =
          'User profile not found. Please complete your profile.';
        });
      }
      return;
    }

    final userData = userDoc.data() as Map<String, dynamic>;
    userData['userId'] = uid;
    final user = UserModel.fromMap(userData);

    // ── Step 7: Fetch updated meeting ──
    final updatedMeetingDoc = await meetingRef.get();
    final updatedMeeting = MeetingModel.fromMap({
      ...updatedMeetingDoc.data() as Map<String, dynamic>,
      'meetingId': updatedMeetingDoc.id,
    });

    if (!mounted) return;

    // ── Step 8: Build clean stack: HomePage → MeetingView ──
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomePage()),
          (route) => false,
    );
    await Future.delayed(const Duration(milliseconds: 150));
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MeetingView(
          meeting: updatedMeeting,
          user: user,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) _goBack();
      },
      child: Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFFFFF9E3),
                Color(0xFFFFD98F),
                Color(0xFFFFB382),
              ],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 30),
                child: _isLoading ? _buildLoading() : _buildError(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.85),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 48,
                height: 48,
                child: CircularProgressIndicator(
                  color: Color(0xFFFFB382),
                  strokeWidth: 3,
                ),
              ),
              SizedBox(height: 24),
              Text(
                'Joining Meeting...',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A2E),
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Please wait while we connect you',
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildError() {
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.85),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 56),
          const SizedBox(height: 16),
          const Text(
            'Unable to Join',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _errorMessage ?? 'An unknown error occurred.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey, fontSize: 15),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _goBack,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF1A1A2E),
                    side: const BorderSide(color: Color(0xFFFFB382)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Go Back'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _joinMeeting,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFB382),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Retry'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}