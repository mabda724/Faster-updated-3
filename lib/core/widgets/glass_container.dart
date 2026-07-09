import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/design_tokens.dart';

/// Apple-style frosted glass container with blue gradient undertones.
class GlassContainer extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final double blurIntensity;
  final bool useBlueTint;

  const GlassContainer({
    super.key,
    required this.child,
    this.borderRadius = DesignTokens.radius2xl,
    this.padding = DesignTokens.cardPadding,
    this.blurIntensity = 15,
    this.useBlueTint = true,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: blurIntensity,
          sigmaY: blurIntensity,
        ),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            gradient: useBlueTint
                ? LinearGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0.65),
                      AppTheme.backgroundColor.withValues(alpha: 0.45),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : LinearGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0.7),
                      Colors.white.withValues(alpha: 0.4),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.6),
              width: 1.5,
            ),
            boxShadow: [
              ...DesignTokens.shadow4(AppTheme.primaryColor),
              ...DesignTokens.shadow2(Colors.black),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}
