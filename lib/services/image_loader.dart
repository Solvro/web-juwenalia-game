import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';

import 'bundled_photos.dart';
import 'directus.dart';

/// Resolves a Directus asset URL to the cheapest provider available:
///   1. [AssetImage] when the UUID is bundled (offline-instant).
///   2. [NetworkImage] on web (uses an `<img>` element — bypasses
///      CORS-related XHR decode errors).
///   3. [CachedNetworkImageProvider] elsewhere (disk-cached).
///
/// Returns `null` for empty URLs so callers can render a placeholder
/// without piping garbage URLs into image decoders.
ImageProvider? imageProviderFor(String url, {int? width = 500}) {
  if (url.trim().isEmpty) return null;

  final uuid = BundledPhotos.uuidFromUrl(url);
  if (uuid != null && BundledPhotos.has(uuid)) {
    return AssetImage(BundledPhotos.pathFor(uuid));
  }

  final transformed = Directus.transformedAssetUrl(url, width: width);
  if (kIsWeb) return NetworkImage(transformed);
  return CachedNetworkImageProvider(transformed);
}
