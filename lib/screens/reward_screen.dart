import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../services/data_service.dart';
import '../theme/app_theme.dart';

/// Reward & congratulations screen — theme-aware.
class RewardScreen extends StatelessWidget {
  const RewardScreen({
    super.key,
    required this.data,
    required this.completed,
    required this.isLocked,
    required this.onLock,
  });

  final AppData data;
  final List<String> completed;
  final bool isLocked;
  final Future<void> Function() onLock;

  int get _validCompleted => completed
      .where((id) => data.checkpoints.any((c) => c.id.toString() == id))
      .length;

  bool get _canClaim => _validCompleted >= data.goal && !isLocked;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: AppTheme.surfaceContainerLowestOf(context),
      body: CustomScrollView(
        slivers: [
          _buildAppBar(context, cs),
          SliverFillRemaining(
            hasScrollBody: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 48),
              child: _buildContent(context, cs),
            ),
          ),
        ],
      ),
    );
  }

  SliverAppBar _buildAppBar(BuildContext context, ColorScheme cs) {
    return SliverAppBar(
      pinned: true,
      backgroundColor: AppTheme.surfaceContainerLowestOf(context),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded),
        color: cs.onSurface,
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        'Nagroda',
        style: GoogleFonts.spaceGrotesk(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: cs.onSurface,
          letterSpacing: -0.3,
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, ColorScheme cs) {
    return Column(
      children: [
        const SizedBox(height: 8),
        _buildProgressCircle(cs)
            .animate()
            .scale(
              begin: const Offset(0.6, 0.6),
              end: const Offset(1, 1),
              duration: 500.ms,
              curve: Curves.elasticOut,
            )
            .fadeIn(duration: 300.ms),
        const SizedBox(height: 28),
        Text(
              isLocked
                  ? '✅ Nagrodę już odebrano'
                  : _canClaim
                  ? '🎉 Odblokowano nagrodę!'
                  : 'Zbierz jeszcze pieczątki',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: isLocked
                    ? cs.onSurfaceVariant
                    : _canClaim
                    ? cs.secondary
                    : cs.onSurface,
                letterSpacing: -0.5,
              ),
              textAlign: TextAlign.center,
            )
            .animate(delay: 150.ms)
            .fadeIn(duration: 350.ms)
            .slideY(begin: 0.1, end: 0, duration: 350.ms),
        const SizedBox(height: 12),
        Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surfaceContainerHighOf(context),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                data.rewardDescription,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  color: cs.onSurface,
                  height: 1.6,
                ),
                textAlign: TextAlign.center,
              ),
            )
            .animate(delay: 200.ms)
            .fadeIn(duration: 350.ms)
            .slideY(begin: 0.08, end: 0, duration: 350.ms),
        const Spacer(),
        if (isLocked)
          _buildLockedQR(cs)
        else if (_canClaim)
          _buildClaimButton(context, cs)
        else
          _buildNotEnoughPoints(context, cs),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildProgressCircle(ColorScheme cs) {
    final progress = (data.goal > 0)
        ? (_validCompleted / data.goal).clamp(0.0, 1.0)
        : 0.0;
    final done = _validCompleted >= data.goal || isLocked;

    return SizedBox(
      width: 160,
      height: 160,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 160,
            height: 160,
            child: CircularProgressIndicator(
              value: 1,
              strokeWidth: 10,
              color: cs.outlineVariant,
            ),
          ),
          SizedBox(
            width: 160,
            height: 160,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: progress),
              duration: const Duration(milliseconds: 1000),
              curve: Curves.easeOutCubic,
              builder: (_, v, _) => CircularProgressIndicator(
                value: v,
                strokeWidth: 10,
                strokeCap: StrokeCap.round,
                valueColor: AlwaysStoppedAnimation<Color>(
                  done ? cs.secondary : cs.primaryContainer,
                ),
              ),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$_validCompleted',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 42,
                  fontWeight: FontWeight.w900,
                  color: done ? cs.secondary : cs.primary,
                  height: 1,
                ),
              ),
              Text(
                '/ ${data.goal}',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildClaimButton(BuildContext context, ColorScheme cs) {
    return Column(
      children: [
        FilledButton.icon(
          onPressed: () => _confirmClaim(context, cs),
          icon: const Icon(Icons.card_giftcard_rounded, size: 20),
          label: const Text('Odbierz nagrodę'),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            backgroundColor: cs.secondary,
            foregroundColor: cs.onSecondary,
            textStyle: GoogleFonts.spaceGrotesk(
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Udaj się do Punktu Informacyjnego, aby pokazać kod QR',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            color: cs.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildNotEnoughPoints(BuildContext context, ColorScheme cs) {
    final remaining = data.goal - _validCompleted;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerHighOf(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.sports_esports_rounded, color: cs.primary, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Odwiedź jeszcze $remaining ${_pluralStrefa(remaining)}, by odblokować nagrodę',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                color: cs.onSurface,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLockedQR(ColorScheme cs) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: QrImageView(
            data: 'Juwenalia PWr - $_validCompleted pkt.',
            version: QrVersions.auto,
            size: 180,
            backgroundColor: Colors.white,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Pokaż ten kod przy Punkcie Informacyjnym',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            color: cs.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  void _confirmClaim(BuildContext context, ColorScheme cs) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Odbierz nagrodę'),
        content: const Text(
          'Czy na pewno chcesz odebrać nagrodę? '
          'Aplikacja wyświetli kod QR, który zostanie zablokowany po użyciu.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Anuluj'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              await onLock();
            },
            style: FilledButton.styleFrom(
              backgroundColor: cs.secondary,
              foregroundColor: cs.onSecondary,
            ),
            child: const Text('Odbierz'),
          ),
        ],
      ),
    );
  }

  String _pluralStrefa(int n) {
    if (n == 1) return 'strefę';
    if (n >= 2 && n <= 4) return 'strefy';
    return 'stref';
  }
}
