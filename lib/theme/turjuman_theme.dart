import 'package:flutter/material.dart';

/// Design tokens for the liquid-glass redesign.
///
/// Brand: white pages, peach/gold accents, warm dark-brown text instead of
/// black. Keep every colour here so screens never hard-code hex values.
class TColors {
  TColors._();

  // Surfaces
  static const Color page = Color(0xFFFFFFFF);
  static const Color card = Color(0xFFFFFFFF);
  static const Color field = Color(0xFFFAFAFA);
  static const Color soft = Color(0xFFFFF5EE); // peach-tinted tile
  static const Color line = Color(0xFFEFEFEF);
  static const Color fieldLine = Color(0xFFE6E6E6);

  // Brand
  static const Color peach = Color(0xFFFFB382);
  static const Color gold = Color(0xFFFFD98F);
  static const Color cream = Color(0xFFFFF9E3);
  static const Color ember = Color(0xFFE0742F); // focus ring, active dots

  // Text (warm, never pure black)
  static const Color ink = Color(0xFF3A2C24);
  static const Color inkSoft = Color(0xFF5F6368);
  static const Color inkMuted = Color(0xFF7D8083);
  static const Color accent = Color(0xFFA84F1F); // links, small labels on white
  static const Color accentDeep = Color(0xFF7E3A15);
  static const Color onPeach = Color(0xFF3B1E0E); // text on peach/gold

  // States
  static const Color success = Color(0xFF2E9E6A);
  static const Color danger = Color(0xFFB3261E);
  static const Color dangerSoft = Color(0xFFFFF6F6);
}

class TGradients {
  TGradients._();

  /// The "ابدأ الآن" button gradient — used for every primary button.
  static const LinearGradient primary = LinearGradient(
    colors: [TColors.peach, TColors.gold],
  );

  /// Full-screen brand background (onboarding, log in, sign up).
  static const LinearGradient brand = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [TColors.cream, Color(0xFFFFE7B0), TColors.gold, TColors.peach],
    stops: [0.0, 0.35, 0.55, 1.0],
  );

  /// Home hero card.
  static const LinearGradient hero = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [Color(0xFFFFF3E9), Color(0xFFFFD9BF), TColors.peach],
    stops: [0.0, 0.55, 1.0],
  );

  /// The glossy "droplet" used for the selected tab and active toggles.
  static const LinearGradient drop = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFFFD6BA), Color(0xE6FFB382)],
  );
}

class TMotion {
  TMotion._();

  static const Duration fast = Duration(milliseconds: 160);
  static const Duration medium = Duration(milliseconds: 320);
  static const Duration slow = Duration(milliseconds: 460);

  /// Slight overshoot used for the tab indicator and toggles.
  static const Curve spring = Cubic(0.34, 1.45, 0.64, 1);
  static const Curve out = Cubic(0.22, 1, 0.36, 1);

  /// True when the user asked the OS to reduce motion.
  static bool reduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;
}

ThemeData buildTurjumanTheme() {
  final base = ThemeData(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: TColors.page,
    colorScheme: ColorScheme.fromSeed(
      seedColor: TColors.peach,
      primary: TColors.ember,
      surface: TColors.page,
      onSurface: TColors.ink,
    ),
    textTheme: base.textTheme.apply(
      bodyColor: TColors.ink,
      displayColor: TColors.ink,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: TColors.field,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      hintStyle: const TextStyle(color: TColors.inkMuted),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: TColors.fieldLine),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: TColors.fieldLine),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: TColors.ember, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: TColors.danger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: TColors.danger, width: 1.6),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}
