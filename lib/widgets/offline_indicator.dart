import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../services/connectivity_service.dart';
import '../services/data_service.dart';

class OfflineState extends ChangeNotifier {
  OfflineState._() {
    ConnectivityService.instance.isOnline.addListener(_onConnectivityChange);
    _lastSeenOnline = ConnectivityService.instance.isOnline.value;
  }
  static final OfflineState instance = OfflineState._();

  static const Duration collapseAfter = Duration(seconds: 3);

  static const double cornerSlotWidth = 44;

  Timer? _timer;
  bool _expanded = true;
  bool? _lastSeenOnline;

  bool get expanded => _expanded;
  bool get isOnline => ConnectivityService.instance.isOnline.value;
  bool get cornerVisible => !isOnline && !_expanded;
  bool get inlineVisible => !isOnline && _expanded;

  void _onConnectivityChange() {
    final online = ConnectivityService.instance.isOnline.value;
    if (online == _lastSeenOnline) return;
    _lastSeenOnline = online;
    _timer?.cancel();
    if (online) {
      _expanded = true;
    } else {
      _expanded = true;
      _timer = Timer(collapseAfter, _collapseNow);
    }
    notifyListeners();
  }

  void _collapseNow() {
    if (_expanded) {
      _expanded = false;
      notifyListeners();
    }
  }

  void touch() {
    _timer?.cancel();
    if (!_expanded) {
      _expanded = true;
      notifyListeners();
    }
    _timer = Timer(collapseAfter, _collapseNow);
  }
}

enum OfflinePillMode { inline, corner }

class OfflinePill extends StatelessWidget {
  const OfflinePill({super.key, required this.mode});

  final OfflinePillMode mode;

  static const _animDuration = Duration(milliseconds: 240);
  static const _badgeColor = Color(0xFFF59E0B);

  void _onTap(BuildContext context) {
    showOfflineInfoDialog(context);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        ConnectivityService.instance.isOnline,
        OfflineState.instance,
      ]),
      builder: (context, _) {
        final visible = mode == OfflinePillMode.inline
            ? OfflineState.instance.inlineVisible
            : OfflineState.instance.cornerVisible;

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: mode == OfflinePillMode.inline
                    ? const Offset(0, -0.3)
                    : const Offset(0.3, -0.3),
                end: Offset.zero,
              ).animate(anim),
              child: child,
            ),
          ),
          child: visible
              ? KeyedSubtree(
                  key: ValueKey('offline-${mode.name}'),
                  child: _buildBadge(context),
                )
              : const SizedBox.shrink(key: ValueKey('hidden')),
        );
      },
    );
  }

  Widget _buildBadge(BuildContext context) {
    final expanded = mode == OfflinePillMode.inline;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () => _onTap(context),
        child: AnimatedContainer(
          duration: _animDuration,
          curve: Curves.easeOutCubic,
          padding: expanded
              ? const EdgeInsets.symmetric(horizontal: 14, vertical: 9)
              : const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _badgeColor,
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              BoxShadow(
                color: _badgeColor.withValues(alpha: 0.35),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: AnimatedSize(
            duration: _animDuration,
            curve: Curves.easeOutCubic,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Symbols.wifi_off_rounded,
                  size: 16,
                  color: Colors.white,
                ),
                if (expanded) ...const [
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> showOfflineInfoDialog(BuildContext context) async {
  final cs = Theme.of(context).colorScheme;
  await showDialog<void>(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        icon: Icon(
          Symbols.wifi_off_rounded,
          size: 36,
          color: cs.onSurfaceVariant,
        ),
        title: const Text('Jesteś offline'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Działasz obecnie w trybie offline. Niektóre funkcje mogą być niedostępne, a dane mogą być nieaktualne.',
              style: Theme.of(ctx).textTheme.bodyMedium,
            ),
            const SizedBox(height: 10),
            const _LastSyncLine(),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Zamknij'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              ConnectivityService.instance.refresh();
            },
            child: const Text('Spróbuj ponownie'),
          ),
        ],
      );
    },
  );
}

class _LastSyncLine extends StatelessWidget {
  const _LastSyncLine();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final style = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant);
    return FutureBuilder<DateTime?>(
      future: lastSyncTime(),
      builder: (context, snapshot) {
        final dt = snapshot.data;
        final text = dt == null
            ? 'Ostatnia aktualizacja: nieznana'
            : 'Ostatnia aktualizacja: ${_formatLastSync(dt)}';
        return Text(text, style: style);
      },
    );
  }

  static String _formatLastSync(DateTime dt) {
    final local = dt.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(local.year, local.month, local.day);
    final time = DateFormat.Hm().format(local);
    if (that == today) return 'dziś, $time';
    if (that == today.subtract(const Duration(days: 1))) {
      return 'wczoraj, $time';
    }
    return '${DateFormat('d MMM', 'pl').format(local)}, $time';
  }
}
