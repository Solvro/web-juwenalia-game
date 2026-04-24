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
      flexibleSpace: FlexibleSpaceBar(
        centerTitle: false,
        // The title lives in FlexibleSpaceBar.title so the framework keeps
        // it pinned when the header collapses (it translates into the app
        // bar's title slot). We mirror the same padding used by the
        // background placeholder below so the two overlap pixel-for-pixel
        // while expanded — no visible duplicate.
        titlePadding: EdgeInsets.only(left: 20, right: 16, bottom: bottomInset),
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
                    palette.base.withValues(alpha: isDark ? 0.20 : 0.16),
                    palette.accent.withValues(alpha: 0.10),
                    AppTheme.surfaceContainerLowestOf(
                      context,
                    ).withValues(alpha: 0.0),
                  ],
                  stops: const [0.0, 0.4, 1.0],
                ),
              ),
            ),
            // Background column: visible supertitle + an invisible copy
            // of the title that reserves the same vertical footprint as
            // FlexibleSpaceBar.title. When the title wraps to multiple
            // lines the Column grows upward and pushes the supertitle up
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
                  // IgnorePointer so the invisible title doesn't steal
                  // hit testing from anything below it.
                  IgnorePointer(child: Opacity(opacity: 0, child: actualTitle)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
