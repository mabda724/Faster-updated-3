import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../theme/app_theme.dart';
import '../theme/design_tokens.dart';

/// Unified AppBar for the Faster app.
/// Transparent background, centered title, adaptive dark/light mode.
/// Usage: [AppAppBar]
class AppAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final Widget? subtitle;
  final List<Widget>? actions;
  final bool automaticallyImplyLeading;
  final Widget? leading;
  final VoidCallback? onBack;
  final bool isGlass;
  final Color? backgroundColor;
  final double? elevation;
  final PreferredSizeWidget? bottom;

  const AppAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
    this.automaticallyImplyLeading = true,
    this.leading,
    this.onBack,
    this.isGlass = true,
    this.backgroundColor,
    this.elevation,
    this.bottom,
  });

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? (isGlass ? Colors.transparent : AppTheme.adaptiveSurface(context));
    return AppBar(
      title: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: AppTheme.adaptiveTextPrimary(context),
            fontWeight: FontWeight.w600,
          )),
          if (subtitle != null) subtitle!,
        ],
      ),
      centerTitle: true,
      backgroundColor: bg,
      elevation: elevation ?? 0,
      automaticallyImplyLeading: automaticallyImplyLeading,
      leading: leading ?? (automaticallyImplyLeading && Navigator.of(context).canPop()
          ? IconButton(
              icon: Icon(Icons.arrow_back_ios_new_rounded, size: DesignTokens.iconSm, color: AppTheme.adaptiveTextPrimary(context)),
              onPressed: onBack ?? () => Navigator.of(context).maybePop(),
            )
          : null),
      actions: actions,
      bottom: bottom,
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0));
}
