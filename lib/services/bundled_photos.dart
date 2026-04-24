import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

/// Registry of Directus asset UUIDs that were downloaded and shipped
/// inside the app bundle by `tool/sync_data.dart`. Lets images load
/// instantly on first launch — including offline — without any network
/// round-trip, at the cost of a larger binary.
///
/// The manifest is a tiny JSON (`assets/data/photos_manifest.json`) that
/// lists the UUIDs present under `assets/data/photos/`. We load it once
/// at startup (best-effort) and answer synchronous lookups thereafter.
class BundledPhotos {
  static Set<String> _ids = const {};
  static bool _loaded = false;

  /// Load the bundled manifest. Safe to call multiple times — first call
  /// wins. Never throws: a missing/corrupt manifest just leaves the
  /// registry empty (runtime falls through to network as usual).
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
    } catch (_) {
      // Missing manifest is the normal case during dev builds — stay silent.
    }
  }

  /// Matches `/assets/<uuid>` (with optional query/hash) anywhere in the
  /// URL. Returns the UUID if found, otherwise null.
  static final _assetUrlPattern = RegExp(r'/assets/([^/?#]+)');

  /// Returns the bundled-asset path for [url] if its UUID is present in
  /// the manifest, otherwise null.
  static String? assetFor(String url) {
    if (_ids.isEmpty || url.isEmpty) return null;
    final m = _assetUrlPattern.firstMatch(url);
    if (m == null) return null;
    final id = m.group(1)!;
    if (!_ids.contains(id)) return null;
    return 'assets/data/photos/$id';
  }
}
