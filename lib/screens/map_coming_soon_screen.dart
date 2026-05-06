import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../theme/elements.dart';
import '../widgets/app_refresh_indicator.dart';
import '../widgets/section_header.dart';

/// Placeholder shown on the Map tab when [AppConfig.mapDisabled] is true
/// (e.g. while the festival plan is still being finalised). The tab is
/// kept in the navigation so users see what's coming, instead of
/// silently disappearing.
class MapComingSoonScreen extends StatelessWidget {
  const MapComingSoonScreen({super.key, required this.onRefresh});

  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final palette = AppElements.earth;

    return AppRefreshIndicator(
      onRefresh: onRefresh,
      palette: palette,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SectionHeader(
            supertitle: 'MAPA WYDARZENIA',
            title: 'Już wkrótce',
            palette: palette,
          ),
          SliverFillRemaining(
            hasScrollBody: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 48),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: palette.linearGradient,
                      boxShadow: [
                        BoxShadow(
                          color: palette.base.withValues(alpha: 0.35),
                          blurRadius: 22,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Symbols.map_rounded,
                      color: Colors.white,
                      size: 44,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Mapa już wkrótce',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: cs.onSurface,
                      letterSpacing: -0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Pracujemy jeszcze nad planem terenu juwenaliów. '
                    'Wróć tutaj wkrótce',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      color: cs.onSurfaceVariant,
                      height: 1.6,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
