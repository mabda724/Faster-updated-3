import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/design_tokens.dart';

class SnackBarUtils {
  static void showSuccess(BuildContext context, String message) {
    _show(context, message, AppTheme.successColor, Icons.check_circle_outline_rounded);
  }

  static void showError(BuildContext context, String message) {
    _show(context, message, AppTheme.errorColor, Icons.error_outline_rounded);
  }

  static void showInfo(BuildContext context, String message) {
    _show(context, message, AppTheme.infoColor, Icons.info_outline_rounded);
  }

  static void showWarning(BuildContext context, String message) {
    _show(context, message, AppTheme.warningColor, Icons.warning_amber_rounded);
  }

  static void _show(
    BuildContext context,
    String message,
    Color backgroundColor,
    IconData icon,
  ) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: DesignTokens.iconMd),
            SizedBox(width: DesignTokens.space3),
            Expanded(
              child: Text(
                message,
                textAlign: TextAlign.start,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: DesignTokens.brMd),
        margin: EdgeInsets.all(DesignTokens.space4),
      ),
    );
  }
}
