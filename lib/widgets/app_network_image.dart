import 'package:flutter/material.dart';

import '../services/image_loader.dart';

/// Renders a Directus asset through whichever [ImageProvider]
/// [imageProviderFor] picks (bundled / network / cached). Always
/// requests the image at [cap] device pixels wide so the URL is the
/// same on every device and across precache + runtime.
class AppNetworkImage extends StatelessWidget {
  const AppNetworkImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
    this.cap = defaultContentCap,
  });

  static const int defaultContentCap = 500;

  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;

  final int cap;

  @override
  Widget build(BuildContext context) {
    final provider = imageProviderFor(url, width: cap);
    if (provider == null) return _error();

    return Image(
      image: provider,
      width: width,
      height: height,
      fit: fit,
      gaplessPlayback: true,
      frameBuilder: (_, child, frame, sync) {
        if (frame == null && !sync) return _placeholder();
        return child;
      },
      errorBuilder: (_, _, _) => _placeholder(),
    );
  }

  Widget _placeholder() =>
      placeholder ?? _DefaultPlaceholder(width: width, height: height);

  Widget _error() =>
      errorWidget ?? _DefaultPlaceholder(width: width, height: height);
}

class _DefaultPlaceholder extends StatelessWidget {
  const _DefaultPlaceholder({this.width, this.height});

  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: width,
      height: height,
      color: cs.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Icon(
        Icons.hide_image_outlined,
        size: _iconSize(width, height),
        color: cs.onSurfaceVariant.withValues(alpha: 0.6),
      ),
    );
  }

  double _iconSize(double? w, double? h) {
    final shortest = [
      ?w,
      ?h,
    ].fold<double?>(null, (acc, v) => acc == null ? v : (v < acc ? v : acc));
    if (shortest == null) return 32;
    return (shortest * 0.33).clamp(18.0, 48.0);
  }
}
