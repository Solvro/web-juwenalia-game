import 'package:flutter/material.dart';

/// Pin positioned in the plan image's native pixel space.
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

  /// Called with the current inverse scale so pin builders can
  /// counter-scale to stay pixel-sized regardless of zoom.
  final Widget Function(BuildContext context, double pinScale) builder;
}

/// Zoomable festival-plan viewer. Pins position in the source image's
/// native pixel space; a [FittedBox] handles screen-fit scaling.
class FestivalPlanMap extends StatefulWidget {
  const FestivalPlanMap({
    super.key,
    required this.imageProvider,
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

  final ImageProvider imageProvider;

  final List<FestivalPlanPin> pins;

  /// Fallback dimensions used until the real image resolves. Replaced
  /// by the loaded image's actual size on first frame.
  final Size naturalSize;

  final TransformationController? controller;

  /// Centers and zooms to this pin on first layout. Later changes are
  /// ignored — supply a fresh [Key] to re-trigger.
  final FestivalPlanPin? autoFocus;
  final double autoFocusScale;

  final double minScale;
  final double maxScale;

  /// `true` on pointer-down, `false` on up/cancel — lets a parent
  /// scrollable suspend while the user drags.
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

  Size? _detectedNaturalSize;
  ImageStreamListener? _imageListener;
  ImageStream? _imageStream;

  Size get _naturalSize => _detectedNaturalSize ?? widget.naturalSize;

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _controller = widget.controller!;
    } else {
      _controller = TransformationController();
      _ownsController = true;
    }
    _resolveNaturalSize();
  }

  @override
  void didUpdateWidget(covariant FestivalPlanMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageProvider != widget.imageProvider) {
      _detectedNaturalSize = null;
      _resolveNaturalSize();
    }
  }

  void _resolveNaturalSize() {
    _imageStream?.removeListener(_imageListener!);
    final stream = widget.imageProvider.resolve(const ImageConfiguration());
    final listener = ImageStreamListener((info, _) {
      if (!mounted) return;
      final size = Size(
        info.image.width.toDouble(),
        info.image.height.toDouble(),
      );
      if (size != _detectedNaturalSize) {
        setState(() => _detectedNaturalSize = size);
      }
    }, onError: (_, _) {});
    stream.addListener(listener);
    _imageStream = stream;
    _imageListener = listener;
  }

  @override
  void dispose() {
    if (_imageListener != null) _imageStream?.removeListener(_imageListener!);
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  /// Mirrors `FittedBox(BoxFit.contain)` so we can map a pin's
  /// natural-space (x, y) to viewport pixels for [_applyAutoFocus].
  Offset _projectToViewport(double x, double y) {
    if (_viewport == Size.zero) return Offset.zero;
    final natural = _naturalSize;
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

        final natural = _naturalSize;

        final naturalStack = SizedBox(
          width: natural.width,
          height: natural.height,
          child: Stack(
            children: [
              Positioned.fill(
                child: Image(image: widget.imageProvider, fit: BoxFit.contain),
              ),
              AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  final sceneScale = _controller.value
                      .getMaxScaleOnAxis()
                      .clamp(widget.minScale, widget.maxScale)
                      .toDouble();
                  // pinScale = 1/(fit*scene) so pins paint at constant
                  // viewport size regardless of either factor.
                  final fitScale = _viewport == Size.zero
                      ? 1.0
                      : (_viewport.width / natural.width).clamp(
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
