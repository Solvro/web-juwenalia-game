import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'directus.dart';

/// Tracks whether the app can reach the CMS.
///
/// `connectivity_plus` on its own is unreliable: on Flutter Web it often
/// reports `ConnectivityResult.none` even when the browser is clearly online,
/// and even on native it only knows about network interfaces, not actual
/// reachability. So we treat the platform signal as a *hint*, and confirm
/// with a real HEAD probe before flipping the pill to "offline".
///
/// `fetchData` also calls [reportFetchSuccess] / [reportFetchFailure] so the
/// UI state stays in sync with what the user actually sees.
class ConnectivityService {
  ConnectivityService._();

  static final ConnectivityService instance = ConnectivityService._();

  /// `true` means we believe the app can reach the CMS. Starts optimistic
  /// so we don't flash the offline pill before the first probe finishes.
  final ValueNotifier<bool> isOnline = ValueNotifier<bool>(true);

  StreamSubscription<List<ConnectivityResult>>? _sub;
  bool _started = false;
  DateTime _lastProbeAt = DateTime.fromMillisecondsSinceEpoch(0);

  /// Anything more recent than this and we skip re-probing.
  static const _probeCooldown = Duration(seconds: 15);

  Future<void> start() async {
    if (_started) return;
    _started = true;

    // Subscribe first so we don't miss the burst of events that some
    // platforms emit right after `checkConnectivity()`.
    _sub = Connectivity().onConnectivityChanged.listen((results) {
      _handleSignal(results);
    });

    // Initial signal.
    try {
      final initial = await Connectivity().checkConnectivity();
      _handleSignal(initial);
    } catch (_) {
      // If the platform can't even tell us, assume online and let real
      // fetches correct us.
      isOnline.value = true;
    }
  }

  /// Called by the data layer after a successful network fetch.
  void reportFetchSuccess() {
    _lastProbeAt = DateTime.now();
    if (!isOnline.value) isOnline.value = true;
  }

  /// Called by the data layer when a fetch fails for network reasons.
  /// Triggers a probe to confirm before flipping the pill.
  void reportFetchFailure() {
    // Fast path: a failed fetch means we just tried the network and lost,
    // so a HEAD probe right now is almost certainly going to agree.
    unawaited(_probe(force: true));
  }

  /// Manual "tap the offline pill to retry" entry point.
  Future<void> refresh() => _probe(force: true);

  void dispose() {
    _sub?.cancel();
    _sub = null;
    _started = false;
  }

  void _handleSignal(List<ConnectivityResult> results) {
    if (_hasInterface(results)) {
      // Interface looks usable — trust it optimistically.
      isOnline.value = true;
    } else {
      // Platform claims offline; confirm with a real probe before showing
      // the pill. This dodges the connectivity_plus web false-negative.
      unawaited(_probe(force: false));
    }
  }

  Future<void> _probe({required bool force}) async {
    final now = DateTime.now();
    if (!force && now.difference(_lastProbeAt) < _probeCooldown) return;
    _lastProbeAt = now;

    try {
      // Cheap HEAD against the CMS root. If this comes back (any status),
      // we have working internet + DNS + TLS, which is what we actually
      // care about for the pill.
      final uri = Uri.parse('${Directus.baseUrl}/server/ping');
      final response = await http.get(uri).timeout(const Duration(seconds: 5));
      // Any HTTP response counts as "online" — even a 404 means we made it
      // to the server.
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
