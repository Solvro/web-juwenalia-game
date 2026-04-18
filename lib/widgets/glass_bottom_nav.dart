import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';
import 'platform_utils.dart';

/// A bottom navigation bar with a centered floating QR scan button.
///
/// On iOS / macOS we render a translucent "liquid-glass" surface with a
/// strong backdrop blur (matching iOS 26's UIKit material). On other
/// platforms we fall back to a near-opaque Material surface so that
/// readability stays consistent.
class GlassBottomNav extends StatelessWidget {
  const GlassBottomNav({
    super.key,
    required this.selectedIndex,
    required this.onSelect,
    required this.onScanQr,
    required this.destinations,
  });

  /// Index into [destinations].
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onScanQr;
  final List<NavDestination> destinations;

  @override
  Widget build(BuildContext context) {
    assert(
      destinations.length == 4,
      'GlassBottomNav expects exactly 4 destinations (split 2/2 around the QR button)',
    );

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final useGlass = PlatformUtils.isApple;

    final surface = AppTheme.surfaceContainerOf(context);
    final glassTint = surface.withValues(alpha: useGlass ? 0.55 : 0.96);

    return SafeArea(
      top: false,
      child: Padding(
        // Floats above the screen edge — gives the QR FAB room to overhang.
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: useGlass
                ? ImageFilter.blur(sigmaX: 28, sigmaY: 28)
                : ImageFilter.blur(sigmaX: 0, sigmaY: 0),
            child: Container(
              height: 64,
              decoration: BoxDecoration(
                color: glassTint,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.black.withValues(alpha: 0.06),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.10),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  _NavItem(
                    destination: destinations[0],
                    selected: selectedIndex == 0,
                    onTap: () => onSelect(0),
                  ),
                  _NavItem(
                    destination: destinations[1],
                    selected: selectedIndex == 1,
                    onTap: () => onSelect(1),
                  ),
                  _ScanButton(onTap: onScanQr),
                  _NavItem(
                    destination: destinations[2],
                    selected: selectedIndex == 2,
                    onTap: () => onSelect(2),
                  ),
                  _NavItem(
                    destination: destinations[3],
                    selected: selectedIndex == 3,
                    onTap: () => onSelect(3),
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

class NavDestination {
  const NavDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });
  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final NavDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeColor = isDark ? cs.primary : cs.primaryContainer;
    final color = selected ? activeColor : cs.onSurfaceVariant;

    return Expanded(
      child: InkResponse(
        onTap: onTap,
        radius: 28,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              selected ? destination.selectedIcon : destination.icon,
              size: 22,
              color: color,
            ),
            const SizedBox(height: 2),
            Text(
              destination.label,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 10,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScanButton extends StatelessWidget {
  const _ScanButton({required this.onTap});

  final VoidCallback onTap;

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
              gradient: AppTheme.brandGradient,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.brandTeal.withValues(alpha: 0.45),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.18),
                width: 1,
              ),
            ),
            child: const Icon(
              Icons.qr_code_scanner_rounded,
              color: Colors.white,
              size: 26,
            ),
          ),
        ),
      ),
    );
  }
}
