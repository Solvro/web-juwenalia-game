import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../services/bundled_photos.dart';

/// Thin wrapper around [CachedNetworkImage] / [Image.network] that works
/// around a few gotchas at once:
///
///  1. **Web CORS.** Directus serves our assets without
///     `Access-Control-Allow-Origin` headers, so anything that fetches
///     bytes over XHR (including [CachedNetworkImage]) fails silently in
///     the browser. [Image.network] on web renders through an `<img>`
///     tag which bypasses CORS for display, so we use that on web.
///
///  2. **SVG fallback.** Directus file UUIDs are extension-less — we
///     can't tell ahead of time whether bytes are raster or SVG. If the
///     raster decode fails we flip to [SvgPicture.network] on the next
///     frame (returning it directly from an `errorWidget` frequently
///     renders 0×height because width constraints haven't settled).
///
///  3. **Empty/invalid URLs.** Directus returns `assetUrl('')` for
///     unset file references, which CMS callers pass straight through.
///     We never attempt to load empty URLs — SVG would throw
///     `Bad state: Invalid SVG data` during parse and pollute the logs.
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
  /// Set when the bundled asset (if any) failed to decode. We then fall
  /// through to the network path — kept separate from [_rasterFailed] so a
  /// corrupt bundled asset doesn't force every subsequent image to SVG.
  bool _bundledFailed = false;

  /// Set when the *network* raster decode failed, meaning the bytes are
  /// most likely SVG. Only then do we render [SvgPicture.network].
  bool _rasterFailed = false;

  /// Set when even the SVG fallback gave up. We then render [_error]
  /// instead of letting flutter_svg throw "Invalid SVG data" over and over.
  bool _svgFailed = false;

  @override
  void didUpdateWidget(covariant AppNetworkImage old) {
    super.didUpdateWidget(old);
    // URL reuse (e.g. this widget sits inside a re-used list item) must
    // reset the fallback flags, otherwise a previous image's failure
    // would force a valid new URL down the SVG path.
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
    // Never attempt a network load for an empty/whitespace URL — that's how
    // Directus represents "no file attached", and poking SvgPicture.network
    // at it throws `Bad state: Invalid SVG data` during parse.
    if (widget.url.trim().isEmpty) return _error();

    // Prefer the bundled copy when sync_data.dart shipped one — it means
    // zero network, zero CORS pain, works fully offline on first launch.
    final bundled = BundledPhotos.assetFor(widget.url);
    if (bundled != null && !_bundledFailed) {
      return Image.asset(
        bundled,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        errorBuilder: (_, _, _) {
          // If the bundled bytes fail to decode (corrupt file, SVG in a
          // .png slot, etc.), fall through to the network path which
          // handles the SVG flip on its own.
          _flipBundledFailed();
          return _placeholder();
        },
      );
    }

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
      // Browsers can display cross-origin images through an <img> tag
      // without CORS — which is exactly what Image.network uses on web.
      return Image.network(
        widget.url,
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
      imageUrl: widget.url,
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

/// Renders [SvgPicture.network] inside a [FutureBuilder] so we can catch
/// parse failures instead of letting them propagate as uncaught promise
/// rejections (flutter_svg throws `Bad state: Invalid SVG data` when the
/// response is HTML, binary, or empty).
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

  /// Drives flutter_svg's own loader through our error boundary.
  /// SvgPicture.network has no errorBuilder in 2.x, so we pre-flight the
  /// load here: if parse throws, we surface it to the parent and render
  /// the placeholder instead of handing bytes to SvgPicture.
  Future<bool> _probe() async {
    try {
      final loader = SvgNetworkLoader(widget.url);
      await loader.loadBytes(null);
      return true;
    } catch (_) {
      // Defer the parent notify — setState during build isn't allowed.
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

/// Neutral grey placeholder used when no explicit error/placeholder widget
/// is passed. Renders Material's [Icons.hide_image_outlined] centred on a
/// surface-variant fill — same feel across raster/SVG failure paths.
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
