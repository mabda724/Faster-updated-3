import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/design_tokens.dart';
import 'app_button.dart';

/// Reusable empty state widget for screens with no data.
class AppEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final double iconSize;

  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.iconSize = 64,
  });

  static AppEmptyState forOrders({VoidCallback? onAction}) => AppEmptyState(
        icon: Icons.receipt_long_outlined,
        title: 'لا توجد طلبات',
        subtitle: 'اطلب خدمة الآن واحصل على أفضل المزودين',
        actionLabel: 'اطلب الآن',
        onAction: onAction,
      );

  static AppEmptyState forNotifications({VoidCallback? onAction}) => AppEmptyState(
        icon: Icons.notifications_none_outlined,
        title: 'لا توجد إشعارات',
        subtitle: 'سنخبرك عندما تحدث أشياء مثيرة!',
        actionLabel: 'استكشف',
        onAction: onAction,
      );

  static AppEmptyState forSearch({String? query}) => AppEmptyState(
        icon: Icons.search_off_outlined,
        title: 'لا توجد نتائج',
        subtitle: query != null ? 'جرب بحثك عن "$query" بكلمات أخرى.' : 'جرب مصطلحات بحث مختلفة.',
      );

  static AppEmptyState forNetwork({VoidCallback? onRetry}) => AppEmptyState(
        icon: Icons.wifi_off_outlined,
        title: 'لا يوجد اتصال بالإنترنت',
        subtitle: 'الرجاء التحقق من إعدادات الشبكة والمحاولة مرة أخرى.',
        actionLabel: 'إعادة المحاولة',
        onAction: onRetry,
      );

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: DesignTokens.pagePaddingH,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(DesignTokens.space4),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: iconSize, color: AppTheme.primaryColor),
            ),
            SizedBox(height: DesignTokens.space16),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppTheme.adaptiveTextPrimary(context),
                  ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              SizedBox(height: DesignTokens.space8),
              Text(
                subtitle!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.adaptiveTextSecondary(context),
                    ),
                textAlign: TextAlign.center,
              ),
            ],
            if (onAction != null && actionLabel != null) ...[
              SizedBox(height: DesignTokens.space16),
              AppButton(
                text: actionLabel!,
                onPressed: onAction,
                isFullWidth: false,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
