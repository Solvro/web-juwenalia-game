import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/models.dart';
import '../theme/app_theme.dart';
import 'brand_gradient.dart';

/// Fallbacks used only before [fetchData] resolves or when the CMS
/// fields are blank.
class _DownloadDefaults {
  static const String iosUrl = 'https://apps.apple.com/pl/app/juwenalia-wroc%C5%82awrazem/id6763130512';
  static const String androidUrl =
      'https://play.google.com/store/apps/details?id=pl.solvro.juwenalia';
  static const String qrUrl = 'https://juwenalia.wroc.pl/app';
  static const String description =
      'Pobierz naszą oficjalną aplikację, by zagrać w grę na Juwenaliach i mieć wszystkie informacje zawsze pod ręką!';
}

class DownloadAppPanel extends StatelessWidget {
  const DownloadAppPanel({super.key, this.config, this.compact = false});

  final AppConfig? config;

  /// When true, hides the QR for narrow sidebars.
  final bool compact;

  String? _trimmed(String? v) {
    final t = v?.trim();
    return (t == null || t.isEmpty) ? null : t;
  }

  String get _iosUrl =>
      _trimmed(config?.appStoreUrlIos) ?? _DownloadDefaults.iosUrl;
  String get _androidUrl =>
      _trimmed(config?.appStoreUrlAndroid) ?? _DownloadDefaults.androidUrl;
  String get _qrUrl =>
      _trimmed(config?.downloadQrUrl) ?? _DownloadDefaults.qrUrl;
  String get _description =>
      _trimmed(config?.downloadPanelDescription) ??
      _DownloadDefaults.description;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfHigh = AppTheme.surfaceContainerHighOf(context);

    return Container(
      padding: EdgeInsets.all(compact ? 12 : 16),
      decoration: BoxDecoration(
        color: surfHigh,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.brandTeal.withValues(alpha: 0.25),
          width: 1,
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  AppTheme.brandTeal.withValues(alpha: 0.10),
                  AppTheme.brandGreen.withValues(alpha: 0.04),
                ]
              : [
                  AppTheme.brandTeal.withValues(alpha: 0.08),
                  AppTheme.brandGreen.withValues(alpha: 0.04),
                ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const BrandGradientBar(width: 18, height: 3),
              const SizedBox(width: 8),
              BrandGradientText(
                'POBIERZ APLIKACJĘ',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _description,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              color: cs.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          if (!compact) ...[
            const SizedBox(height: 14),
            Center(
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: QrImageView(
                  data: _qrUrl,
                  size: 124,
                  version: QrVersions.auto,
                  backgroundColor: Colors.white,
                  padding: EdgeInsets.zero,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Zeskanuj telefonem',
              textAlign: TextAlign.center,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: cs.onSurfaceVariant,
                letterSpacing: 0.4,
              ),
            ),
          ],
          const SizedBox(height: 12),
          _StoreButton(
            icon: Symbols.phone_iphone_rounded,
            label: 'App Store',
            url: _iosUrl,
          ),
          const SizedBox(height: 8),
          _StoreButton(
            icon: Symbols.shop_rounded,
            label: 'Google Play',
            url: _androidUrl,
          ),
        ],
      ),
    );
  }
}

class _StoreButton extends StatelessWidget {
  const _StoreButton({
    required this.icon,
    required this.label,
    required this.url,
  });

  final IconData icon;
  final String label;
  final String url;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () =>
            launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: cs.onSurface,
          side: BorderSide(
            color: cs.outlineVariant.withValues(alpha: 0.6),
            width: 1,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          textStyle: GoogleFonts.spaceGrotesk(
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.centerLeft,
        ),
      ),
    );
  }
}
