import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'directus.dart';

/// Tracks reachability of the CMS. Treats `connectivity_plus` as a hint
/// and confirms with a HEAD probe — `connectivity_plus` on Flutter Web
/// frequently reports `none` while the browser is online.
class ConnectivityService {
  ConnectivityService._();

  static final ConnectivityService instance = ConnectivityService._();

  final ValueNotifier<bool> isOnline = ValueNotifier<bool>(true);

  StreamSubscription<List<ConnectivityResult>>? _sub;
  bool _started = false;
  DateTime _lastProbeAt = DateTime.fromMillisecondsSinceEpoch(0);

  static const _probeCooldown = Duration(seconds: 15);

  Future<void> start() async {
    if (_started) return;
    _started = true;

    _sub = Connectivity().onConnectivityChanged.listen(_handleSignal);

    try {
      _handleSignal(await Connectivity().checkConnectivity());
    } catch (_) {
      isOnline.value = true;
    }
  }

  void reportFetchSuccess() {
    _lastProbeAt = DateTime.now();
    if (!isOnline.value) isOnline.value = true;
  }

  Future<void> reportFetchFailure() => _probe(force: true);

  Future<void> refresh() => _probe(force: true);

  void dispose() {
    _sub?.cancel();
    _sub = null;
    _started = false;
  }

  void _handleSignal(List<ConnectivityResult> results) {
    if (_hasInterface(results)) {
      isOnline.value = true;
    } else {
      unawaited(_probe(force: false));
    }
  }

  Future<void> _probe({required bool force}) async {
    final now = DateTime.now();
    if (!force && now.difference(_lastProbeAt) < _probeCooldown) return;
    _lastProbeAt = now;

    try {
      final uri = Uri.parse('${Directus.baseUrl}/server/ping');
      final response = await http.head(uri).timeout(const Duration(seconds: 5));
      // Any HTTP response (including 404/405) means we reached the server.
      final reachable = response.statusCode > 0;
      if (isOnline.value != reachable) isOnline.value = reachable;
    } catch (_) {
      if (isOnline.value) isOnline.value = false;
    }
  }

  static bool _hasInterface(List<ConnectivityResult> results) {
    if (results.isEmpty) return false;
    return results.any((r) => r != ConnectivityResult.none);
  }
}
