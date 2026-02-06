import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _userName = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        // First, immediately show the display name (no waiting)
        setState(() {
          _userName = user.displayName ?? 'User';
          _isLoading = false;
        });

        // Then optionally fetch from Firestore in background to update if needed
        try {
          final userDoc = await FirebaseFirestore.instance
              .collection('User')
              .doc(user.uid)
              .get();

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
          // Continue with displayName, no problem
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

  Future<void> _startMeeting() async {
    // TODO: Implement your meeting logic here
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Starting meeting...'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _signOut() async {
    try {
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    } catch (e) {
      debugPrint("Error signing out: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFF9E3), Color(0xFFFFB382)],
          ),
        ),
        child: SafeArea(
          child: _isLoading
              ? const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFB382)),
            ),
          )
              : Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with greeting and sign out
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Hello,',
                            style: TextStyle(
                              fontSize: 24,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _userName,
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1A1A2E),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Sign out button
                    IconButton(
                      onPressed: _signOut,
                      icon: const Icon(Icons.logout),
                      color: Colors.grey.shade700,
                      iconSize: 28,
                    ),
                  ],
                ),

                const SizedBox(height: 60),

                // Main content area
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Meeting icon
                        Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 30,
                                offset: const Offset(0, 15),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.video_call,
                            size: 70,
                            color: Color(0xFFFFB382),
                          ),
                        ),

                        const SizedBox(height: 50),

                        // Start Meeting button
                        ElevatedButton(
                          onPressed: _startMeeting,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFFB382),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 48,
                              vertical: 18,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 5,
                            shadowColor: Colors.black.withOpacity(0.3),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.video_call,
                                size: 28,
                              ),
                              SizedBox(width: 12),
                              Text(
                                'Start Meeting',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}