import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../theme/app_theme.dart';
import '../theme/design_tokens.dart';

/// ButtonType determines the visual style of the button.
enum AppButtonType { primary, secondary, outline, danger, ghost }

/// Unified button component for the Faster app.
class AppButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final AppButtonType type;
  final IconData? icon;
  final bool isLoading;
  final bool isFullWidth;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;

  const AppButton({
    super.key,
    required this.text,
    this.onPressed,
    this.type = AppButtonType.primary,
    this.icon,
    this.isLoading = false,
    this.isFullWidth = true,
    this.height,
    this.padding,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final buttonHeight = height ?? DesignTokens.buttonHeight;
    final buttonPadding = padding ?? DesignTokens.buttonPadding;

    Widget child = isLoading
        ? SizedBox(
            height: 20.w,
            width: 20.w,
            child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: DesignTokens.iconSm, color: _textColor(context, isDark)),
                SizedBox(width: 6.w),
              ],
              Text(
                text,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: _textColor(context, isDark),
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          );

    Widget button;
    switch (type) {
      case AppButtonType.primary:
        button = ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryColor,
            foregroundColor: Colors.white,
            elevation: DesignTokens.elevation0,
            padding: buttonPadding,
            shape: RoundedRectangleBorder(borderRadius: DesignTokens.brLg),
            minimumSize: Size(isFullWidth ? double.infinity : 0, buttonHeight),
          ),
          child: child,
        );
        break;
      case AppButtonType.secondary:
        button = ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.secondaryColor,
            foregroundColor: Colors.white,
            elevation: DesignTokens.elevation0,
            padding: buttonPadding,
            shape: RoundedRectangleBorder(borderRadius: DesignTokens.brLg),
            minimumSize: Size(isFullWidth ? double.infinity : 0, buttonHeight),
          ),
          child: child,
        );
        break;
      case AppButtonType.outline:
        button = OutlinedButton(
          onPressed: isLoading ? null : onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.primaryColor,
            side: BorderSide(color: AppTheme.primaryColor, width: 1.5),
            padding: buttonPadding,
            shape: RoundedRectangleBorder(borderRadius: DesignTokens.brLg),
            minimumSize: Size(isFullWidth ? double.infinity : 0, buttonHeight),
          ),
          child: child,
        );
        break;
      case AppButtonType.danger:
        button = ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.errorColor,
            foregroundColor: Colors.white,
            elevation: DesignTokens.elevation0,
            padding: buttonPadding,
            shape: RoundedRectangleBorder(borderRadius: DesignTokens.brLg),
            minimumSize: Size(isFullWidth ? double.infinity : 0, buttonHeight),
          ),
          child: child,
        );
        break;
      case AppButtonType.ghost:
        button = TextButton(
          onPressed: isLoading ? null : onPressed,
          style: TextButton.styleFrom(
            foregroundColor: AppTheme.primaryColor,
            padding: buttonPadding,
            minimumSize: Size(isFullWidth ? double.infinity : 0, buttonHeight),
          ),
          child: child,
        );
        break;
    }

    if (margin != null) {
      button = Padding(padding: margin!, child: button);
    }

    return button;
  }

  Color _textColor(BuildContext context, bool isDark) {
    switch (type) {
      case AppButtonType.primary:
      case AppButtonType.secondary:
      case AppButtonType.danger:
        return Colors.white;
      case AppButtonType.outline:
      case AppButtonType.ghost:
        return AppTheme.primaryColor;
    }
  }
}

/// Small compact button for tight spaces (chips, cards).
class AppSmallButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final AppButtonType type;
  final IconData? icon;
  final bool isLoading;

  const AppSmallButton({
    super.key,
    required this.text,
    this.onPressed,
    this.type = AppButtonType.primary,
    this.icon,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return AppButton(
      text: text,
      onPressed: onPressed,
      type: type,
      icon: icon,
      isLoading: isLoading,
      isFullWidth: false,
      height: DesignTokens.buttonHeightSmall,
      padding: DesignTokens.buttonPaddingSmall,
    );
  }
}
