import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../services/data_service.dart';
import '../theme/app_theme.dart';
import '../widgets/desktop_sidebar.dart';
import '../widgets/glass_bottom_nav.dart';
import '../widgets/platform_utils.dart';
import 'checkpoint_details_screen.dart';
import 'field_game_screen.dart';
import 'map_screen.dart';
import 'news_screen.dart';
import 'qr_scanner_screen.dart';
import 'schedule_screen.dart';

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

class _MainShellState extends State<MainShell> {
  int _tabIndex = 0;
  late Future<AppData> _dataFuture;
  List<String> _completed = [];
  bool _isLocked = false;
  bool _imagesPrecached = false;

  static const _destinations = <NavDestination>[
    NavDestination(
      icon: Icons.newspaper_outlined,
      selectedIcon: Icons.newspaper_rounded,
      label: 'Aktualności',
    ),
    NavDestination(
      icon: Icons.calendar_today_outlined,
      selectedIcon: Icons.calendar_today_rounded,
      label: 'Harmonogram',
    ),
    NavDestination(
      icon: Icons.map_outlined,
      selectedIcon: Icons.map_rounded,
      label: 'Mapa',
    ),
    NavDestination(
      icon: Icons.sports_esports_outlined,
      selectedIcon: Icons.sports_esports_rounded,
      label: 'Gra',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _refresh();
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _completed = prefs.getStringList('completedCheckpoints') ?? [];
      _isLocked = prefs.getBool('isLocked') ?? false;
    });
  }

  void _refresh() {
    setState(() {
      _imagesPrecached = false;
      _dataFuture = fetchData(http.Client());
    });
  }

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

    return Scaffold(
      backgroundColor: AppTheme.surfaceContainerLowestOf(context),
      // We render the nav over the body for the iOS liquid-glass look.
      extendBody: true,
      body: _buildBody(snapshot),
      bottomNavigationBar: GlassBottomNav(
        selectedIndex: _tabIndex,
        onSelect: (i) => setState(() => _tabIndex = i),
        onScanQr: data == null ? () {} : () => _scanQr(data),
        destinations: _destinations,
      ),
    );
  }

  // ── Desktop shell ──────────────────────────────────────────────────────────

  Widget _buildDesktopShell(AsyncSnapshot<AppData> snapshot) {
    final data = snapshot.data;

    return Scaffold(
      backgroundColor: AppTheme.surfaceContainerLowestOf(context),
      body: Row(
        children: [
          DesktopSidebar(
            selectedIndex: _tabIndex,
            onSelect: (i) => setState(() => _tabIndex = i),
            onScanQr: data == null ? () {} : () => _scanQr(data),
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
        return NewsScreen(data: data, onRefresh: _refresh);
      case 1:
        return ScheduleScreen(data: data);
      case 2:
        return MapScreen(data: data);
      case 3:
        return FieldGameScreen(
          data: data,
          completed: _completed,
          isLocked: _isLocked,
          onUnlock: _unlockCheckpoint,
          onLockReward: _lockReward,
          onRefresh: _refresh,
        );
      default:
        return const SizedBox.shrink();
    }
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
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const QRScannerScreen()),
    );
    if (result == null || !mounted) return;

    final cp = data.checkpoints
        .where((c) => c.id.toString() == result)
        .firstOrNull;

    final sm = ScaffoldMessenger.of(context);
    if (cp != null) {
      await _unlockCheckpoint(result);
      if (!mounted) return;
      sm
        ..removeCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('✓ Zeskanowano: ${cp.title}'),
            action: SnackBarAction(
              label: 'Zobacz',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CheckpointDetailsScreen(
                    checkpoint: cp,
                    isCompleted: true,
                  ),
                ),
              ),
            ),
          ),
        );
    } else {
      sm
        ..removeCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Nieznany kod QR: $result')));
    }
  }
}
