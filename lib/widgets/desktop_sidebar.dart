import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/models.dart';
import '../theme/app_theme.dart';
import '../theme/elements.dart';
import 'brand_gradient.dart';
import 'download_app_panel.dart';
import 'glass_bottom_nav.dart' show NavDestination;

class DesktopSidebar extends StatelessWidget {
  const DesktopSidebar({
    super.key,
    required this.selectedIndex,
    required this.onSelect,
    required this.onScanQr,
    this.qrEnabled = true,
    required this.destinations,
    this.config,
    this.width = 280,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onScanQr;
  final bool qrEnabled;
  final List<NavDestination> destinations;

  final AppConfig? config;

  final double width;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      width: width,
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLowestOf(context),
        border: Border(
          right: BorderSide(
            color: cs.outlineVariant.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final topItems = <Widget>[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    BrandGradientText(
                      'JUWENALIA #WrocławRazem',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Juwenalia 2026',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: cs.onSurface,
                        letterSpacing: -0.5,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const BrandGradientBar(width: 36),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              _ScanCallToAction(onTap: onScanQr, enabled: qrEnabled),
              const SizedBox(height: 16),
              for (var i = 0; i < destinations.length; i++)
                _SidebarItem(
                  destination: destinations[i],
                  selected: selectedIndex == i,
                  onTap: () => onSelect(i),
                ),
            ];

            // Below this height the column overflows, so switch to
            // a scrollable layout instead of bottom-anchoring with
            // Spacer.
            const naturalContentHeight = 720.0;
            final fitsWithSlack = constraints.maxHeight >= naturalContentHeight;

            if (fitsWithSlack) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ...topItems,
                    const Spacer(),
                    const SizedBox(height: 16),
                    DownloadAppPanel(config: config),
                  ],
                ),
              );
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ...topItems,
                  const SizedBox(height: 24),
                  DownloadAppPanel(config: config),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
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
    final activeColor = AppElements.of(destination.element).base;
    final color = selected ? activeColor : cs.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: selected
            ? activeColor.withValues(alpha: isDark ? 0.18 : 0.14)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(
                  selected ? destination.selectedIcon : destination.icon,
                  size: 22,
                  color: color,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    destination.label,
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 14,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: color,
                    ),
                  ),
                ),
                if (selected)
                  Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: activeColor,
                      shape: BoxShape.circle,
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

class _ScanCallToAction extends StatelessWidget {
  const _ScanCallToAction({required this.onTap, required this.enabled});

  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            gradient: enabled
                ? AppTheme.brandGradient
                : LinearGradient(
                    colors: [
                      AppTheme.brandTeal.withValues(alpha: 0.5),
                      AppTheme.brandBlue.withValues(alpha: 0.4),
                    ],
                  ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: AppTheme.brandTeal.withValues(
                  alpha: enabled ? 0.35 : 0.18,
                ),
                blurRadius: enabled ? 14 : 9,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(
                Icons.qr_code_scanner_rounded,
                color: Colors.white.withValues(alpha: enabled ? 1 : 0.78),
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Skanuj QR',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withValues(alpha: enabled ? 1 : 0.82),
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.white.withValues(alpha: enabled ? 1 : 0.8),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
