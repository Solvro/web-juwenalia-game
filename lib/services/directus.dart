import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Public-access REST wrapper for the Juwenalia Directus instance.
class Directus {
  Directus._();

  static const String baseUrl = 'https://cms.juwenalia.solvro.pl';

  /// Returns the raw `data` payload — Map for singletons, List for
  /// collections. Retries timeouts and 5xx; 4xx raises immediately.
  static Future<dynamic> items(
    String collection, {
    Map<String, String>? query,
    Duration timeout = const Duration(seconds: 12),
    int retries = 1,
  }) async {
    final uri = Uri.parse(
      '$baseUrl/items/$collection',
    ).replace(queryParameters: query);

    final response = await _getWithRetry(
      uri,
      timeout: timeout,
      retries: retries,
    );

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return decoded['data'];
  }

  /// Returns `/fields/:collection/:field` — used for `meta.options.choices`
  /// on enum-like fields.
  static Future<Map<String, dynamic>?> field(
    String collection,
    String field, {
    Duration timeout = const Duration(seconds: 12),
    int retries = 1,
  }) async {
    final uri = Uri.parse('$baseUrl/fields/$collection/$field');

    final response = await _getWithRetry(
      uri,
      timeout: timeout,
      retries: retries,
    );

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final data = decoded['data'];
    if (data is Map<String, dynamic>) return data;
    return null;
  }

  static Future<http.Response> _getWithRetry(
    Uri uri, {
    required Duration timeout,
    required int retries,
  }) async {
    Object? lastError;
    for (var attempt = 0; attempt <= retries; attempt++) {
      if (attempt > 0) {
        await Future<void>.delayed(Duration(milliseconds: 400 * attempt));
      }
      try {
        final response = await http.get(uri).timeout(timeout);
        if (response.statusCode == 200) return response;
        if (response.statusCode >= 500) {
          lastError = DirectusException(
            'GET $uri failed: ${response.statusCode} ${response.reasonPhrase}',
            statusCode: response.statusCode,
          );
          continue;
        }
        throw DirectusException(
          'GET $uri failed: ${response.statusCode} ${response.reasonPhrase}',
          statusCode: response.statusCode,
        );
      } on TimeoutException catch (e) {
        lastError = e;
      } on http.ClientException catch (e) {
        lastError = e;
      }
    }
    throw lastError!;
  }

  /// Returns empty string for null/empty uuids so callers can guard
  /// with `.isNotEmpty`.
  static String assetUrl(
    String? uuid, {
    int? width,
    int? height,
    String? fit,
    int? quality,
    String? format,
  }) {
    if (uuid == null || uuid.isEmpty) return '';
    final params = <String, String>{};
    if (width != null) params['width'] = width.toString();
    if (height != null) params['height'] = height.toString();
    if (fit != null) params['fit'] = fit;
    if (quality != null) params['quality'] = quality.toString();
    if (format != null) params['format'] = format;
    final qs = params.isEmpty
        ? ''
        : '?${params.entries.map((e) => '${e.key}=${e.value}').join('&')}';
    return '$baseUrl/assets/$uuid$qs';
  }

  /// Adds the canonical transform query (`width`, `format=webp`,
  /// `quality=80`, `withoutEnlargement`). [width] is in *device pixels* —
  /// we do NOT multiply by DPR, so the URL is identical on every device
  /// and shares cache entries between bundle, runtime and precache.
  /// Non-Directus URLs and ones with explicit transform params pass
  /// through unchanged.
  static String transformedAssetUrl(String url, {int? width = 500}) {
    if (url.isEmpty) return url;
    final uri = Uri.tryParse(url);
    if (uri == null) return url;
    final segments = uri.pathSegments;
    if (segments.length < 2 || segments[segments.length - 2] != 'assets') {
      return url;
    }

    final existing = uri.queryParameters;
    final params = <String, String>{
      ...existing,
      if (width != null && !existing.containsKey('width'))
        'width': width.toString(),
      if (!existing.containsKey('format')) 'format': 'webp',
      if (!existing.containsKey('quality')) 'quality': '80',
      if (width != null && !existing.containsKey('withoutEnlargement'))
        'withoutEnlargement': 'true',
    };

    return uri.replace(queryParameters: params).toString();
  }
}

class DirectusException implements Exception {
  DirectusException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => 'DirectusException: $message';
}
