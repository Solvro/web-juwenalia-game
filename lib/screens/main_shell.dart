import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import '../services/connectivity_service.dart';
import '../services/data_service.dart';
import '../theme/app_theme.dart';
import '../theme/elements.dart';
import '../widgets/desktop_sidebar.dart';
import '../widgets/glass_bottom_nav.dart';
import '../widgets/platform_utils.dart';
import '../widgets/swipe_down_dismissible.dart';
import 'checkpoint_details_screen.dart';
import 'field_game_screen.dart';
import 'game_locked_screen.dart';
import 'info_screen.dart';
import 'map_screen.dart';
import 'qr_scanner_screen.dart';
import 'schedule_screen.dart';
import 'solvro_easter_egg_screen.dart';
import 'update_required_screen.dart';

/// Main 4-tab shell with a centered QR scan action.
///   Aktualności · Harmonogram · [QR] · Mapa · Gra Terenowa
///
/// Layout adapts to window size:
///   - compact (mobile)        → glass bottom nav with floating QR button
///   - expanded (desktop/web)  → left sidebar with download-app prompt
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with WidgetsBindingObserver {
  int _tabIndex = 0;
  late Future<AppData> _dataFuture;
  List<String> _completed = [];
  bool _isLocked = false;
  bool _imagesPrecached = false;
  String _appVersion = '';

  static const _destinations = <NavDestination>[
    NavDestination(
      icon: Icons.info_outline_rounded,
      selectedIcon: Icons.info_rounded,
      label: 'Info',
      element: AppElement.wind,
    ),
    NavDestination(
      icon: Icons.music_note_outlined,
      selectedIcon: Icons.music_note_rounded,
      label: 'Koncerty',
      element: AppElement.fire,
    ),
    NavDestination(
      icon: Icons.map_outlined,
      selectedIcon: Icons.map_rounded,
      label: 'Mapa',
      element: AppElement.earth,
    ),
    NavDestination(
      icon: Icons.sports_esports_outlined,
      selectedIcon: Icons.sports_esports_rounded,
      label: 'Gra',
      element: AppElement.water,
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
    _loadProgress();
    _loadVersion();
    ConnectivityService.instance.start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // When the user returns to a backgrounded app, silently refresh if the
    // cache is older than the configured staleness threshold. Keeps the
    // shell current without the user having to pull-to-refresh.
    if (state == AppLifecycleState.resumed) {
      _maybeRefreshOnResume();
    }
  }

  Future<void> _maybeRefreshOnResume() async {
    if (!mounted) return;
    if (await shouldForceRefetch() && mounted) {
      _refresh();
    }
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() => _appVersion = info.version);
    } catch (_) {
      // Best-effort: fall back to an empty string (never gates the shell).
    }
  }

  /// Returns the min version required for this platform from [config].
  String _platformMinVersion(AppConfig config) {
    if (kIsWeb) return config.minAppVersionWeb;
    if (PlatformUtils.isIOS) return config.minAppVersionIos;
    if (PlatformUtils.isAndroid) return config.minAppVersionAndroid;
    return '';
  }

  bool _needsUpdate(AppConfig config) {
    if (_appVersion.isEmpty) return false;
    final min = _platformMinVersion(config);
    if (min.trim().isEmpty) return false;
    return compareVersions(_appVersion, min) < 0;
  }

  Future<void> _loadProgress() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _completed = prefs.getStringList('completedCheckpoints') ?? [];
      _isLocked = prefs.getBool('isLocked') ?? false;
    });
  }

  /// Kicks off a fresh data fetch. Returns a Future so pull-to-refresh
  /// handlers can await spinner lifecycle.
  ///
  /// When [force] is true, skips the cache/bundled-asset fallback so a
  /// failed network fetch surfaces as an error instead of silently
  /// returning stale data.
  Future<void> _refresh({bool force = false}) async {
    final future = fetchData(http.Client(), forceNetwork: force);
    if (!mounted) return;
    setState(() {
      _imagesPrecached = false;
      _dataFuture = future;
    });
    try {
      await future;
    } catch (e) {
      if (!force || !mounted) return;
      ScaffoldMessenger.of(context)
        ..removeCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Nie udało się pobrać najnowszych danych.'),
            duration: Duration(seconds: 2),
          ),
        );
    }
  }

  /// Shorthand used by RefreshIndicator — always forces a network fetch.
  Future<void> _pullToRefresh() => _refresh(force: true);

  Future<void> _unlockCheckpoint(String id) async {
    if (_completed.contains(id)) return;
    final prefs = await SharedPreferences.getInstance();
    setState(() => _completed.add(id));
    await prefs.setStringList('completedCheckpoints', _completed);
  }

  Future<void> _lockReward() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _isLocked = true);
    await prefs.setBool('isLocked', true);
  }

  /// Kicks off background image precaching the first time data lands.
  /// Idempotent — a second invocation is a no-op until data is reloaded.
  void _maybePrecacheImages(AppData data) {
    if (_imagesPrecached) return;
    _imagesPrecached = true;
    // Defer until after the current build so we have a settled context.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      precacheAppImages(data, context: context);
    });
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppData>(
      future: _dataFuture,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          _maybePrecacheImages(snapshot.data!);
        }

        // Hard update gate — shown above the entire shell when the
        // running build is older than the platform's minimum.
        final data = snapshot.data;
        if (data != null && _needsUpdate(data.config)) {
          return UpdateRequiredScreen(
            config: data.config,
            currentVersion: _appVersion,
          );
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final useDesktop = constraints.maxWidth >= Breakpoints.expanded;
            return useDesktop
                ? _buildDesktopShell(snapshot)
                : _buildMobileShell(snapshot);
          },
        );
      },
    );
  }

  // ── Mobile shell ───────────────────────────────────────────────────────────

  Widget _buildMobileShell(AsyncSnapshot<AppData> snapshot) {
    final data = snapshot.data;
    final qrEnabled = data != null && _gameEnabled(data);

    return Scaffold(
      backgroundColor: AppTheme.surfaceContainerLowestOf(context),
      extendBody: true,
      body: Stack(
        children: [
          Positioned.fill(child: _buildBody(snapshot)),
          const _OfflinePill(alignment: Alignment.topCenter),
        ],
      ),
      bottomNavigationBar: GlassBottomNav(
        selectedIndex: _tabIndex,
        onSelect: (i) => setState(() => _tabIndex = i),
        onScanQr: data == null ? () {} : () => _scanQr(data),
        qrEnabled: qrEnabled,
        destinations: _destinations,
      ),
    );
  }

  // ── Desktop shell ──────────────────────────────────────────────────────────

  Widget _buildDesktopShell(AsyncSnapshot<AppData> snapshot) {
    final data = snapshot.data;
    final qrEnabled = data != null && _gameEnabled(data);

    return Scaffold(
      backgroundColor: AppTheme.surfaceContainerLowestOf(context),
      body: Stack(
        children: [
          Positioned.fill(
            child: Row(
              children: [
                DesktopSidebar(
                  selectedIndex: _tabIndex,
                  onSelect: (i) => setState(() => _tabIndex = i),
                  onScanQr: data == null ? () {} : () => _scanQr(data),
                  qrEnabled: qrEnabled,
                  destinations: _destinations,
                ),
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 880),
                      child: _buildBody(snapshot),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const _OfflinePill(alignment: Alignment.topRight),
        ],
      ),
    );
  }

  // ── Body (shared) ──────────────────────────────────────────────────────────

  Widget _buildBody(AsyncSnapshot<AppData> snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: Theme.of(context).colorScheme.primaryContainer,
        ),
      );
    }

    if (snapshot.hasError && !snapshot.hasData) {
      return _buildError();
    }

    final data = snapshot.data;
    if (data == null) return _buildError();

    switch (_tabIndex) {
      case 0:
        return InfoScreen(data: data, onRefresh: _pullToRefresh);
      case 1:
        return ScheduleScreen(data: data, onRefresh: _pullToRefresh);
      case 2:
        return MapScreen(data: data, onRefresh: _pullToRefresh);
      case 3:
        if (!_gameEnabled(data)) {
          return GameLockedScreen(config: data.config);
        }
        return FieldGameScreen(
          data: data,
          completed: _completed,
          isLocked: _isLocked,
          onLockReward: _lockReward,
          onRefresh: _pullToRefresh,
        );
      default:
        return const SizedBox.shrink();
    }
  }

  bool _gameEnabled(AppData data) {
    final override = data.config.gameEnabledOverride;
    if (override != null) return override;
    final start = data.config.eventStartsAt;
    if (start == null) return true;
    return DateTime.now().isAfter(start);
  }

  Widget _buildError() {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off_rounded, size: 52, color: cs.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              'Brak połączenia',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Sprawdź sieć i spróbuj ponownie',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _refresh,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Spróbuj ponownie'),
            ),
          ],
        ),
      ),
    );
  }

  // ── QR scanning (centralised here so both layouts share it) ────────────────

  Future<void> _scanQr(AppData data) async {
    if (!_gameEnabled(data)) {
      setState(() => _tabIndex = 3);
      return;
    }

    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const QRScannerScreen()),
    );
    if (result == null || !mounted) return;

    // Easter egg: a specific code (either scanned or typed) opens a tiny
    // mini-game instead of the regular checkpoint flow.
    if (result.trim().toLowerCase() == 'kochamsolvro123') {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SolvroEasterEggScreen()),
      );
      return;
    }

    final cp = data.checkpoints.where((c) => c.qrCode == result).firstOrNull;

    final sm = ScaffoldMessenger.of(context);
    sm.removeCurrentSnackBar();

    if (cp == null) {
      sm.showSnackBar(
        SnackBar(
          content: Text('Nieznany kod QR: $result'),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    final alreadyScanned = _completed.contains(cp.qrCode);
    if (!alreadyScanned) await _unlockCheckpoint(cp.qrCode);
    if (!mounted) return;

    sm.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 2),
        content: Text(
          alreadyScanned
              ? '${cp.title} była już zeskanowana'
              : '✓ Zeskanowano: ${cp.title}',
        ),
        action: SnackBarAction(
          label: 'Zobacz',
          onPressed: () => Navigator.push(
            context,
            swipeDownPageRoute(
              (_) => CheckpointDetailsScreen(
                checkpoint: cp,
                isCompleted: true,
                data: data,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Floating orange pill shown whenever connectivity_plus reports no network.
/// Tapping re-checks immediately. Renders nothing when online.
class _OfflinePill extends StatelessWidget {
  const _OfflinePill({required this.alignment});

  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: ConnectivityService.instance.isOnline,
      builder: (context, online, _) {
        return SafeArea(
          child: Align(
            alignment: alignment,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, -0.3),
                    end: Offset.zero,
                  ).animate(anim),
                  child: child,
                ),
              ),
              child: online
                  ? const SizedBox.shrink(key: ValueKey('online'))
                  : Padding(
                      key: const ValueKey('offline'),
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(999),
                          onTap: ConnectivityService.instance.refresh,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 9,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF59E0B),
                              borderRadius: BorderRadius.circular(999),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFFF59E0B,
                                  ).withValues(alpha: 0.35),
                                  blurRadius: 18,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.wifi_off_rounded,
                                  size: 16,
                                  color: Colors.white,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Brak internetu',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
          ),
        );
      },
    );
  }
}
