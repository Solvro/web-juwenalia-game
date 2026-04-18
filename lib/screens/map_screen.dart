import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/models.dart';
import '../services/data_service.dart';
import '../theme/app_theme.dart';
import '../widgets/brand_gradient.dart';

/// Map & Partners tab — real Google Maps view of the Juwenalia campus,
/// with a graceful gradient hero fallback on platforms where the maps
/// plugin isn't supported (web, macOS, Linux, Windows).
class MapScreen extends StatefulWidget {
  const MapScreen({super.key, required this.data});

  final AppData data;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  static const _campus = LatLng(51.10795, 17.05887);

  final Completer<GoogleMapController> _controller = Completer();
  String? _selectedId;

  // Light, branded map style — hides POI clutter, tints water/landscape.
  static const _mapStyle = '''
  [
    {"featureType":"poi","stylers":[{"visibility":"off"}]},
    {"featureType":"transit","stylers":[{"visibility":"off"}]},
    {"featureType":"road","elementType":"labels.icon","stylers":[{"visibility":"off"}]},
    {"featureType":"water","stylers":[{"color":"#c8e7e4"}]},
    {"featureType":"landscape","stylers":[{"color":"#f5f7f7"}]}
  ]
  ''';

  /// google_maps_flutter supports Android, iOS, and web.
  /// Desktop platforms (macOS, Windows, Linux) fall back to a gradient hero.
  bool get _supportsNativeMaps {
    if (kIsWeb) return true;
    try {
      return Platform.isAndroid || Platform.isIOS;
    } catch (_) {
      return false;
    }
  }

  Set<Marker> _markers() => widget.data.mapPoints
      .where((p) => p.lat != null && p.lng != null)
      .map(
        (p) => Marker(
          markerId: MarkerId(p.id),
          position: LatLng(p.lat!, p.lng!),
          infoWindow: InfoWindow(title: p.name, snippet: p.description),
          icon: _hueForType(p.type),
          onTap: () => setState(() => _selectedId = p.id),
        ),
      )
      .toSet();

  BitmapDescriptor _hueForType(String type) {
    const hue = <String, double>{
      'stage': BitmapDescriptor.hueCyan,
      'food': BitmapDescriptor.hueOrange,
      'medical': BitmapDescriptor.hueRed,
      'wc': BitmapDescriptor.hueViolet,
      'chill': BitmapDescriptor.hueGreen,
      'vip': BitmapDescriptor.hueMagenta,
      'info': BitmapDescriptor.hueAzure,
    };
    return BitmapDescriptor.defaultMarkerWithHue(
      hue[type] ?? BitmapDescriptor.hueBlue,
    );
  }

  Future<void> _focus(MapPoint p) async {
    if (p.lat == null || p.lng == null) return;
    setState(() => _selectedId = p.id);

    if (_supportsNativeMaps && _controller.isCompleted) {
      final c = await _controller.future;
      await c.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(p.lat!, p.lng!), 18),
      );
    } else {
      // Fallback: open Google Maps in the browser/native maps app.
      final uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=${p.lat},${p.lng}',
      );
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return CustomScrollView(
      slivers: [
        _buildHeader(context, cs),
        SliverToBoxAdapter(
          child: _supportsNativeMaps
              ? _buildMap(context)
              : _buildMapFallback(context, cs),
        ),
        SliverToBoxAdapter(child: _buildLegend(context, cs)),
        if (widget.data.partners.isNotEmpty) ...[
          SliverToBoxAdapter(child: _buildPartnersHeader(cs)),
          SliverToBoxAdapter(child: _buildPartnersList(context, cs)),
        ],
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }

  SliverAppBar _buildHeader(BuildContext context, ColorScheme cs) {
    return SliverAppBar(
      pinned: true,
      expandedHeight: 130,
      backgroundColor: AppTheme.surfaceContainerLowestOf(context),
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.fromLTRB(20, 0, 16, 14),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BrandGradientText(
              'MAPA I PARTNERZY',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 2.4,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Teren festiwalu',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: cs.onSurface,
                letterSpacing: -0.5,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 6),
            const BrandGradientBar(width: 36),
          ],
        ),
      ),
    );
  }

  // ── Native map (Android / iOS) ────────────────────────────────────────────

  Widget _buildMap(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: SizedBox(
          height: 320,
          child: GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: _campus,
              zoom: 16,
            ),
            style: _mapStyle,
            markers: _markers(),
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            compassEnabled: false,
            mapToolbarEnabled: false,
            onMapCreated: _controller.complete,
          ),
        ),
      ).animate().fadeIn(duration: 400.ms),
    );
  }

  // ── Fallback hero (web/macOS/Linux/Windows) ───────────────────────────────

  Widget _buildMapFallback(BuildContext context, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: AspectRatio(
        aspectRatio: 16 / 11,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Brand gradient backdrop — Figma cyan→teal→green vibe.
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: AppTheme.brandRadialGradient,
                ),
              ),
              // Subtle dotted overlay to imply a "map".
              CustomPaint(
                painter: _DotGridPainter(
                  color: Colors.white.withValues(alpha: 0.12),
                ),
              ),
              // Centered call-to-action.
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.map_rounded,
                          size: 32,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Mapa Juwenaliów',
                        style: GoogleFonts.spaceGrotesk(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 20,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Kampus Politechniki Wrocławskiej',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 13,
                          height: 1.4,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: () => launchUrl(
                          Uri.parse(
                            'https://www.google.com/maps/search/?api=1&query=${_campus.latitude},${_campus.longitude}',
                          ),
                          mode: LaunchMode.externalApplication,
                        ),
                        icon: const Icon(Icons.open_in_new_rounded, size: 16),
                        label: const Text('Otwórz w Mapach Google'),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.95),
                          foregroundColor: AppTheme.brandTeal,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 12,
                          ),
                          textStyle: GoogleFonts.spaceGrotesk(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ).animate().fadeIn(duration: 400.ms),
      ),
    );
  }

  // ── Legend ────────────────────────────────────────────────────────────────

  Widget _buildLegend(BuildContext context, ColorScheme cs) {
    if (widget.data.mapPoints.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const BrandGradientBar(width: 18, height: 3),
              const SizedBox(width: 8),
              Text(
                'LEGENDA',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurfaceVariant,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...widget.data.mapPoints.map((p) => _buildLegendItem(context, p, cs)),
        ],
      ),
    );
  }

  Widget _buildLegendItem(
    BuildContext context,
    MapPoint point,
    ColorScheme cs,
  ) {
    final color = point.type.mapPointColor(context);
    final icon = point.type.mapPointIcon;
    final surfHigh = AppTheme.surfaceContainerHighOf(context);
    final selected = _selectedId == point.id;

    return GestureDetector(
      onTap: () => _focus(point),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.12) : surfHigh,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? color : cs.outlineVariant.withValues(alpha: 0.3),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    point.name,
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                    ),
                  ),
                  if (point.description != null) ...[
                    const SizedBox(height: 1),
                    Text(
                      point.description!,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: cs.onSurfaceVariant,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: cs.onSurfaceVariant,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  // ── Partners ──────────────────────────────────────────────────────────────

  Widget _buildPartnersHeader(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 28, 16, 12),
      child: Row(
        children: [
          const BrandGradientBar(width: 18, height: 3),
          const SizedBox(width: 8),
          Text(
            'NASI PARTNERZY',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: cs.onSurfaceVariant,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPartnersList(BuildContext context, ColorScheme cs) {
    final mainPartners = widget.data.partners
        .where((p) => p.tier == 'main')
        .toList();
    final mediaPartners = widget.data.partners
        .where((p) => p.tier == 'media')
        .toList();
    final surfHigh = AppTheme.surfaceContainerHighOf(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (mainPartners.isNotEmpty) ...[
            Text(
              'Sponsorzy Główni',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: mainPartners
                  .map((p) => _buildPartnerChip(p, cs, surfHigh, true))
                  .toList(),
            ),
          ],
          if (mediaPartners.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              'Patroni Medialni',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: mediaPartners
                  .map((p) => _buildPartnerChip(p, cs, surfHigh, false))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPartnerChip(
    Partner p,
    ColorScheme cs,
    Color surfHigh,
    bool isMain,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: surfHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isMain
              ? AppTheme.brandTeal.withValues(alpha: 0.45)
              : cs.outlineVariant.withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: Text(
        p.name,
        style: GoogleFonts.spaceGrotesk(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: cs.onSurface,
        ),
      ),
    );
  }
}

/// Subtle dotted backdrop — cheap "map texture" for the gradient fallback.
class _DotGridPainter extends CustomPainter {
  _DotGridPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    const step = 22.0;
    const radius = 1.2;
    for (var x = step / 2; x < size.width; x += step) {
      for (var y = step / 2; y < size.height; y += step) {
        canvas.drawCircle(Offset(x, y), radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
