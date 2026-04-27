import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/models.dart';
import '../services/data_service.dart';
import '../theme/app_theme.dart';
import '../theme/elements.dart';
import '../theme/icon_names.dart';
import '../widgets/app_network_image.dart';
import '../widgets/brand_gradient.dart';
import '../widgets/section_header.dart';

class InfoScreen extends StatefulWidget {
  const InfoScreen({super.key, required this.data, required this.onRefresh});

  final AppData data;
  final Future<void> Function() onRefresh;

  @override
  State<InfoScreen> createState() => _InfoScreenState();
}

class _InfoScreenState extends State<InfoScreen> {
  bool _newsExpanded = false;
  bool _faqExpanded = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final palette = AppElements.wind;

    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      color: palette.base,
      backgroundColor: AppTheme.surfaceContainerHighOf(context),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          _buildHeader(context, cs, palette),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.data.news.isNotEmpty) ...[
                    _NavSectionCard(
                      icon: Symbols.newspaper_rounded,
                      label: 'Aktualności',
                      color: palette.base,
                      count: widget.data.news.length,
                      isExpanded: _newsExpanded,
                      onTap: () =>
                          setState(() => _newsExpanded = !_newsExpanded),
                    ),
                    SizedBox(
                      width: double.infinity,
                      child: AnimatedSize(
                        duration: const Duration(milliseconds: 220),
                        alignment: Alignment.topCenter,
                        curve: Curves.easeInOut,
                        child: _newsExpanded
                            ? Padding(
                                padding: const EdgeInsets.only(top: 10),
                                child: _buildNewsContent(context, cs),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (widget.data.faqs.isNotEmpty) ...[
                    _NavSectionCard(
                      icon: Symbols.help_rounded,
                      label: 'FAQ',
                      color: palette.accent,
                      count: widget.data.faqs.length,
                      isExpanded: _faqExpanded,
                      onTap: () => setState(() => _faqExpanded = !_faqExpanded),
                    ),
                    SizedBox(
                      width: double.infinity,
                      child: AnimatedSize(
                        duration: const Duration(milliseconds: 220),
                        alignment: Alignment.topCenter,
                        curve: Curves.easeInOut,
                        child: _faqExpanded
                            ? Padding(
                                padding: const EdgeInsets.only(top: 10),
                                child: _buildFaqContent(context, cs, palette),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (_activeImportantInfo().isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _buildImportantInfo(context, cs),
                    const SizedBox(height: 16),
                  ],
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(child: _buildCredit(context, cs)),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _buildCredit(BuildContext context, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Center(
        child: Text(
          'by Antoni Czaplicki | KN Solvro',
          style: GoogleFonts.spaceGrotesk(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: cs.onSurfaceVariant.withValues(alpha: 0.7),
            letterSpacing: 0.4,
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    ColorScheme cs,
    ElementPalette palette,
  ) {
    return SectionHeader(
      supertitle: 'INFO',
      titleWidget: BrandGradientText(
        '#wrocławrazem',
        style: GoogleFonts.spaceGrotesk(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.3,
        ),
      ),
      palette: palette,
      trailingLogoAsset: 'assets/app_icon.png',
    );
  }

  /// Filter at render time so cached payloads respect the wall clock
  /// even when offline.
  List<ImportantInfo> _activeImportantInfo() {
    final now = DateTime.now();
    return widget.data.importantInfo
        .where((i) => i.expiresAt == null || i.expiresAt!.isAfter(now))
        .toList();
  }

  Widget _buildImportantInfo(BuildContext context, ColorScheme cs) {
    final active = _activeImportantInfo();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(context, cs, 'PAMIĘTAJ O', AppElements.fire.base),
        const SizedBox(height: 12),
        for (var i = 0; i < active.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          _importantInfoCard(context, cs, active[i]),
        ],
      ],
    );
  }

  Widget _importantInfoCard(
    BuildContext context,
    ColorScheme cs,
    ImportantInfo info,
  ) {
    final color = parseHexColor(info.color) ?? AppElements.fire.base;
    final surfHigh = AppTheme.surfaceContainerHighOf(context);
    final hasUrl = info.url != null && info.url!.isNotEmpty;
    final hasBody = info.body.isNotEmpty;

    final card = Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surfHigh,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        // Center icon with title when no body — avoids a bottom-heavy card.
        crossAxisAlignment: hasBody
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Icon(iconFromName(info.icon), color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        info.title,
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface,
                        ),
                      ),
                    ),
                    if (hasUrl) ...[
                      const SizedBox(width: 8),
                      Icon(Symbols.open_in_new, size: 16, color: color),
                    ],
                  ],
                ),
                if (hasBody) ...[
                  const SizedBox(height: 4),
                  _html(info.body, cs, baseSize: 13),
                ],
              ],
            ),
          ),
        ],
      ),
    );

    if (!hasUrl) return card;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => launchUrl(
          Uri.parse(info.url!),
          mode: LaunchMode.externalApplication,
        ),
        child: card,
      ),
    );
  }

  Widget _buildNewsContent(BuildContext context, ColorScheme cs) {
    return Column(
      children: widget.data.news
          .map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _newsCard(context, cs, item),
            ),
          )
          .toList(),
    );
  }

  Widget _newsCard(BuildContext context, ColorScheme cs, NewsItem item) {
    final surfHigh = AppTheme.surfaceContainerHighOf(context);
    final surfHighest = AppTheme.surfaceContainerHighestOf(context);
    final dateStr = _formatDate(item.date);

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: surfHigh,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (item.imageUrl.isNotEmpty)
            AspectRatio(
              aspectRatio: 16 / 9,
              child: AppNetworkImage(
                url: item.imageUrl,
                fit: BoxFit.cover,
                placeholder: Container(color: surfHighest),
                errorWidget: Container(color: surfHighest),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dateStr,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  item.title,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 8),
                _html(item.body, cs, baseSize: 13),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFaqContent(
    BuildContext context,
    ColorScheme cs,
    ElementPalette palette,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerHighOf(context),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          for (var i = 0; i < widget.data.faqs.length; i++) ...[
            _faqTile(context, cs, widget.data.faqs[i]),
            if (i < widget.data.faqs.length - 1)
              Divider(
                height: 1,
                thickness: 1,
                color: cs.outlineVariant.withValues(alpha: 0.3),
                indent: 16,
                endIndent: 16,
              ),
          ],
        ],
      ),
    );
  }

  Widget _faqTile(BuildContext context, ColorScheme cs, FaqItem faq) {
    return Theme(
      data: Theme.of(context).copyWith(
        dividerColor: Colors.transparent,
        splashColor: Colors.transparent,
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        iconColor: cs.onSurfaceVariant,
        collapsedIconColor: cs.onSurfaceVariant,
        title: Text(
          faq.question,
          style: GoogleFonts.spaceGrotesk(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: cs.onSurface,
          ),
        ),
        children: [_html(faq.answer, cs, baseSize: 13)],
      ),
    );
  }

  Widget _sectionHeader(
    BuildContext context,
    ColorScheme cs,
    String label,
    Color color,
  ) {
    return Row(
      children: [
        Container(
          width: 18,
          height: 3,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: GoogleFonts.spaceGrotesk(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: cs.onSurfaceVariant,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _html(String html, ColorScheme cs, {double baseSize = 14}) {
    return Html(
      data: html,
      style: {
        'body': Style(
          margin: Margins.zero,
          padding: HtmlPaddings.zero,
          color: cs.onSurfaceVariant,
          fontSize: FontSize(baseSize),
          lineHeight: const LineHeight(1.55),
          fontFamily: GoogleFonts.plusJakartaSans().fontFamily,
        ),
        'p': Style(margin: Margins.only(bottom: 8)),
        'a': Style(
          color: AppElements.wind.base,
          textDecoration: TextDecoration.none,
        ),
        'ul': Style(margin: Margins.only(bottom: 8)),
        'li': Style(margin: Margins.only(bottom: 4)),
      },
      onLinkTap: (url, _, _) {
        if (url == null) return;
        launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      },
    );
  }

  String _formatDate(DateTime dt) {
    try {
      return DateFormat('d MMM yyyy', 'pl').format(dt);
    } catch (_) {
      return DateFormat('d MMM yyyy').format(dt);
    }
  }
}

class _NavSectionCard extends StatelessWidget {
  const _NavSectionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.count,
    required this.isExpanded,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final int count;
  final bool isExpanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final surfHigh = AppTheme.surfaceContainerHighOf(context);

    return Material(
      color: surfHigh,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$count',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              AnimatedRotation(
                turns: isExpanded ? 0.25 : 0,
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  Symbols.chevron_right_rounded,
                  color: cs.onSurfaceVariant,
                  size: 22,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
