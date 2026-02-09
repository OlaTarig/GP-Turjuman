import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/UserModel.dart';
import '../controllers/ProfileController.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProfileView extends StatefulWidget {
  final UserModel user;
  const ProfileView({super.key, required this.user});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  static const Color primaryOrange = Color(0xFFFFB382);
  static const Color darkBg = Color(0xFF2D2F31);

  late final TextEditingController _nameCtrl;
  late final TextEditingController _emailCtrl;

  final _formKey = GlobalKey<FormState>();
  final _controller = ProfileController();

  bool _saving = false;

  // ✅ صورة مختارة محلياً
  File? _pickedImage;

  // ✅ رابط الصورة (لو انرفع للسحابة)
  String? _photoUrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.user.name);
    _emailCtrl = TextEditingController(text: widget.user.email);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  // ✅ اختيار صورة من المعرض
  Future<void> _pickImageFromGallery() async {
    final picker = ImagePicker();
    final XFile? file = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (file == null) return;

    setState(() {
      _pickedImage = File(file.path);
    });
  }

  // ✅ تصوير صورة بالكاميرا
  Future<void> _pickImageFromCamera() async {
    final picker = ImagePicker();
    final XFile? file = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
    );
    if (file == null) return;

    setState(() {
      _pickedImage = File(file.path);
    });
  }

  // ✅ BottomSheet لاختيار المصدر (Camera / Gallery)
  void _showImageSourceSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take photo'),
              onTap: () {
                Navigator.pop(context);
                _pickImageFromCamera();
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImageFromGallery();
              },
            ),
          ],
        ),
      ),
    );
  }

  // ✅ رفع الصورة لـ Firebase Storage وإرجاع رابطها
  Future<String?> _uploadProfileImage(String userId) async {
    if (_pickedImage == null) return _photoUrl;

    final storageRef = FirebaseStorage.instance
        .ref()
        .child('profile_pictures')
        .child('$userId.jpg');

    await storageRef.putFile(_pickedImage!);
    return await storageRef.getDownloadURL();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      // ✅ ارفع الصورة (إذا موجودة)
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

      if (uid.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: user not logged in')),
        );
        return;
      }

// ارفع الصورة
      final uploadedUrl = await _uploadProfileImage(uid);
      _photoUrl = uploadedUrl;

// حدّث في Firestore
      await _controller.updateProfile(
        userId: uid,
        name: _nameCtrl.text.trim(),
        photoUrl: _photoUrl,
      );

// حدّث الموديل محليًا
      widget.user.name = _nameCtrl.text.trim();

      // email ما يتغير
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated')),
      );

      Navigator.pop(context, widget.user); // ✅ يرجع للـSettings مع الموديل
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
      // لا تسوين pop في الخطأ، خليها تبقى عشان تعدل وتعيد محاولة
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final initial =
    (widget.user.name.isNotEmpty ? widget.user.name[0] : 'U').toUpperCase();

    return Scaffold(
      backgroundColor: const Color(0xFFFFFBF5),
      appBar: AppBar(
        backgroundColor: primaryOrange, // ✅ نفس لون الزر
        centerTitle: true,
        title: const Text('Profile', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              const SizedBox(height: 10),

              // ✅ صورة أكبر + قابل للضغط
              GestureDetector(
                onTap: _showImageSourceSheet, // ✅ Camera / Gallery
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    CircleAvatar(
                      radius: 58,
                      backgroundColor: primaryOrange,
                      backgroundImage:
                      _pickedImage != null ? FileImage(_pickedImage!) : null,
                      child: _pickedImage == null
                          ? Text(
                        initial,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 34,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                          : null,
                    ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.12),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          )
                        ],
                      ),
                      child: const Icon(
                        Icons.camera_alt,
                        size: 18,
                        color: primaryOrange,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              _field(
                label: 'Name',
                controller: _nameCtrl,
                validator: (v) {
                  final t = (v ?? '').trim();
                  if (t.isEmpty) return 'Name is required';
                  if (t.length < 2) return 'Name is too short';
                  return null;
                },
              ),

              const SizedBox(height: 12),

              // ✅ Email للعرض فقط (ممنوع التعديل)
              _field(
                label: 'Email',
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                enabled: false,
              ),

              const SizedBox(height: 18),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryOrange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : const Text(
                    'Save',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field({
    required String label,
    required TextEditingController controller,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    bool enabled = true,
  }) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            validator: validator,
            enabled: enabled,
            decoration: InputDecoration(
              filled: true,
              fillColor: enabled ? Colors.white : Colors.grey.shade100,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
            ),
          ),
        ],
      ),
    );
  }
}