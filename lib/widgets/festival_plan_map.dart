import 'package:flutter/material.dart';

/// Pin positioned on the festival plan via raw pixel coordinates in the
/// plan image's native coordinate space (1600×1100 by default — see
/// [FestivalPlanMap.naturalSize]).
///
/// We dropped lat/lng projection in favour of direct pixel positions
/// because editors hand-place pins on the plan photo; mapping every
/// chair-and-tent through GPS bounds added drift and required keeping
/// per-edition geographic bounds in sync with the plan asset.
class FestivalPlanPin {
  const FestivalPlanPin({
    required this.id,
    required this.x,
    required this.y,
    required this.builder,
  });

  final String id;
  final double x;
  final double y;

  /// Called every frame with the current inverse-scale so pins can
  /// counter-scale and stay pixel-sized regardless of zoom.
  final Widget Function(BuildContext context, double pinScale) builder;
}

/// Reusable zoomable festival plan. Used by the main Mapa tab and by the
/// checkpoint mini-map — anything that wants to render pins onto the
/// bundled plan PNG.
///
/// Layout: an inner [SizedBox] sized to [naturalSize] holds the image
/// and pin stack in the image's own pixel space. A [FittedBox] then
/// scales that whole composition to fit the available area uniformly,
/// so a pin placed at (800, 550) always lands on the same spot on the
/// image regardless of the widget's outer size.
class FestivalPlanMap extends StatefulWidget {
  const FestivalPlanMap({
    super.key,
    required this.pins,
    this.controller,
    this.autoFocus,
    this.autoFocusScale = 2.2,
    this.minScale = 1.0,
    this.maxScale = 4.0,
    this.onInteractionChanged,
    this.panEnabled = true,
    this.scaleEnabled = true,
    this.naturalSize = const Size(1600, 1100),
  });

  static const String planAsset = 'assets/maps/festival_plan.png';

  final List<FestivalPlanPin> pins;

  /// Native pixel dimensions of the plan asset. Pins coordinate in this
  /// space; the [FittedBox] handles screen-fit scaling. Defaults to the
  /// bundled 1600×1100 plan.
  final Size naturalSize;

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

  /// FittedBox(BoxFit.contain) scales the natural-sized stack uniformly
  /// to fit [_viewport]. We replicate that math so we can convert a pin's
  /// natural-space (x, y) into viewport-space pixels for auto-focus.
  Offset _projectToViewport(double x, double y) {
    if (_viewport == Size.zero) return Offset.zero;
    final natural = widget.naturalSize;
    final scale = (_viewport.width / natural.width).clamp(
      0.0,
      _viewport.height / natural.height,
    );
    final dx = (_viewport.width - natural.width * scale) / 2;
    final dy = (_viewport.height - natural.height * scale) / 2;
    return Offset(dx + x * scale, dy + y * scale);
  }

  void _applyAutoFocus() {
    final pin = widget.autoFocus;
    if (pin == null || _viewport == Size.zero) return;
    final target = _projectToViewport(pin.x, pin.y);
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

        // Inner stack lives in the plan's native pixel space — pins
        // position with raw (x, y). FittedBox + BoxFit.contain scales
        // it uniformly into the viewport without cropping.
        final naturalStack = SizedBox(
          width: widget.naturalSize.width,
          height: widget.naturalSize.height,
          child: Stack(
            children: [
              const Positioned.fill(
                child: Image(
                  image: AssetImage(FestivalPlanMap.planAsset),
                  fit: BoxFit.contain,
                ),
              ),
              AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  final sceneScale = _controller.value
                      .getMaxScaleOnAxis()
                      .clamp(widget.minScale, widget.maxScale)
                      .toDouble();
                  // FittedBox scales the natural stack into the viewport
                  // by fitScale; InteractiveViewer then scales by
                  // sceneScale on top of that. Pin builders apply
                  // Transform.scale(pinScale) themselves so the painted
                  // pin lands at a constant viewport size regardless of
                  // either factor.
                  final fitScale = _viewport == Size.zero
                      ? 1.0
                      : (_viewport.width / widget.naturalSize.width).clamp(
                          1e-3,
                          double.infinity,
                        );
                  final pinScale = 1.0 / (fitScale * sceneScale);

                  return Stack(
                    children: [
                      for (final pin in widget.pins)
                        Positioned(
                          left: pin.x - 22,
                          top: pin.y - 22,
                          width: 44,
                          height: 44,
                          child: Center(child: pin.builder(context, pinScale)),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        );

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
            child: FittedBox(fit: BoxFit.contain, child: naturalStack),
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
