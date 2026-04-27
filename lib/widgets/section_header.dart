import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';
import '../theme/elements.dart';
import 'offline_indicator.dart';

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

  /// Ignored if [titleWidget] is provided.
  final String? title;
  final Widget? titleWidget;
  final String supertitle;
  final ElementPalette palette;
  final PreferredSizeWidget? bottom;
  final List<Widget>? actions;

  /// Asset shrunk into the toolbar slot as the header collapses.
  final String? trailingLogoAsset;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasBottom = bottom != null;

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

    final hasUserActions = actions != null && actions!.isNotEmpty;
    final effectiveActions = hasUserActions
        ? <Widget>[
            const Center(child: OfflinePill(mode: OfflinePillMode.corner)),
            ...actions!,
          ]
        : actions;

    return SliverAppBar(
      pinned: true,
      stretch: true,
      expandedHeight: expandedHeight,
      centerTitle: false,
      backgroundColor: AppTheme.surfaceContainerLowestOf(context),
      bottom: bottom,
      actions: effectiveActions,
      flexibleSpace: LayoutBuilder(
        builder: (context, constraints) {
          // t = 1 fully expanded, 0 fully collapsed.
          final topPad = MediaQuery.paddingOf(context).top;
          final bottomH = bottom?.preferredSize.height ?? 0;
          final maxH = expandedHeight + topPad;
          final minH = kToolbarHeight + topPad + bottomH;
          final h = constraints.maxHeight;
          final t = (maxH - minH) <= 0
              ? 1.0
              : ((h - minH) / (maxH - minH)).clamp(0.0, 1.0);

          return Stack(
            fit: StackFit.expand,
            children: [
              FlexibleSpaceBar(
                centerTitle: false,
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
              _HeaderOfflineSlot(
                progress: t,
                topPad: topPad,
                hasTrailingLogo: trailingLogoAsset != null,
                renderCornerInFlexibleSpace: !hasUserActions,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _HeaderOfflineSlot extends StatelessWidget {
  const _HeaderOfflineSlot({
    required this.progress,
    required this.topPad,
    required this.hasTrailingLogo,
    required this.renderCornerInFlexibleSpace,
  });

  final double progress;
  final double topPad;
  final bool hasTrailingLogo;
  final bool renderCornerInFlexibleSpace;

  @override
  Widget build(BuildContext context) {
    const cornerGap = 8.0;
    final logoSize = hasTrailingLogo ? _lerp(42.0, 96.0, progress) : 0.0;
    final logoRight = hasTrailingLogo ? _lerp(12.0, 20.0, progress) : 0.0;
    final cornerRight = hasTrailingLogo
        ? logoRight + logoSize + cornerGap
        : 12.0;

    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned(
          top: topPad + 10,
          left: 0,
          right: 0,
          child: const Align(
            alignment: Alignment.topCenter,
            child: OfflinePill(mode: OfflinePillMode.inline),
          ),
        ),
        if (renderCornerInFlexibleSpace)
          Positioned(
            top: topPad + 12,
            right: cornerRight,
            child: const OfflinePill(mode: OfflinePillMode.corner),
          ),
      ],
    );
  }
}

class _TrailingLogo extends StatelessWidget {
  const _TrailingLogo({
    required this.asset,
    required this.progress,
    required this.topPad,
    required this.bottomH,
  });

  final String asset;

  final double progress;
  final double topPad;
  final double bottomH;

  @override
  Widget build(BuildContext context) {
    final size = _lerp(42.0, 96.0, progress);
    final right = _lerp(12.0, 20.0, progress);
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
