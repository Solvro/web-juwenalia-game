import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../services/bundled_photos.dart';

/// Thin wrapper around [CachedNetworkImage] / [Image.network] that works
/// around two gotchas at once:
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
  bool _rasterFailed = false;

  Widget _placeholder() =>
      widget.placeholder ??
      SizedBox(width: widget.width, height: widget.height);

  Widget _error() =>
      widget.errorWidget ??
      SizedBox(width: widget.width, height: widget.height);

  @override
  Widget build(BuildContext context) {
    // Prefer the bundled copy when sync_data.dart shipped one — it means
    // zero network, zero CORS pain, works fully offline on first launch.
    final bundled = BundledPhotos.assetFor(widget.url);
    if (bundled != null && !_rasterFailed) {
      return Image.asset(
        bundled,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        errorBuilder: (_, _, _) {
          // If the bundled bytes fail to decode as raster (e.g. it's an
          // SVG), fall through to the network path which already handles
          // the SVG flip on the next frame.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && !_rasterFailed) {
              setState(() => _rasterFailed = true);
            }
          });
          return _placeholder();
        },
      );
    }

    if (_rasterFailed) {
      return SvgPicture.network(
        widget.url,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        placeholderBuilder: (_) => _placeholder(),
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
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && !_rasterFailed) {
              setState(() => _rasterFailed = true);
            }
          });
          return _error();
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
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_rasterFailed) {
            setState(() => _rasterFailed = true);
          }
        });
        return _error();
      },
    );
  }
}
