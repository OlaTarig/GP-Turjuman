import 'package:flutter/material.dart';
import '../l10n/l10n.dart';
import '../theme/turjuman_theme.dart';
import 'SignUpView.dart';
import 'SignInView.dart';
import 'widgets/glass.dart';

/// Entry screen for signed-out users: logo orb on the brand background,
/// with Log in (primary) and Register (white) buttons on a glass card.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      body: BrandBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Column(
                children: [
                  RiseIn(
                    child: Floating(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          const PulseRings(size: 210),
                          Glass(
                            borderRadius: BorderRadius.circular(105),
                            child: SizedBox(
                              width: 210,
                              height: 210,
                              child: Center(
                                child: Image.asset('assets/logoT.png', width: 172, fit: BoxFit.contain),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 36),
                  RiseIn(
                    delay: const Duration(milliseconds: 150),
                    child: Glass(
                      tint: const Color(0xC7FFFFFF),
                      borderRadius: BorderRadius.circular(30),
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            l10n.welcomeTitle,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 22, height: 1.4, fontWeight: FontWeight.w700, color: TColors.ink),
                          ),
                          const SizedBox(height: 24),
                          GradientButton(
                            label: l10n.login,
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const LoginScreen()),
                            ),
                          ),
                          const SizedBox(height: 12),
                          GradientButton(
                            label: l10n.register,
                            white: true,
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const SignUpScreen()),
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
      ),
    );
  }
}
