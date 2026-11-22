import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'HomePage.dart';
import 'SignUpView.dart';
import '../l10n/l10n.dart';
import '../theme/turjuman_theme.dart';
import 'widgets/glass.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _obscurePassword = true;
  bool _isLoading = false;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (_emailController.text.trim().isEmpty) {
      _showSnackBar(
        context.l10n.errEnterEmail,
        Colors.orange,
        Icons.email_outlined,
      );
      return;
    }

    if (_passwordController.text.trim().isEmpty) {
      _showSnackBar(
        context.l10n.errEnterPassword,
        Colors.orange,
        Icons.lock_outline,
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (!mounted) return;

      _showSnackBar(
        context.l10n.loginSuccess,
        Colors.green,
        Icons.check_circle_outline,
      );

      await Future.delayed(const Duration(milliseconds: 500));

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomePage()),
      );
    } on FirebaseAuthException catch (e) {
      String message = context.l10n.errOccurred;
      IconData icon = Icons.error_outline;

      if (e.code == 'user-not-found' ||
          e.code == 'wrong-password' ||
          e.code == 'invalid-credential') {
        message = context.l10n.errInvalidCredentials;
        icon = Icons.lock_outline;
      } else if (e.code == 'invalid-email') {
        message = context.l10n.errInvalidEmail;
        icon = Icons.email_outlined;
      } else if (e.code == 'network-request-failed') {
        message = context.l10n.errNoInternet;
        icon = Icons.wifi_off_outlined;
      } else if (e.code == 'too-many-requests') {
        message = context.l10n.errTooManyRequests;
        icon = Icons.block_outlined;
      }

      _showSnackBar(message, Colors.redAccent, icon);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
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
                style:
                const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
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

  Future<void> _showForgotPasswordDialog() async {
    final TextEditingController resetEmailController = TextEditingController();

    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            context.l10n.resetPassword,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: TColors.ink,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.resetPasswordDesc,
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: resetEmailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  hintText: context.l10n.emailHint,
                  hintStyle:
                  TextStyle(color: Colors.grey.shade400, fontSize: 14),
                  filled: true,
                  fillColor: const Color(0xFFF8F9FA),
                  prefixIcon:
                  const Icon(Icons.email_outlined, color: Colors.orange),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(
                context.l10n.cancel,
                style: const TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                final email = resetEmailController.text.trim();

                if (email.isEmpty) {
                  _showSnackBar(
                    context.l10n.errEnterEmailAddress,
                    Colors.orange,
                    Icons.email_outlined,
                  );
                  return;
                }

                try {
                  await FirebaseAuth.instance
                      .sendPasswordResetEmail(email: email);

                  if (!mounted) return;
                  Navigator.of(context).pop();

                  _showSnackBar(
                    context.l10n.passwordResetSent,
                    Colors.green,
                    Icons.mark_email_read_outlined,
                  );
                } on FirebaseAuthException catch (e) {
                  String message = context.l10n.errOccurred;
                  IconData icon = Icons.error_outline;

                  if (e.code == 'user-not-found') {
                    message = context.l10n.errNoAccountFound;
                    icon = Icons.person_off_outlined;
                  } else if (e.code == 'invalid-email') {
                    message = context.l10n.errInvalidEmail;
                    icon = Icons.email_outlined;
                  } else if (e.code == 'network-request-failed') {
                    message = context.l10n.errNoInternet;
                    icon = Icons.wifi_off_outlined;
                  }

                  _showSnackBar(message, Colors.redAccent, icon);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: TColors.peach,
                foregroundColor: TColors.onPeach,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(context.l10n.sendResetLink),
            ),
          ],
        );
      },
    );
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
                padding: const EdgeInsets.fromLTRB(22, 24, 22, 32),
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    RiseIn(
                      child: Floating(
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            const PulseRings(size: 150, count: 2),
                            Glass(
                              borderRadius: BorderRadius.circular(75),
                              child: SizedBox(
                                width: 150,
                                height: 150,
                                child: Center(
                                  child: Image.asset('assets/logoT.png', width: 122, fit: BoxFit.contain),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    RiseIn(
                      delay: const Duration(milliseconds: 80),
                      child: Text(l10n.loginWelcomeTitle,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 28, fontWeight: FontWeight.w700, color: TColors.ink)),
                    ),
                    const SizedBox(height: 6),
                    RiseIn(
                      delay: const Duration(milliseconds: 140),
                      child: Text(l10n.loginWelcomeSubtitle,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 16, height: 1.5, color: Color(0xFF4F5254))),
                    ),
                    const SizedBox(height: 26),
                    RiseIn(
                      delay: const Duration(milliseconds: 200),
                      child: Glass(
                        tint: const Color(0xC7FFFFFF),
                        borderRadius: BorderRadius.circular(30),
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _inputField(l10n.email, l10n.emailHint, _emailController, Icons.email_outlined),
                            const SizedBox(height: 16),
                            _buildPasswordField(),
                            Align(
                              alignment: AlignmentDirectional.centerEnd,
                              child: TextButton(
                                onPressed: _showForgotPasswordDialog,
                                child: Text(l10n.forgotPassword,
                                    style: const TextStyle(color: TColors.accent, fontWeight: FontWeight.w600)),
                              ),
                            ),
                            const SizedBox(height: 8),
                            GradientButton(
                              label: l10n.login,
                              loading: _isLoading,
                              onPressed: _isLoading ? null : _signIn,
                            ),
                            const SizedBox(height: 18),
                            Wrap(
                              alignment: WrapAlignment.center,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(l10n.dontHaveAccount,
                                    style: const TextStyle(fontSize: 15, color: TColors.inkSoft)),
                                TextButton(
                                  onPressed: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const SignUpScreen()),
                                  ),
                                  child: Text(l10n.signUp,
                                      style: const TextStyle(
                                          color: TColors.accent, fontWeight: FontWeight.w700, fontSize: 15)),
                                ),
                              ],
                            ),
                          ],
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
        TextField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _isLoading ? null : _signIn(),
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

  Widget _inputField(String label, String hint, TextEditingController controller, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(label),
        TextField(
          controller: controller,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.email],
          decoration: InputDecoration(hintText: hint, prefixIcon: Icon(icon)),
        ),
      ],
    );
  }
}

