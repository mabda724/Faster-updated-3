import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/design_tokens.dart';

class NoInternetScreen extends StatelessWidget {
  final VoidCallback? onRetry;

  const NoInternetScreen({super.key, this.onRetry});

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
                    color: AppTheme.tertiaryColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.wifi_off_rounded, size: DesignTokens.iconXl + 16, color: AppTheme.tertiaryColor),
                ),
                const SizedBox(height: DesignTokens.space32),
                const Text(
                  'لا يوجد اتصال بالإنترنت',
                  style: TextStyle(fontSize: DesignTokens.textTitleLarge, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: DesignTokens.space12),
                const Text(
                  'تأكد من اتصالك بالإنترنت وحاول مرة أخرى',
                  style: TextStyle(fontSize: DesignTokens.textBodyMedium, color: AppTheme.textSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: DesignTokens.space40),
                if (onRetry != null)
                  ElevatedButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('إعادة المحاولة'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: DesignTokens.buttonPadding,
                      shape: RoundedRectangleBorder(borderRadius: DesignTokens.brMd),
                      elevation: 0,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
