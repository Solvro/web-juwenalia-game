import 'package:flutter/material.dart';

/// Wraps a route's body so an over-scroll past the top of its inner
/// scroll view feels like a drag-down-to-dismiss gesture.
///
/// Implementation note: instead of fighting the inner scrollable for
/// gestures, we listen to its [ScrollNotification]s. While the scroll
/// position is at the top and the user pulls further down we accumulate
/// the overscroll into a translation+fade. When the drag ends we either
/// pop (past [threshold]) or spring back to zero.
///
/// The host route should be pushed with `opaque: false` (see
/// [swipeDownPageRoute]) so the previous screen is visible behind the
/// translated body during the gesture; otherwise the exposed area is
/// just black.
/// Builds the dismissible body. [offset] is the current pull distance in
/// logical pixels (0 when idle); [progress] is `offset/maxOffset` clamped
/// to 0..1, useful for fades. Use [offset] to drive any visual you want
/// — translate, scale, stretch a hero image, etc.
typedef SwipeDownBuilder = Widget Function(
  BuildContext context,
  double offset,
  double progress,
);

class SwipeDownDismissible extends StatefulWidget {
  const SwipeDownDismissible({
    super.key,
    required this.builder,
    this.threshold = 110,
    this.maxOffset = 360,
  });

  final SwipeDownBuilder builder;

  /// How far the user has to pull down before releasing dismisses the
  /// route. Below this, the body springs back.
  final double threshold;

  /// Caps the offset so even an aggressive fling doesn't push the body
  /// further than the user can see.
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
      // Cancel any in-flight spring-back so the new pull starts fresh.
      _stopSpring();
      // 0.6 dampens the pull so it feels rubber-band-y rather than 1:1.
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
    final anim = Tween<double>(begin: from, end: 0).animate(
      CurvedAnimation(parent: _spring, curve: Curves.easeOutCubic),
    );
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

/// Pushes [builder] over the current route as a vertical slide-up sheet
/// with a transparent barrier so [SwipeDownDismissible] inside the page
/// reveals the underlying screen as the user drags.
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
