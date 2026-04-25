import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';
import '../theme/elements.dart';

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    this.title,
    required this.supertitle,
    required this.palette,
    this.bottom,
    this.titleWidget,
    this.actions,
    this.trailingLogoAsset,
  });

  /// The main title text (e.g. 'Juwenalia 2026').
  /// Ignored if [titleWidget] is provided.
  final String? title;

  /// Optional custom title widget. If provided, replaces the default Text widget.
  final Widget? titleWidget;

  /// The small text above the title (e.g. 'KONCERTY', 'INFO')
  final String supertitle;

  /// Color palette for the gradient and accents
  final ElementPalette palette;

  /// Optional bottom widget, usually a TabBar
  final PreferredSizeWidget? bottom;

  /// Actions for the SliverAppBar
  final List<Widget>? actions;

  /// Optional asset path for a logo rendered at the right edge of the
  /// header. The logo grows to ~64 px when fully expanded and shrinks
  /// to ~28 px (toolbar-friendly) as the user scrolls — same idea as
  /// iOS large-title app icons.
  final String? trailingLogoAsset;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasBottom = bottom != null;

    // Adjust height and padding to fit tabs if present.
    final expandedHeight = hasBottom ? 208.0 : 160.0;
    final bottomInset = hasBottom ? 62.0 : 14.0;

    final actualTitle =
        titleWidget ??
        Text(
          title ?? '',
          style: GoogleFonts.spaceGrotesk(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: cs.onSurface,
            letterSpacing: -0.5,
            height: 1.1,
          ),
        );

    final supertitleBlock = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          supertitle.toUpperCase(),
          style: GoogleFonts.spaceGrotesk(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: palette.base,
            letterSpacing: 2.4,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: 36,
          height: 3,
          decoration: BoxDecoration(
            gradient: palette.linearGradient,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(height: 10),
      ],
    );

    return SliverAppBar(
      pinned: true,
      stretch: true,
      expandedHeight: expandedHeight,
      centerTitle: false,
      backgroundColor: AppTheme.surfaceContainerLowestOf(context),
      bottom: bottom,
      actions: actions,
      flexibleSpace: LayoutBuilder(
        builder: (context, constraints) {
          // LayoutBuilder gives us the bar's current height; the
          // FlexibleSpaceBar shrinks it from `expandedHeight` (plus
          // status-bar padding) down to the toolbar height as the user
          // scrolls. Normalize to t∈[0,1]: 1 = fully expanded, 0 = fully
          // collapsed. Used to drive the trailing logo's size + offset.
          final topPad = MediaQuery.paddingOf(context).top;
          final bottomH = bottom?.preferredSize.height ?? 0;
          final maxH = expandedHeight + topPad;
          final minH = kToolbarHeight + topPad + bottomH;
          final h = constraints.maxHeight;
          final t = (maxH - minH) <= 0
              ? 1.0
              : ((h - minH) / (maxH - minH)).clamp(0.0, 1.0);

          // FlexibleSpaceBar.background fades out as the bar collapses
          // — that's fine for the gradient + supertitle, but the logo
          // should stay visible throughout, just shrinking. So we
          // render it as a sibling of FlexibleSpaceBar in this Stack
          // instead of inside its background slot.
          return Stack(
            fit: StackFit.expand,
            children: [
              FlexibleSpaceBar(
                centerTitle: false,
                // The title lives in FlexibleSpaceBar.title so the
                // framework keeps it pinned when the header collapses
                // (it translates into the app bar's title slot). We
                // mirror the same padding used by the background
                // placeholder below so the two overlap pixel-for-pixel
                // while expanded — no visible duplicate.
                titlePadding: EdgeInsets.only(
                  left: 20,
                  right: 16,
                  bottom: bottomInset,
                ),
                expandedTitleScale: 1.0,
                title: actualTitle,
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: const Alignment(0.8, 1.8),
                          colors: [
                            palette.base.withValues(
                              alpha: isDark ? 0.20 : 0.16,
                            ),
                            palette.accent.withValues(alpha: 0.10),
                            AppTheme.surfaceContainerLowestOf(
                              context,
                            ).withValues(alpha: 0.0),
                          ],
                          stops: const [0.0, 0.4, 1.0],
                        ),
                      ),
                    ),
                    // Background column: visible supertitle + an
                    // invisible copy of the title that reserves the
                    // same vertical footprint as FlexibleSpaceBar.title.
                    // When the title wraps to multiple lines the Column
                    // grows upward and pushes the supertitle up
                    // instead of overlapping it.
                    Padding(
                      padding: EdgeInsets.only(
                        left: 20,
                        right: 16,
                        bottom: bottomInset,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          supertitleBlock,
                          // IgnorePointer so the invisible title doesn't
                          // steal hit testing from anything below it.
                          IgnorePointer(
                            child: Opacity(opacity: 0, child: actualTitle),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (trailingLogoAsset != null)
                _TrailingLogo(
                  asset: trailingLogoAsset!,
                  progress: t,
                  topPad: topPad,
                  bottomH: bottomH,
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Right-anchored logo that grows with the header. At t=1 it sits in
/// the expanded area at ~64 px; at t=0 it tucks into the collapsed
/// toolbar slot at ~28 px. Vertically it's always centered on whichever
/// strip is currently visible — the toolbar when collapsed, the
/// expanded supertitle row when expanded.
class _TrailingLogo extends StatelessWidget {
  const _TrailingLogo({
    required this.asset,
    required this.progress,
    required this.topPad,
    required this.bottomH,
  });

  final String asset;

  /// 1 = fully expanded, 0 = fully collapsed.
  final double progress;
  final double topPad;
  final double bottomH;

  @override
  Widget build(BuildContext context) {
    final size = _lerp(42.0, 96.0, progress);
    final right = _lerp(12.0, 20.0, progress);
    // Center vertically on the toolbar strip when collapsed; nudge
    // upward toward the expanded area as the bar grows.
    final toolbarCenter = topPad + (kToolbarHeight - size) / 2;
    final expandedTop = topPad + 18.0;
    final top = _lerp(toolbarCenter, expandedTop, progress);

    return Positioned(
      right: right,
      top: top,
      child: IgnorePointer(
        child: Image.asset(
          asset,
          width: size,
          height: size,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.medium,
        ),
      ),
    );
  }
}

double _lerp(double a, double b, double t) => a + (b - a) * t;
