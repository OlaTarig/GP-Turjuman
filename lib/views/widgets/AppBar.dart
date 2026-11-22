import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../theme/turjuman_theme.dart';
import 'glass.dart';

/// Floating liquid-glass bottom navigation.
///
/// A peach "droplet" slides under the selected tab with a slight spring.
/// Use with `Scaffold(extendBody: true)` so page content scrolls behind it.
class BottomBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const BottomBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  static const double height = 74;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final items = [
      (Icons.home_outlined, Icons.home_rounded, l10n.homeTab),
      (Icons.folder_outlined, Icons.folder_rounded, l10n.filesTab),
      (Icons.settings_outlined, Icons.settings_rounded, l10n.settingsTab),
    ];
    final reduced = TMotion.reduced(context);

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Semantics(
          container: true,
          label: l10n.mainNavigation,
          child: Glass(
            borderRadius: BorderRadius.circular(height / 2),
            padding: const EdgeInsets.all(7),
            child: SizedBox(
              height: height - 14,
              child: Stack(
                children: [
                  AnimatedAlign(
                    alignment: AlignmentDirectional(
                      -1.0 + currentIndex * (2.0 / (items.length - 1)),
                      0,
                    ),
                    duration: reduced ? Duration.zero : TMotion.slow,
                    curve: TMotion.spring,
                    child: FractionallySizedBox(
                      widthFactor: 1 / items.length,
                      heightFactor: 1,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: TGradients.drop,
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFF8C50).withValues(alpha: 0.22),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      for (var i = 0; i < items.length; i++)
                        Expanded(
                          child: _NavItem(
                            icon: items[i].$1,
                            activeIcon: items[i].$2,
                            label: items[i].$3,
                            selected: currentIndex == i,
                            onTap: () => onTap(i),
                          ),
                        ),
                    ],
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

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? TColors.accentDeep : TColors.inkSoft;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        radius: 36,
        highlightShape: BoxShape.rectangle,
        borderRadius: BorderRadius.circular(30),
        child: AnimatedScale(
          scale: selected ? 1.04 : 1,
          duration: TMotion.medium,
          curve: TMotion.spring,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(selected ? activeIcon : icon, color: color, size: 24),
              const SizedBox(height: 3),
              AnimatedDefaultTextStyle(
                duration: TMotion.medium,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
                child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
