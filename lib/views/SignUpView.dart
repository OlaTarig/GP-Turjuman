import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:ui';
// Import your email verification screen
import '../views/email_verification_screen.dart';
// Import your auth service
import '../AuthService.dart';
import '../l10n/l10n.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  bool _obscurePassword = true;
  bool _isLoading = false;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  final _formKey = GlobalKey<FormState>();
  final AuthService _authService = AuthService();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, Color color, IconData icon) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: context.l10n.ok,
          textColor: Colors.white,
          onPressed: () {},
        ),
      ),
    );
  }

  Future<void> _handleSignUp() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final String name = _nameController.text.trim();
      final String email = _emailController.text.trim();
      final String password = _passwordController.text.trim();

      // Step 1: Create Firebase Auth account
      UserCredential userCredential = await _authService.signUp(
        email: email,
        password: password,
      );

      final String uid = userCredential.user!.uid;
      debugPrint("✅ Firebase Auth account created: $uid");

      // Step 2: Update display name
      await _authService.updateUsername(username: name);
      debugPrint("✅ Display name updated");

      // Step 3: Create Firestore user document with all default fields
      await FirebaseFirestore.instance.collection('User').doc(uid).set({
        'name': name,
        'email': email,
        'micAccessSettings': false,
        'cameraAccessSettings': false,
        'micPermissionGranted': false,
        'cameraPermissionGranted': false,
        'isMicrophoneOn': false,
        'isCameraOn': false,
        'isHandRaised': false,
        'isSignCaptioningOn': false,
        'isSpeechCaptioningOn': false,
        'isHandAvatarOn': false,
        'emailVerified': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
      debugPrint("✅ User document created in Firestore");

      // Step 4: Send email verification
      await _authService.sendEmailVerification();
      debugPrint("✅ Email verification sent");

      if (mounted) {
        _showSnackBar(
          context.l10n.accountCreated,
          Colors.green,
          Icons.check_circle_outline,
        );

        await Future.delayed(const Duration(milliseconds: 500));

        if (!mounted) return;

        // Navigate to email verification screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => EmailVerificationScreen(
              email: email,
              userId: uid,
            ),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      IconData icon = Icons.error_outline;

      switch (e.code) {
        case 'weak-password':
          errorMessage = context.l10n.errWeakPassword;
          icon = Icons.lock_outline;
          break;
        case 'email-already-in-use':
          errorMessage = context.l10n.errEmailInUse;
          icon = Icons.person_outline;
          break;
        case 'invalid-email':
          errorMessage = context.l10n.errInvalidEmail;
          icon = Icons.email_outlined;
          break;
        case 'operation-not-allowed':
          errorMessage = context.l10n.errOperationNotAllowed;
          icon = Icons.block_outlined;
          break;
        case 'network-request-failed':
          errorMessage = context.l10n.errNoInternet;
          icon = Icons.wifi_off_outlined;
          break;
        default:
          errorMessage = context.l10n.errRegistrationFailed;
          icon = Icons.error_outline;
      }

      if (mounted) {
        _showSnackBar(errorMessage, Colors.redAccent, icon);
      }
    } catch (e) {
      debugPrint("❌ Unexpected error during registration: $e");
      if (mounted) {
        _showSnackBar(
          context.l10n.errUnexpected,
          Colors.redAccent,
          Icons.error_outline,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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
            colors: [Color(0xFFFFF9E3), Color(0xFFFFD98F), Color(0xFFFFB382)],
          ),
        ),
        child: Stack(
          children: [
            SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 30),
                  Image.asset(
                    'assets/logoT.png',
                    height: 180,
                    errorBuilder: (context, error, stackTrace) =>
                    const Icon(Icons.auto_awesome, size: 80, color: Colors.orange),
                  ),
                  const SizedBox(height: 30),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 25),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(30),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                            child: Container(
                              padding: const EdgeInsets.all(30),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.85),
                                borderRadius: BorderRadius.circular(30),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.3),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 20,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: Form(
                                key: _formKey,
                                child: Column(
                                  children: [
                                    Text(
                                      context.l10n.signUp,
                                      style: const TextStyle(
                                        fontSize: 32,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF1A1A2E),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      context.l10n.signUpSubtitle,
                                      style: const TextStyle(color: Colors.grey, fontSize: 15),
                                    ),
                                    const SizedBox(height: 30),
                                    _inputField(
                                      context.l10n.fullName,
                                      context.l10n.fullNameHint,
                                      _nameController,
                                      Icons.person_outline,
                                      validator: (value) {
                                        if (value == null || value.trim().isEmpty) {
                                          return context.l10n.valEnterName;
                                        }

                                        final trimmedValue = value.trim();

                                        if (trimmedValue.length < 2) {
                                          return context.l10n.valNameTooShort;
                                        }

                                        if (trimmedValue.length > 20) {
                                          return context.l10n.valNameTooLong;
                                        }

                                        if (RegExp(r'^[0-9]').hasMatch(trimmedValue)) {
                                          return context.l10n.valNameStartsNumber;
                                        }

                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 20),
                                    _inputField(
                                      context.l10n.email,
                                      context.l10n.emailHint,
                                      _emailController,
                                      Icons.email_outlined,
                                      keyboardType: TextInputType.emailAddress,
                                      validator: (value) {
                                        if (value == null || value.trim().isEmpty) {
                                          return context.l10n.valEnterEmail;
                                        }

                                        final email = value.trim();

                                        // No spaces
                                        if (email.contains(' ')) {
                                          return context.l10n.valEmailSpace;
                                        }

                                        // No consecutive dots
                                        if (email.contains('..')) {
                                          return context.l10n.valEmailDots;
                                        }

                                        // Basic email pattern with TLD check
                                        final emailRegex = RegExp(
                                          r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$',
                                        );

                                        if (!emailRegex.hasMatch(email)) {
                                          return context.l10n.valInvalidEmail;
                                        }

                                        // Check TLD length manually
                                        final tld = email.split('.').last;

                                        if (tld.length < 2 || tld.length > 6) {
                                          return context.l10n.valInvalidDomain;
                                        }

                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 20),
                                    _buildPasswordField(),
                                    const SizedBox(height: 40),
                                    AnimatedSignUpButton(
                                      text: context.l10n.register,
                                      onTap: _isLoading ? () {} : _handleSignUp,
                                      isLoading: _isLoading,
                                    ),
                                    const SizedBox(height: 20),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          context.l10n.alreadyHaveAccount,
                                          style: const TextStyle(fontSize: 15),
                                        ),
                                        GestureDetector(
                                          onTap: () => Navigator.pop(context),
                                          child: Text(
                                            context.l10n.login,
                                            style: const TextStyle(
                                              color: Colors.orange,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
            Positioned(
              top: 50,
              left: 20,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new,
                      color: Color(0xFF4A4A4A), size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPasswordField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 5, bottom: 8),
          child: Text(
            context.l10n.password,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        TextFormField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return context.l10n.valEnterPassword;
            }

            if (value.length < 9) {
              return context.l10n.valPasswordShort;
            }

            if (value.length > 20) {
              return context.l10n.valPasswordLong;
            }

            // Must contain letters
            if (!RegExp(r'[A-Za-z]').hasMatch(value)) {
              return context.l10n.valPasswordLetters;
            }

            // Must contain numbers
            if (!RegExp(r'[0-9]').hasMatch(value)) {
              return context.l10n.valPasswordNumbers;
            }

            return null;
          },
          decoration: InputDecoration(
            hintText: context.l10n.passwordHint,
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
            filled: true,
            fillColor: const Color(0xFFF8F9FA),
            prefixIcon: const Icon(Icons.lock_outline, color: Colors.grey),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: Colors.grey,
              ),
              onPressed: () {
                setState(() {
                  _obscurePassword = !_obscurePassword;
                });
              },
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide.none,
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          ),
        ),
      ],
    );
  }

  Widget _inputField(
      String label,
      String hint,
      TextEditingController controller,
      IconData icon, {
        TextInputType? keyboardType,
        String? Function(String?)? validator,
      }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 5, bottom: 8),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
            filled: true,
            fillColor: const Color(0xFFF8F9FA),
            prefixIcon: Icon(icon, color: Colors.grey),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide.none,
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          ),
        ),
      ],
    );
  }
}

// Animated Sign Up Button Widget
class AnimatedSignUpButton extends StatefulWidget {
  final String text;
  final VoidCallback onTap;
  final bool isLoading;

  const AnimatedSignUpButton({
    super.key,
    required this.text,
    required this.onTap,
    this.isLoading = false,
  });

  @override
  State<AnimatedSignUpButton> createState() => _AnimatedSignUpButtonState();
}

class _AnimatedSignUpButtonState extends State<AnimatedSignUpButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.isLoading ? null : (_) => setState(() => _isPressed = true),
      onTapUp: widget.isLoading
          ? null
          : (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: widget.isLoading ? null : () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeInOut,
        width: double.infinity,
        height: 60,
        transform: Matrix4.identity()..scale(_isPressed ? 0.95 : 1.0),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: widget.isLoading
                ? [Colors.grey.shade400, Colors.grey.shade500]
                : [const Color(0xFFFDBB84), const Color(0xFFFFD98F)],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: _isPressed || widget.isLoading
              ? []
              : [
            BoxShadow(
              color: const Color(0xFFFFD98F).withOpacity(0.5),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Center(
          child: widget.isLoading
              ? const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 2.5,
            ),
          )
              : Text(
            widget.text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
