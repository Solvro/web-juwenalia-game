import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/models.dart';
import '../services/data_service.dart';
import '../theme/app_theme.dart';
import '../widgets/brand_gradient.dart';

/// Schedule tab — matches Stitch "Harmonogram" screen.
/// Day-based tabs with artist cards showing genre + stage.
class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key, required this.data});

  final AppData data;

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: widget.data.schedule.length,
      vsync: this,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final days = widget.data.schedule;

    if (days.isEmpty) {
      return Center(
        child: Text(
          'Harmonogram niedostępny',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      );
    }

    return NestedScrollView(
      headerSliverBuilder: (context, innerBoxIsScrolled) => [
        SliverAppBar(
          pinned: true,
          floating: true,
          snap: true,
          expandedHeight: 130,
          backgroundColor: AppTheme.surfaceContainerLowestOf(context),
          flexibleSpace: FlexibleSpaceBar(
            titlePadding: const EdgeInsets.fromLTRB(20, 0, 16, 50),
            background: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.brandTeal.withValues(alpha: 0.14),
                    AppTheme.brandSeafoam.withValues(alpha: 0.05),
                    AppTheme.surfaceContainerLowestOf(context),
                  ],
                ),
              ),
            ),
            title: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BrandGradientText(
                  'HARMONOGRAM',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Juwenalia 2026',
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
          bottom: TabBar(
            controller: _tabController,
            labelColor: AppTheme.brandTeal,
            unselectedLabelColor: cs.onSurfaceVariant,
            labelStyle: GoogleFonts.spaceGrotesk(
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
            unselectedLabelStyle: GoogleFonts.spaceGrotesk(
              fontWeight: FontWeight.w500,
              fontSize: 13,
            ),
            indicator: const UnderlineTabIndicator(
              borderSide: BorderSide(color: AppTheme.brandTeal, width: 3),
              insets: EdgeInsets.symmetric(horizontal: 16),
            ),
            dividerHeight: 0,
            tabs: days.map((d) => Tab(text: d.label.split(',').first)).toList(),
          ),
        ),
      ],
      body: TabBarView(
        controller: _tabController,
        children: days.map((day) => _buildDayList(context, day, cs)).toList(),
      ),
    );
  }

  Widget _buildDayList(BuildContext context, ScheduleDay day, ColorScheme cs) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      children: [
        // Day header
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                day.label,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Icon(
                    Icons.location_on_rounded,
                    size: 13,
                    color: cs.onSurfaceVariant,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    day.venue,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Event cards
        ...day.events.asMap().entries.map(
          (e) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildEventCard(context, e.value, e.key, cs),
          ),
        ),
      ],
    );
  }

  Widget _buildEventCard(
    BuildContext context,
    ScheduleEvent event,
    int index,
    ColorScheme cs,
  ) {
    final surfHigh = AppTheme.surfaceContainerHighOf(context);
    final surfHighest = AppTheme.surfaceContainerHighestOf(context);

    return Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: surfHigh,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Artist image
              if (event.imageUrl.isNotEmpty)
                SizedBox(
                  height: 160,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CachedNetworkImage(
                        imageUrl: event.imageUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, _) => Container(color: surfHighest),
                        errorWidget: (_, _, _) => Container(color: surfHighest),
                      ),
                      // Gradient overlay
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        height: 80,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                surfHigh.withValues(alpha: 0.9),
                              ],
                            ),
                          ),
                        ),
                      ),
                      // Time badge
                      Positioned(
                        top: 10,
                        right: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: cs.primaryContainer,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            event.time,
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              // Info
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.artist,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: cs.onSurface,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      children: [
                        if (event.genre.isNotEmpty)
                          _chip(event.genre, cs.secondary, cs),
                        if (event.stage.isNotEmpty)
                          _chip(event.stage, cs.primary, cs),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        )
        .animate(delay: (50 * index).ms)
        .fadeIn(duration: 400.ms)
        .slideY(
          begin: 0.1,
          end: 0,
          duration: 400.ms,
          curve: Curves.easeOutCubic,
        );
  }

  Widget _chip(String label, Color color, ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: GoogleFonts.spaceGrotesk(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
