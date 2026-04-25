import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../checkpoint.dart';
import '../models/models.dart';
import '../services/data_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_network_image.dart';
import '../widgets/festival_plan_map.dart';
import '../widgets/swipe_down_dismissible.dart';

class CheckpointDetailsScreen extends StatelessWidget {
  const CheckpointDetailsScreen({
    super.key,
    required this.checkpoint,
    required this.isCompleted,
    this.data,
  });

  final Checkpoint checkpoint;
  final bool isCompleted;

  /// Full app payload — used to look up the checkpoint's [MapPoint] for
  /// the mini-map and to source [PlanBounds] without duplicating them
  /// onto the checkpoint itself. Optional because some legacy entry
  /// points (easter-egg flows, etc.) push without [AppData] in hand.
  final AppData? data;

  MapPoint? get _locationPin {
    final d = data;
    final locId = checkpoint.locationId;
    if (d == null || locId == null) return null;
    for (final p in d.mapPoints) {
      if (p.id == locId && p.lat != null && p.lng != null) return p;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: AppTheme.surfaceContainerLowestOf(context),
      body: SwipeDownDismissible(
        builder: (context, offset, progress) => Opacity(
          opacity: 1.0 - progress * 0.35,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: ClampingScrollPhysics(),
            ),
            slivers: [
              _buildSliverAppBar(context, cs, stretch: offset),
              SliverToBoxAdapter(
                child: _buildContent(context, cs)
                    .animate()
                    .fadeIn(duration: 400.ms, delay: 150.ms)
                    .slideY(
                      begin: 0.06,
                      end: 0,
                      duration: 400.ms,
                      delay: 150.ms,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  SliverAppBar _buildSliverAppBar(
    BuildContext context,
    ColorScheme cs, {
    double stretch = 0,
  }) {
    final surfaceHigh = AppTheme.surfaceContainerHighOf(context);
    final surfaceLowest = AppTheme.surfaceContainerLowestOf(context);

    return SliverAppBar(
      expandedHeight: 280 + stretch,
      pinned: true,
      stretch: true,
      backgroundColor: surfaceLowest,
      leading: Padding(
        padding: const EdgeInsets.all(8),
        child: CircleAvatar(
          backgroundColor: surfaceHigh.withValues(alpha: 0.85),
          child: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, size: 20),
            color: cs.onSurface,
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [
          StretchMode.zoomBackground,
          StretchMode.blurBackground,
        ],
        background: Stack(
          fit: StackFit.expand,
          children: [
            Hero(
              tag: 'cp_image_${checkpoint.id}',
              child: AppNetworkImage(
                url: checkpoint.image,
                fit: BoxFit.cover,
                placeholder: Container(
                  color: AppTheme.surfaceContainerHighestOf(context),
                ),
                errorWidget: Container(
                  color: AppTheme.surfaceContainerHighestOf(context),
                  child: Icon(
                    Icons.image_not_supported_outlined,
                    size: 40,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.0, 0.5, 1.0],
                  colors: [
                    Colors.transparent,
                    Colors.transparent,
                    surfaceLowest.withValues(alpha: 0.95),
                  ],
                ),
              ),
            ),
            if (isCompleted)
              Positioned(
                bottom: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.check_circle_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Zaliczone',
                        style: GoogleFonts.spaceGrotesk(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, ColorScheme cs) {
    final catColor =
        parseHexColor(checkpoint.categoryColor) ?? cs.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: catColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              checkpoint.categoryLabel,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: catColor,
                letterSpacing: 0.8,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Hero(
            tag: 'cp_title_${checkpoint.id}',
            child: Material(
              type: MaterialType.transparency,
              child: Text(
                checkpoint.title,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: cs.onSurface,
                  letterSpacing: -0.5,
                  height: 1.15,
                ),
              ),
            ),
          ),
          if (checkpoint.subtitle.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              checkpoint.subtitle,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 20),
          _buildMetaRow(context, cs),
          if (checkpoint.description.isNotEmpty) ...[
            const SizedBox(height: 20),
            Divider(height: 1, thickness: 1, color: cs.outlineVariant),
            const SizedBox(height: 20),
            Text(
              'Opis',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: cs.onSurfaceVariant,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 8),
            Html(
              data: checkpoint.description,
              onLinkTap: (url, _, _) {
                if (url == null) return;
                launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
              },
              style: {
                'body': Style(
                  margin: Margins.zero,
                  padding: HtmlPaddings.zero,
                  fontSize: FontSize(15),
                  lineHeight: const LineHeight(1.6),
                  color: cs.onSurface,
                ),
                'p': Style(margin: Margins.only(bottom: 10)),
                'a': Style(
                  color: cs.primary,
                  textDecoration: TextDecoration.underline,
                ),
                'li': Style(margin: Margins.only(bottom: 6)),
              },
            ),
          ],
          if (_locationPin != null && data != null) ...[
            const SizedBox(height: 20),
            Divider(height: 1, thickness: 1, color: cs.outlineVariant),
            const SizedBox(height: 20),
            Text(
              'Gdzie szukać',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: cs.onSurfaceVariant,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 10),
            _buildMiniMap(context, cs),
          ],
        ],
      ),
    );
  }

  Widget _buildMiniMap(BuildContext context, ColorScheme cs) {
    final pin = _locationPin!;
    final appData = data!;
    final color = pin.type.mapPointColor(context);
    final icon = pin.type.mapPointIcon;

    final planPin = FestivalPlanPin(
      id: pin.id,
      lat: pin.lat!,
      lng: pin.lng!,
      builder: (context, pinScale) => Transform.scale(
        scale: pinScale,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.95),
              width: 3,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.5),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Icon(icon, size: 22, color: Colors.white),
        ),
      ),
    );

    return AspectRatio(
      aspectRatio: 16 / 11,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppTheme.surfaceContainerOf(context),
          ),
          child: FestivalPlanMap(
            bounds: appData.config.planBounds,
            pins: [planPin],
            autoFocus: planPin,
            autoFocusScale: 2.4,
          ),
        ),
      ),
    );
  }

  Widget _buildMetaRow(BuildContext context, ColorScheme cs) {
    return Wrap(
      spacing: 10,
      runSpacing: 8,
      children: [
        if (checkpoint.location.isNotEmpty)
          _metaChip(
            icon: Icons.location_on_rounded,
            label: checkpoint.location,
            iconColor: cs.primary,
            context: context,
            cs: cs,
          ),
        if (checkpoint.time.trim().isNotEmpty)
          _metaChip(
            icon: Icons.schedule_rounded,
            label: checkpoint.time.trim(),
            iconColor: cs.secondary,
            context: context,
            cs: cs,
          ),
      ],
    );
  }

  Widget _metaChip({
    required IconData icon,
    required String label,
    required Color iconColor,
    required BuildContext context,
    required ColorScheme cs,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerHighOf(context),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: iconColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: cs.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
