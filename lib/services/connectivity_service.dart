import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Observes device connectivity via connectivity_plus and exposes a
/// [ValueListenable] of `isOnline`. A single instance is shared across the
/// app (see [ConnectivityService.instance]).
class ConnectivityService {
  ConnectivityService._();

  static final ConnectivityService instance = ConnectivityService._();

  final ValueNotifier<bool> isOnline = ValueNotifier<bool>(true);
  StreamSubscription<List<ConnectivityResult>>? _sub;
  bool _started = false;

  Future<void> start() async {
    if (_started) return;
    _started = true;

    final connectivity = Connectivity();
    try {
      final initial = await connectivity.checkConnectivity();
      isOnline.value = _hasConnection(initial);
    } catch (_) {
      isOnline.value = true;
    }

    _sub = connectivity.onConnectivityChanged.listen((results) {
      isOnline.value = _hasConnection(results);
    });
  }

  Future<void> refresh() async {
    try {
      final r = await Connectivity().checkConnectivity();
      isOnline.value = _hasConnection(r);
    } catch (_) {}
  }

  void dispose() {
    _sub?.cancel();
    _sub = null;
    _started = false;
  }

  static bool _hasConnection(List<ConnectivityResult> results) {
    if (results.isEmpty) return false;
    return results.any((r) => r != ConnectivityResult.none);
  }
}
