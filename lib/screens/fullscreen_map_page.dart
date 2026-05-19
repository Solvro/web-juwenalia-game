import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../models/models.dart';
import '../services/data_service.dart';
import '../theme/app_theme.dart';
import '../theme/elements.dart';
import '../theme/icon_names.dart';
import '../widgets/map_common.dart';

class FullScreenMapPage extends StatefulWidget {
  const FullScreenMapPage({
    super.key,
    required this.data,
    required this.initialMode,
    required this.planImage,
    required this.planNaturalSize,
    required this.supportsLiveMap,
    this.selectedId,
    this.initialLocation,
  });

  final AppData data;
  final EmbeddedMapMode initialMode;
  final ImageProvider? planImage;
  final Size planNaturalSize;
  final bool supportsLiveMap;
  final String? selectedId;
  final LatLng? initialLocation;

  @override
  State<FullScreenMapPage> createState() => _FullScreenMapPageState();
}

class _FullScreenMapPageState extends State<FullScreenMapPage> {
  static const _campus = LatLng(51.141441, 16.946014);
  static const double _planMinScale = 1.0;
  static const double _planMaxScale = 8.0;

  final TransformationController _planController = TransformationController();
  final MapController _liveController = MapController();

  late EmbeddedMapMode _mode;
  String? _selectedId;
  Size _planViewport = Size.zero;
  LatLng? _myLocation;
  bool _locating = false;
  double _liveRotationDeg = 0;
  StreamSubscription<MapEvent>? _mapEventSub;
  StreamSubscription<Position>? _locationSub;

  EmbeddedMapMode get _effectiveMode =>
      widget.supportsLiveMap ? _mode : EmbeddedMapMode.plan;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
    _selectedId = widget.selectedId;
    _myLocation = widget.initialLocation;
    if (widget.supportsLiveMap) {
      _maybeStartLocationStream();
      _mapEventSub = _liveController.mapEventStream.listen((event) {
        final next = _normalizeDeg(event.camera.rotation);
        if ((next - _liveRotationDeg).abs() < 0.05) return;
        if (!mounted) return;
        setState(() => _liveRotationDeg = next);
      });
    }
  }

  static double _normalizeDeg(double deg) {
    var d = deg % 360;
    if (d > 180) d -= 360;
    if (d <= -180) d += 360;
    return d;
  }

  @override
  void dispose() {
    _planController.dispose();
    _locationSub?.cancel();
    _mapEventSub?.cancel();
    super.dispose();
  }

  Future<void> _maybeStartLocationStream() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) return;
      final perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.always ||
          perm == LocationPermission.whileInUse) {
        _startLocationStream();
      }
    } catch (_) {}
  }

  void _startLocationStream() {
    _locationSub?.cancel();
    _locationSub =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 4,
          ),
        ).listen((pos) {
          if (!mounted) return;
          setState(() => _myLocation = LatLng(pos.latitude, pos.longitude));
        }, onError: (_) {});
  }

  void _setMode(EmbeddedMapMode mode) {
    if (_mode == mode) return;
    setState(() => _mode = mode);
  }

  void _zoomIn() {
    if (_effectiveMode == EmbeddedMapMode.live) {
      final z = _liveController.camera.zoom + 1;
      _liveController.move(_liveController.camera.center, z.clamp(3.0, 19.0));
      return;
    }
    _zoomPlan(1.2);
  }

  void _zoomOut() {
    if (_effectiveMode == EmbeddedMapMode.live) {
      final z = _liveController.camera.zoom - 1;
      _liveController.move(_liveController.camera.center, z.clamp(3.0, 19.0));
      return;
    }
    _zoomPlan(1 / 1.2);
  }

  void _zoomPlan(double factor) {
    if (_planViewport == Size.zero) return;
    final currentScale = _planController.value.getMaxScaleOnAxis();
    final targetScale = (currentScale * factor).clamp(
      _planMinScale,
      _planMaxScale,
    );
    final center = _scenePointForViewportCenter();
    final dx = _planViewport.width / 2 - center.dx * targetScale;
    final dy = _planViewport.height / 2 - center.dy * targetScale;
    _planController.value = Matrix4.diagonal3Values(targetScale, targetScale, 1)
      ..setTranslationRaw(dx, dy, 0);
  }

  Offset _scenePointForViewportCenter() {
    final center = Offset(_planViewport.width / 2, _planViewport.height / 2);
    final inverse = Matrix4.inverted(_planController.value);
    return MatrixUtils.transformPoint(inverse, center);
  }

  void _resetPlanView() {
    _planController.value = Matrix4.identity();
  }

  void _resetLiveRotation() {
    _liveController.rotate(0);
  }

  Future<void> _handleLocateMe() async {
    if (_locating) return;
    final cached = _myLocation;
    if (cached != null && _effectiveMode == EmbeddedMapMode.live) {
      _liveController.move(cached, 17.5);
    }
    setState(() => _locating = true);
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }
      if (_locationSub == null) _startLocationStream();
      LatLng? fresh;
      try {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 8),
          ),
        ).timeout(const Duration(seconds: 10));
        fresh = LatLng(position.latitude, position.longitude);
      } on TimeoutException {
        fresh = _myLocation;
      }
      if (!mounted) return;
      if (fresh != null) {
        setState(() => _myLocation = fresh);
        if (_effectiveMode == EmbeddedMapMode.live) {
          _liveController.move(fresh, 17.5);
        }
      }
    } catch (_) {
      // ignore
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  MapPoint? get _selectedPoint {
    if (_selectedId == null) return null;
    final now = DateTime.now();
    for (final p in widget.data.mapPoints) {
      if (p.id == _selectedId && !p.hidden && !p.isExpiredAt(now)) return p;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final palette = AppElements.earth;
    final top = MediaQuery.of(context).padding.top;
    final bottom = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: AppTheme.surfaceContainerOf(context),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: _effectiveMode == EmbeddedMapMode.plan
                ? _buildPlanMap(context)
                : _buildLiveMap(context),
          ),
          Positioned(
            top: top + 12,
            left: 12,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppTheme.surfaceContainerHighOf(
                  context,
                ).withValues(alpha: 0.94),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: cs.outlineVariant.withValues(alpha: 0.4),
                ),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: cs.surface.withValues(alpha: 0.24),
                    ),
                    child: Icon(
                      Symbols.close_rounded,
                      size: 20,
                      color: cs.onSurface,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: top + 12,
            right: 12,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (widget.supportsLiveMap) ...[
                  _buildModeToggle(context, palette),
                  const SizedBox(height: 8),
                ],
                _buildControls(context),
                const SizedBox(height: 8),
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 220),
                  opacity:
                      _effectiveMode == EmbeddedMapMode.live &&
                          _liveRotationDeg.abs() > 0.5
                      ? 1
                      : 0,
                  child: IgnorePointer(
                    ignoring:
                        _effectiveMode != EmbeddedMapMode.live ||
                        _liveRotationDeg.abs() <= 0.5,
                    child: CompassButton(
                      rotationDeg: _liveRotationDeg,
                      onTap: _resetLiveRotation,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_effectiveMode == EmbeddedMapMode.live)
            const Positioned(bottom: 12, left: 12, child: OsmAttribution()),
          _buildInfoTileOverlay(context, bottom),
        ],
      ),
    );
  }

  Widget _buildInfoTileOverlay(BuildContext context, double bottomInset) {
    final point = _selectedPoint;
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      bottom: point != null ? bottomInset + 16 : -120,
      left: 16,
      right: 16,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: point != null
            ? _buildInfoTile(context, point)
            : const SizedBox.shrink(),
      ),
    );
  }

  Widget _buildInfoTile(BuildContext context, MapPoint point) {
    final cs = Theme.of(context).colorScheme;
    final color =
        parseHexColor(point.color) ?? point.type.mapPointColor(context);
    final icon = point.icon != null
        ? iconFromName(point.icon!)
        : point.type.mapPointIcon;

    return Container(
      key: ValueKey('info-${point.id}'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerHighOf(context).withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  point.name,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                ),
                if (point.description != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    point.description!,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 4),
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => setState(() => _selectedId = null),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(
                  Symbols.close_rounded,
                  size: 18,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeToggle(BuildContext context, ElementPalette palette) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerHighOf(context).withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ModeChip(
            label: 'Plan',
            selected: _effectiveMode == EmbeddedMapMode.plan,
            color: palette.base,
            onTap: () => _setMode(EmbeddedMapMode.plan),
          ),
          const SizedBox(width: 4),
          ModeChip(
            label: 'Na żywo',
            selected: _effectiveMode == EmbeddedMapMode.live,
            color: palette.base,
            onTap: () => _setMode(EmbeddedMapMode.live),
          ),
        ],
      ),
    );
  }

  Widget _buildControls(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerHighOf(context).withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          MapControlButton(
            icon: Symbols.add_rounded,
            tooltip: 'Przybliż',
            onTap: _zoomIn,
          ),
          const SizedBox(height: 4),
          MapControlButton(
            icon: Symbols.remove_rounded,
            tooltip: 'Oddal',
            onTap: _zoomOut,
          ),
          if (_effectiveMode == EmbeddedMapMode.live) ...[
            const SizedBox(height: 4),
            MapControlButton(
              icon: _locating
                  ? Symbols.more_horiz_rounded
                  : Symbols.my_location_rounded,
              tooltip: 'Moja lokalizacja',
              onTap: _handleLocateMe,
            ),
          ] else ...[
            const SizedBox(height: 4),
            MapControlButton(
              icon: Symbols.center_focus_strong_rounded,
              tooltip: 'Resetuj plan',
              onTap: _resetPlanView,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPlanMap(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _planViewport = Size(constraints.maxWidth, constraints.maxHeight);

        final naturalStack = SizedBox(
          width: widget.planNaturalSize.width,
          height: widget.planNaturalSize.height,
          child: AnimatedBuilder(
            animation: _planController,
            builder: (context, _) {
              final sceneScale = _planController.value
                  .getMaxScaleOnAxis()
                  .clamp(_planMinScale, _planMaxScale)
                  .toDouble();
              final fitScale = _planViewport == Size.zero
                  ? 1.0
                  : (_planViewport.width / widget.planNaturalSize.width)
                        .clamp(1e-3, double.infinity)
                        .toDouble();
              final pinScale = 1.0 / (fitScale * sceneScale);

              final planImage = widget.planImage;
              final now = DateTime.now();
              final planPoints = widget.data.mapPoints
                  .where(
                    (p) =>
                        !p.hidden && !p.isExpiredAt(now) && p.hasPlanPosition,
                  )
                  .toList();
              planPoints.sort((a, b) {
                if (a.id == _selectedId) return 1;
                if (b.id == _selectedId) return -1;
                return 0;
              });
              return Stack(
                children: [
                  Positioned.fill(
                    child: planImage == null
                        ? ColoredBox(
                            color: AppTheme.surfaceContainerOf(context),
                          )
                        : Image(image: planImage, fit: BoxFit.fill),
                  ),
                  for (final point in planPoints)
                    Positioned(
                      key: ValueKey('fs-plan-pin-${point.id}'),
                      left: point.planX! - 22,
                      top: point.planY! - 22,
                      width: 44,
                      height: 44,
                      child: Center(
                        child: Transform.scale(
                          scale: pinScale,
                          child: MapPinMarker(
                            key: ValueKey('fs-plan-pin-inner-${point.id}'),
                            point: point,
                            selected: point.id == _selectedId,
                            onTap: () => setState(() => _selectedId = point.id),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        );

        return InteractiveViewer(
          transformationController: _planController,
          minScale: _planMinScale,
          maxScale: _planMaxScale,
          boundaryMargin: const EdgeInsets.all(120),
          child: SizedBox(
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            child: FittedBox(fit: BoxFit.contain, child: naturalStack),
          ),
        );
      },
    );
  }

  Widget _buildLiveMap(BuildContext context) {
    final now = DateTime.now();
    final points = widget.data.mapPoints
        .where(
          (p) =>
              !p.hidden &&
              !p.isExpiredAt(now) &&
              p.lat != null &&
              p.lng != null,
        )
        .toList();
    points.sort((a, b) {
      if (a.id == _selectedId) return 1;
      if (b.id == _selectedId) return -1;
      return 0;
    });

    return FlutterMap(
      mapController: _liveController,
      options: MapOptions(
        initialCenter: _campus,
        initialZoom: 16.5,
        minZoom: 12,
        maxZoom: 19,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all,
        ),
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
                rotate: true,
                child: MapPinMarker(
                  key: ValueKey('fs-live-pin-${p.id}'),
                  point: p,
                  selected: p.id == _selectedId,
                  onTap: () => setState(() => _selectedId = p.id),
                ),
              ),
            if (_myLocation != null)
              Marker(
                point: _myLocation!,
                width: 26,
                height: 26,
                rotate: true,
                child: const MyLocationDot(),
              ),
          ],
        ),
      ],
    );
  }
}
