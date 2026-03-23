import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/UserModel.dart';
import '../controllers/SettingsController.dart';
import '../views/ProfileView.dart';
import '../views/SignInView.dart';
import 'package:shared_preferences/shared_preferences.dart';
class SettingsView extends StatefulWidget {
  final UserModel user;
  final ValueChanged<UserModel> onUserUpdated; // ✅ جديد
  const SettingsView({
    super.key,
    required this.user,
    required this.onUserUpdated,
  });

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  static const Color primaryOrange = Color(0xFFFFB382);
  static const Color darkBg = Color(0xFF2D2F31);

  late UserModel _user;
  late SettingsController _controller;

  bool _loadingMic = false;
  bool _loadingCam = false;

  @override
  void initState() {
    super.initState();
    _user = widget.user;
    _controller = SettingsController();
    // ✅ شلنا ريفرش الصلاحيات هنا لأنه كان يخبّص على صلاحيات الهوست
  }

  Future<void> _openProfile() async {
    final updated = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProfileView(user: _user)),
    );

    if (updated is UserModel && mounted) {
      setState(() => _user = updated);
      widget.onUserUpdated(updated); // ✅ يخبر HomePage
    }
  }

  Future<void> _toggleMic(bool enable) async {
    setState(() => _loadingMic = true);
    try {
      _user = await _controller.setMicrophoneEnabled(_user, enable);

      // ✅ لا نعتمد على micPermissionGranted لأنه للهوست
      if (enable && mounted) {
        final st = await Permission.microphone.status;
        if (!st.isGranted) {
          await _permissionDialog(
            title: 'Microphone permission needed',
            message:
            'Permission was not granted. If it is permanently denied, enable it from system settings.',
            permission: Permission.microphone,
          );
        }
      }

      if (mounted) setState(() {});
    } finally {
      if (mounted) setState(() => _loadingMic = false);
    }
  }

  Future<void> _toggleCamera(bool enable) async {
    setState(() => _loadingCam = true);
    try {
      _user = await _controller.setCameraEnabled(_user, enable);

      // ✅ لا نعتمد على cameraPermissionGranted لأنه للهوست
      if (enable && mounted) {
        final st = await Permission.camera.status;
        if (!st.isGranted) {
          await _permissionDialog(
            title: 'Camera permission needed',
            message:
            'Permission was not granted. If it is permanently denied, enable it from system settings.',
            permission: Permission.camera,
          );
        }
      }

      if (mounted) setState(() {});
    } finally {
      if (mounted) setState(() => _loadingCam = false);
    }
  }

  Future<void> _permissionDialog({
    required String title,
    required String message,
    required Permission permission,
  }) async {
    final st = await permission.status;
    final permanentlyDenied = st.isPermanentlyDenied;

    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
          if (permanentlyDenied)
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: primaryOrange),
              onPressed: () {
                Navigator.pop(context);
                openAppSettings();
              },
              child: const Text('Open system settings'),
            ),
        ],
      ),
    );
  }

  Future<void> _signOut() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_logged_in', false);
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;

      Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
            (route) => false,
      );
    } catch (e) {
      debugPrint("Error signing out: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Logout failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ✅ نفس مكان/تصميم زر الهوم (أعلى يمين) + عنوان Settings
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Settings',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),

              // ✅ نفس تصميم الهوم بالضبط
              Container(
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
                child: IconButton(
                  onPressed: _signOut,
                  icon: const Icon(Icons.logout_rounded),
                  color: primaryOrange,
                  iconSize: 24,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ✅ كارد البروفايل (كبرناه شوي)
          _profileCard(onTap: _openProfile),
          const SizedBox(height: 14),

          _card(
            title: 'Meeting Access',
            children: [
              _switchRow(
                title: 'Microphone (App)',
                subtitle:
                'OFF disables mic in app. ON requests system permission.',
                value: _user.micAccessSettings,
                loading: _loadingMic,
                onChanged: _toggleMic,
              ),
              // ✅ نفس التنبيه موجود، بس بدون ربطه بصلاحيات الهوست
              // (لو تبغى نشيله بالكامل قلّي)
              const Divider(height: 24),
              _switchRow(
                title: 'Camera (App)',
                subtitle:
                'OFF disables camera in app. ON requests system permission.',
                value: _user.cameraAccessSettings,
                loading: _loadingCam,
                onChanged: _toggleCamera,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _profileCard({required VoidCallback onTap}) {
    final initial = (_user.name.isNotEmpty ? _user.name[0] : 'U').toUpperCase();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16), // ✅ أكبر
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: primaryOrange.withOpacity(0.18)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30, // ✅ أكبر من قبل
              backgroundColor: primaryOrange,
              child: Text(
                initial,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _user.name.isNotEmpty ? _user.name : 'User',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _user.email,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: Colors.grey.shade400, size: 28),
          ],
        ),
      ),
    );
  }

  Widget _card({required String title, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(16),
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
          Text(title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }

  Widget _switchRow({
    required String title,
    required String subtitle,
    required bool value,
    required bool loading,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(subtitle,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            ],
          ),
        ),
        if (loading)
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else
          Switch(
            value: value,
            activeThumbColor: primaryOrange,
            onChanged: onChanged,
          ),
      ],
    );
  }

  Widget _hintRevoke(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: primaryOrange.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(text, style: const TextStyle(fontSize: 12))),
            TextButton(
              onPressed: openAppSettings,
              child: const Text('System settings'),
            ),
          ],
        ),
      ),
    );
  }
}