import 'dart:ui';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_spacing.dart';

/// Elite Frosted Glass Card with subtle specular rim highlight and diffused depth.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final Color? surfaceColor;
  final Color? borderColor;
  final double borderWidth;
  final double blurSigma;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius = AppSpacing.radiusLg,
    this.surfaceColor,
    this.borderColor,
    this.borderWidth = 1.0,
    this.blurSigma = 12.0,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveBorderColor = borderColor ?? AppColors.surfaceBorder;
    final effectiveSurface = surfaceColor ?? AppColors.surfaceElevated.withValues(alpha: 0.85);

    Widget content = Container(
      padding: padding ?? AppSpacing.paddingLg,
      decoration: BoxDecoration(
        color: effectiveSurface,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: effectiveBorderColor, width: borderWidth),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );

    if (blurSigma > 0) {
      content = ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: content,
        ),
      );
    }

    if (margin != null) {
      content = Padding(padding: margin!, child: content);
    }

    return content;
  }
}
