import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../services/bundled_photos.dart';

/// Image loader that handles three CMS-specific gotchas:
///   1. Web CORS — Directus assets lack ACAO headers, so we route web
///      through `Image.network` (`<img>` tag) instead of XHR.
///   2. Extension-less UUIDs — falls back to `SvgPicture.network` when
///      the raster decode fails.
///   3. Empty URLs short-circuit to placeholder/error before SVG parse.
class AppNetworkImage extends StatefulWidget {
  const AppNetworkImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
  });

  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;

  @override
  State<AppNetworkImage> createState() => _AppNetworkImageState();
}

class _AppNetworkImageState extends State<AppNetworkImage> {
  bool _bundledFailed = false;
  bool _rasterFailed = false;
  bool _svgFailed = false;

  @override
  void didUpdateWidget(covariant AppNetworkImage old) {
    super.didUpdateWidget(old);
    // Recycled list-item: reset fallback flags so a previous URL's
    // failure doesn't force the new URL down the SVG path.
    if (old.url != widget.url) {
      _bundledFailed = false;
      _rasterFailed = false;
      _svgFailed = false;
    }
  }

  Widget _placeholder() =>
      widget.placeholder ??
      _DefaultPlaceholder(width: widget.width, height: widget.height);

  Widget _error() =>
      widget.errorWidget ??
      _DefaultPlaceholder(width: widget.width, height: widget.height);

  void _flipRasterFailed() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_rasterFailed) {
        setState(() => _rasterFailed = true);
      }
    });
  }

  void _flipBundledFailed() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_bundledFailed) {
        setState(() => _bundledFailed = true);
      }
    });
  }

  void _flipSvgFailed() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_svgFailed) {
        setState(() => _svgFailed = true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.url.trim().isEmpty) return _error();

    final bundled = BundledPhotos.assetFor(widget.url);
    if (bundled != null && !_bundledFailed) {
      return Image.asset(
        bundled,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        errorBuilder: (_, _, _) {
          _flipBundledFailed();
          return _placeholder();
        },
      );
    }

    final dpr = MediaQuery.devicePixelRatioOf(context);
    final transformedUrl = _withDirectusTransform(widget.url, widget.width, dpr);

    if (_rasterFailed) {
      if (_svgFailed) return _error();
      return _SafeSvgNetwork(
        url: widget.url,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        placeholder: _placeholder(),
        onError: _flipSvgFailed,
      );
    }

    if (kIsWeb) {
      return Image.network(
        transformedUrl,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        errorBuilder: (_, _, _) {
          _flipRasterFailed();
          return _placeholder();
        },
      );
    }

    return CachedNetworkImage(
      imageUrl: transformedUrl,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      placeholder: (_, _) => _placeholder(),
      errorWidget: (_, _, _) {
        _flipRasterFailed();
        return _placeholder();
      },
    );
  }
}

String _withDirectusTransform(
  String url,
  double? logicalWidth,
  double dpr,
) {
  if (url.isEmpty) return url;
  final uri = Uri.tryParse(url);
  if (uri == null) return url;
  final segments = uri.pathSegments;
  if (segments.length < 2 || segments[segments.length - 2] != 'assets') {
    return url;
  }

  final existing = uri.queryParameters;

  String? targetWidth() {
    if (existing.containsKey('width')) return existing['width'];
    if (logicalWidth == null || logicalWidth <= 0) return null;
    // 1200 px covers any phone at 3× DPR plus tablets in landscape;
    // anything bigger just wastes bytes for the typical layout sizes.
    final px = (logicalWidth * dpr).round().clamp(1, 1200);
    return px.toString();
  }

  final params = <String, String>{
    ...existing,
    'width': ?targetWidth(),
    if (!existing.containsKey('format')) 'format': 'webp',
    if (!existing.containsKey('quality')) 'quality': '80',
    if (!existing.containsKey('withoutEnlargement')) 'withoutEnlargement': 'true',
  };

  return uri.replace(queryParameters: params).toString();
}

/// `SvgPicture.network` inside a probe so we can catch parse failures
/// before they hit the build cycle (flutter_svg throws on HTML/binary
/// bodies which the picture widget can't recover from).
class _SafeSvgNetwork extends StatefulWidget {
  const _SafeSvgNetwork({
    required this.url,
    required this.placeholder,
    required this.onError,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  });

  final String url;
  final Widget placeholder;
  final VoidCallback onError;
  final double? width;
  final double? height;
  final BoxFit fit;

  @override
  State<_SafeSvgNetwork> createState() => _SafeSvgNetworkState();
}

class _SafeSvgNetworkState extends State<_SafeSvgNetwork> {
  late final Future<bool> _parseProbe;

  @override
  void initState() {
    super.initState();
    _parseProbe = _probe();
  }

  Future<bool> _probe() async {
    try {
      final loader = SvgNetworkLoader(widget.url);
      await loader.loadBytes(null);
      return true;
    } catch (_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onError();
      });
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _parseProbe,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return widget.placeholder;
        }
        if (snapshot.data != true) return widget.placeholder;
        return SvgPicture.network(
          widget.url,
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
          placeholderBuilder: (_) => widget.placeholder,
        );
      },
    );
  }
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
