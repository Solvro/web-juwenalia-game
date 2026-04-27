import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_symbols_icons/symbols.dart';

/// Stitch "Kinetic Pulse" design system — both dark and light variants.
/// Brand: primary blue #00A1E4 / amber #F9A01B.
/// Fonts: Space Grotesk (headlines/labels) + Plus Jakarta Sans (body).
class AppTheme {
  AppTheme._();

  // ── Shared brand constants (brightness-independent) ────────────────────────
  static const Color brandBlue = Color(0xFF00A1E4);
  static const Color brandAmber = Color(0xFFF9A01B);

  // Figma brand gradient — cyan → teal → green (Juwenalia 2025 identity).
  static const Color brandCyan = Color(0xFF049BAD);
  static const Color brandTeal = Color(0xFF19A59F);
  static const Color brandSeafoam = Color(0xFF2EB090);
  static const Color brandGreen = Color(0xFF58C473);

  static const List<Color> brandGradientColors = [
    brandCyan,
    brandTeal,
    brandSeafoam,
    brandGreen,
  ];

  /// Diagonal cyan→teal→green gradient — primary brand accent.
  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: brandGradientColors,
    stops: [0.0, 0.4, 0.7, 1.0],
  );

  /// Radial variant — used for hero spotlights.
  static const RadialGradient brandRadialGradient = RadialGradient(
    center: Alignment.topLeft,
    radius: 1.4,
    colors: brandGradientColors,
    stops: [0.0, 0.35, 0.7, 1.0],
  );

  // ── Dark palette (from Stitch namedColors) ─────────────────────────────────
  static const ColorScheme _darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFF88CEFF),
    onPrimary: Color(0xFF00344D),
    primaryContainer: Color(0xFF00A1E4),
    onPrimaryContainer: Color(0xFFC8E6FF),
    secondary: Color(0xFFFFB963),
    onSecondary: Color(0xFF472A00),
    secondaryContainer: Color(0xFFE59000),
    onSecondaryContainer: Color(0xFFFFDDB9),
    tertiary: Color(0xFFC6C6C7),
    onTertiary: Color(0xFF2F3131),
    tertiaryContainer: Color(0xFF979898),
    onTertiaryContainer: Color(0xFFE2E2E2),
    error: Color(0xFFFFB4AB),
    onError: Color(0xFF690005),
    errorContainer: Color(0xFF93000A),
    onErrorContainer: Color(0xFFFFDAD6),
    surface: Color(0xFF131313),
    onSurface: Color(0xFFE2E2E2),
    onSurfaceVariant: Color(0xFFBEC8D2),
    surfaceTint: Color(0xFF88CEFF),
    outline: Color(0xFF88929B),
    outlineVariant: Color(0xFF3E4850),
    inverseSurface: Color(0xFFE2E2E2),
    onInverseSurface: Color(0xFF303030),
    inversePrimary: Color(0xFF006590),
    scrim: Color(0xFF000000),
    shadow: Color(0xFF000000),
  );

  // ── Light palette (derived from same brand, Material 3 tonal system) ────────
  static const ColorScheme _lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFF006590),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFC8E6FF),
    onPrimaryContainer: Color(0xFF001E2F),
    secondary: Color(0xFF7B5800),
    onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: Color(0xFFFFDDB9),
    onSecondaryContainer: Color(0xFF2B1700),
    tertiary: Color(0xFF5D5E5E),
    onTertiary: Color(0xFFFFFFFF),
    tertiaryContainer: Color(0xFFE2E2E2),
    onTertiaryContainer: Color(0xFF1A1C1C),
    error: Color(0xFFBA1A1A),
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFFFFDAD6),
    onErrorContainer: Color(0xFF410002),
    surface: Color(0xFFF8FAFC),
    onSurface: Color(0xFF191C1E),
    onSurfaceVariant: Color(0xFF42474E),
    surfaceTint: Color(0xFF006590),
    outline: Color(0xFF73797F),
    outlineVariant: Color(0xFFC3C7CF),
    inverseSurface: Color(0xFF2E3133),
    onInverseSurface: Color(0xFFEFF1F3),
    inversePrimary: Color(0xFF88CEFF),
    scrim: Color(0xFF000000),
    shadow: Color(0xFF000000),
  );

  // ── Surface tier helpers (context-aware) ──────────────────────────────────
  static Color surfaceContainerOf(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF1F1F1F)
        : const Color(0xFFEBEFF3);
  }

  static Color surfaceContainerHighOf(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF2A2A2A)
        : const Color(0xFFE1E5EA);
  }

  static Color surfaceContainerLowestOf(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF0E0E0E)
        : const Color(0xFFFFFFFF);
  }

  static Color surfaceContainerHighestOf(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF353535)
        : const Color(0xFFD6DAE0);
  }

  // ── Public theme getters ──────────────────────────────────────────────────
  static ThemeData get dark => _buildTheme(_darkScheme);
  static ThemeData get light => _buildTheme(_lightScheme);

  // ── Shared builder ────────────────────────────────────────────────────────
  static ThemeData _buildTheme(ColorScheme cs) {
    final isDark = cs.brightness == Brightness.dark;
    final baseText = GoogleFonts.plusJakartaSansTextTheme();
    final headText = GoogleFonts.spaceGroteskTextTheme();
    final onSurface = cs.onSurface;
    final onSurfaceVariant = cs.onSurfaceVariant;

    final surfaceContainer = isDark
        ? const Color(0xFF1F1F1F)
        : const Color(0xFFEBEFF3);
    final surfaceContainerHigh = isDark
        ? const Color(0xFF2A2A2A)
        : const Color(0xFFE1E5EA);
    final surfaceContainerLowest = isDark
        ? const Color(0xFF0E0E0E)
        : const Color(0xFFFFFFFF);

    return ThemeData(
      useMaterial3: true,
      brightness: cs.brightness,
      colorScheme: cs,
      scaffoldBackgroundColor: surfaceContainerLowest,
      cardColor: surfaceContainerHigh,
      dividerColor: Colors.transparent,

      textTheme: baseText
          .copyWith(
            displayLarge: headText.displayLarge?.copyWith(
              color: onSurface,
              fontWeight: FontWeight.w800,
            ),
            displayMedium: headText.displayMedium?.copyWith(
              color: onSurface,
              fontWeight: FontWeight.w700,
            ),
            displaySmall: headText.displaySmall?.copyWith(
              color: onSurface,
              fontWeight: FontWeight.w700,
            ),
            headlineLarge: headText.headlineLarge?.copyWith(
              color: onSurface,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
            headlineMedium: headText.headlineMedium?.copyWith(
              color: onSurface,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.3,
            ),
            headlineSmall: headText.headlineSmall?.copyWith(
              color: onSurface,
              fontWeight: FontWeight.w600,
            ),
            titleLarge: baseText.titleLarge?.copyWith(
              color: onSurface,
              fontWeight: FontWeight.w600,
              fontSize: 20,
            ),
            titleMedium: baseText.titleMedium?.copyWith(
              color: onSurface,
              fontWeight: FontWeight.w500,
            ),
            titleSmall: baseText.titleSmall?.copyWith(
              color: onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
            bodyLarge: baseText.bodyLarge?.copyWith(color: onSurface),
            bodyMedium: baseText.bodyMedium?.copyWith(color: onSurfaceVariant),
            bodySmall: baseText.bodySmall?.copyWith(color: onSurfaceVariant),
            labelLarge: headText.labelLarge?.copyWith(
              color: onSurface,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
            labelMedium: headText.labelMedium?.copyWith(
              color: onSurfaceVariant,
              letterSpacing: 0.4,
            ),
            labelSmall: headText.labelSmall?.copyWith(
              color: onSurfaceVariant,
              letterSpacing: 0.5,
            ),
          )
          .apply(bodyColor: onSurface, displayColor: onSurface),

      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.spaceGrotesk(
          color: onSurface,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        iconTheme: IconThemeData(color: onSurface),
        actionsIconTheme: IconThemeData(color: onSurfaceVariant),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: cs.primaryContainer,
        foregroundColor: isDark ? Colors.white : cs.onPrimaryContainer,
        elevation: 0,
        shape: const CircleBorder(),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: surfaceContainerHigh,
        contentTextStyle: GoogleFonts.plusJakartaSans(color: onSurface),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: cs.primaryContainer,
          foregroundColor: isDark ? Colors.white : cs.onPrimaryContainer,
          textStyle: GoogleFonts.spaceGrotesk(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: cs.primary,
          side: BorderSide(color: cs.primary.withValues(alpha: 0.4)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),

      iconTheme: IconThemeData(color: onSurfaceVariant, size: 22),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surfaceContainer.withValues(alpha: 0.95),
        indicatorColor: cs.primaryContainer.withValues(
          alpha: isDark ? 0.2 : 0.25,
        ),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(
              color: isDark ? cs.primary : cs.primaryContainer,
              size: 24,
            );
          }
          return IconThemeData(color: onSurfaceVariant, size: 24);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return GoogleFonts.spaceGrotesk(
              color: isDark ? cs.primary : cs.primaryContainer,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            );
          }
          return GoogleFonts.spaceGrotesk(
            color: onSurfaceVariant,
            fontWeight: FontWeight.w500,
            fontSize: 12,
          );
        }),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),

      chipTheme: ChipThemeData(
        backgroundColor: surfaceContainerHigh,
        labelStyle: GoogleFonts.spaceGrotesk(
          color: cs.secondary,
          fontWeight: FontWeight.w500,
          fontSize: 12,
        ),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: surfaceContainer,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: GoogleFonts.spaceGrotesk(
          color: onSurface,
          fontWeight: FontWeight.w700,
          fontSize: 20,
        ),
        contentTextStyle: GoogleFonts.plusJakartaSans(
          color: onSurfaceVariant,
          fontSize: 15,
        ),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surfaceContainer,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
    );
  }
}

// ── Hex color parsing ────────────────────────────────────────────────────────

/// Parses a CMS-supplied hex string ("#RRGGBB", "#RRGGBBAA", or with no
/// leading hash) into a [Color]. Returns `null` for blank/invalid input
/// so callers can apply their own neutral fallback.
Color? parseHexColor(String? hex) {
  if (hex == null) return null;
  var s = hex.trim();
  if (s.isEmpty) return null;
  if (s.startsWith('#')) s = s.substring(1);
  if (s.length == 6) s = 'FF$s';
  final v = int.tryParse(s, radix: 16);
  return v == null ? null : Color(v);
}

// ── Map point icon/color helpers ─────────────────────────────────────────────

extension MapPointDisplay on String {
  IconData get mapPointIcon {
    switch (this) {
      case 'stage':
        return Symbols.music_note_rounded;
      case 'food':
        return Symbols.restaurant_rounded;
      case 'medical':
        return Symbols.local_hospital_rounded;
      case 'wc':
        return Symbols.wc_rounded;
      case 'vip':
        return Symbols.star_rounded;
      case 'chill':
        return Symbols.self_improvement_rounded;
      case 'info':
        return Symbols.info_rounded;
      default:
        return Symbols.place_rounded;
    }
  }

  Color mapPointColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    switch (this) {
      case 'stage':
        return isDark ? const Color(0xFFFFB963) : const Color(0xFFE59000);
      case 'food':
        return isDark ? const Color(0xFFFF9E8E) : const Color(0xFFD0422E);
      case 'medical':
        return isDark ? const Color(0xFFFF8A8A) : const Color(0xFFC62828);
      case 'wc':
        return isDark ? const Color(0xFF88CEFF) : const Color(0xFF006590);
      case 'vip':
        return isDark ? const Color(0xFFD4AAFF) : const Color(0xFF6B3FA0);
      case 'chill':
        return isDark ? const Color(0xFF9DDFB0) : const Color(0xFF1D6B3A);
      case 'info':
        return isDark ? const Color(0xFF88CEFF) : const Color(0xFF006590);
      default:
        return isDark ? const Color(0xFFBEC8D2) : const Color(0xFF42474E);
    }
  }
}
