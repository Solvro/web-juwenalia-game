import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../services/data_service.dart';
import '../theme/app_theme.dart';
import 'field_game_screen.dart';
import 'map_screen.dart';
import 'news_screen.dart';
import 'schedule_screen.dart';

/// Main 4-tab shell matching the Stitch bottom navigation:
/// Aktualności · Harmonogram · Mapa · Gra Terenowa
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

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppData>(
      future: _dataFuture,
      builder: (context, snapshot) {
        return Scaffold(
          backgroundColor: AppTheme.surfaceContainerLowestOf(context),
          body: _buildBody(snapshot),
          bottomNavigationBar: _buildNav(context),
        );
      },
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

  NavigationBar _buildNav(BuildContext context) {
    return NavigationBar(
      selectedIndex: _tabIndex,
      onDestinationSelected: (i) => setState(() => _tabIndex = i),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.newspaper_outlined),
          selectedIcon: Icon(Icons.newspaper_rounded),
          label: 'Aktualności',
        ),
        NavigationDestination(
          icon: Icon(Icons.calendar_today_outlined),
          selectedIcon: Icon(Icons.calendar_today_rounded),
          label: 'Harmonogram',
        ),
        NavigationDestination(
          icon: Icon(Icons.map_outlined),
          selectedIcon: Icon(Icons.map_rounded),
          label: 'Mapa',
        ),
        NavigationDestination(
          icon: Icon(Icons.sports_esports_outlined),
          selectedIcon: Icon(Icons.sports_esports_rounded),
          label: 'Gra',
        ),
      ],
    );
  }
}
