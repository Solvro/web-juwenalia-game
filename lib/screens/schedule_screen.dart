import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/models.dart';
import '../services/data_service.dart';
import '../theme/app_theme.dart';
import '../theme/elements.dart';
import '../widgets/app_network_image.dart';
import '../widgets/section_header.dart';

/// Koncerty tab — fire element. Day tabs, current-event auto-scroll,
/// past events dimmed.
class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key, required this.data});

  final AppData data;

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late final Map<String, GlobalKey> _eventKeys;

  @override
  void initState() {
    super.initState();
    final days = widget.data.schedule;
    final todayIdx = _findTodayIndex(days);
    _tabController = TabController(
      length: days.length,
      vsync: this,
      initialIndex: todayIdx < 0 ? 0 : todayIdx,
    );

    _eventKeys = {
      for (final day in days)
        for (final e in day.events) e.id: GlobalKey(),
    };

    // Scroll to the currently-happening event after first frame.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted || todayIdx < 0) return;
      _scrollToCurrent(days[todayIdx]);
    });
  }

  int _findTodayIndex(List<ScheduleDay> days) {
    final now = DateTime.now();
    for (var i = 0; i < days.length; i++) {
      final firstStart = days[i].events
          .map((e) => e.startTime)
          .whereType<DateTime>()
          .firstOrNull;
      if (firstStart == null) continue;
      if (firstStart.year == now.year &&
          firstStart.month == now.month &&
          firstStart.day == now.day) {
        return i;
      }
    }
    return -1;
  }

  void _scrollToCurrent(ScheduleDay day) {
    final now = DateTime.now();
    final target = day.events.firstWhere(
      (e) {
        final end = e.endTime ?? e.startTime;
        if (end == null) return false;
        return end.isAfter(now);
      },
      orElse: () => day.events.isNotEmpty
          ? day.events.last
          : const ScheduleEvent(
              id: '',
              artist: '',
              genre: '',
              stage: '',
              time: '',
              imageUrl: '',
            ),
    );

    final key = _eventKeys[target.id];
    final ctx = key?.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 500),
      alignment: 0.1,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _getWeekday(String label) {
    final datePart = label.split(',').first;
    final date = DateTime.tryParse(datePart);
    if (date != null) {
      switch (date.weekday) {
        case DateTime.monday:
          return 'Poniedziałek';
        case DateTime.tuesday:
          return 'Wtorek';
        case DateTime.wednesday:
          return 'Środa';
        case DateTime.thursday:
          return 'Czwartek';
        case DateTime.friday:
          return 'Piątek';
        case DateTime.saturday:
          return 'Sobota';
        case DateTime.sunday:
          return 'Niedziela';
      }
    }
    return datePart;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final days = widget.data.schedule;
    final palette = AppElements.fire;

    if (days.isEmpty) {
      return Center(
        child: Text(
          'Harmonogram niedostępny',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      );
    }

    final tabBar = TabBar(
      controller: _tabController,
      isScrollable: true,
      tabAlignment: TabAlignment.start,
      padding: EdgeInsets.zero,
      labelPadding: const EdgeInsets.symmetric(horizontal: 16),
      labelColor: palette.base,
      unselectedLabelColor: cs.onSurfaceVariant,
      labelStyle: GoogleFonts.spaceGrotesk(
        fontWeight: FontWeight.w700,
        fontSize: 13,
      ),
      unselectedLabelStyle: GoogleFonts.spaceGrotesk(
        fontWeight: FontWeight.w500,
        fontSize: 13,
      ),
      indicator: UnderlineTabIndicator(
        borderSide: BorderSide(color: palette.base, width: 3),
        insets: const EdgeInsets.symmetric(horizontal: 16),
      ),
      dividerHeight: 0,
      tabs: days.map((d) => Tab(text: _getWeekday(d.label))).toList(),
    );

    return NestedScrollView(
      headerSliverBuilder: (context, innerBoxIsScrolled) => [
        SectionHeader(
          supertitle: 'KONCERTY',
          title: 'Juwenalia 2026',
          palette: palette,
          bottom: tabBar,
        ),
      ],
      body: TabBarView(
        controller: _tabController,
        children: [
          for (var i = 0; i < days.length; i++)
            _buildDayList(context, days[i], cs, palette, i),
        ],
      ),
    );
  }

  Widget _buildDayList(
    BuildContext context,
    ScheduleDay day,
    ColorScheme cs,
    ElementPalette palette,
    int dayIndex,
  ) {
    final now = DateTime.now();
    return CustomScrollView(
      key: PageStorageKey<String>(day.label),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              ...day.events.map((e) {
                final isPast = _isPast(e, now);
                return Padding(
                  key: _eventKeys[e.id],
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Opacity(
                    opacity: isPast ? 0.45 : 1.0,
                    child: _buildEventCard(context, e, cs, palette, isPast),
                  ),
                );
              }),
            ]),
          ),
        ),
      ],
    );
  }

  bool _isPast(ScheduleEvent e, DateTime now) {
    final end = e.endTime ?? e.startTime;
    if (end == null) return false;
    return end.isBefore(now);
  }

  bool _isLive(ScheduleEvent e, DateTime now) {
    final start = e.startTime;
    final end = e.endTime ?? start?.add(const Duration(minutes: 45));
    if (start == null || end == null) return false;
    return now.isAfter(start) && now.isBefore(end);
  }

  Widget _buildEventCard(
    BuildContext context,
    ScheduleEvent event,
    ColorScheme cs,
    ElementPalette palette,
    bool isPast,
  ) {
    final now = DateTime.now();
    final live = _isLive(event, now);
    final displayArtist = event.artist.trim().isEmpty
        ? 'Artysta wkrótce'
        : event.artist;
    final surfHigh = AppTheme.surfaceContainerHighOf(context);
    final surfHighest = AppTheme.surfaceContainerHighestOf(context);

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: surfHigh,
        borderRadius: BorderRadius.circular(14),
        border: live ? Border.all(color: palette.base, width: 1.5) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (event.imageUrl.isNotEmpty)
            SizedBox(
              height: 160,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  AppNetworkImage(
                    url: event.imageUrl,
                    fit: BoxFit.cover,
                    placeholder: Container(color: surfHighest),
                    errorWidget: Container(color: surfHighest),
                  ),
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
                  Positioned(
                    top: 10,
                    right: 12,
                    child: _timeBadge(event.time, palette),
                  ),
                  if (live)
                    Positioned(top: 10, left: 12, child: _liveBadge(palette)),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (event.imageUrl.isEmpty) ...[
                      _timeBadge(event.time, palette),
                      const SizedBox(width: 8),
                      if (live) _liveBadge(palette),
                    ],
                  ],
                ),
                if (event.imageUrl.isEmpty) const SizedBox(height: 8),
                Text(
                  displayArtist,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: cs.onSurface,
                    letterSpacing: -0.3,
                  ),
                ),
                if (event.stage.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 13,
                        color: cs.onSurfaceVariant,
                      ),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          event.stage,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _timeBadge(String time, ElementPalette palette) {
    if (time.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        gradient: palette.linearGradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        time,
        style: GoogleFonts.spaceGrotesk(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _liveBadge(ElementPalette palette) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: palette.base,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            'NA ŻYWO',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}
