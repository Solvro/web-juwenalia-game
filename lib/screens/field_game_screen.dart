import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../checkpoint.dart';
import '../services/data_service.dart';
import '../theme/app_theme.dart';
import '../widgets/brand_gradient.dart';
import 'checkpoint_details_screen.dart';
import 'qr_scanner_screen.dart';
import 'reward_screen.dart';

/// Field Game tab — matches Stitch "Gra Terenowa" screen.
/// Checkpoint list with QR scanning, progress tracking, and rewards.
class FieldGameScreen extends StatelessWidget {
  const FieldGameScreen({
    super.key,
    required this.data,
    required this.completed,
    required this.isLocked,
    required this.onUnlock,
    required this.onLockReward,
    required this.onRefresh,
  });

  final AppData data;
  final List<String> completed;
  final bool isLocked;
  final Future<void> Function(String id) onUnlock;
  final Future<void> Function() onLockReward;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        _buildHeader(context, cs, isDark),
        _buildDescription(context, cs),
        _buildProgressSliver(context, cs),
        _buildCheckpointSliver(context, cs),
      ],
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  SliverAppBar _buildHeader(BuildContext context, ColorScheme cs, bool isDark) {
    return SliverAppBar(
      expandedHeight: 150,
      pinned: true,
      stretch: true,
      backgroundColor: AppTheme.surfaceContainerLowestOf(context),
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.fromLTRB(20, 0, 16, 14),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [
                AppTheme.brandGreen.withValues(alpha: isDark ? 0.16 : 0.10),
                AppTheme.brandTeal.withValues(alpha: isDark ? 0.06 : 0.04),
                AppTheme.surfaceContainerLowestOf(context),
              ],
            ),
          ),
        ),
        title: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  BrandGradientText(
                    'GRA TERENOWA',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Zbierz pieczątki',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: cs.onSurface,
                      letterSpacing: -0.5,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const BrandGradientBar(width: 36),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // QR scanner button
                IconButton(
                  icon: const Icon(Icons.qr_code_scanner_rounded, size: 22),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  color: cs.primary,
                  onPressed: () => _scanQR(context),
                ),
                const SizedBox(width: 4),
                // Reward button
                if (data.goal > 0)
                  IconButton(
                    icon: const Icon(Icons.card_giftcard_rounded, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    color: cs.secondary,
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RewardScreen(
                          data: data,
                          completed: completed,
                          isLocked: isLocked,
                          onLock: onLockReward,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Description ───────────────────────────────────────────────────────────

  SliverToBoxAdapter _buildDescription(BuildContext context, ColorScheme cs) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Text(
          'Rozwiąż wszystkie zadania, zbierz pieczątki i zgarnij '
          'festiwalowe nagrody. Czas ucieka!',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            color: cs.onSurfaceVariant,
            height: 1.5,
          ),
        ),
      ).animate().fadeIn(duration: 300.ms),
    );
  }

  // ── Progress ──────────────────────────────────────────────────────────────

  SliverToBoxAdapter _buildProgressSliver(
    BuildContext context,
    ColorScheme cs,
  ) {
    if (data.goal <= 0) return const SliverToBoxAdapter(child: SizedBox());

    final validCount = completed
        .where((id) => data.checkpoints.any((c) => c.id.toString() == id))
        .length;
    final progress = (validCount / data.goal).clamp(0.0, 1.0);
    final done = validCount >= data.goal;

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
        child: GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => RewardScreen(
                data: data,
                completed: completed,
                isLocked: isLocked,
                onLock: onLockReward,
              ),
            ),
          ),
          child:
              Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceContainerHighOf(context),
                      borderRadius: BorderRadius.circular(16),
                      border: done
                          ? Border.all(
                              color: cs.secondary.withValues(alpha: 0.4),
                              width: 1.5,
                            )
                          : null,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              done ? '🎉 Cel osiągnięty!' : 'Twój postęp',
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: done
                                    ? cs.secondary
                                    : cs.onSurfaceVariant,
                                letterSpacing: 0.3,
                              ),
                            ),
                            const Spacer(),
                            Icon(
                              done
                                  ? Icons.emoji_events_rounded
                                  : Icons.chevron_right_rounded,
                              size: 16,
                              color: done ? cs.secondary : cs.onSurfaceVariant,
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '$validCount',
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 32,
                                fontWeight: FontWeight.w800,
                                color: done ? cs.secondary : cs.primary,
                                height: 1,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(
                                bottom: 3,
                                left: 2,
                              ),
                              child: Text(
                                ' / ${data.goal} stref',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: progress),
                            duration: const Duration(milliseconds: 800),
                            curve: Curves.easeOutCubic,
                            builder: (_, v, _) => Stack(
                              children: [
                                Container(
                                  height: 6,
                                  color: cs.outlineVariant.withValues(
                                    alpha: 0.4,
                                  ),
                                ),
                                FractionallySizedBox(
                                  widthFactor: v,
                                  child: Container(
                                    height: 6,
                                    decoration: const BoxDecoration(
                                      gradient: AppTheme.brandGradient,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                  .animate()
                  .fadeIn(duration: 450.ms)
                  .slideY(
                    begin: 0.08,
                    end: 0,
                    duration: 450.ms,
                    curve: Curves.easeOutCubic,
                  ),
        ),
      ),
    );
  }

  // ── Checkpoint list ───────────────────────────────────────────────────────

  SliverPadding _buildCheckpointSliver(BuildContext context, ColorScheme cs) {
    final checkpoints = data.checkpoints;

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
      sliver: SliverList.separated(
        itemCount: checkpoints.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, i) =>
            _buildCheckpointCard(context, checkpoints[i], cs),
      ),
    );
  }

  Widget _buildCheckpointCard(
    BuildContext context,
    Checkpoint cp,
    ColorScheme cs,
  ) {
    final isCompleted = completed.contains(cp.id.toString());
    final surfHigh = AppTheme.surfaceContainerHighOf(context);
    final surfHighest = AppTheme.surfaceContainerHighestOf(context);
    final surfLowest = AppTheme.surfaceContainerLowestOf(context);

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              CheckpointDetailsScreen(checkpoint: cp, isCompleted: isCompleted),
        ),
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          color: surfHigh,
          borderRadius: BorderRadius.circular(16),
          border: isCompleted
              ? Border.all(
                  color: cs.primaryContainer.withValues(alpha: 0.5),
                  width: 1.5,
                )
              : null,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image
            Stack(
              children: [
                SizedBox(
                  height: 150,
                  width: double.infinity,
                  child: Hero(
                    tag: 'cp_image_${cp.id}',
                    child: CachedNetworkImage(
                      imageUrl: cp.image,
                      fit: BoxFit.cover,
                      placeholder: (_, _) => Container(
                        color: surfHighest,
                        child: const Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      ),
                      errorWidget: (_, _, _) => Container(
                        color: surfHighest,
                        child: Icon(
                          Icons.image_not_supported_outlined,
                          size: 32,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ),
                // Bottom gradient
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  height: 60,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          surfHigh.withValues(alpha: 0.85),
                        ],
                      ),
                    ),
                  ),
                ),
                // Category chip
                Positioned(
                  top: 10,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: surfLowest.withValues(alpha: 0.88),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      cp.category.categoryLabel,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: cp.category.categoryColor(context),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
                // Completion badge
                Positioned(
                  top: 10,
                  right: 12,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: isCompleted
                        ? Container(
                            key: const ValueKey('done'),
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: cs.primaryContainer,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                          )
                        : Container(
                            key: const ValueKey('todo'),
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: surfLowest.withValues(alpha: 0.75),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: cs.outlineVariant,
                                width: 1,
                              ),
                            ),
                          ),
                  ),
                ),
              ],
            ),
            // Content
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 13),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Hero(
                    tag: 'cp_title_${cp.id}',
                    child: Material(
                      type: MaterialType.transparency,
                      child: Text(
                        cp.title,
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: isCompleted ? cs.primary : cs.onSurface,
                          letterSpacing: -0.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  if (cp.subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      cp.subtitle,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: cs.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 13,
                        color: cs.onSurfaceVariant,
                      ),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(
                          cp.location,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: cs.onSurfaceVariant,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (cp.time.trim().isNotEmpty) ...[
                        const SizedBox(width: 10),
                        Icon(
                          Icons.schedule_outlined,
                          size: 13,
                          color: cs.onSurfaceVariant,
                        ),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            cp.time.trim(),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              color: cs.onSurfaceVariant,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── QR scanning ───────────────────────────────────────────────────────────

  Future<void> _scanQR(BuildContext context) async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const QRScannerScreen()),
    );
    if (result == null) return;
    if (!context.mounted) return;

    final cp = data.checkpoints
        .where((c) => c.id.toString() == result)
        .firstOrNull;

    if (cp != null) {
      await onUnlock(result);
      if (!context.mounted) return;
      final sm = ScaffoldMessenger.of(context);
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
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..removeCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Nieznany kod QR: $result')));
    }
  }
}
