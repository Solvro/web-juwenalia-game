import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/models.dart';
import '../services/data_service.dart';
import '../theme/app_theme.dart';
import '../theme/elements.dart';
import '../widgets/app_network_image.dart';
import '../widgets/platform_utils.dart';
import '../widgets/section_header.dart';

enum _EmbeddedMapMode { live, plan }

/// Mapa tab — earth element. Two modes:
/// - **plan**: bundled festival plan PNG, zoomable, pins projected onto it
/// - **live**: OpenStreetMap via flutter_map (no Google Maps dependency)
class MapScreen extends StatefulWidget {
  const MapScreen({super.key, required this.data, this.onRefresh});

  final AppData data;
  final Future<void> Function()? onRefresh;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  static const _campus = LatLng(51.10795, 17.05887);
  static const _planAspectRatio = 16 / 11;
  static const _planAsset = 'assets/maps/festival_plan.png';

  final TransformationController _planController = TransformationController();
  final MapController _liveController = MapController();
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _legendKeys = {};

  String? _selectedId;
  bool _locating = false;
  bool _interactingWithMap = false;
  Size _planViewport = Size.zero;
  late _EmbeddedMapMode _preferredMode;

  bool get _supportsLiveMap =>
      kIsWeb || PlatformUtils.isAndroid || PlatformUtils.isIOS;

  _EmbeddedMapMode get _effectiveMode =>
      _supportsLiveMap ? _preferredMode : _EmbeddedMapMode.plan;

  /// Geographic extents of the bundled festival plan PNG, sourced from
  /// CMS config so editors can replace the plan asset without requiring
  /// an app update. Falls back to hardcoded campus bounds if the CMS
  /// value is missing (older clients / pre-migration cache).
  _GeoBounds get _bounds {
    final pb = widget.data.config.planBounds;
    return _GeoBounds(
      minLat: pb.south,
      maxLat: pb.north,
      minLng: pb.west,
      maxLng: pb.east,
    );
  }

  @override
  void initState() {
    super.initState();
    _preferredMode = _EmbeddedMapMode.plan;
    for (final p in widget.data.mapPoints) {
      _legendKeys[p.id] = GlobalKey();
    }
  }

  @override
  void didUpdateWidget(covariant MapScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    for (final p in widget.data.mapPoints) {
      _legendKeys.putIfAbsent(p.id, () => GlobalKey());
    }
  }

  @override
  void dispose() {
    _planController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _focus(MapPoint p, {bool fromPin = false}) async {
    if (p.lat == null || p.lng == null) {
      setState(() => _selectedId = p.id);
      return;
    }
    setState(() => _selectedId = p.id);

    if (_effectiveMode == _EmbeddedMapMode.live) {
      _liveController.move(LatLng(p.lat!, p.lng!), 18);
    } else {
      _focusPlanPosition(p.lat!, p.lng!, scale: 2.2);
    }

    if (fromPin) {
      await Future<void>.delayed(const Duration(milliseconds: 80));
      final ctx = _legendKeys[p.id]?.currentContext;
      if (ctx != null && ctx.mounted) {
        await Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOutCubic,
          alignment: 0.1,
        );
      }
    }
  }

  Future<void> _handleLocateMe() async {
    if (_locating) return;
    setState(() => _locating = true);

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showMessage('Włącz usługi lokalizacji, aby odnaleźć swoją pozycję.');
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _showMessage('Brak zgody na lokalizację.');
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          timeLimit: Duration(seconds: 8),
        ),
      );

      if (!mounted) return;

      if (_effectiveMode == _EmbeddedMapMode.live) {
        _liveController.move(
          LatLng(position.latitude, position.longitude),
          17.5,
        );
      }
    } catch (_) {
      _showMessage('Nie udało się pobrać Twojej lokalizacji.');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _zoomIn() {
    if (_effectiveMode == _EmbeddedMapMode.live) {
      final z = _liveController.camera.zoom + 1;
      _liveController.move(_liveController.camera.center, z.clamp(3.0, 19.0));
      return;
    }
    _zoomPlan(1.2);
  }

  void _zoomOut() {
    if (_effectiveMode == _EmbeddedMapMode.live) {
      final z = _liveController.camera.zoom - 1;
      _liveController.move(_liveController.camera.center, z.clamp(3.0, 19.0));
      return;
    }
    _zoomPlan(1 / 1.2);
  }

  void _zoomPlan(double factor) {
    if (_planViewport == Size.zero) return;

    final currentScale = _planController.value.getMaxScaleOnAxis();
    final targetScale = (currentScale * factor).clamp(1.0, 4.0);
    final currentCenterScene = _scenePointForViewportCenter();
    final dx = _planViewport.width / 2 - currentCenterScene.dx * targetScale;
    final dy = _planViewport.height / 2 - currentCenterScene.dy * targetScale;

    _planController.value = Matrix4.diagonal3Values(targetScale, targetScale, 1)
      ..setTranslationRaw(dx, dy, 0);
  }

  Offset _scenePointForViewportCenter() {
    final center = Offset(_planViewport.width / 2, _planViewport.height / 2);
    final inverse = Matrix4.inverted(_planController.value);
    return MatrixUtils.transformPoint(inverse, center);
  }

  void _focusPlanPosition(double lat, double lng, {double scale = 2.2}) {
    if (_planViewport == Size.zero) return;
    final target = _projectToPlan(lat, lng, _planViewport);
    final dx = _planViewport.width / 2 - target.dx * scale;
    final dy = _planViewport.height / 2 - target.dy * scale;
    _planController.value = Matrix4.diagonal3Values(scale, scale, 1)
      ..setTranslationRaw(dx, dy, 0);
  }

  void _resetPlanView() {
    _planController.value = Matrix4.identity();
  }

  Offset _projectToPlan(double lat, double lng, Size size) {
    final bounds = _bounds;
    final lngRange = (bounds.maxLng - bounds.minLng).abs();
    final latRange = (bounds.maxLat - bounds.minLat).abs();
    final safeLngRange = lngRange == 0 ? 1 : lngRange;
    final safeLatRange = latRange == 0 ? 1 : latRange;

    const horizontalPadding = 78.0;
    const verticalPadding = 62.0;
    final usableWidth = size.width - horizontalPadding * 2;
    final usableHeight = size.height - verticalPadding * 2;

    final x = ((lng - bounds.minLng) / safeLngRange).clamp(0.0, 1.0);
    final y = ((bounds.maxLat - lat) / safeLatRange).clamp(0.0, 1.0);

    return Offset(
      horizontalPadding + usableWidth * x,
      verticalPadding + usableHeight * y,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final palette = AppElements.earth;

    final scrollView = CustomScrollView(
      controller: _scrollController,
      physics: _interactingWithMap
          ? const NeverScrollableScrollPhysics()
          : const AlwaysScrollableScrollPhysics(),
      slivers: [
        _buildHeader(context, cs, palette),
        SliverToBoxAdapter(child: _buildMapPanel(context, cs, palette)),
        SliverToBoxAdapter(child: _buildLegend(context, cs, palette)),
        if (widget.data.partners.isNotEmpty) ...[
          SliverToBoxAdapter(child: _buildPartnersHeader(cs, palette)),
          SliverToBoxAdapter(child: _buildPartnersList(context, cs)),
        ],
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );

    final onRefresh = widget.onRefresh;
    if (onRefresh == null) return scrollView;

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: palette.base,
      backgroundColor: AppTheme.surfaceContainerHighOf(context),
      child: scrollView,
    );
  }

  Widget _buildHeader(
    BuildContext context,
    ColorScheme cs,
    ElementPalette palette,
  ) {
    return SectionHeader(
      supertitle: 'MAPA',
      title: 'Teren festiwalu',
      palette: palette,
    );
  }

  Widget _buildMapPanel(
    BuildContext context,
    ColorScheme cs,
    ElementPalette palette,
  ) {
    final isPlanMode = _effectiveMode == _EmbeddedMapMode.plan;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: _planAspectRatio,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Listener(
                onPointerDown: (_) {
                  if (!_interactingWithMap) {
                    setState(() => _interactingWithMap = true);
                  }
                },
                onPointerUp: (_) {
                  if (_interactingWithMap) {
                    setState(() => _interactingWithMap = false);
                  }
                },
                onPointerCancel: (_) {
                  if (_interactingWithMap) {
                    setState(() => _interactingWithMap = false);
                  }
                },
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceContainerOf(context),
                      ),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 240),
                        child: isPlanMode
                            ? _buildPlanMap(context)
                            : _buildLiveMap(context),
                      ),
                    ),
                    Positioned(
                      top: 12,
                      left: 12,
                      right: 12,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_supportsLiveMap)
                            _buildModeToggle(context, palette),
                          const Spacer(),
                          _buildMapControls(context),
                        ],
                      ),
                    ),
                    if (_effectiveMode == _EmbeddedMapMode.live)
                      Positioned(
                        bottom: 6,
                        right: 10,
                        child: _buildOsmAttribution(context),
                      ),
                  ],
                ),
              ),
            ).animate().fadeIn(duration: 400.ms),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveMap(BuildContext context) {
    final points = widget.data.mapPoints
        .where((p) => !p.hidden && p.lat != null && p.lng != null)
        .toList();

    return FlutterMap(
      key: const ValueKey('live-map'),
      mapController: _liveController,
      options: MapOptions(
        initialCenter: _campus,
        initialZoom: 16.5,
        minZoom: 12,
        maxZoom: 19,
        onTap: (_, _) => setState(() => _selectedId = null),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'pl.solvro.juwenalia',
          maxZoom: 19,
        ),
        MarkerLayer(
          markers: [
            for (final p in points)
              Marker(
                point: LatLng(p.lat!, p.lng!),
                width: 44,
                height: 44,
                child: _MapPin(
                  point: p,
                  selected: p.id == _selectedId,
                  onTap: () => _focus(p, fromPin: true),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildOsmAttribution(BuildContext context) {
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

  Widget _buildPlanMap(BuildContext context) {
    return LayoutBuilder(
      key: const ValueKey('plan-map'),
      builder: (context, constraints) {
        _planViewport = Size(constraints.maxWidth, constraints.maxHeight);

        return InteractiveViewer(
          transformationController: _planController,
          minScale: 1,
          maxScale: 4,
          boundaryMargin: const EdgeInsets.all(120),
          child: SizedBox(
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            child: Stack(
              children: [
                Positioned.fill(
                  child: Image.asset(_planAsset, fit: BoxFit.cover),
                ),
                Positioned.fill(
                  child: AnimatedBuilder(
                    animation: _planController,
                    builder: (context, _) {
                      final sceneScale = _planController.value
                          .getMaxScaleOnAxis()
                          .clamp(1.0, 4.0)
                          .toDouble();
                      final pinScale = 1 / sceneScale;

                      return Stack(
                        children: [
                          ...widget.data.mapPoints
                              .where(
                                (p) =>
                                    !p.hidden && p.lat != null && p.lng != null,
                              )
                              .map((point) {
                                final offset = _projectToPlan(
                                  point.lat!,
                                  point.lng!,
                                  _planViewport,
                                );
                                final selected = point.id == _selectedId;

                                return Positioned(
                                  left: offset.dx - 22,
                                  top: offset.dy - 22,
                                  width: 44,
                                  height: 44,
                                  child: Transform.scale(
                                    scale: pinScale,
                                    child: Center(
                                      child: _MapPin(
                                        point: point,
                                        selected: selected,
                                        onTap: () =>
                                            _focus(point, fromPin: true),
                                      ),
                                    ),
                                  ),
                                );
                              }),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildModeToggle(BuildContext context, ElementPalette palette) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerHighOf(context).withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Theme.of(
            context,
          ).colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ModeChip(
            label: 'Plan',
            selected: _effectiveMode == _EmbeddedMapMode.plan,
            color: palette.base,
            onTap: () => setState(() => _preferredMode = _EmbeddedMapMode.plan),
          ),
          const SizedBox(width: 4),
          _ModeChip(
            label: 'Na żywo',
            selected: _effectiveMode == _EmbeddedMapMode.live,
            color: palette.base,
            onTap: _supportsLiveMap
                ? () => setState(() => _preferredMode = _EmbeddedMapMode.live)
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildMapControls(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerHighOf(context).withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Theme.of(
            context,
          ).colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _MapControlButton(
            icon: Icons.add_rounded,
            tooltip: 'Przybliż',
            onTap: _zoomIn,
          ),
          const SizedBox(height: 4),
          _MapControlButton(
            icon: Icons.remove_rounded,
            tooltip: 'Oddal',
            onTap: _zoomOut,
          ),
          if (_effectiveMode == _EmbeddedMapMode.live) ...[
            const SizedBox(height: 4),
            _MapControlButton(
              icon: _locating
                  ? Icons.more_horiz_rounded
                  : Icons.my_location_rounded,
              tooltip: 'Moja lokalizacja',
              onTap: _handleLocateMe,
            ),
          ] else ...[
            const SizedBox(height: 4),
            _MapControlButton(
              icon: Icons.center_focus_strong_rounded,
              tooltip: 'Resetuj plan',
              onTap: _resetPlanView,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLegend(
    BuildContext context,
    ColorScheme cs,
    ElementPalette palette,
  ) {
    final visible = widget.data.mapPoints.where((p) => !p.hidden).toList();
    if (visible.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 18,
                height: 3,
                decoration: BoxDecoration(
                  gradient: palette.linearGradient,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
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
          ...visible.map((p) => _buildLegendItem(context, p, cs)),
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
    final key = _legendKeys.putIfAbsent(point.id, () => GlobalKey());

    return GestureDetector(
      key: key,
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

  Widget _buildPartnersHeader(ColorScheme cs, ElementPalette palette) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 28, 16, 12),
      child: Row(
        children: [
          Container(
            width: 18,
            height: 3,
            decoration: BoxDecoration(
              gradient: palette.linearGradient,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
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
    final partners = widget.data.partners;
    if (partners.isEmpty) return const SizedBox.shrink();

    // Group partners by tier, preserving CMS-supplied tier ordering when
    // available. Any partners whose tier value isn't in the CMS list get
    // appended under a synthesised fallback entry so nothing is lost.
    final grouped = <String, List<Partner>>{};
    for (final p in partners) {
      grouped.putIfAbsent(p.tier, () => []).add(p);
    }

    final tiers = <PartnerTier>[];
    final seen = <String>{};
    for (final t in widget.data.partnerTiers) {
      if (grouped.containsKey(t.value)) {
        tiers.add(t);
        seen.add(t.value);
      }
    }
    // Fallback labels for when CMS tier metadata hasn't loaded yet (e.g.
    // first run from the bundled cache). Keeps the Partnerzy rail
    // readable instead of showing raw role values "0"/"1"/"2".
    const fallbackLabels = <String, String>{
      '0': 'Uczelnia',
      '1': 'Samorząd',
      '2': 'Partner Główny',
      '3': 'Patron Medialny',
      '4': 'Sponsor',
    };
    for (final raw in grouped.keys) {
      if (seen.add(raw)) {
        tiers.add(PartnerTier(value: raw, label: fallbackLabels[raw] ?? raw));
      }
    }

    if (tiers.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < tiers.length; i++) ...[
          if (i != 0) const SizedBox(height: 22),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              tiers[i].label,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
          ),
          const SizedBox(height: 10),
          _PartnerCarousel(
            partners: grouped[tiers[i].value]!,
            style: _TierStyle.forRank(i, tiers.length),
            onTap: _openPartner,
          ),
        ],
      ],
    );
  }

  void _openPartner(Partner p) {
    final url = p.url;
    if (url == null || url.isEmpty) return;
    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }
}

/// Per-tier visual weight. Derived from the tier's position in the
/// CMS-supplied ordering so editors can rename/reorder freely.
class _TierStyle {
  const _TierStyle({
    required this.logoHeight,
    required this.textSize,
    required this.highlight,
  });

  final double logoHeight;
  final double textSize;
  final bool highlight;

  /// rank=0 is the most prominent tier.
  factory _TierStyle.forRank(int rank, int total) {
    switch (rank) {
      case 0:
        return const _TierStyle(logoHeight: 48, textSize: 15, highlight: true);
      case 1:
        return const _TierStyle(logoHeight: 42, textSize: 14, highlight: true);
      case 2:
        return const _TierStyle(logoHeight: 36, textSize: 13, highlight: false);
      case 3:
        return const _TierStyle(logoHeight: 32, textSize: 12, highlight: false);
      default:
        return const _TierStyle(logoHeight: 28, textSize: 12, highlight: false);
    }
  }
}

/// Horizontal carousel of partner cards. Auto-scrolls forever (marquee
/// style) and pauses while the user drags.
///
/// We fake infinity with a huge [itemCount] and start scrolled to the
/// middle so both directions have effectively unlimited headroom. The
/// earlier implementation duplicated the list and jumped back at the
/// halfway mark — that wrap was visible when the user dragged across
/// the boundary. Modulo-indexing with a fixed [itemExtent] avoids the
/// jump entirely and keeps build-time constant no matter the count.
class _PartnerCarousel extends StatefulWidget {
  const _PartnerCarousel({
    required this.partners,
    required this.style,
    required this.onTap,
  });

  final List<Partner> partners;
  final _TierStyle style;
  final void Function(Partner) onTap;

  @override
  State<_PartnerCarousel> createState() => _PartnerCarouselState();
}

class _PartnerCarouselState extends State<_PartnerCarousel>
    with SingleTickerProviderStateMixin {
  static const _pxPerSecond = 22.0;
  static const _cardWidth = 168.0;
  static const _cardGap = 10.0;
  static const _itemExtent = _cardWidth + _cardGap;
  static const _resumeDelay = Duration(seconds: 2);

  /// Huge virtual item count — ListView.builder with a fixed itemExtent
  /// is O(viewport), so cost is independent of this number. 2 ** 20
  /// items ≈ 186 million pixels at 178 px each, plenty of runway in
  /// both directions before we'd ever hit an edge.
  static const _virtualCount = 1 << 20;
  static const _initialIndex = _virtualCount ~/ 2;

  final ScrollController _controller = ScrollController(
    initialScrollOffset: _initialIndex * _itemExtent,
  );
  Ticker? _ticker;
  Duration _lastTick = Duration.zero;
  bool _userInteracting = false;
  Timer? _resumeTimer;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _resumeTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    if (_userInteracting || !_controller.hasClients) {
      _lastTick = elapsed;
      return;
    }
    final dt = (elapsed - _lastTick).inMicroseconds / 1e6;
    _lastTick = elapsed;
    if (dt <= 0) return;
    // Plain additive scroll — no wrap, no jump. The virtual count is
    // large enough that even at max auto-scroll speed we'd run for
    // years before reaching the end, and a user who manages to drag
    // past it just hits the BouncingScrollPhysics edge.
    final next = _controller.offset + _pxPerSecond * dt;
    final max = _controller.position.maxScrollExtent;
    _controller.jumpTo(next.clamp(0, max));
  }

  void _handlePointerDown(_) {
    _resumeTimer?.cancel();
    setState(() => _userInteracting = true);
  }

  void _handlePointerUp(_) {
    _resumeTimer?.cancel();
    _resumeTimer = Timer(_resumeDelay, () {
      if (mounted) setState(() => _userInteracting = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final partners = widget.partners;
    if (partners.isEmpty) return const SizedBox.shrink();

    // Logo + 8 px gap + two lines of name text + vertical padding.
    // Text line-height ≈ textSize * 1.35, and we allow 2 lines.
    final nameBlock = widget.style.textSize * 1.35 * 2;
    final railHeight = widget.style.logoHeight + 8 + nameBlock + 34;

    return SizedBox(
      height: railHeight,
      child: Listener(
        onPointerDown: _handlePointerDown,
        onPointerUp: _handlePointerUp,
        onPointerCancel: _handlePointerUp,
        child: ListView.builder(
          controller: _controller,
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemExtent: _itemExtent,
          itemCount: _virtualCount,
          itemBuilder: (context, i) {
            final p = partners[i % partners.length];
            return Padding(
              padding: const EdgeInsets.only(right: _cardGap),
              child: _PartnerCard(
                partner: p,
                style: widget.style,
                cs: cs,
                onTap: () => widget.onTap(p),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PartnerCard extends StatelessWidget {
  const _PartnerCard({
    required this.partner,
    required this.style,
    required this.cs,
    required this.onTap,
  });

  final Partner partner;
  final _TierStyle style;
  final ColorScheme cs;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final surfHigh = AppTheme.surfaceContainerHighOf(context);
    final hasLogo = partner.logoUrl != null && partner.logoUrl!.isNotEmpty;
    // Scale is clamped to 1.0 in the carousel so every card in a tier
    // row has the same vertical budget — lets editors shrink oversized
    // logos without breaking the rail height.
    final logoHeight = (style.logoHeight * (partner.logoScale ?? 1.0))
        .clamp(18.0, style.logoHeight)
        .toDouble();
    final borderColor = style.highlight
        ? AppElements.earth.base.withValues(alpha: 0.45)
        : cs.outlineVariant.withValues(alpha: 0.4);

    return SizedBox(
      width: 168,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: partner.url == null || partner.url!.isEmpty ? null : onTap,
          child: Container(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
            decoration: BoxDecoration(
              color: surfHigh,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: borderColor,
                width: style.highlight ? 1.2 : 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (hasLogo) ...[
                  Center(
                    child: SizedBox(
                      height: logoHeight,
                      child: _PartnerLogo(
                        url: partner.logoUrl!,
                        height: logoHeight,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                Flexible(
                  child: Text(
                    partner.name,
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: style.textSize,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                      height: 1.25,
                    ),
                    textAlign: hasLogo ? TextAlign.center : TextAlign.start,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
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

class _PartnerLogo extends StatelessWidget {
  const _PartnerLogo({required this.url, required this.height});

  final String url;
  final double height;

  @override
  Widget build(BuildContext context) {
    return AppNetworkImage(
      url: url,
      height: height,
      fit: BoxFit.contain,
      placeholder: SizedBox(width: height, height: height),
      errorWidget: SizedBox(width: height, height: height),
    );
  }
}

class _GeoBounds {
  const _GeoBounds({
    required this.minLat,
    required this.maxLat,
    required this.minLng,
    required this.maxLng,
  });

  final double minLat;
  final double maxLat;
  final double minLng;
  final double maxLng;
}

class _MapPin extends StatelessWidget {
  const _MapPin({
    required this.point,
    required this.selected,
    required this.onTap,
  });

  final MapPoint point;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = point.type.mapPointColor(context);
    final icon = point.type.mapPointIcon;

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

class _ModeChip extends StatelessWidget {
  const _ModeChip({
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
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.18) : Colors.transparent,
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
    );
  }
}

class _MapControlButton extends StatelessWidget {
  const _MapControlButton({
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
