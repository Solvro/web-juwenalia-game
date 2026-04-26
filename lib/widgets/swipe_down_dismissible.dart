import 'package:flutter/material.dart';

/// Drag-down-to-dismiss gesture for a scrollable route. Listens to
/// [ScrollNotification]s instead of fighting the inner scrollable for
/// pan gestures. Push via [swipeDownPageRoute] so the underlying screen
/// shows through during the drag.
///
/// The builder receives the current pull `offset` (px, 0 when idle) and
/// `progress` (offset/maxOffset, clamped). Use them to translate, fade,
/// or stretch the body.
typedef SwipeDownBuilder =
    Widget Function(BuildContext context, double offset, double progress);

class SwipeDownDismissible extends StatefulWidget {
  const SwipeDownDismissible({
    super.key,
    required this.builder,
    this.threshold = 110,
    this.maxOffset = 360,
  });

  final SwipeDownBuilder builder;

  /// Pull distance past which release dismisses the route.
  final double threshold;
  final double maxOffset;

  @override
  State<SwipeDownDismissible> createState() => _SwipeDownDismissibleState();
}

class _SwipeDownDismissibleState extends State<SwipeDownDismissible>
    with SingleTickerProviderStateMixin {
  double _offset = 0;
  late final AnimationController _spring;
  Animation<double>? _springAnim;
  void Function()? _springListener;

  @override
  void initState() {
    super.initState();
    _spring = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
  }

  @override
  void dispose() {
    if (_springListener != null) _springAnim?.removeListener(_springListener!);
    _spring.dispose();
    super.dispose();
  }

  bool _onNotification(ScrollNotification n) {
    if (n.metrics.axis != Axis.vertical) return false;

    if (n is OverscrollNotification &&
        n.overscroll < 0 &&
        n.metrics.pixels <= 0) {
      _stopSpring();
      // 0.6 = rubber-band damping factor.
      setState(() {
        _offset = (_offset - n.overscroll * 0.6).clamp(0.0, widget.maxOffset);
      });
    } else if (n is ScrollEndNotification && _offset > 0) {
      if (_offset >= widget.threshold) {
        Navigator.of(context).maybePop();
      } else {
        _springBack();
      }
    }
    return false;
  }

  void _stopSpring() {
    if (_springListener != null) {
      _springAnim?.removeListener(_springListener!);
      _springListener = null;
    }
    _spring.stop();
  }

  void _springBack() {
    _stopSpring();
    final from = _offset;
    final anim = Tween<double>(
      begin: from,
      end: 0,
    ).animate(CurvedAnimation(parent: _spring, curve: Curves.easeOutCubic));
    void onTick() {
      if (mounted) setState(() => _offset = anim.value);
    }

    anim.addListener(onTick);
    _springAnim = anim;
    _springListener = onTick;
    _spring.forward(from: 0).whenComplete(() {
      anim.removeListener(onTick);
      if (identical(_springListener, onTick)) _springListener = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_offset / widget.maxOffset).clamp(0.0, 1.0);
    return NotificationListener<ScrollNotification>(
      onNotification: _onNotification,
      child: widget.builder(context, _offset, progress),
    );
  }
}

/// Slide-up route with a transparent barrier so a child
/// [SwipeDownDismissible] reveals the underlying screen as the user
/// drags.
PageRoute<T> swipeDownPageRoute<T>(WidgetBuilder builder) {
  return PageRouteBuilder<T>(
    opaque: false,
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 320),
    reverseTransitionDuration: const Duration(milliseconds: 240),
    pageBuilder: (context, _, _) => builder(context),
    transitionsBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 1),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      );
    },
  );
}
