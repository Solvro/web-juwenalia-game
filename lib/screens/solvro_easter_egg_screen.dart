import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_theme.dart';

class SolvroEasterEggScreen extends StatefulWidget {
  const SolvroEasterEggScreen({super.key});

  @override
  State<SolvroEasterEggScreen> createState() => _SolvroEasterEggScreenState();
}

class _SolvroEasterEggScreenState extends State<SolvroEasterEggScreen>
    with SingleTickerProviderStateMixin {
  static const _duration = Duration(seconds: 30);
  static const _initialDotLifetime = Duration(milliseconds: 1800);
  static const _minDotLifetime = Duration(milliseconds: 750);
  static const _initialSpawnInterval = Duration(milliseconds: 800);
  static const _minSpawnInterval = Duration(milliseconds: 320);
  static const _initialLives = 3;
  static const _bestScorePrefsKey = 'solvro_easter_egg_best_score';

  final _rng = Random();
  final _dots = <_Dot>[];
  int _score = 0;
  int _lives = _initialLives;
  int _bestScore = 0;
  bool _running = true;
  late DateTime _startedAt;
  late DateTime _endsAt;
  int? _frozenSeconds;
  Timer? _spawner;
  Timer? _ticker;

  double get _difficulty {
    final elapsed = DateTime.now().difference(_startedAt).inMilliseconds;
    return (elapsed / _duration.inMilliseconds).clamp(0.0, 1.0);
  }

  Duration get _dotLifetime {
    final t = _difficulty;
    final ms = lerpDouble(
      _initialDotLifetime.inMilliseconds,
      _minDotLifetime.inMilliseconds,
      t,
    )!;
    return Duration(milliseconds: ms.round());
  }

  @override
  void initState() {
    super.initState();
    _startedAt = DateTime.now();
    _endsAt = _startedAt.add(_duration);
    _loadBestScore();
    _scheduleSpawn(_initialSpawnInterval);
    _ticker = Timer.periodic(const Duration(milliseconds: 80), (_) {
      if (!mounted) return;
      final now = DateTime.now();
      final lifetime = _dotLifetime;
      final wasRunning = _running;
      setState(() {
        _dots.removeWhere((d) {
          if (now.isAfter(d.bornAt.add(lifetime))) {
            if (_running) _lives = (_lives - 1).clamp(0, 99);
            return true;
          }
          return false;
        });
        if (_running && (_lives <= 0 || now.isAfter(_endsAt))) {
          _running = false;
          _frozenSeconds = _endsAt
              .difference(now)
              .inSeconds
              .clamp(0, _duration.inSeconds);
        }
      });
      if (wasRunning && !_running) {
        _spawner?.cancel();
        _maybePersistBestScore();
      }
    });
  }

  Future<void> _loadBestScore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() => _bestScore = prefs.getInt(_bestScorePrefsKey) ?? 0);
    } catch (_) {}
  }

  Future<void> _maybePersistBestScore() async {
    if (_score <= _bestScore) return;
    final newBest = _score;
    setState(() => _bestScore = newBest);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_bestScorePrefsKey, newBest);
    } catch (_) {}
  }

  void _scheduleSpawn(Duration delay) {
    _spawner?.cancel();
    _spawner = Timer(delay, () {
      if (!mounted) return;
      if (_running) setState(_spawnDot);
      final nextMs = lerpDouble(
        _initialSpawnInterval.inMilliseconds,
        _minSpawnInterval.inMilliseconds,
        _difficulty,
      )!;
      _scheduleSpawn(Duration(milliseconds: nextMs.round()));
    });
  }

  @override
  void dispose() {
    _spawner?.cancel();
    _ticker?.cancel();
    super.dispose();
  }

  void _spawnDot() {
    _dots.add(
      _Dot(
        id: _rng.nextInt(1 << 30),
        dx: _rng.nextDouble(),
        dy: 0.08 + _rng.nextDouble() * 0.8,
        hue: _rng.nextInt(360),
        bornAt: DateTime.now(),
      ),
    );
  }

  void _hit(_Dot dot) {
    if (!_running) return;
    setState(() {
      _dots.removeWhere((d) => d.id == dot.id);
      _score += 1;
    });
  }

  void _restart() {
    setState(() {
      _score = 0;
      _lives = _initialLives;
      _dots.clear();
      _running = true;
      _frozenSeconds = null;
      _startedAt = DateTime.now();
      _endsAt = _startedAt.add(_duration);
    });
    _scheduleSpawn(_initialSpawnInterval);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final seconds = _running
        ? _endsAt.difference(now).inSeconds.clamp(0, _duration.inSeconds)
        : (_frozenSeconds ?? 0);

    return Scaffold(
      backgroundColor: AppTheme.surfaceContainerLowestOf(context),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Symbols.close_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'kochamsolvro ♥',
          style: GoogleFonts.spaceGrotesk(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/solvro_bg.png',
            fit: BoxFit.cover,
            alignment: Alignment.center,
          ),
          Container(color: Colors.black.withValues(alpha: 0.35)),
          SafeArea(
            child: Column(
              children: [
                _scoreBar(cs, seconds),
                const SizedBox(height: 8),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _running ? () {} : null,
                        child: Stack(
                          children: [
                            for (final dot in _dots)
                              _buildDot(dot, constraints),
                            // Lives stay parked in the bottom-right
                            // corner so the top score row stays clean
                            // and players track their remaining hearts
                            // near where their thumb already is.
                            Positioned(
                              right: 20,
                              bottom: 16,
                              child: IgnorePointer(child: _livesIndicator(cs)),
                            ),
                            if (!_running) _buildGameOver(cs),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 18),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _scoreBar(ColorScheme cs, int seconds) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 6,
        children: [
          _chip('WYNIK', _score.toString(), cs),
          _chip('REKORD', _bestScore.toString(), cs),
          _chip('CZAS', '${seconds}s', cs),
        ],
      ),
    );
  }

  Widget _livesIndicator(ColorScheme cs) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(_initialLives, (i) {
        final on = i < _lives;
        return Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Icon(
            Symbols.favorite_rounded,
            color: on
                ? const Color(0xFFE91E63)
                : cs.onSurfaceVariant.withValues(alpha: 0.4),
            size: 22,
            fill: on ? 1 : 0,
          ),
        );
      }),
    );
  }

  Widget _chip(String label, String value, ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: cs.onSurfaceVariant,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            value,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: cs.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDot(_Dot dot, BoxConstraints constraints) {
    final w = constraints.maxWidth;
    final h = constraints.maxHeight;
    const size = 64.0;
    final elapsed =
        DateTime.now().difference(dot.bornAt).inMilliseconds /
        _dotLifetime.inMilliseconds;
    final fade = (1.0 - elapsed).clamp(0.0, 1.0);

    return Positioned(
      left: (w - size) * dot.dx,
      top: (h - size) * dot.dy,
      child: GestureDetector(
        onTap: () => _hit(dot),
        child: Opacity(
          opacity: fade,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  HSLColor.fromAHSL(1, dot.hue.toDouble(), 0.9, 0.6).toColor(),
                  HSLColor.fromAHSL(1, dot.hue.toDouble(), 0.9, 0.4).toColor(),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: HSLColor.fromAHSL(
                    0.6,
                    dot.hue.toDouble(),
                    0.9,
                    0.55,
                  ).toColor(),
                  blurRadius: 18,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Center(
              child: Text(
                '♥',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 26,
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGameOver(ColorScheme cs) {
    final isNewBest = _score > 0 && _score >= _bestScore;
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.55),
        alignment: Alignment.center,
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _lives > 0 ? 'Czas minął!' : 'Koniec gry',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Wynik: $_score',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                isNewBest && _score > 0
                    ? '🏆 Nowy rekord!'
                    : 'Rekord: $_bestScore',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isNewBest
                      ? const Color(0xFFFFC857)
                      : Colors.white.withValues(alpha: 0.75),
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: _restart,
                icon: const Icon(Symbols.replay_rounded),
                label: const Text('Zagraj jeszcze raz'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Dot {
  _Dot({
    required this.id,
    required this.dx,
    required this.dy,
    required this.hue,
    required this.bornAt,
  });

  final int id;
  final double dx;
  final double dy;
  final int hue;
  final DateTime bornAt;
}
