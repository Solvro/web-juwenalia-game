import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';
import '../theme/elements.dart';

/// Bottom navigation bar with a centered floating QR scan button, used on
/// non-iOS platforms. iOS goes through a native UIKit view so it can use
/// the real iOS 26 liquid-glass material.
class GlassBottomNav extends StatelessWidget {
  const GlassBottomNav({
    super.key,
    required this.selectedIndex,
    required this.onSelect,
    required this.onScanQr,
    this.qrEnabled = true,
    required this.destinations,
  });

  /// Index into [destinations].
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onScanQr;
  final bool qrEnabled;
  final List<NavDestination> destinations;

  @override
  Widget build(BuildContext context) {
    assert(
      destinations.length == 4,
      'GlassBottomNav expects exactly 4 destinations (split 2/2 around the QR button)',
    );

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = AppTheme.surfaceContainerOf(context);

    return SafeArea(
      top: false,
      child: Padding(
        // Floats above the screen edge — gives the QR FAB room to overhang.
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: surface.withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: (isDark ? Colors.white : Colors.black).withValues(
                alpha: 0.06,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.26 : 0.10),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: SizedBox(
            height: 64,
            child: Row(
              children: [
                _NavItem(
                  destination: destinations[0],
                  selected: selectedIndex == 0,
                  onTap: () => onSelect(0),
                  outerEdge: _OuterEdge.left,
                ),
                _NavItem(
                  destination: destinations[1],
                  selected: selectedIndex == 1,
                  onTap: () => onSelect(1),
                ),
                _ScanButton(onTap: onScanQr, enabled: qrEnabled),
                _NavItem(
                  destination: destinations[2],
                  selected: selectedIndex == 2,
                  onTap: () => onSelect(2),
                ),
                _NavItem(
                  destination: destinations[3],
                  selected: selectedIndex == 3,
                  onTap: () => onSelect(3),
                  outerEdge: _OuterEdge.right,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class NavDestination {
  const NavDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.element,
  });
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final AppElement element;
}

/// Which end of the bar a nav item sits at. Outer-edge items round their
/// outer corners more so the selected-pill highlight tracks the parent
/// bar's 30px curve instead of standing off it.
enum _OuterEdge { none, left, right }

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.destination,
    required this.selected,
    required this.onTap,
    this.outerEdge = _OuterEdge.none,
  });

  final NavDestination destination;
  final bool selected;
  final VoidCallback onTap;
  final _OuterEdge outerEdge;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final activeColor = AppElements.of(destination.element).base;
    final color = selected ? activeColor : cs.onSurfaceVariant;
    final highlight = activeColor.withValues(
      alpha: Theme.of(context).brightness == Brightness.dark ? 0.18 : 0.12,
    );

    // Parent bar has radius 30 and the pill is inset by ~4px horizontally
    // / 6px vertically — 24 lines up the outer arc smoothly. Inner corners
    // stay at 18 so adjacent pills don't visually compete.
    const innerRadius = Radius.circular(18);
    const outerRadius = Radius.circular(24);
    final pillRadius = switch (outerEdge) {
      _OuterEdge.left => const BorderRadius.only(
        topLeft: outerRadius,
        bottomLeft: outerRadius,
        topRight: innerRadius,
        bottomRight: innerRadius,
      ),
      _OuterEdge.right => const BorderRadius.only(
        topLeft: innerRadius,
        bottomLeft: innerRadius,
        topRight: outerRadius,
        bottomRight: outerRadius,
      ),
      _OuterEdge.none => const BorderRadius.all(innerRadius),
    };

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: InkResponse(
          onTap: onTap,
          radius: 28,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: selected ? highlight : Colors.transparent,
              borderRadius: pillRadius,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  selected ? destination.selectedIcon : destination.icon,
                  size: 22,
                  color: color,
                ),
                const SizedBox(height: 2),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      destination.label,
                      maxLines: 1,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 10,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: color,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ScanButton extends StatelessWidget {
  const _ScanButton({required this.onTap, required this.enabled});

  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: enabled
                  ? AppTheme.brandGradient
                  : LinearGradient(
                      colors: [
                        AppTheme.brandTeal.withValues(alpha: 0.45),
                        AppTheme.brandBlue.withValues(alpha: 0.35),
                      ],
                    ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.brandTeal.withValues(
                    alpha: enabled ? 0.45 : 0.2,
                  ),
                  blurRadius: enabled ? 16 : 10,
                  offset: const Offset(0, 6),
                ),
              ],
              border: Border.all(
                color: Colors.white.withValues(alpha: enabled ? 0.18 : 0.12),
                width: 1,
              ),
            ),
            child: Icon(
              Icons.qr_code_scanner_rounded,
              color: Colors.white.withValues(alpha: enabled ? 1 : 0.78),
              size: 26,
            ),
          ),
        ),
      ),
    );
  }
}
