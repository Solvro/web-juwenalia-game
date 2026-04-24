import 'package:flutter/material.dart';

import '../models/models.dart';

/// Pin projected onto the festival plan. Lat/lng are mapped to pixel
/// offsets using [PlanBounds] the same way the main map does — a shared
/// projection keeps both renders visually consistent.
class FestivalPlanPin {
  const FestivalPlanPin({
    required this.id,
    required this.lat,
    required this.lng,
    required this.builder,
  });

  final String id;
  final double lat;
  final double lng;

  /// Called every frame with the current inverse-scale so pins can
  /// counter-scale and stay pixel-sized regardless of zoom.
  final Widget Function(BuildContext context, double pinScale) builder;
}

/// Reusable zoomable festival plan. Used by the main Mapa tab and by the
/// checkpoint mini-map — anything that wants to render pins onto the
/// bundled plan PNG.
///
/// The plan asset path is fixed (the asset is bundled in pubspec.yaml);
/// the caller supplies [bounds] so different editions can ship different
/// plans without a code change.
class FestivalPlanMap extends StatefulWidget {
  const FestivalPlanMap({
    super.key,
    required this.bounds,
    required this.pins,
    this.controller,
    this.autoFocus,
    this.autoFocusScale = 2.2,
    this.minScale = 1.0,
    this.maxScale = 4.0,
    this.onInteractionChanged,
    this.panEnabled = true,
    this.scaleEnabled = true,
  });

  static const String planAsset = 'assets/maps/festival_plan.png';

  final PlanBounds bounds;
  final List<FestivalPlanPin> pins;

  /// Optional external controller. Lets the parent drive zoom/reset
  /// without having to reach into this widget's state.
  final TransformationController? controller;

  /// When supplied, the view centers and zooms to this pin after the
  /// first layout pass. Later [autoFocus] changes are ignored — set a
  /// fresh [Key] on this widget if you want the focus to re-apply.
  final FestivalPlanPin? autoFocus;
  final double autoFocusScale;

  final double minScale;
  final double maxScale;

  /// Fires `true` on pointer-down, `false` on pointer-up/cancel. Used by
  /// the main map to suspend the outer scrollable while the user drags.
  final ValueChanged<bool>? onInteractionChanged;

  final bool panEnabled;
  final bool scaleEnabled;

  @override
  State<FestivalPlanMap> createState() => _FestivalPlanMapState();
}

class _FestivalPlanMapState extends State<FestivalPlanMap> {
  late final TransformationController _controller;
  bool _ownsController = false;
  Size _viewport = Size.zero;
  bool _didAutoFocus = false;

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _controller = widget.controller!;
    } else {
      _controller = TransformationController();
      _ownsController = true;
    }
  }

  @override
  void dispose() {
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  Offset _project(double lat, double lng, Size size) {
    final b = widget.bounds;
    final lngRange = (b.east - b.west).abs();
    final latRange = (b.north - b.south).abs();
    final safeLngRange = lngRange == 0 ? 1 : lngRange;
    final safeLatRange = latRange == 0 ? 1 : latRange;

    const horizontalPadding = 78.0;
    const verticalPadding = 62.0;
    final usableWidth = size.width - horizontalPadding * 2;
    final usableHeight = size.height - verticalPadding * 2;

    final x = ((lng - b.west) / safeLngRange).clamp(0.0, 1.0);
    final y = ((b.north - lat) / safeLatRange).clamp(0.0, 1.0);

    return Offset(
      horizontalPadding + usableWidth * x,
      verticalPadding + usableHeight * y,
    );
  }

  void _applyAutoFocus() {
    final pin = widget.autoFocus;
    if (pin == null || _viewport == Size.zero) return;
    final target = _project(pin.lat, pin.lng, _viewport);
    final scale = widget.autoFocusScale.clamp(widget.minScale, widget.maxScale);
    final dx = _viewport.width / 2 - target.dx * scale;
    final dy = _viewport.height / 2 - target.dy * scale;
    _controller.value = Matrix4.diagonal3Values(scale, scale, 1)
      ..setTranslationRaw(dx, dy, 0);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final newViewport = Size(constraints.maxWidth, constraints.maxHeight);
        if (newViewport != _viewport) {
          _viewport = newViewport;
          if (!_didAutoFocus && widget.autoFocus != null) {
            _didAutoFocus = true;
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => _applyAutoFocus(),
            );
          }
        }

        final viewer = InteractiveViewer(
          transformationController: _controller,
          minScale: widget.minScale,
          maxScale: widget.maxScale,
          panEnabled: widget.panEnabled,
          scaleEnabled: widget.scaleEnabled,
          boundaryMargin: const EdgeInsets.all(120),
          child: SizedBox(
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            child: Stack(
              children: [
                const Positioned.fill(
                  child: Image(
                    image: AssetImage(FestivalPlanMap.planAsset),
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned.fill(
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (context, _) {
                      final sceneScale = _controller.value
                          .getMaxScaleOnAxis()
                          .clamp(widget.minScale, widget.maxScale)
                          .toDouble();
                      final pinScale = 1 / sceneScale;

                      return Stack(
                        children: [
                          for (final pin in widget.pins)
                            Positioned(
                              left:
                                  _project(pin.lat, pin.lng, _viewport).dx - 22,
                              top:
                                  _project(pin.lat, pin.lng, _viewport).dy - 22,
                              width: 44,
                              height: 44,
                              child: Center(
                                child: pin.builder(context, pinScale),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );

        final onInteraction = widget.onInteractionChanged;
        if (onInteraction == null) return viewer;

        return Listener(
          onPointerDown: (_) => onInteraction(true),
          onPointerUp: (_) => onInteraction(false),
          onPointerCancel: (_) => onInteraction(false),
          child: viewer,
        );
      },
    );
  }
}
