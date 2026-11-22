import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../theme/turjuman_theme.dart';

/// Frosted "liquid glass" surface: blur + translucent white + specular rim.
///
/// Use only for floating chrome (nav bar, controls, chips) so content stays
/// readable. [tint] lets dark screens (meeting) use a dark glass.
class Glass extends StatelessWidget {
  const Glass({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(24)),
    this.padding,
    this.tint = const Color(0x99FFFFFF),
    this.blur = 22,
    this.shadow = true,
    this.dark = false,
  });

  final Widget child;
  final BorderRadius borderRadius;
  final EdgeInsetsGeometry? padding;
  final Color tint;
  final double blur;
  final bool shadow;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final rim = dark ? const Color(0x38FFFFFF) : const Color(0xBFFFFFFF);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: shadow
            ? [
                BoxShadow(
                  color: dark
                      ? Colors.black.withValues(alpha: 0.30)
                      : const Color(0xFFA84F1F).withValues(alpha: 0.14),
                  blurRadius: 30,
                  offset: const Offset(0, 12),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          // Tint and sheen are separate layers: a BoxDecoration ignores
          // `color` whenever `gradient` is set.
          child: DecoratedBox(
            decoration: BoxDecoration(color: tint, borderRadius: borderRadius),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: borderRadius,
                border: Border.all(color: rim),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: dark ? 0.10 : 0.35),
                    Colors.white.withValues(alpha: 0.0),
                  ],
                  stops: const [0.0, 0.55],
                ),
              ),
              child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
            ),
          ),
        ),
      ),
    );
  }
}

/// Primary call-to-action: peach→gold gradient pill with warm text.
/// Shrinks slightly while pressed.
class GradientButton extends StatefulWidget {
  const GradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.height = 56,
    this.white = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final double height;

  /// White variant for use on top of a peach surface (home hero card).
  final bool white;

  @override
  State<GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<GradientButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null && !widget.loading;
    final fg = widget.white ? TColors.accentDeep : TColors.onPeach;
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      child: GestureDetector(
        onTapDown: enabled ? (_) => setState(() => _down = true) : null,
        onTapCancel: () => setState(() => _down = false),
        onTapUp: enabled
            ? (_) {
                setState(() => _down = false);
                widget.onPressed!();
              }
            : null,
        child: AnimatedScale(
          scale: _down ? 0.97 : 1,
          duration: TMotion.fast,
          curve: TMotion.out,
          child: AnimatedOpacity(
            opacity: enabled || widget.loading ? 1 : 0.55,
            duration: TMotion.fast,
            child: Container(
              height: widget.height,
              decoration: BoxDecoration(
                color: widget.white ? Colors.white : null,
                gradient: widget.white ? null : TGradients.primary,
                borderRadius: BorderRadius.circular(widget.height / 2),
                boxShadow: [
                  BoxShadow(
                    color: const Color(
                      0xFFFF8C50,
                    ).withValues(alpha: widget.white ? 0.18 : 0.35),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: widget.loading
                  ? SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: fg,
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.icon != null) ...[
                          Icon(widget.icon, color: fg, size: 22),
                          const SizedBox(width: 8),
                        ],
                        Flexible(
                          child: Text(
                            widget.label,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: fg,
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
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

/// Animated brand background for onboarding / log in / sign up:
/// slowly shifting cream→gold→peach gradient with morphing liquid blobs.
class BrandBackground extends StatefulWidget {
  const BrandBackground({super.key, required this.child});

  final Widget child;

  @override
  State<BrandBackground> createState() => _BrandBackgroundState();
}

class _BrandBackgroundState extends State<BrandBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 12),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (TMotion.reduced(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_c.value);
        return Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.lerp(
                    Alignment.topRight,
                    Alignment.topCenter,
                    t,
                  )!,
                  end: Alignment.lerp(
                    Alignment.bottomLeft,
                    Alignment.bottomCenter,
                    t,
                  )!,
                  colors: TGradients.brand.colors,
                  stops: TGradients.brand.stops,
                ),
              ),
            ),
            _Blob(
              t: t,
              size: 270,
              top: -80,
              right: -80,
              phase: 0,
              colors: const [Color(0xE6FFFFFF), Color(0x26FFFFFF)],
            ),
            _Blob(
              t: t,
              size: 220,
              top: 300,
              left: -90,
              phase: 2,
              colors: const [Color(0xBFFFA06E), Color(0x00FFB382)],
            ),
            _Blob(
              t: t,
              size: 160,
              top: 190,
              right: -40,
              phase: 4,
              colors: const [Color(0xF2FFECAA), Color(0x00FFD98F)],
            ),
            child!,
          ],
        );
      },
      child: widget.child,
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({
    required this.t,
    required this.size,
    required this.colors,
    required this.phase,
    this.top,
    this.left,
    this.right,
  });

  final double t;
  final double size;
  final List<Color> colors;
  final double phase;
  final double? top;
  final double? left;
  final double? right;

  @override
  Widget build(BuildContext context) {
    final a = (t * 2 * math.pi) + phase;
    // Morph by animating each corner radius independently.
    BorderRadius r(double s) => BorderRadius.only(
      topLeft: Radius.elliptical(
        s * (0.42 + 0.16 * math.sin(a)),
        s * (0.45 + 0.12 * math.cos(a)),
      ),
      topRight: Radius.elliptical(
        s * (0.58 - 0.16 * math.sin(a)),
        s * (0.41 + 0.15 * math.sin(a)),
      ),
      bottomRight: Radius.elliptical(
        s * (0.63 - 0.2 * math.cos(a)),
        s * (0.59 - 0.14 * math.sin(a)),
      ),
      bottomLeft: Radius.elliptical(
        s * (0.37 + 0.2 * math.cos(a)),
        s * (0.55 - 0.1 * math.cos(a)),
      ),
    );
    return Positioned(
      top: top,
      left: left,
      right: right,
      child: Transform.translate(
        offset: Offset(16 * math.sin(a), -12 * math.cos(a)),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: r(size),
            gradient: RadialGradient(
              colors: colors,
              center: const Alignment(-0.3, -0.3),
            ),
          ),
        ),
      ),
    );
  }
}

/// Expanding white rings behind a hero element (logo orb).
class PulseRings extends StatefulWidget {
  const PulseRings({super.key, required this.size, this.count = 3});

  final double size;
  final int count;

  @override
  State<PulseRings> createState() => _PulseRingsState();
}

class _PulseRingsState extends State<PulseRings>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3600),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (TMotion.reduced(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => Stack(
          alignment: Alignment.center,
          children: List.generate(widget.count, (i) {
            final p = (_c.value + i / widget.count) % 1.0;
            final e = TMotion.out.transform(p);
            return Opacity(
              opacity: (1 - p) * 0.9,
              child: Transform.scale(
                scale: 0.72 + 0.8 * e,
                child: Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.85),
                      width: 2,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

/// Gentle up-and-down float used on hero elements.
class Floating extends StatefulWidget {
  const Floating({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.distance = 7,
  });

  final Widget child;
  final Duration delay;
  final double distance;

  @override
  State<Floating> createState() => _FloatingState();
}

class _FloatingState extends State<Floating>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3400),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (TMotion.reduced(context)) {
      _c.stop();
      return;
    }
    if (!_started) {
      _started = true;
      Future.delayed(widget.delay, () {
        if (mounted) _c.repeat(reverse: true);
      });
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) => Transform.translate(
        offset: Offset(
          0,
          -widget.distance * Curves.easeInOut.transform(_c.value),
        ),
        child: child,
      ),
      child: widget.child,
    );
  }
}

/// One-shot fade + rise on first build (cards, forms, slides).
class RiseIn extends StatelessWidget {
  const RiseIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.offset = 24,
  });

  final Widget child;
  final Duration delay;
  final double offset;

  @override
  Widget build(BuildContext context) {
    if (TMotion.reduced(context)) return child;
    final total = const Duration(milliseconds: 620) + delay;
    final startFrac = delay.inMilliseconds / total.inMilliseconds;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: total,
      builder: (context, v, child) {
        final p = startFrac >= 1
            ? 1.0
            : ((v - startFrac) / (1 - startFrac)).clamp(0.0, 1.0);
        final e = TMotion.out.transform(p);
        return Opacity(
          opacity: e,
          child: Transform.translate(
            offset: Offset(0, offset * (1 - e)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}
