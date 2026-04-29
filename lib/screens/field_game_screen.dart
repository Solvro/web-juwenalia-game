import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:url_launcher/url_launcher.dart';

import '../checkpoint.dart';
import '../services/data_service.dart';
import '../theme/app_theme.dart';
import '../theme/elements.dart';
import '../widgets/app_network_image.dart';
import '../widgets/section_header.dart';
import '../widgets/swipe_down_dismissible.dart';
import 'checkpoint_details_screen.dart';
import 'reward_screen.dart';

class FieldGameScreen extends StatelessWidget {
  const FieldGameScreen({
    super.key,
    required this.data,
    required this.completed,
    required this.isLocked,
    required this.onLockReward,
    required this.onRefresh,
  });

  final AppData data;
  final List<String> completed;
  final bool isLocked;
  final Future<void> Function() onLockReward;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final palette = AppElements.water;

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: palette.base,
      backgroundColor: AppTheme.surfaceContainerHighOf(context),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          _buildHeader(context, cs, palette),
          _buildDescription(context, cs),
          _buildProgressSliver(context, cs, palette),
          _buildCheckpointSliver(context, cs, palette),
        ],
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    ColorScheme cs,
    ElementPalette palette,
  ) {
    final hasTerms = data.config.gameTerms.trim().isNotEmpty;

    return SectionHeader(
      supertitle: 'GRA TERENOWA',
      title: 'Spróbuj wszystkiego',
      palette: palette,
      actions: hasTerms
          ? [
              IconButton(
                icon: const Icon(Symbols.info_rounded, size: 22),
                color: palette.base,
                tooltip: 'Zasady gry',
                onPressed: () => _showGameTerms(context, palette),
              ),
            ]
          : null,
    );
  }

  void _showGameTerms(BuildContext context, ElementPalette palette) {
    final cs = Theme.of(context).colorScheme;
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
        backgroundColor: AppTheme.surfaceContainerOf(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520, maxHeight: 640),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 20, 10, 6),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: palette.linearGradient,
                      ),
                      child: const Icon(
                        Symbols.sports_esports_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Zasady gry',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          color: cs.onSurface,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(dialogCtx),
                      icon: const Icon(Symbols.close_rounded),
                      color: cs.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(22, 16, 22, 20),
                  child: Html(
                    data: data.config.gameTerms,
                    onLinkTap: (url, _, _) {
                      if (url == null) return;
                      launchUrl(
                        Uri.parse(url),
                        mode: LaunchMode.externalApplication,
                      );
                    },
                    style: {
                      'body': Style(
                        margin: Margins.zero,
                        padding: HtmlPaddings.zero,
                        fontSize: FontSize(14),
                        lineHeight: const LineHeight(1.6),
                        color: cs.onSurface,
                      ),
                      'p': Style(margin: Margins.only(bottom: 10)),
                      'a': Style(
                        color: palette.base,
                        textDecoration: TextDecoration.underline,
                      ),
                      'li': Style(margin: Margins.only(bottom: 6)),
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  SliverToBoxAdapter _buildDescription(BuildContext context, ColorScheme cs) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Text(
          'Odwiedź strefy na terenie festiwalu, zeskanuj kody QR '
          'i zgarnij nagrody. Spróbuj wszystkiego!',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            color: cs.onSurfaceVariant,
            height: 1.5,
          ),
        ),
      ).animate().fadeIn(duration: 300.ms),
    );
  }

  SliverToBoxAdapter _buildProgressSliver(
    BuildContext context,
    ColorScheme cs,
    ElementPalette palette,
  ) {
    if (data.config.gameGoal <= 0) {
      return const SliverToBoxAdapter(child: SizedBox());
    }

    final validCount = completed
        .where((qr) => data.checkpoints.any((c) => c.qrCode == qr))
        .length;
    final progress = (validCount / data.config.gameGoal).clamp(0.0, 1.0);
    final done = validCount >= data.config.gameGoal;

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
                              strokeAlign: BorderSide.strokeAlignOutside,
                            )
                          : null,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              isLocked
                                  ? '🏆 Nagroda odebrana'
                                  : done
                                  ? '🎉 Cel osiągnięty!'
                                  : 'Twój postęp',
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
                              isLocked
                                  ? Symbols.verified_rounded
                                  : done
                                  ? Symbols.emoji_events_rounded
                                  : Symbols.chevron_right_rounded,
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
                                ' / ${data.config.gameGoal} stref',
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
                                    decoration: BoxDecoration(
                                      gradient: palette.linearGradient,
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

  SliverPadding _buildCheckpointSliver(
    BuildContext context,
    ColorScheme cs,
    ElementPalette palette,
  ) {
    final checkpoints = data.checkpoints;

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 120),
      sliver: SliverList.separated(
        itemCount: checkpoints.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, i) =>
            _buildCheckpointCard(context, checkpoints[i], cs, palette),
      ),
    );
  }

  Widget _buildCheckpointCard(
    BuildContext context,
    Checkpoint cp,
    ColorScheme cs,
    ElementPalette palette,
  ) {
    final isCompleted = completed.contains(cp.qrCode);
    final surfHigh = AppTheme.surfaceContainerHighOf(context);
    final surfHighest = AppTheme.surfaceContainerHighestOf(context);
    final surfLowest = AppTheme.surfaceContainerLowestOf(context);

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        swipeDownPageRoute(
          (_) => CheckpointDetailsScreen(
            checkpoint: cp,
            isCompleted: isCompleted,
            data: data,
          ),
        ),
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          color: surfHigh,
          borderRadius: BorderRadius.circular(16),
          border: isCompleted
              ? Border.all(
                  color: palette.base.withValues(alpha: 0.5),
                  width: 1.5,
                  strokeAlign: BorderSide.strokeAlignOutside,
                )
              : null,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Stack(
              children: [
                SizedBox(
                  height: 150,
                  width: double.infinity,
                  child: Hero(
                    tag: 'cp_image_${cp.id}',
                    child: AppNetworkImage(
                      url: cp.image,
                      fit: BoxFit.cover,
                      placeholder: Container(
                        color: surfHighest,
                        child: const Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      ),
                      errorWidget: Container(
                        color: surfHighest,
                        child: Icon(
                          Symbols.image_not_supported,
                          size: 32,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ),
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
                      cp.categoryLabel,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color:
                            parseHexColor(cp.categoryColor) ??
                            cs.onSurfaceVariant,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
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
                              color: palette.base,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Symbols.check_rounded,
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
                          color: isCompleted ? palette.base : cs.onSurface,
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
                  if (cp.location.trim().isNotEmpty ||
                      cp.time.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (cp.location.trim().isNotEmpty) ...[
                          Icon(
                            Symbols.location_on,
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
                        ],
                        if (cp.time.trim().isNotEmpty) ...[
                          if (cp.location.trim().isNotEmpty)
                            const SizedBox(width: 10),
                          Icon(
                            Symbols.schedule,
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
