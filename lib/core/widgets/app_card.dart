import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/design_tokens.dart';

/// CardType determines the visual style of the card.
enum CardType { glass, elevated, outlined, flat }

/// Unified card component for the Faster app.
/// Supports glassmorphism, elevated, outlined, and flat variants.
class AppCard extends StatelessWidget {
  final Widget child;
  final CardType type;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? margin;
  final Color? backgroundColor;

  const AppCard({
    super.key,
    required this.child,
    this.type = CardType.elevated,
    this.padding,
    this.onTap,
    this.width,
    this.height,
    this.margin,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: _buildDecoration(context, isDark),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: DesignTokens.brXl,
          child: Padding(
            padding: padding ?? DesignTokens.cardPadding,
            child: child,
          ),
        ),
      ),
    );
  }

  BoxDecoration _buildDecoration(BuildContext context, bool isDark) {
    switch (type) {
      case CardType.glass:
        return BoxDecoration(
          borderRadius: DesignTokens.brXl,
          color: backgroundColor ?? (isDark
              ? AppTheme.darkSurfaceColor.withValues(alpha: 0.6)
              : Colors.white.withValues(alpha: 0.7)),
          border: Border.all(
            color: isDark
                ? AppTheme.darkBorder.withValues(alpha: 0.3)
                : Colors.white.withValues(alpha: 0.5),
            width: 1.5,
          ),
          boxShadow: DesignTokens.shadow1(isDark ? Colors.black : Colors.grey),
        );
      case CardType.elevated:
        return BoxDecoration(
          borderRadius: DesignTokens.brXl,
          color: backgroundColor ?? AppTheme.adaptiveSurface(context),
          boxShadow: DesignTokens.shadow2(isDark ? Colors.black : Colors.grey),
        );
      case CardType.outlined:
        return BoxDecoration(
          borderRadius: DesignTokens.brXl,
          color: backgroundColor ?? AppTheme.adaptiveSurface(context),
          border: Border.all(color: AppTheme.adaptiveBorder(context), width: 1),
        );
      case CardType.flat:
        return BoxDecoration(
          borderRadius: DesignTokens.brXl,
          color: backgroundColor ?? AppTheme.adaptiveSurface(context),
        );
    }
  }
}
