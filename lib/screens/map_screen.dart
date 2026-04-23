import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/models.dart';
import '../services/data_service.dart';
import '../theme/app_theme.dart';
import '../widgets/brand_gradient.dart';
import '../widgets/platform_utils.dart';

enum _EmbeddedMapMode { live, plan }

/// Map & Partners tab — uses a hybrid approach:
/// - bundled zoomable festival plan as the dependable default on iOS/offline
/// - native Google Map where live tiles are useful and available
class MapScreen extends StatefulWidget {
  const MapScreen({super.key, required this.data});

  final AppData data;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  static const _campus = LatLng(51.10795, 17.05887);
  static const _planAspectRatio = 16 / 11;
  static const _planAsset = 'assets/maps/festival_plan.png';

  static const _mapStyle = '''
  [
    {"featureType":"poi","stylers":[{"visibility":"off"}]},
    {"featureType":"transit","stylers":[{"visibility":"off"}]},
    {"featureType":"road","elementType":"labels.icon","stylers":[{"visibility":"off"}]},
    {"featureType":"water","stylers":[{"color":"#c8e7e4"}]},
    {"featureType":"landscape","stylers":[{"color":"#f5f7f7"}]}
  ]
  ''';

  final TransformationController _planController = TransformationController();

  GoogleMapController? _mapController;
  String? _selectedId;
  bool _locating = false;
  Size _planViewport = Size.zero;
  late _EmbeddedMapMode _preferredMode;

  bool get _supportsNativeMaps =>
      kIsWeb || PlatformUtils.isAndroid || PlatformUtils.isIOS;

  bool get _canUseLiveMap => _supportsNativeMaps && !widget.data.isFromCache;

  _EmbeddedMapMode get _effectiveMode =>
      _canUseLiveMap ? _preferredMode : _EmbeddedMapMode.plan;

  MapPoint? get _selectedPoint {
    final id = _selectedId;
    if (id == null) return null;
    for (final point in widget.data.mapPoints) {
      if (point.id == id) return point;
    }
    return null;
  }

  _GeoBounds get _bounds {
    final withCoords = widget.data.mapPoints
        .where((p) => p.lat != null && p.lng != null)
        .toList();
    if (withCoords.isEmpty) {
      return const _GeoBounds(
        minLat: 51.1062,
        maxLat: 51.1098,
        minLng: 17.0562,
        maxLng: 17.0624,
      );
    }

    var minLat = withCoords.first.lat!;
    var maxLat = withCoords.first.lat!;
    var minLng = withCoords.first.lng!;
    var maxLng = withCoords.first.lng!;

    for (final point in withCoords.skip(1)) {
      minLat = point.lat! < minLat ? point.lat! : minLat;
      maxLat = point.lat! > maxLat ? point.lat! : maxLat;
      minLng = point.lng! < minLng ? point.lng! : minLng;
      maxLng = point.lng! > maxLng ? point.lng! : maxLng;
    }

    const latPadding = 0.0008;
    const lngPadding = 0.0009;
    return _GeoBounds(
      minLat: minLat - latPadding,
      maxLat: maxLat + latPadding,
      minLng: minLng - lngPadding,
      maxLng: maxLng + lngPadding,
    );
  }

  @override
  void initState() {
    super.initState();
    _preferredMode = _EmbeddedMapMode.plan;
  }

  @override
  void dispose() {
    _mapController?.dispose();
    _planController.dispose();
    super.dispose();
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

    if (_effectiveMode == _EmbeddedMapMode.live && _mapController != null) {
      await _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(p.lat!, p.lng!), 18),
      );
      return;
    }

    _focusPlanPosition(p.lat!, p.lng!, scale: 2.2);
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

      final userLocation = LatLng(position.latitude, position.longitude);

      if (_effectiveMode == _EmbeddedMapMode.live && _mapController != null) {
        await _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(userLocation, 17.5),
        );
      }
    } catch (_) {
      _showMessage('Nie udało się pobrać Twojej lokalizacji.');
    } finally {
      if (mounted) {
        setState(() => _locating = false);
      }
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
      _mapController?.animateCamera(CameraUpdate.zoomIn());
      return;
    }
    _zoomPlan(1.2);
  }

  void _zoomOut() {
    if (_effectiveMode == _EmbeddedMapMode.live) {
      _mapController?.animateCamera(CameraUpdate.zoomOut());
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

    return CustomScrollView(
      slivers: [
        _buildHeader(context, cs),
        SliverToBoxAdapter(child: _buildMapPanel(context, cs)),
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

  Widget _buildMapPanel(BuildContext context, ColorScheme cs) {
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
                        if (_canUseLiveMap) _buildModeToggle(context),
                        const Spacer(),
                        _buildMapControls(context),
                      ],
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 400.ms),
          ),
          const SizedBox(height: 12),
          Text(
            isPlanMode
                ? _canUseLiveMap
                      ? 'Plan festiwalu otwiera się jako widok domyślny. Jeśli masz internet, możesz przełączyć się na mapę na żywo.'
                      : 'Plan festiwalu działa offline i zawsze będzie dostępny nawet bez internetu.'
                : 'Mapa na żywo pokazuje punkty na kampusie. Gdyby Google Maps znowu nie chciało się załadować, wrócisz jednym tapnięciem do planu.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              color: cs.onSurfaceVariant,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveMap(BuildContext context) {
    return GoogleMap(
      key: const ValueKey('live-map'),
      initialCameraPosition: const CameraPosition(target: _campus, zoom: 16),
      style: _mapStyle,
      markers: _markers(),
      myLocationEnabled: true,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      compassEnabled: false,
      mapToolbarEnabled: false,
      onMapCreated: (controller) => _mapController = controller,
      onTap: (_) => setState(() => _selectedId = null),
    );
  }

  Widget _buildPlanMap(BuildContext context) {
    return LayoutBuilder(
      key: const ValueKey('plan-map'),
      builder: (context, constraints) {
        _planViewport = Size(constraints.maxWidth, constraints.maxHeight);
        final selectedPoint = _selectedPoint;

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
                ...widget.data.mapPoints
                    .where((p) => p.lat != null && p.lng != null)
                    .map((point) {
                      final offset = _projectToPlan(
                        point.lat!,
                        point.lng!,
                        _planViewport,
                      );
                      final selected = point.id == _selectedId;
                      final color = point.type.mapPointColor(context);
                      final icon = point.type.mapPointIcon;

                      return Positioned(
                        left: offset.dx - 17,
                        top: offset.dy - 17,
                        child: GestureDetector(
                          onTap: () => _focus(point),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: selected ? 36 : 34,
                            height: selected ? 36 : 34,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.95),
                                width: selected ? 2.5 : 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: color.withValues(alpha: 0.35),
                                  blurRadius: selected ? 16 : 10,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Icon(icon, size: 16, color: Colors.white),
                          ),
                        ),
                      );
                    }),
                if (selectedPoint != null)
                  Positioned(
                    left: 18,
                    top: 18,
                    child: IgnorePointer(
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 220),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.88),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 18,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              selectedPoint.name,
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Colors.black.withValues(alpha: 0.84),
                              ),
                            ),
                            if (selectedPoint.description != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                selectedPoint.description!,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  color: Colors.black.withValues(alpha: 0.65),
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildModeToggle(BuildContext context) {
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
            onTap: () => setState(() => _preferredMode = _EmbeddedMapMode.plan),
          ),
          const SizedBox(width: 4),
          _ModeChip(
            label: 'Na żywo',
            selected: _effectiveMode == _EmbeddedMapMode.live,
            onTap: _canUseLiveMap
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

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
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
          color: selected
              ? cs.primary.withValues(alpha: 0.16)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          label,
          style: GoogleFonts.spaceGrotesk(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? cs.primary : cs.onSurfaceVariant,
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
