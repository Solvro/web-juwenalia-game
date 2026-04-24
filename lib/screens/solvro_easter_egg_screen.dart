import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';

/// "kochamsolvro123" easter egg. A tiny reflex game: taps on the floating
/// Solvro dots score points; misses cost a life. Unapologetically silly.
///
/// Navigate here via [Navigator.push] — the main shell triggers it from
/// the keystroke listener in [MainShell].
class SolvroEasterEggScreen extends StatefulWidget {
  const SolvroEasterEggScreen({super.key});

  @override
  State<SolvroEasterEggScreen> createState() => _SolvroEasterEggScreenState();
}

class _SolvroEasterEggScreenState extends State<SolvroEasterEggScreen>
    with SingleTickerProviderStateMixin {
  static const _duration = Duration(seconds: 30);
  static const _dotLifetime = Duration(milliseconds: 1400);

  final _rng = Random();
  final _dots = <_Dot>[];
  int _score = 0;
  int _lives = 3;
  bool _running = true;
  late DateTime _endsAt;
  Timer? _spawner;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _endsAt = DateTime.now().add(_duration);
    _spawner = Timer.periodic(const Duration(milliseconds: 650), (_) {
      if (!mounted || !_running) return;
      setState(_spawnDot);
    });
    _ticker = Timer.periodic(const Duration(milliseconds: 80), (_) {
      if (!mounted) return;
      final now = DateTime.now();
      setState(() {
        _dots.removeWhere((d) {
          if (now.isAfter(d.bornAt.add(_dotLifetime))) {
            if (_running) _lives = (_lives - 1).clamp(0, 99);
            return true;
          }
          return false;
        });
        if (_lives <= 0 || now.isAfter(_endsAt)) _running = false;
      });
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
        // Normalised position so Stack placement is size-agnostic.
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
      _lives = 3;
      _dots.clear();
      _running = true;
      _endsAt = DateTime.now().add(_duration);
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final remaining = _endsAt.difference(now);
    final seconds = remaining.inSeconds.clamp(0, _duration.inSeconds);

    return Scaffold(
      backgroundColor: AppTheme.surfaceContainerLowestOf(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
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
      body: SafeArea(
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
    );
  }

  Widget _scoreBar(ColorScheme cs, int seconds) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      child: Row(
        children: [
          _chip('WYNIK', _score.toString(), cs),
          const SizedBox(width: 10),
          _chip('CZAS', '${seconds}s', cs),
          const Spacer(),
          Row(
            children: List.generate(3, (i) {
              final on = i < _lives;
              return Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Icon(
                  on ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  color: on
                      ? const Color(0xFFE91E63)
                      : cs.onSurfaceVariant.withValues(alpha: 0.4),
                  size: 22,
                ),
              );
            }),
          ),
        ],
      ),
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
                  color: HSLColor.fromAHSL(0.6, dot.hue.toDouble(), 0.9, 0.55)
                      .toColor(),
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
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: _restart,
                icon: const Icon(Icons.replay_rounded),
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
