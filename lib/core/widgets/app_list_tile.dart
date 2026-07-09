import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/design_tokens.dart';

/// Unified list tile component that respects the design system.
/// Replaces standard ListTile where consistent styling is needed.
class AppListTile extends StatelessWidget {
  final Widget? leading;
  final Widget? title;
  final Widget? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final Color? backgroundColor;

  const AppListTile({
    super.key,
    this.leading,
    this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.padding,
    this.backgroundColor,
  });

  // ─── Factory constructors for common patterns ──

  factory AppListTile.simple({
    required IconData icon,
    required String title,
    String? subtitle,
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    return AppListTile(
      leading: Icon(icon, color: AppTheme.primaryColor, size: DesignTokens.iconMd),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.w600)),
      subtitle: subtitle != null ? Text(subtitle, style: TextStyle(color: AppTheme.textTertiary)) : null,
      trailing: trailing ?? const Icon(Icons.arrow_forward_ios, size: 14, color: AppTheme.textTertiary),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.transparent,
        borderRadius: DesignTokens.brLg,
      ),
      child: ListTile(
        contentPadding: padding ?? DesignTokens.hPadding16,
        leading: leading,
        title: DefaultTextStyle.merge(
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
          child: title ?? const SizedBox.shrink(),
        ),
        subtitle: subtitle,
        trailing: trailing,
        onTap: onTap,
        splashColor: AppTheme.primaryColor.withValues(alpha: 0.1),
        shape: RoundedRectangleBorder(borderRadius: DesignTokens.brLg),
      ),
    );
  }
}
