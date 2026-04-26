import 'package:flutter/services.dart' show AssetManifest, rootBundle;

/// Registry of UUIDs that are physically present in the app bundle
/// under [_photosPrefix]. Backed by Flutter's [AssetManifest], so we
/// only ever advertise files that genuinely exist — no 404s when the
/// pubspec or sync_data state drifts.
class BundledPhotos {
  static const _photosPrefix = 'assets/data/photos/';
  static Set<String> _ids = const {};
  static bool _loaded = false;

  /// Idempotent. Safe to call without awaiting in `main` — lookups
  /// before this finishes just return false (network fallback kicks in).
  static Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      _ids = manifest
          .listAssets()
          .where((p) => p.startsWith(_photosPrefix))
          .map((p) => p.substring(_photosPrefix.length))
          .toSet();
    } catch (_) {
      _ids = const {};
    }
  }

  static bool has(String uuid) => _ids.contains(uuid);

  static String pathFor(String uuid) => '$_photosPrefix$uuid';

  static final _uuidPattern = RegExp(r'/assets/([^/?#]+)');

  /// Pulls the file UUID out of a Directus asset URL, with or without
  /// transform query params.
  static String? uuidFromUrl(String url) =>
      _uuidPattern.firstMatch(url)?.group(1);
}
