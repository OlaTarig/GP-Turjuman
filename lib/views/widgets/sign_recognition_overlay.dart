import 'package:flutter/material.dart';
import '../../controllers/sign_recognition_controller.dart';
import '../../l10n/l10n.dart';

/// Overlay for continuous sign recognition results.
/// Shows nothing while idle or active (waiting for first batch).
/// Shows a top-5 card at the caption position once results are available.
class SignRecognitionOverlay extends StatelessWidget {
  final SignRecognitionController controller;
  const SignRecognitionOverlay({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final state = controller.state;
    if (state != SignRecogState.results && state != SignRecogState.unrecognized) {
      return const SizedBox.shrink();
    }

    return Stack(
      children: [
        Positioned(
          bottom: 60,
          left: 12,
          right: 12,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.88),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: state == SignRecogState.unrecognized
                      ? Colors.orange.withOpacity(0.5)
                      : Colors.tealAccent.withOpacity(0.35),
                  width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      context.l10n.signRecognition,
                      style: const TextStyle(
                          color: Colors.tealAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 8),
                    _HandBadge(label: 'LH', ok: controller.leftHandVisible),
                    const SizedBox(width: 4),
                    _HandBadge(label: 'RH', ok: controller.rightHandVisible),
                    const Spacer(),
                    GestureDetector(
                      onTap: controller.clearResults,
                      child: const Icon(Icons.close,
                          color: Colors.white54, size: 16),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (state == SignRecogState.unrecognized)
                  const Text(
                    'Could not recognize the sign',
                    style: TextStyle(
                        color: Colors.orangeAccent,
                        fontSize: 14,
                        fontWeight: FontWeight.w500),
                    textAlign: TextAlign.center,
                  )
                else
                  ...controller.topPredictions
                      .asMap()
                      .entries
                      .map((e) => _ResultRow(rank: e.key, pred: e.value)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ResultRow extends StatelessWidget {
  final int rank;
  final SignRecogPrediction pred;
  const _ResultRow({required this.rank, required this.pred});

  @override
  Widget build(BuildContext context) {
    final isTop = rank == 0;
    final pct = (pred.confidence * 100).clamp(0.0, 100.0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        children: [
          SizedBox(
            width: 18,
            child: Text(
              '${rank + 1}.',
              style: TextStyle(
                color: isTop ? Colors.tealAccent : Colors.white38,
                fontSize: isTop ? 13 : 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pred.arabic,
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    color: isTop ? Colors.white : Colors.white70,
                    fontSize: isTop ? 16 : 13,
                    fontWeight:
                        isTop ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                if (pred.english.isNotEmpty && pred.english != '?')
                  Text(
                    pred.english,
                    style: TextStyle(
                      color: isTop ? Colors.white70 : Colors.white38,
                      fontSize: isTop ? 12 : 10,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 72,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${pct.toStringAsFixed(1)}%',
                  style: TextStyle(
                    color: isTop ? Colors.tealAccent : Colors.white54,
                    fontSize: isTop ? 12 : 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: pct / 100,
                    minHeight: 4,
                    backgroundColor: Colors.white12,
                    valueColor: AlwaysStoppedAnimation<Color>(
                        isTop ? Colors.tealAccent : Colors.white38),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HandBadge extends StatelessWidget {
  final String label;
  final bool ok;
  const _HandBadge({required this.label, required this.ok});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: ok
              ? Colors.green.withOpacity(0.75)
              : Colors.red.withOpacity(0.65),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          ok ? '$label: OK' : '$label: ✗',
          style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w600),
        ),
      );
}
