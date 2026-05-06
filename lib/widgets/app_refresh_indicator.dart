import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/elements.dart';
import 'platform_utils.dart';

/// App-wide [RefreshIndicator] with the brand palette colors and an
/// iOS-aware top offset.
///
/// On iOS the status bar / Dynamic Island sits at the top of every
/// screen and would otherwise cover the spinner — `edgeOffset` is set
/// to the safe-area top inset so the indicator appears just below it.
class AppRefreshIndicator extends StatelessWidget {
  const AppRefreshIndicator({
    super.key,
    required this.onRefresh,
    required this.palette,
    required this.child,
  });

  final Future<void> Function() onRefresh;
  final ElementPalette palette;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: palette.base,
      backgroundColor: AppTheme.surfaceContainerHighOf(context),
      edgeOffset: PlatformUtils.isIOS ? topInset : 0,
      child: child,
    );
  }
}
