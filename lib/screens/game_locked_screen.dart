import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../models/models.dart';
import '../theme/elements.dart';
import '../widgets/section_header.dart';

class GameLockedScreen extends StatelessWidget {
  const GameLockedScreen({super.key, required this.config});

  final AppConfig config;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final palette = AppElements.water;
    final start = config.eventStartsAt;

    return CustomScrollView(
      slivers: [
        SectionHeader(
          supertitle: 'GRA TERENOWA',
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
                    Symbols.lock_clock_rounded,
                    color: Colors.white,
                    size: 44,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Spróbuj wszystkiego',
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
                  start != null
                      ? 'Gra terenowa startuje ${_formatStart(start)}. Wróć tutaj po otwarciu bram..'
                      : 'Gra terenowa ruszy razem z juwenaliami. Wróć tutaj po otwarciu bram.',
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
    );
  }

  String _formatStart(DateTime dt) {
    try {
      return DateFormat("d MMMM 'o' HH:mm", 'pl').format(dt);
    } catch (_) {
      return DateFormat("d MMMM 'o' HH:mm").format(dt);
    }
  }
}
