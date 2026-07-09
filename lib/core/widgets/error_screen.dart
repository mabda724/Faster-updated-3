import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/design_tokens.dart';

class ErrorScreen extends StatelessWidget {
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData icon;

  const ErrorScreen({
    super.key,
    this.title = 'حدث خطأ ما',
    this.message = 'نأسف، حدث خطأ غير متوقع. يرجى المحاولة مرة أخرى.',
    this.actionLabel,
    this.onAction,
    this.icon = Icons.error_outline_rounded,
  });

  const ErrorScreen.notFound({
    super.key,
    this.title = 'الصفحة غير موجودة',
    this.message = 'عذراً، الصفحة التي تبحث عنها غير متوفرة.',
    this.actionLabel = 'العودة للرئيسية',
    this.onAction,
    this.icon = Icons.search_off_rounded,
  });

  const ErrorScreen.serverError({
    super.key,
    this.title = 'خطأ في الخادم',
    this.message = 'المشكلة من جهة الخادم، حاول مرة أخرى لاحقاً.',
    this.actionLabel = 'إعادة المحاولة',
    this.onAction,
    this.icon = Icons.cloud_off_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: DesignTokens.space40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: AppTheme.errorColor.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: DesignTokens.iconXl + 16, color: AppTheme.errorColor),
                ),
                const SizedBox(height: DesignTokens.space32),
                Text(
                  title,
                  style: TextStyle(fontSize: DesignTokens.textTitleLarge, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: DesignTokens.space12),
                Text(
                  message,
                  style: TextStyle(fontSize: DesignTokens.textBodyMedium, color: AppTheme.textSecondary, height: 1.5),
                  textAlign: TextAlign.center,
                ),
                if (actionLabel != null && onAction != null) ...[
                  const SizedBox(height: DesignTokens.space40),
                  ElevatedButton.icon(
                    onPressed: onAction,
                    icon: const Icon(Icons.refresh_rounded),
                    label: Text(actionLabel!),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: DesignTokens.buttonPadding,
                      shape: RoundedRectangleBorder(borderRadius: DesignTokens.brMd),
                      elevation: 0,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
