import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/models.dart';
import '../theme/app_theme.dart';
import '../theme/icon_names.dart';

enum EmbeddedMapMode { live, plan }

class MapPinMarker extends StatelessWidget {
  const MapPinMarker({
    super.key,
    required this.point,
    required this.selected,
    required this.onTap,
  });

  final MapPoint point;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color =
        parseHexColor(point.color) ?? point.type.mapPointColor(context);
    final icon = point.icon != null
        ? iconFromName(point.icon!)
        : point.type.mapPointIcon;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutBack,
        width: selected ? 44 : 34,
        height: selected ? 44 : 34,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.95),
            width: selected ? 3 : 2,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: selected ? 0.5 : 0.35),
              blurRadius: selected ? 18 : 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Icon(icon, size: selected ? 22 : 16, color: Colors.white),
      ),
    );
  }
}

class ModeChip extends StatelessWidget {
  const ModeChip({
    super.key,
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Stack(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: selected
                ? color.withValues(alpha: 0.18)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            label,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 12,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? color : cs.onSurfaceVariant,
            ),
          ),
        ),
        Positioned.fill(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(14),
              splashColor: color.withValues(alpha: 0.22),
              highlightColor: color.withValues(alpha: 0.08),
            ),
          ),
        ),
      ],
    );
  }
}

class MapControlButton extends StatelessWidget {
  const MapControlButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: cs.surface.withValues(alpha: 0.24),
            ),
            child: Icon(icon, size: 20, color: cs.onSurface),
          ),
        ),
      ),
    );
  }
}

class CompassButton extends StatelessWidget {
  const CompassButton({
    super.key,
    required this.rotationDeg,
    required this.onTap,
  });

  final double rotationDeg;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Tooltip(
      message: 'Skieruj na północ',
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppTheme.surfaceContainerHighOf(
            context,
          ).withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: SizedBox(
              width: 42,
              height: 42,
              child: Center(
                child: Transform.rotate(
                  angle: rotationDeg * math.pi / 180.0,
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CustomPaint(
                      painter: CompassNeedlePainter(
                        northColor: const Color(0xFFE53935),
                        southColor: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CompassNeedlePainter extends CustomPainter {
  CompassNeedlePainter({required this.northColor, required this.southColor});

  final Color northColor;
  final Color southColor;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final halfBase = size.width * 0.22;
    final tip = size.height * 0.5;

    final north = ui.Path()
      ..moveTo(cx, cy - tip)
      ..lineTo(cx - halfBase, cy)
      ..lineTo(cx + halfBase, cy)
      ..close();
    canvas.drawPath(north, Paint()..color = northColor);

    final south = ui.Path()
      ..moveTo(cx, cy + tip)
      ..lineTo(cx - halfBase, cy)
      ..lineTo(cx + halfBase, cy)
      ..close();
    canvas.drawPath(south, Paint()..color = southColor);
  }

  @override
  bool shouldRepaint(covariant CompassNeedlePainter old) =>
      old.northColor != northColor || old.southColor != southColor;
}

class MyLocationDot extends StatelessWidget {
  const MyLocationDot({super.key});

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF2D7DFF);
    return Container(
      decoration: BoxDecoration(
        color: accent,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.45),
            blurRadius: 14,
            spreadRadius: 2,
            offset: const Offset(0, 2),
          ),
        ],
      ),
    );
  }
}

class OsmAttribution extends StatelessWidget {
  const OsmAttribution({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.42),
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () => launchUrl(
          Uri.parse('https://www.openstreetmap.org/copyright'),
          mode: LaunchMode.externalApplication,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          child: Text(
            '© OpenStreetMap',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 9,
              color: Colors.white.withValues(alpha: 0.92),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
