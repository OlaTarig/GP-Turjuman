import 'package:flutter/material.dart';
import '../../controllers/SignCaptioningController.dart';
import '../../l10n/l10n.dart';

class SignCaptioningOverlay extends StatelessWidget {
  final SignCaptioningController signing;
  const SignCaptioningOverlay({super.key, required this.signing});

  @override
  Widget build(BuildContext context) {
    if (!signing.isEnabled) return const SizedBox.shrink();
    final l10n = context.l10n;
    return Stack(
      children: [
        if (signing.captureState == CaptureState.inferring)
          Positioned(
            top: 8,
            left: 0,
            right: 0,
            child: Center(
              child: _chip(
                Colors.deepPurple,
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    ),
                    const SizedBox(width: 8),
                    Text(l10n.analyzingSign,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 13)),
                  ],
                ),
              ),
            ),
          ),
        if (signing.captureState == CaptureState.capturing &&
            signing.currentArabicSign != null)
          Positioned(
            top: 12,
            left: 0,
            right: 0,
            child: Center(
              child: _chip(
                Colors.deepPurple,
                Text(
                  signing.currentArabicSign!,
                  textDirection: TextDirection.rtl,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        if (signing.handsOutOfFrame)
          Positioned(
            top: 8,
            left: 0,
            right: 0,
            child: Center(
              child: _chip(
                Colors.orange,
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        color: Colors.white, size: 16),
                    const SizedBox(width: 6),
                    Text(l10n.handsNotDetected,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 13)),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _chip(Color c, Widget child) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: c.withOpacity(0.9),
          borderRadius: BorderRadius.circular(20),
        ),
        child: child,
      );
}
