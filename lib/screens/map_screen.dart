import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/models.dart';
import '../services/connectivity_service.dart';
import '../services/data_service.dart';
import '../theme/app_theme.dart';
import '../theme/elements.dart';
import '../theme/icon_names.dart';
import '../widgets/app_network_image.dart';
import '../widgets/app_refresh_indicator.dart';
import '../widgets/map_common.dart';
import '../widgets/platform_utils.dart';
import '../widgets/section_header.dart';
import 'fullscreen_map_page.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key, required this.data, this.onRefresh});

  final AppData data;
  final Future<void> Function()? onRefresh;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  static const _campus = LatLng(51.141441, 16.946014);
  static const _planAspectRatio = 16 / 11;

  static const _planNaturalFallback = Size(1600, 1100);

  static const double _planMinScale = 1.0;
  static const double _planMaxScale = 8.0;

  final TransformationController _planController = TransformationController();
  final MapController _liveController = MapController();
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _legendKeys = {};
  final GlobalKey _mapPanelKey = GlobalKey();

  String? _selectedId;
  bool _locating = false;
  bool _interactingWithMap = false;
  Size _planViewport = Size.zero;
  late EmbeddedMapMode _preferredMode;

  ImageProvider? _planImage;
  Size _planNaturalSize = _planNaturalFallback;
  ImageStream? _planImageStream;
  ImageStreamListener? _planImageListener;

  LatLng? _myLocation;
  StreamSubscription<Position>? _locationSub;

  double _liveRotationDeg = 0;
  StreamSubscription<MapEvent>? _mapEventSub;

  bool get _supportsLiveMap =>
      kIsWeb || PlatformUtils.isAndroid || PlatformUtils.isIOS;

  EmbeddedMapMode get _effectiveMode =>
      _supportsLiveMap ? _preferredMode : EmbeddedMapMode.plan;

  @override
  void initState() {
    super.initState();
    _preferredMode = EmbeddedMapMode.plan;
    for (final p in widget.data.mapPoints) {
      _legendKeys[p.id] = GlobalKey();
    }
    _resolvePlanImage(widget.data.config.festivalPlanUrl);
    if (_supportsLiveMap) {
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
  void didUpdateWidget(covariant MapScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    for (final p in widget.data.mapPoints) {
      _legendKeys.putIfAbsent(p.id, () => GlobalKey());
    }
    final newUrl = widget.data.config.festivalPlanUrl;
    if (newUrl != oldWidget.data.config.festivalPlanUrl) {
      _planNaturalSize = _planNaturalFallback;
      _resolvePlanImage(newUrl);
    }
  }

  @override
  void dispose() {
    _planController.dispose();
    _scrollController.dispose();
    _locationSub?.cancel();
    _mapEventSub?.cancel();
    if (_planImageListener != null) {
      _planImageStream?.removeListener(_planImageListener!);
    }
    super.dispose();
  }

  void _resolvePlanImage(String url) {
    if (_planImageListener != null) {
      _planImageStream?.removeListener(_planImageListener!);
      _planImageListener = null;
    }
    if (url.isEmpty) {
      setState(() => _planImage = null);
      return;
    }
    final provider = CachedNetworkImageProvider(url);
    setState(() => _planImage = provider);

    final stream = provider.resolve(const ImageConfiguration());
    final listener = ImageStreamListener((info, _) {
      if (!mounted) return;
      final size = Size(
        info.image.width.toDouble(),
        info.image.height.toDouble(),
      );
      if (size != _planNaturalSize) {
        setState(() => _planNaturalSize = size);
      }
    }, onError: (_, _) {});
    stream.addListener(listener);
    _planImageStream = stream;
    _planImageListener = listener;
  }

  /// Only attaches if permission is already granted — we never trigger
  /// the system prompt from here; that's reserved for the explicit
  /// "locate me" tap.
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

  Future<void> _focus(MapPoint p, {bool fromPin = false}) async {
    setState(() => _selectedId = p.id);

    if (fromPin) {
      await _scrollLegendTo(p.id);
      return;
    }

    unawaited(_scrollMapIntoView());

    final hasPlan = p.hasPlanPosition;
    final hasGeo = p.lat != null && p.lng != null;
    final isOnline = ConnectivityService.instance.isOnline.value;
    final canShowLive = _supportsLiveMap && hasGeo && isOnline;

    if (_effectiveMode == EmbeddedMapMode.plan && hasPlan) {
      _focusPlanPosition(p.planX!, p.planY!, scale: 2.2);
      return;
    }
    if (_effectiveMode == EmbeddedMapMode.live && canShowLive) {
      _liveController.move(LatLng(p.lat!, p.lng!), 18);
      return;
    }

    if (hasPlan) {
      setState(() => _preferredMode = EmbeddedMapMode.plan);
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      _focusPlanPosition(p.planX!, p.planY!, scale: 2.2);
      return;
    }
    if (canShowLive) {
      setState(() => _preferredMode = EmbeddedMapMode.live);
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      _liveController.move(LatLng(p.lat!, p.lng!), 18);
      return;
    }

    _showOutsidePlanSnackBar(p, hasGeo: hasGeo);
  }

  Future<void> _setMode(EmbeddedMapMode mode) async {
    if (_preferredMode == mode) return;
    setState(() => _preferredMode = mode);

    final id = _selectedId;
    if (id == null) return;
    MapPoint? selected;
    for (final p in widget.data.mapPoints) {
      if (p.id == id) {
        selected = p;
        break;
      }
    }
    if (selected == null) return;

    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;

    if (mode == EmbeddedMapMode.plan && selected.hasPlanPosition) {
      _focusPlanPosition(selected.planX!, selected.planY!, scale: 2.2);
    } else if (mode == EmbeddedMapMode.live &&
        selected.lat != null &&
        selected.lng != null) {
      _liveController.move(LatLng(selected.lat!, selected.lng!), 18);
    }
  }

  Future<void> _scrollMapIntoView() async {
    final ctx = _mapPanelKey.currentContext;
    if (ctx == null || !ctx.mounted) return;

    final renderBox = ctx.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) return;

    final topLeft = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;
    final screenHeight = MediaQuery.of(ctx).size.height;
    final visibleTop = math.max(topLeft.dy, 0.0);
    final visibleBottom = math.min(topLeft.dy + size.height, screenHeight);
    final visibleFraction = size.height <= 0
        ? 1.0
        : math.max(0.0, visibleBottom - visibleTop) / size.height;

    if (visibleFraction >= 0.5) return;

    await Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeInOutCubic,
      alignment: 0,
    );
  }

  Future<void> _scrollLegendTo(String id) async {
    await Future<void>.delayed(const Duration(milliseconds: 80));
    if (!mounted) return;
    final ctx = _legendKeys[id]?.currentContext;
    if (ctx != null && ctx.mounted) {
      await Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
        alignment: 0.1,
      );
    }
  }

  void _showOutsidePlanSnackBar(MapPoint p, {required bool hasGeo}) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.removeCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 5),
        content: Text(
          hasGeo
              ? 'To miejsce jest poza terenem festiwalu — '
                    'mapę można otworzyć w Google Maps.'
              : 'To miejsce nie ma przypisanej lokalizacji.',
        ),
        action: hasGeo
            ? SnackBarAction(
                label: 'Otwórz w Mapach',
                onPressed: () => _openInGoogleMaps(p),
              )
            : null,
      ),
    );
  }

  Future<void> _openInGoogleMaps(MapPoint p) async {
    if (p.lat == null || p.lng == null) return;
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${p.lat},${p.lng}',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _handleLocateMe() async {
    if (_locating) return;

    final cached = _myLocation;
    final centeredFromCache =
        cached != null && _effectiveMode == EmbeddedMapMode.live;
    if (centeredFromCache) {
      _liveController.move(cached, 17.5);
    }

    setState(() => _locating = true);

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!centeredFromCache) {
          _showMessage('Włącz usługi lokalizacji, aby odnaleźć swoją pozycję.');
        }
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!centeredFromCache) _showMessage('Brak zgody na lokalizację.');
        return;
      }

      if (_locationSub == null) _startLocationStream();

      // Geolocator's `timeLimit` isn't honoured on web — wrap in
      // Future.timeout so the spinner always recovers.
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

      if (fresh == null) {
        if (!centeredFromCache) {
          _showMessage(
            'Nie udało się pobrać lokalizacji w rozsądnym czasie. '
            'Sprawdź, czy GPS jest aktywny i spróbuj ponownie.',
          );
        }
        return;
      }

      setState(() => _myLocation = fresh);
      if (_effectiveMode == EmbeddedMapMode.live) {
        _liveController.move(fresh, 17.5);
      }
    } catch (_) {
      if (!centeredFromCache) {
        _showMessage('Nie udało się pobrać Twojej lokalizacji.');
      }
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

  void _focusPlanPosition(int planX, int planY, {double scale = 2.2}) {
    if (_planViewport == Size.zero) return;
    final target = _projectPlanPointToViewport(
      planX.toDouble(),
      planY.toDouble(),
      _planViewport,
    );
    final dx = _planViewport.width / 2 - target.dx * scale;
    final dy = _planViewport.height / 2 - target.dy * scale;
    _planController.value = Matrix4.diagonal3Values(scale, scale, 1)
      ..setTranslationRaw(dx, dy, 0);
  }

  void _resetPlanView() {
    _planController.value = Matrix4.identity();
  }

  void _resetLiveRotation() {
    _liveController.rotate(0);
  }

  void _openFullScreenMap() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FullScreenMapPage(
          data: widget.data,
          initialMode: _effectiveMode,
          planImage: _planImage,
          planNaturalSize: _planNaturalSize,
          supportsLiveMap: _supportsLiveMap,
          selectedId: _selectedId,
          initialLocation: _myLocation,
        ),
      ),
    );
  }

  /// Mirrors `FittedBox(BoxFit.contain)` so we can convert a pin's
  /// natural-space coordinate to viewport pixels.
  Offset _projectPlanPointToViewport(double planX, double planY, Size size) {
    final fitScale = (size.width / _planNaturalSize.width).clamp(
      0.0,
      size.height / _planNaturalSize.height,
    );
    final dx = (size.width - _planNaturalSize.width * fitScale) / 2;
    final dy = (size.height - _planNaturalSize.height * fitScale) / 2;
    return Offset(dx + planX * fitScale, dy + planY * fitScale);
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
        const SliverToBoxAdapter(child: SizedBox(height: 120)),
      ],
    );

    final onRefresh = widget.onRefresh;
    if (onRefresh == null) return scrollView;

    return AppRefreshIndicator(
      onRefresh: onRefresh,
      palette: palette,
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
    final isPlanMode = _effectiveMode == EmbeddedMapMode.plan;

    return Padding(
      key: _mapPanelKey,
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
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              _buildMapControls(context),
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
                        ],
                      ),
                    ),
                    if (_effectiveMode == EmbeddedMapMode.live)
                      Positioned(
                        bottom: 12,
                        left: 12,
                        child: const OsmAttribution(),
                      ),
                    Positioned(
                      bottom: 12,
                      right: 12,
                      child: _ExpandMapButton(onTap: _openFullScreenMap),
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
      key: const ValueKey('live-map'),
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
                  key: ValueKey('live-pin-inner-${p.id}'),
                  point: p,
                  selected: p.id == _selectedId,
                  onTap: () => _focus(p, fromPin: true),
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

  Widget _buildPlanMap(BuildContext context) {
    return LayoutBuilder(
      key: const ValueKey('plan-map'),
      builder: (context, constraints) {
        _planViewport = Size(constraints.maxWidth, constraints.maxHeight);

        // Inner stack is in the plan's native pixel space; FittedBox
        // scales it uniformly into the viewport.
        final naturalStack = SizedBox(
          width: _planNaturalSize.width,
          height: _planNaturalSize.height,
          child: AnimatedBuilder(
            animation: _planController,
            builder: (context, _) {
              final sceneScale = _planController.value
                  .getMaxScaleOnAxis()
                  .clamp(_planMinScale, _planMaxScale)
                  .toDouble();
              final fitScale = _planViewport == Size.zero
                  ? 1.0
                  : (_planViewport.width / _planNaturalSize.width)
                        .clamp(1e-3, double.infinity)
                        .toDouble();
              // Counter-scale so pins paint at a constant viewport size.
              final pinScale = 1.0 / (fitScale * sceneScale);

              final planImage = _planImage;
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
                      key: ValueKey('plan-pin-${point.id}'),
                      left: point.planX! - 22,
                      top: point.planY! - 22,
                      width: 44,
                      height: 44,
                      child: Center(
                        child: Transform.scale(
                          scale: pinScale,
                          child: MapPinMarker(
                            key: ValueKey('plan-pin-inner-${point.id}'),
                            point: point,
                            selected: point.id == _selectedId,
                            onTap: () => _focus(point, fromPin: true),
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
            onTap: _supportsLiveMap
                ? () => _setMode(EmbeddedMapMode.live)
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

  Widget _buildLegend(
    BuildContext context,
    ColorScheme cs,
    ElementPalette palette,
  ) {
    final now = DateTime.now();
    final visible = widget.data.mapPoints
        .where((p) => !p.hidden && !p.isExpiredAt(now))
        .toList();
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
    final color =
        parseHexColor(point.color) ?? point.type.mapPointColor(context);
    final icon = point.icon != null
        ? iconFromName(point.icon!)
        : point.type.mapPointIcon;
    final surfHigh = AppTheme.surfaceContainerHighOf(context);
    final selected = _selectedId == point.id;
    final key = _legendKeys.putIfAbsent(point.id, () => GlobalKey());

    return Padding(
      key: key,
      padding: const EdgeInsets.only(bottom: 8),
      child: Stack(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: selected ? color.withValues(alpha: 0.12) : surfHigh,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected
                    ? color
                    : cs.outlineVariant.withValues(alpha: 0.3),
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
                  Symbols.chevron_right_rounded,
                  color: cs.onSurfaceVariant,
                  size: 20,
                ),
              ],
            ),
          ),
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _focus(point),
                borderRadius: BorderRadius.circular(14),
                splashColor: color.withValues(alpha: 0.1),
                highlightColor: color.withValues(alpha: 0.05),
              ),
            ),
          ),
        ],
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

class _TierStyle {
  const _TierStyle({
    required this.logoHeight,
    required this.textSize,
    required this.highlight,
  });

  final double logoHeight;
  final double textSize;
  final bool highlight;

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

/// Horizontal partner-card carousel that auto-scrolls forever and
/// pauses while the user drags. Uses a virtual `itemCount` with
/// modulo-indexing so wraparound isn't visible at the boundary.
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

    final logoHeight = (style.logoHeight)
        .clamp(18.0, style.logoHeight)
        .toDouble();
    final borderColor = style.highlight
        ? AppElements.earth.base.withValues(alpha: 0.45)
        : cs.outlineVariant.withValues(alpha: 0.4);

    return SizedBox(
      width: 168,
      child: Material(
        color: surfHigh,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: partner.url == null || partner.url!.isEmpty ? null : onTap,
          child: Container(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
            decoration: BoxDecoration(
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: AppNetworkImage(
        url: url,
        height: height,
        fit: BoxFit.contain,
        cap: 200,
        placeholder: SizedBox(width: height, height: height),
        errorWidget: SizedBox(width: height, height: height),
      ),
    );
  }
}

class _ExpandMapButton extends StatelessWidget {
  const _ExpandMapButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerHighOf(context).withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
      ),
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
            child: Icon(
              Symbols.fullscreen_rounded,
              size: 20,
              color: cs.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}
