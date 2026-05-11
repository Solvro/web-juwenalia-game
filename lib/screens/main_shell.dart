import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:material_symbols_icons/symbols.dart';
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
import 'map_coming_soon_screen.dart';
import 'map_screen.dart';
import 'qr_scanner_screen.dart';
import 'schedule_screen.dart';
import 'solvro_easter_egg_screen.dart';
import 'update_required_screen.dart';

enum _Tab { info, schedule, map, game }

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with WidgetsBindingObserver {
  static const _periodicRefreshInterval = Duration(minutes: 5);

  _Tab _selectedTab = _Tab.info;
  late Future<AppData> _dataFuture;
  List<String> _completed = [];
  bool _isLocked = false;
  bool _imagesPrecached = false;
  String _appVersion = '';
  Timer? _periodicRefreshTimer;
  Timer? _gameUnlockTimer;
  DateTime? _scheduledUnlockAt;

  static const Map<_Tab, NavDestination> _tabDestinations = {
    _Tab.info: NavDestination(
      icon: Symbols.info_rounded,
      selectedIcon: Symbols.info_rounded,
      label: 'Info',
      element: AppElement.wind,
    ),
    _Tab.schedule: NavDestination(
      icon: Symbols.music_note_rounded,
      selectedIcon: Symbols.music_note_rounded,
      label: 'Koncerty',
      element: AppElement.fire,
    ),
    _Tab.map: NavDestination(
      icon: Symbols.map_rounded,
      selectedIcon: Symbols.map_rounded,
      label: 'Mapa',
      element: AppElement.earth,
    ),
    _Tab.game: NavDestination(
      icon: Symbols.sports_esports_rounded,
      selectedIcon: Symbols.sports_esports_rounded,
      label: 'Gra',
      element: AppElement.water,
    ),
  };

  static const List<_Tab> _allTabs = _Tab.values;

  /// Index of [_selectedTab] within [_allTabs]. Falls back to 0 (Info)
  /// if somehow out of range.
  int _selectedTabIndex() {
    final i = _allTabs.indexOf(_selectedTab);
    return i < 0 ? 0 : i;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
    _loadProgress();
    _loadVersion();
    ConnectivityService.instance.start();
    _startPeriodicRefresh();
  }

  @override
  void dispose() {
    _periodicRefreshTimer?.cancel();
    _gameUnlockTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _maybeRefreshOnResume();
      _startPeriodicRefresh();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      _periodicRefreshTimer?.cancel();
      _periodicRefreshTimer = null;
    }
  }

  Future<void> _maybeRefreshOnResume() async {
    if (!mounted) return;
    if (await shouldForceRefetch() && mounted) {
      _refresh();
    }
  }

  void _startPeriodicRefresh() {
    _periodicRefreshTimer?.cancel();
    _periodicRefreshTimer = Timer.periodic(_periodicRefreshInterval, (_) {
      if (!mounted) return;
      _refresh();
    });
  }

  /// Schedules a one-shot rebuild for the exact moment the game
  /// becomes unlocked so users sitting on the locked screen flip over
  /// to the live game without having to pull-to-refresh.
  void _scheduleGameUnlock(AppConfig config) {
    final start = config.eventStartsAt;
    if (start == null || config.gameEnabledOverride == true) {
      _gameUnlockTimer?.cancel();
      _gameUnlockTimer = null;
      _scheduledUnlockAt = null;
      return;
    }
    if (_scheduledUnlockAt == start && _gameUnlockTimer?.isActive == true) {
      return; // Already scheduled for this moment.
    }
    final delay = start.difference(DateTime.now());
    _gameUnlockTimer?.cancel();
    if (!delay.isNegative) {
      _gameUnlockTimer = Timer(delay, () {
        if (!mounted) return;
        setState(() {});
        _refresh();
      });
    }
    _scheduledUnlockAt = start;
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() => _appVersion = info.version);
    } catch (_) {}
  }

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

  Future<void> _refresh({bool force = false}) async {
    // For pull-to-refresh (force), don't swap the future until we know the
    // fetch succeeded — that way a failure leaves the previous data on screen
    // and we can surface a toast instead of the full-page error state.
    if (force) {
      try {
        final fresh = await fetchData(http.Client(), forceNetwork: true);
        if (!mounted) return;
        setState(() {
          _imagesPrecached = false;
          _dataFuture = Future.value(fresh);
        });
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
          ..removeCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text(
                'Nie udało się odświeżyć danych. Pokazujemy ostatnio pobraną wersję.',
              ),
              duration: Duration(seconds: 3),
            ),
          );
      }
      return;
    }

    final future = fetchData(http.Client(), forceNetwork: false);
    if (!mounted) return;
    setState(() {
      _imagesPrecached = false;
      _dataFuture = future;
    });
    // The FutureBuilder watches _dataFuture and surfaces the error itself;
    // we just await here to keep callers' awaits meaningful.
    try {
      await future;
    } catch (_) {}
  }

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

  void _maybePrecacheImages(AppData data) {
    if (_imagesPrecached) return;
    _imagesPrecached = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      precacheAppImages(data, context: context);
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppData>(
      future: _dataFuture,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          _maybePrecacheImages(snapshot.data!);
          _scheduleGameUnlock(snapshot.data!.config);
        }

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

  Widget _buildMobileShell(AsyncSnapshot<AppData> snapshot) {
    final data = snapshot.data;
    final qrEnabled = data != null && _gameEnabled(data);
    final destinations = [for (final t in _allTabs) _tabDestinations[t]!];

    return Scaffold(
      backgroundColor: AppTheme.surfaceContainerLowestOf(context),
      extendBody: true,
      body: _buildBody(snapshot),
      bottomNavigationBar: GlassBottomNav(
        selectedIndex: _selectedTabIndex(),
        onSelect: (i) => setState(() => _selectedTab = _allTabs[i]),
        onScanQr: data == null ? () {} : () => _scanQr(data),
        qrEnabled: qrEnabled,
        destinations: destinations,
      ),
    );
  }

  Widget _buildDesktopShell(AsyncSnapshot<AppData> snapshot) {
    final data = snapshot.data;
    final qrEnabled = data != null && _gameEnabled(data);
    final destinations = [for (final t in _allTabs) _tabDestinations[t]!];

    return Scaffold(
      backgroundColor: AppTheme.surfaceContainerLowestOf(context),
      body: Row(
        children: [
          DesktopSidebar(
            selectedIndex: _selectedTabIndex(),
            onSelect: (i) => setState(() => _selectedTab = _allTabs[i]),
            onScanQr: data == null ? () {} : () => _scanQr(data),
            qrEnabled: qrEnabled,
            destinations: destinations,
            config: data?.config,
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
    );
  }

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

    switch (_selectedTab) {
      case _Tab.info:
        return InfoScreen(data: data, onRefresh: _pullToRefresh);
      case _Tab.schedule:
        return ScheduleScreen(data: data, onRefresh: _pullToRefresh);
      case _Tab.map:
        if (data.config.mapDisabled) {
          return MapComingSoonScreen(onRefresh: _pullToRefresh);
        }
        return MapScreen(data: data, onRefresh: _pullToRefresh);
      case _Tab.game:
        if (!_gameEnabled(data)) {
          return GameLockedScreen(
            config: data.config,
            onRefresh: _pullToRefresh,
          );
        }
        return FieldGameScreen(
          data: data,
          completed: _completed,
          isLocked: _isLocked,
          onLockReward: _lockReward,
          onRefresh: _pullToRefresh,
        );
    }
  }

  bool _gameEnabled(AppData data) {
    if (data.config.gameEnabledOverride == true) return true;
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
            Icon(
              Symbols.wifi_off_rounded,
              size: 52,
              color: cs.onSurfaceVariant,
            ),
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
              icon: const Icon(Symbols.refresh_rounded, size: 18),
              label: const Text('Spróbuj ponownie'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _scanQr(AppData data) async {
    if (!_gameEnabled(data)) {
      setState(() => _selectedTab = _Tab.game);
      return;
    }

    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const QRScannerScreen()),
    );
    if (result == null || !mounted) return;

    // Easter-egg short-circuit before the regular checkpoint flow.
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
