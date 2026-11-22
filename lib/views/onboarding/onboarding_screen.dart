import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../l10n/l10n.dart';
import '../../theme/turjuman_theme.dart';
import '../widgets/glass.dart';

/// Onboarding on the animated brand background.
/// Slides: logo orb → camera recognises signs → inclusive meetings.
class OnboardingScreen extends StatefulWidget {
  final VoidCallback onComplete;
  const OnboardingScreen({super.key, required this.onComplete});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  static const int _pageCount = 3;

  bool get _isLastPage => _currentPage == _pageCount - 1;

  Future<void> _complete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', true);
    widget.onComplete();
  }

  void _next() {
    _pageController.nextPage(
      duration: TMotion.reduced(context) ? Duration.zero : const Duration(milliseconds: 420),
      curve: TMotion.out,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final titles = [l10n.onboarding1Title, l10n.onboardSignTitle, l10n.onboarding3Title];
    final bodies = [l10n.onboarding1Subtitle, l10n.onboarding2Subtitle, l10n.onboardMeetingsBody];

    return Scaffold(
      body: BrandBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // Skip
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: AnimatedOpacity(
                    duration: TMotion.medium,
                    opacity: _isLastPage ? 0 : 1,
                    child: IgnorePointer(
                      ignoring: _isLastPage,
                      child: Glass(
                        borderRadius: BorderRadius.circular(22),
                        child: InkWell(
                          onTap: _complete,
                          borderRadius: BorderRadius.circular(22),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                            child: Text(l10n.skip,
                                style: const TextStyle(
                                    fontSize: 15, fontWeight: FontWeight.w600, color: TColors.ink)),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Illustrations (swipeable)
              Expanded(
                child: PageView(
                  controller: _pageController,
                  onPageChanged: (i) => setState(() => _currentPage = i),
                  children: const [_LogoOrb(), _SignScanner(), _MeetingBubbles()],
                ),
              ),

              // Glass sheet with copy + controls
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(38)),
                child: Glass(
                  shadow: false,
                  tint: const Color(0xB8FFFFFF),
                  blur: 30,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(38)),
                  padding: EdgeInsets.fromLTRB(
                      24, 24, 24, 24 + MediaQuery.paddingOf(context).bottom),
                  child: Column(
                    children: [
                      Semantics(
                        label: '${_currentPage + 1} / $_pageCount',
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            _pageCount,
                            (i) => AnimatedContainer(
                              duration: TMotion.slow,
                              curve: TMotion.spring,
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              width: _currentPage == i ? 28 : 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: _currentPage == i
                                    ? TColors.ember
                                    : TColors.ink.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        height: 150,
                        child: AnimatedSwitcher(
                          duration: TMotion.medium,
                          transitionBuilder: (child, a) => FadeTransition(
                            opacity: a,
                            child: SlideTransition(
                              position: Tween(begin: const Offset(0, 0.08), end: Offset.zero).animate(a),
                              child: child,
                            ),
                          ),
                          child: Column(
                            key: ValueKey(_currentPage),
                            children: [
                              Text(titles[_currentPage],
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      fontSize: 25, height: 1.35, fontWeight: FontWeight.w700, color: TColors.ink)),
                              const SizedBox(height: 10),
                              Text(bodies[_currentPage],
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 16, height: 1.6, color: Color(0xFF4F5254))),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      GradientButton(
                        label: _isLastPage ? l10n.getStarted : l10n.next,
                        onPressed: _isLastPage ? _complete : _next,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Slide 1 — the logo in a glass orb with pulsing rings and orbiting dots.
class _LogoOrb extends StatefulWidget {
  const _LogoOrb();

  @override
  State<_LogoOrb> createState() => _LogoOrbState();
}

class _LogoOrbState extends State<_LogoOrb> with SingleTickerProviderStateMixin {
  late final AnimationController _spin =
      AnimationController(vsync: this, duration: const Duration(seconds: 16));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (TMotion.reduced(context)) {
      _spin.stop();
    } else if (!_spin.isAnimating) {
      _spin.repeat();
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 300,
        height: 300,
        child: Stack(
          alignment: Alignment.center,
          children: [
            const PulseRings(size: 230),
            AnimatedBuilder(
              animation: _spin,
              builder: (context, _) => Transform.rotate(
                angle: _spin.value * 2 * math.pi,
                child: const SizedBox(
                  width: 290,
                  height: 290,
                  child: Stack(
                    children: [
                      Align(alignment: Alignment.topCenter, child: _Dot(22, glass: true)),
                      Align(alignment: Alignment(-0.8, 0.75), child: _Dot(14)),
                      Align(alignment: Alignment(0.95, -0.35), child: _Dot(10, color: TColors.ember)),
                    ],
                  ),
                ),
              ),
            ),
            Glass(
              borderRadius: BorderRadius.circular(115),
              child: SizedBox(
                width: 230,
                height: 230,
                child: Center(
                  child: Image.asset('assets/logoT.png', width: 190, fit: BoxFit.contain),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot(this.size, {this.color = Colors.white, this.glass = false});
  final double size;
  final Color color;
  final bool glass;

  @override
  Widget build(BuildContext context) {
    final dot = Container(width: size, height: size, decoration: BoxDecoration(color: color, shape: BoxShape.circle));
    return glass
        ? Glass(borderRadius: BorderRadius.circular(size / 2), child: SizedBox(width: size, height: size))
        : dot;
  }
}

/// Slide 2 — a glass camera viewfinder with a scanning line, and the
/// recognised word typing out below it.
class _SignScanner extends StatefulWidget {
  const _SignScanner();

  @override
  State<_SignScanner> createState() => _SignScannerState();
}

class _SignScannerState extends State<_SignScanner> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2600));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (TMotion.reduced(context)) {
      _c.value = 1;
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
    final word = context.l10n.sampleHello;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Glass(
            borderRadius: BorderRadius.circular(36),
            child: SizedBox(
              width: 230,
              height: 210,
              child: AnimatedBuilder(
                animation: _c,
                builder: (context, _) {
                  final scan = Curves.easeInOut.transform(_c.value < 0.5 ? _c.value * 2 : 2 - _c.value * 2);
                  return Stack(
                    children: [
                      const _Corners(),
                      const Center(child: Icon(Icons.person_outline_rounded, size: 110, color: Colors.white)),
                      Positioned(
                        top: 26 + 150 * scan,
                        left: 26,
                        right: 26,
                        child: Container(
                          height: 3,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(2),
                            gradient: LinearGradient(colors: [
                              TColors.ember.withValues(alpha: 0),
                              TColors.ember,
                              TColors.ember.withValues(alpha: 0),
                            ]),
                            boxShadow: [BoxShadow(color: TColors.ember.withValues(alpha: 0.8), blurRadius: 14)],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 22),
          Glass(
            borderRadius: BorderRadius.circular(29),
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: TColors.success,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: TColors.success.withValues(alpha: 0.25), spreadRadius: 4)],
                  ),
                ),
                const SizedBox(width: 10),
                AnimatedBuilder(
                  animation: _c,
                  builder: (context, _) {
                    final shown = (word.length * (_c.value / 0.6)).clamp(0, word.length).floor();
                    return Text(
                      word.substring(0, shown),
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: TColors.ink),
                    );
                  },
                ),
                const SizedBox(width: 2),
                Container(width: 2, height: 24, color: TColors.ink),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Corners extends StatelessWidget {
  const _Corners();

  @override
  Widget build(BuildContext context) {
    const side = BorderSide(color: Colors.white, width: 3);
    Widget corner(Alignment a, Border b, BorderRadius r) => Align(
          alignment: a,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Container(width: 30, height: 30, decoration: BoxDecoration(border: b, borderRadius: r)),
          ),
        );
    return Stack(children: [
      corner(Alignment.topLeft, const Border(top: side, left: side),
          const BorderRadius.only(topLeft: Radius.circular(12))),
      corner(Alignment.topRight, const Border(top: side, right: side),
          const BorderRadius.only(topRight: Radius.circular(12))),
      corner(Alignment.bottomLeft, const Border(bottom: side, left: side),
          const BorderRadius.only(bottomLeft: Radius.circular(12))),
      corner(Alignment.bottomRight, const Border(bottom: side, right: side),
          const BorderRadius.only(bottomRight: Radius.circular(12))),
    ]);
  }
}

/// Slide 3 — meeting captions appearing one after another, then the
/// features that are on (captions, avatar, transcripts).
class _MeetingBubbles extends StatelessWidget {
  const _MeetingBubbles();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    Widget bubble(String who, String text, {required bool start, required int i, Color whoColor = TColors.accent}) {
      final r = const Radius.circular(22);
      final tail = const Radius.circular(6);
      return Align(
        alignment: start ? AlignmentDirectional.centerStart : AlignmentDirectional.centerEnd,
        child: RiseIn(
          delay: Duration(milliseconds: 350 * i),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 270),
            child: Glass(
              borderRadius: BorderRadiusDirectional.only(
                topStart: r, topEnd: r,
                bottomStart: start ? tail : r,
                bottomEnd: start ? r : tail,
              ).resolve(Directionality.of(context)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(who, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: whoColor)),
                  Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: TColors.ink)),
                ],
              ),
            ),
          ),
        ),
      );
    }

    Widget chip(String label) => Glass(
          borderRadius: BorderRadius.circular(20),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 8, height: 8, decoration: const BoxDecoration(color: TColors.success, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: TColors.ink)),
          ]),
        );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          bubble(l10n.speakerOne, l10n.sampleCaption1, start: true, i: 0),
          const SizedBox(height: 12),
          bubble(l10n.speakerTwoSign, l10n.sampleCaption2, start: false, i: 1, whoColor: const Color(0xFF1F6F55)),
          const SizedBox(height: 12),
          bubble(l10n.speakerOne, l10n.sampleCaption3, start: true, i: 2),
          const SizedBox(height: 16),
          RiseIn(
            delay: const Duration(milliseconds: 1050),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                chip(l10n.featureSpeechToText),
                chip(l10n.featureAvatar),
                chip(l10n.transcripts),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
