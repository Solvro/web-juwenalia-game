import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class BrandGradientText extends StatelessWidget {
  const BrandGradientText(
    this.text, {
    super.key,
    required this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.gradient,
  });

  final String text;
  final TextStyle style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (rect) =>
          (gradient ?? AppTheme.brandGradient).createShader(rect),
      child: Text(
        text,
        style: style.copyWith(color: Colors.white),
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: overflow,
      ),
    );
  }
}

class BrandGradientBar extends StatelessWidget {
  const BrandGradientBar({
    super.key,
    this.width = 32,
    this.height = 3,
    this.borderRadius = 2,
  });

  final double width;
  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: AppTheme.brandGradient,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

class BrandGradientPill extends StatelessWidget {
  const BrandGradientPill({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    this.borderRadius = 20,
  });

  final Widget child;
  final EdgeInsets padding;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: AppTheme.brandGradient,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: AppTheme.brandTeal.withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}
