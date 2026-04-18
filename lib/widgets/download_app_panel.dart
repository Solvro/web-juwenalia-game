import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_theme.dart';
import 'brand_gradient.dart';

/// Store URLs — wire these to real listings when you have them.
class AppStoreLinks {
  AppStoreLinks._();

  // Replace with the real product page once published.
  static const String iosUrl =
      'https://apps.apple.com/app/juwenalia-pwr/id000000000';
  static const String androidUrl =
      'https://play.google.com/store/apps/details?id=pl.solvro.juwenalia';

  /// QR encodes a "smart" URL — open the right store based on the device the
  /// user scans with. (For now we encode the Android URL; swap for a real
  /// branch.io / AppsFlyer / custom redirector when available.)
  static const String universalUrl = androidUrl;
}

/// Side / bottom panel suggesting users to download the mobile app.
/// Used on desktop / web breakpoints.
class DownloadAppPanel extends StatelessWidget {
  const DownloadAppPanel({super.key, this.compact = false});

  /// When true, hides the QR + uses a vertically denser layout for narrow
  /// sidebars.
  final bool compact;

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
            'Skanuj kody QR, sprawdzaj harmonogram i nawigację bezpośrednio na telefonie.',
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
                  data: AppStoreLinks.universalUrl,
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
            icon: Icons.apple_rounded,
            label: 'App Store',
            url: AppStoreLinks.iosUrl,
          ),
          const SizedBox(height: 8),
          _StoreButton(
            icon: Icons.shop_rounded,
            label: 'Google Play',
            url: AppStoreLinks.androidUrl,
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
