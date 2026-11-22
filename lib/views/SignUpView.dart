import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// Import your email verification screen
import '../views/email_verification_screen.dart';
// Import your auth service
import '../AuthService.dart';
import '../l10n/l10n.dart';
import '../theme/turjuman_theme.dart';
import 'widgets/glass.dart';
import 'widgets/sign_letters.dart';

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

  String? _validateName(String? value) {
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
  }

  String? _validateEmail(String? value) {
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
  }

  String? _validatePassword(String? value) {
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
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      body: BrandBackground(
        child: SafeArea(
          child: Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 64, 22, 32),
                child: Column(
                  children: [
                    RiseIn(
                      child: Floating(
                        child: Glass(
                          borderRadius: BorderRadius.circular(48),
                          child: SizedBox(
                            width: 96,
                            height: 96,
                            child: Center(
                              child: Image.asset('assets/logoT.png', width: 78, fit: BoxFit.contain),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    RiseIn(
                      delay: const Duration(milliseconds: 80),
                      child: Text(l10n.signUpJourneyTitle,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 27, fontWeight: FontWeight.w700, color: TColors.ink)),
                    ),
                    const SizedBox(height: 6),
                    RiseIn(
                      delay: const Duration(milliseconds: 140),
                      child: Text(l10n.signUpSubtitle,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 16, height: 1.5, color: Color(0xFF4F5254))),
                    ),
                    const SizedBox(height: 22),
                    RiseIn(
                      delay: const Duration(milliseconds: 200),
                      child: Glass(
                        tint: const Color(0xC7FFFFFF),
                        borderRadius: BorderRadius.circular(30),
                        padding: const EdgeInsets.all(22),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _inputField(
                                l10n.fullName,
                                l10n.fullNameHint,
                                _nameController,
                                Icons.person_outline,
                                validator: _validateName,
                                autofill: AutofillHints.name,
                              ),
                              const SizedBox(height: 12),
                              ValueListenableBuilder<TextEditingValue>(
                                valueListenable: _nameController,
                                builder: (context, value, _) => NameInSign(name: value.text),
                              ),
                              const SizedBox(height: 16),
                              _inputField(
                                l10n.email,
                                l10n.emailHint,
                                _emailController,
                                Icons.email_outlined,
                                keyboardType: TextInputType.emailAddress,
                                validator: _validateEmail,
                                autofill: AutofillHints.email,
                              ),
                              const SizedBox(height: 16),
                              _buildPasswordField(),
                              const SizedBox(height: 24),
                              GradientButton(
                                label: l10n.register,
                                loading: _isLoading,
                                onPressed: _isLoading ? null : _handleSignUp,
                              ),
                              const SizedBox(height: 14),
                              Wrap(
                                alignment: WrapAlignment.center,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(l10n.alreadyHaveAccount,
                                      style: const TextStyle(fontSize: 15, color: TColors.inkSoft)),
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: Text(l10n.login,
                                        style: const TextStyle(
                                            color: TColors.accent, fontWeight: FontWeight.w700, fontSize: 15)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (Navigator.of(context).canPop())
                PositionedDirectional(
                  top: 8,
                  start: 16,
                  child: Glass(
                    borderRadius: BorderRadius.circular(24),
                    child: IconButton(
                      tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                      icon: const BackButtonIcon(),
                      color: TColors.ink,
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsetsDirectional.only(start: 4, bottom: 8),
        child: Text(text,
            style: const TextStyle(color: TColors.ink, fontSize: 14, fontWeight: FontWeight.w600)),
      );

  Widget _buildPasswordField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(context.l10n.password),
        TextFormField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          validator: _validatePassword,
          autofillHints: const [AutofillHints.newPassword],
          decoration: InputDecoration(
            hintText: context.l10n.passwordHint,
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
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
    String? autofill,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(label),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: validator,
          textInputAction: TextInputAction.next,
          autofillHints: autofill == null ? null : [autofill],
          decoration: InputDecoration(hintText: hint, prefixIcon: Icon(icon)),
        ),
      ],
    );
  }
}
