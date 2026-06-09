import 'package:flutter/material.dart';

class CoachMarkOverlay extends StatelessWidget {
  final Offset spotlightCenter;
  final double spotlightRadius;
  final IconData featureIcon;
  final String title;
  final String description;
  final String buttonLabel;
  final VoidCallback onNext;

  const CoachMarkOverlay({
    super.key,
    required this.spotlightCenter,
    required this.spotlightRadius,
    required this.featureIcon,
    required this.title,
    required this.description,
    required this.buttonLabel,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final showAbove = spotlightCenter.dy > screenSize.height / 2;

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // Dark overlay with spotlight cutout — tap outside to skip
          GestureDetector(
            onTap: onNext,
            child: CustomPaint(
              size: screenSize,
              painter: _SpotlightPainter(
                center: spotlightCenter,
                radius: spotlightRadius,
              ),
            ),
          ),
          // Info card positioned above or below the spotlight
          Positioned(
            left: 24,
            right: 24,
            top: showAbove ? null : spotlightCenter.dy + spotlightRadius + 20,
            bottom: showAbove
                ? screenSize.height - spotlightCenter.dy + spotlightRadius + 20
                : null,
            child: _InfoCard(
              featureIcon: featureIcon,
              title: title,
              description: description,
              buttonLabel: buttonLabel,
              onNext: onNext,
            ),
          ),
        ],
      ),
    );
  }
}

class _SpotlightPainter extends CustomPainter {
  final Offset center;
  final double radius;

  const _SpotlightPainter({required this.center, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addOval(Rect.fromCircle(center: center, radius: radius))
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, Paint()..color = Colors.black.withOpacity(0.75));

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = const Color(0xFFFFB382).withOpacity(0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );

    // Arrow pointing down from card to spotlight
    final arrowPaint = Paint()
      ..color = const Color(0xFFFFB382)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final lineTop    = center.dy - radius - 52;
    final lineBottom = center.dy - radius - 6;

    canvas.drawLine(
      Offset(center.dx, lineTop),
      Offset(center.dx, lineBottom),
      arrowPaint,
    );

    // Arrowhead
    final headPaint = Paint()
      ..color = const Color(0xFFFFB382)
      ..style = PaintingStyle.fill;

    final head = Path()
      ..moveTo(center.dx, lineBottom + 10)
      ..lineTo(center.dx - 9, lineBottom - 4)
      ..lineTo(center.dx + 9, lineBottom - 4)
      ..close();

    canvas.drawPath(head, headPaint);
  }

  @override
  bool shouldRepaint(_SpotlightPainter old) =>
      old.center != center || old.radius != radius;
}

class _InfoCard extends StatelessWidget {
  final IconData featureIcon;
  final String title;
  final String description;
  final String buttonLabel;
  final VoidCallback onNext;

  const _InfoCard({
    required this.featureIcon,
    required this.title,
    required this.description,
    required this.buttonLabel,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF2D2F31),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFFFB382).withOpacity(0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: const Color(0xFFFFB382),
                child: Icon(featureIcon, color: Colors.black87, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFFFFB382),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              onPressed: onNext,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFB382),
                foregroundColor: Colors.black87,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              ),
              child: Text(
                buttonLabel,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
