import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../models/models.dart';
import '../services/data_service.dart';
import '../theme/app_theme.dart';
import '../widgets/brand_gradient.dart';

/// News feed tab — matches Stitch "Aktualności" screen.
class NewsScreen extends StatelessWidget {
  const NewsScreen({super.key, required this.data, required this.onRefresh});

  final AppData data;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      color: cs.primaryContainer,
      backgroundColor: AppTheme.surfaceContainerHighOf(context),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          _buildHeader(context, cs, isDark),
          if (data.news.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Text(
                  'Brak aktualności',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              sliver: SliverList.separated(
                itemCount: data.news.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, i) =>
                    _buildNewsCard(context, data.news[i], cs),
              ),
            ),
        ],
      ),
    );
  }

  SliverAppBar _buildHeader(BuildContext context, ColorScheme cs, bool isDark) {
    return SliverAppBar(
      expandedHeight: 160,
      pinned: true,
      stretch: true,
      backgroundColor: AppTheme.surfaceContainerLowestOf(context),
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.fromLTRB(20, 0, 16, 14),
        // Keep the collapsed title to a single short line — the rich
        // composition (eyebrow + heading + brand bar) lives in `background`
        // and only shows when the bar is expanded.
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: BrandGradientText(
                '#wrocławrazem',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
            ),
            if (data.isFromCache) ...[
              const SizedBox(width: 8),
              _buildOfflineBadge(cs),
            ],
          ],
        ),
        background: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [
                          AppTheme.brandCyan.withValues(alpha: 0.18),
                          AppTheme.brandGreen.withValues(alpha: 0.06),
                          AppTheme.surfaceContainerLowestOf(context),
                        ]
                      : [
                          AppTheme.brandCyan.withValues(alpha: 0.12),
                          AppTheme.brandGreen.withValues(alpha: 0.05),
                          AppTheme.surfaceContainerLowestOf(context),
                        ],
                ),
              ),
            ),
            Positioned(
              left: 20,
              right: 16,
              bottom: 56,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  BrandGradientText(
                    'JUWENALIA #WrocławRazem',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2.4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const BrandGradientBar(width: 36),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOfflineBadge(ColorScheme cs) {
    return Container(
      margin: const EdgeInsets.only(right: 4),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: cs.secondaryContainer.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: cs.secondary.withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.wifi_off_rounded, size: 10, color: cs.secondary),
          const SizedBox(width: 2),
          Text(
            'OFFLINE',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 8,
              fontWeight: FontWeight.w700,
              color: cs.secondary,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNewsCard(BuildContext context, NewsItem item, ColorScheme cs) {
    final surfHigh = AppTheme.surfaceContainerHighOf(context);
    final dateStr = _formatDate(item.date);
    final catColor = _newsCategoryColor(item.category, context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfHigh,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: catColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  _newsCategoryLabel(item.category),
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: catColor,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                dateStr,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            item.title,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            item.body,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              color: cs.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    try {
      return DateFormat('d MMM yyyy', 'pl').format(dt);
    } catch (_) {
      return DateFormat('d MMM yyyy').format(dt);
    }
  }

  String _newsCategoryLabel(String cat) {
    switch (cat) {
      case 'lineup':
        return 'LINE-UP';
      case 'tickets':
        return 'BILETY';
      case 'schedule':
        return 'HARMONOGRAM';
      case 'game':
        return 'GRA';
      case 'info':
        return 'INFO';
      default:
        return 'OGÓLNE';
    }
  }

  Color _newsCategoryColor(String cat, BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    switch (cat) {
      case 'lineup':
        return isDark ? const Color(0xFFFFB963) : const Color(0xFF7B5800);
      case 'tickets':
        return isDark ? const Color(0xFF9DDFB0) : const Color(0xFF1D6B3A);
      case 'schedule':
        return isDark ? const Color(0xFF88CEFF) : const Color(0xFF006590);
      case 'game':
        return isDark ? const Color(0xFFD4AAFF) : const Color(0xFF6B3FA0);
      default:
        return isDark ? const Color(0xFFBEC8D2) : const Color(0xFF42474E);
    }
  }
}
