import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Thin REST wrapper for the Juwenalia Directus instance.
/// All reads go through public (anon) access — no auth header needed.
class Directus {
  Directus._();

  static const String baseUrl = 'https://cms.juwenalia.solvro.pl';

  /// Fetches items from a collection. [query] is appended as query string.
  /// For singletons, Directus returns `{"data": {...}}` (single object).
  /// For regular collections, Directus returns `{"data": [...]}` (array).
  /// Callers get the raw decoded `data` value and cast as needed.
  ///
  /// Retries transient failures (timeouts, network blips, 5xx) up to
  /// [retries] times with a small linear backoff. 4xx responses are not
  /// retried — they indicate a caller bug, not a flaky link.
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

  /// Fetches a single field definition from `/fields/:collection/:field`.
  /// Returns the `data` payload (a Map with `meta.options.choices` for
  /// dropdowns). Used to keep enum-like selects (e.g. partner tier) in sync
  /// with the CMS instead of hard-coding their values in the app.
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

  /// GET with linear backoff. Retries on timeout, socket-level errors, and
  /// 5xx. 4xx raises immediately (a bad query won't get better by retrying).
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
        // 4xx — no point retrying.
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

  /// Asset URL for a Directus file uuid. Optional transform params.
  /// Returns empty string for null/empty uuids so callers can use the result
  /// directly with `imageUrl.isNotEmpty` guards.
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
}

class DirectusException implements Exception {
  DirectusException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => 'DirectusException: $message';
}
