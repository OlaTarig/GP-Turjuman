import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../services/sign_letters_service.dart';
import '../../theme/turjuman_theme.dart';

/// Sign image for one Arabic letter, loaded from Firebase Storage.
/// Falls back to nothing (the caller still shows the letter itself).
class SignLetterImage extends StatelessWidget {
  const SignLetterImage({super.key, required this.letter, required this.width, required this.height});

  final String letter;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: SignLettersService.instance.urlFor(letter),
      builder: (context, snap) {
        final url = snap.data;
        if (url == null) {
          return SizedBox(
            width: width,
            height: height,
            child: snap.connectionState == ConnectionState.waiting
                ? const Center(
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: TColors.ember),
                    ),
                  )
                : null,
          );
        }
        return Image.network(
          url,
          width: width,
          height: height,
          fit: BoxFit.contain,
          cacheWidth: (width * MediaQuery.devicePixelRatioOf(context)).round(),
          errorBuilder: (_, __, ___) => SizedBox(width: width, height: height),
          frameBuilder: (context, child, frame, wasSync) => AnimatedOpacity(
            opacity: frame == null ? 0 : 1,
            duration: TMotion.medium,
            child: child,
          ),
        );
      },
    );
  }
}

/// "حرف اليوم" — home card with today's letter. Changes every UTC day.
class LetterOfTheDayCard extends StatelessWidget {
  const LetterOfTheDayCard({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final letter = SignLettersService.instance.letterOfTheDay();
    return Semantics(
      container: true,
      label: '${l10n.letterOfTheDay}: $letter',
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: TColors.card,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: TColors.line),
          boxShadow: [
            BoxShadow(color: TColors.ink.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, 6)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 78,
              height: 92,
              decoration: BoxDecoration(
                gradient: TGradients.drop,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(color: const Color(0xFFFF8C50).withValues(alpha: 0.25), blurRadius: 14, offset: const Offset(0, 6)),
                ],
              ),
              alignment: Alignment.center,
              child: SignLetterImage(letter: letter, width: 64, height: 80),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.letterOfTheDay,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: TColors.accent)),
                  Text(letter,
                      style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w700, height: 1.2, color: TColors.ink)),
                  Text(l10n.letterOfTheDayHint,
                      style: const TextStyle(fontSize: 13, color: TColors.inkSoft)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "اسمك بلغة الإشارة" — shows each letter of [name] with its sign image.
/// Chips pop in with a spring as the user types.
class NameInSign extends StatelessWidget {
  const NameInSign({super.key, required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final letters = SignLettersService.instance.lettersOf(name, limit: 10);
    return Container(
      constraints: const BoxConstraints(minHeight: 100),
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xE6FFF9E3), Color(0x73FFD98F)],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.nameInSign,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: TColors.accent)),
          const SizedBox(height: 8),
          Semantics(
            liveRegion: true,
            label: letters.isEmpty ? l10n.typeYourName : letters.join(' '),
            child: letters.isEmpty
                ? Text(l10n.typeYourName, style: const TextStyle(fontSize: 14, color: TColors.inkSoft))
                : Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (var i = 0; i < letters.length; i++)
                        _LetterChip(key: ValueKey('$i-${letters[i]}'), letter: letters[i], index: i),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _LetterChip extends StatelessWidget {
  const _LetterChip({super.key, required this.letter, required this.index});

  final String letter;
  final int index;

  @override
  Widget build(BuildContext context) {
    final hasImage = SignLettersService.instance.fileFor(letter) != null;
    final chip = Container(
      width: 52,
      height: hasImage ? 70 : 52,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFF6EE), Color(0xFFFFE3CF)],
        ),
        boxShadow: [
          BoxShadow(color: const Color(0xFFFF8C50).withValues(alpha: 0.22), blurRadius: 14, offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (hasImage) SignLetterImage(letter: letter, width: 40, height: 46),
          Text(letter,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, height: 1, color: TColors.onPeach)),
        ],
      ),
    );
    if (TMotion.reduced(context)) return chip;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 460),
      curve: TMotion.spring,
      builder: (context, v, child) => Opacity(
        opacity: v.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, 12 * (1 - v)),
          child: Transform.scale(scale: 0.75 + 0.25 * v, child: child),
        ),
      ),
      child: chip,
    );
  }
}
