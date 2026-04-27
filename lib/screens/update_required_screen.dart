import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/models.dart';
import '../theme/app_theme.dart';
import '../theme/elements.dart';
import '../widgets/platform_utils.dart';

class UpdateRequiredScreen extends StatelessWidget {
  const UpdateRequiredScreen({
    super.key,
    required this.config,
    required this.currentVersion,
  });

  final AppConfig config;
  final String currentVersion;

  String get _minVersion {
    if (kIsWeb) return config.minAppVersionWeb;
    if (PlatformUtils.isIOS) return config.minAppVersionIos;
    if (PlatformUtils.isAndroid) return config.minAppVersionAndroid;
    return '';
  }

  String? get _storeUrl {
    if (kIsWeb) return null;
    if (PlatformUtils.isIOS) return config.appStoreUrlIos;
    if (PlatformUtils.isAndroid) return config.appStoreUrlAndroid;
    return null;
  }

  String get _actionLabel {
    if (kIsWeb) return 'Odśwież stronę';
    if (PlatformUtils.isIOS) return 'Otwórz App Store';
    if (PlatformUtils.isAndroid) return 'Otwórz Google Play';
    return 'Zaktualizuj';
  }

  IconData get _actionIcon {
    if (kIsWeb) return Symbols.refresh_rounded;
    return Symbols.cloud_download_rounded;
  }

  Future<void> _onAction() async {
    if (kIsWeb) {
      // Forces the browser to refetch the bundle without pulling in
      // dart:html (which would complicate non-web builds).
      final uri = Uri.base.replace(
        queryParameters: {
          ...Uri.base.queryParameters,
          '_r': DateTime.now().millisecondsSinceEpoch.toString(),
        },
      );
      await launchUrl(uri, webOnlyWindowName: '_self');
      return;
    }
    final url = _storeUrl;
    if (url == null || url.isEmpty) return;
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final palette = AppElements.fire;
    final min = _minVersion;

    return Scaffold(
      backgroundColor: AppTheme.surfaceContainerLowestOf(context),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 112,
                  height: 112,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: palette.linearGradient,
                    boxShadow: [
                      BoxShadow(
                        color: palette.base.withValues(alpha: 0.35),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Symbols.system_update_rounded,
                    color: Colors.white,
                    size: 56,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Dostępna jest nowa wersja',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: cs.onSurface,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  kIsWeb
                      ? 'Odśwież stronę, aby pobrać najnowszą wersję aplikacji.'
                      : 'Aby kontynuować, zaktualizuj aplikację do najnowszej wersji.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    color: cs.onSurfaceVariant,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Twoja wersja: $currentVersion • Wymagana: ${min.isEmpty ? '—' : min}',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: palette.base,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _onAction,
                  icon: Icon(_actionIcon, size: 20),
                  label: Text(
                    _actionLabel,
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Compares dotted version strings. Negative if [a] < [b].
int compareVersions(String a, String b) {
  List<int> parts(String s) {
    if (s.trim().isEmpty) return const [];
    return s
        .trim()
        .split(RegExp(r'[.\-+]'))
        .map((p) => int.tryParse(p) ?? 0)
        .toList();
  }

  final aa = parts(a);
  final bb = parts(b);
  final len = aa.length > bb.length ? aa.length : bb.length;
  for (var i = 0; i < len; i++) {
    final av = i < aa.length ? aa[i] : 0;
    final bv = i < bb.length ? bb[i] : 0;
    if (av != bv) return av - bv;
  }
  return 0;
}
