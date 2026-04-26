import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

/// Registry of asset UUIDs shipped inside the app bundle by
/// `tool/sync_data.dart`. Lets images load instantly (and offline) on
/// first launch.
class BundledPhotos {
  static Set<String> _ids = const {};
  static bool _loaded = false;

  /// Idempotent — first call wins. Never throws.
  static Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final raw = await rootBundle.loadString(
        'assets/data/photos_manifest.json',
      );
      final decoded = jsonDecode(raw);
      final list = (decoded is Map)
          ? (decoded['ids'] as List?)
          : (decoded is List ? decoded : null);
      if (list == null) return;
      _ids = list.map((e) => e.toString()).toSet();
    } catch (_) {}
  }

  static final _assetUrlPattern = RegExp(r'/assets/([^/?#]+)');

  /// Bundled-asset path for [url], or null if its UUID isn't present.
  static String? assetFor(String url) {
    if (_ids.isEmpty || url.isEmpty) return null;
    final m = _assetUrlPattern.firstMatch(url);
    if (m == null) return null;
    final id = m.group(1)!;
    if (!_ids.contains(id)) return null;
    return 'assets/data/photos/$id';
  }
}
