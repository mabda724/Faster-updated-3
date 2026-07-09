import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/design_tokens.dart';

/// Apple-style reusable widgets
/// Clean white & blue design matching iOS

// ============ BUTTONS ============

class AppleButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isPrimary;
  final bool isLoading;
  final double? width;
  final double? height;
  final EdgeInsets? padding;

  const AppleButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isPrimary = true,
    this.isLoading = false,
    this.width,
    this.height,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final borderRadius = DesignTokens.brMd;
    final btnHeight = height ?? DesignTokens.buttonHeight;

    if (isLoading) {
      return SizedBox(
        height: btnHeight,
        width: width ?? double.infinity,
        child: ElevatedButton(
          padding: padding ?? DesignTokens.buttonPadding,
          borderRadius: borderRadius,
          color: AppTheme.primaryColor.withValues(alpha: 0.3),
          onPressed: null,
          child: const CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    if (isPrimary) {
      return SizedBox(
        height: btnHeight,
        width: width ?? double.infinity,
        child: ElevatedButton(
          padding: padding ?? DesignTokens.buttonPadding,
          borderRadius: borderRadius,
          color: AppTheme.primaryColor,
          disabledColor: Colors.grey.shade300,
          onPressed: onPressed,
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: DesignTokens.iconMd,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    } else {
      return SizedBox(
        height: btnHeight,
        width: width ?? double.infinity,
        child: ElevatedButton(
          padding: padding ?? DesignTokens.buttonPadding,
          borderRadius: borderRadius,
          color: Colors.white,
          disabledColor: Colors.grey.shade100,
          onPressed: onPressed,
          child: Text(
            text,
            style: const TextStyle(
              color: AppTheme.primaryColor,
              fontSize: DesignTokens.iconMd,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }
  }
}

class AppleTextButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final TextStyle? style;

  const AppleTextButton({
    super.key,
    required this.text,
    this.onPressed,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      padding: EdgeInsets.zero,
      onPressed: onPressed,
      child: Text(
        text,
        style: style ??
            const TextStyle(
              color: AppTheme.primaryColor,
              fontSize: DesignTokens.textBodyLarge,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

// ============ CARDS ============

class AppleCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final double? elevation;
  final BorderRadius? borderRadius;
  final Color? color;
  final VoidCallback? onTap;

  const AppleCard({
    super.key,
    required this.child,
    this.padding,
    this.elevation,
    this.borderRadius,
    this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cardColor = color ?? theme.cardColor;
    final radius = borderRadius ?? DesignTokens.brLg;

    Widget card = Container(
      padding: padding ?? DesignTokens.cardPadding,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: radius,
        border: Border.all(
          color: theme.brightness == Brightness.dark
              ? AppTheme.darkBorder
              : AppTheme.borderColor,
          width: 0.5,
        ),
        boxShadow: elevation != null && elevation! > 0
            ? (theme.brightness == Brightness.dark
                ? DesignTokens.shadow2(Colors.black)
                : DesignTokens.shadow1(Colors.black))
            : null,
      ),
      child: child,
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: card,
      );
    }

    return card;
  }
}

// ============ TEXT FIELDS ============

class AppleTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String? hintText;
  final String? labelText;
  final bool obscureText;
  final TextInputType? keyboardType;
  final Widget? prefix;
  final Widget? suffix;
  final bool enabled;
  final int? maxLines;
  final int? minLines;
  final TextInputAction? textInputAction;
  final void Function(String)? onChanged;
  final void Function(String)? onSubmitted;
  final String? Function(String?)? validator;

  const AppleTextField({
    super.key,
    this.controller,
    this.hintText,
    this.labelText,
    this.obscureText = false,
    this.keyboardType,
    this.prefix,
    this.suffix,
    this.enabled = true,
    this.maxLines = 1,
    this.minLines,
    this.textInputAction,
    this.onChanged,
    this.onSubmitted,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      maxLines: maxLines,
      minLines: minLines,
      textInputAction: textInputAction,
      onChanged: onChanged,
      onFieldSubmitted: onSubmitted,
      validator: validator,
      enabled: enabled,
      style: TextStyle(
        fontSize: DesignTokens.textBodyLarge,
        color: Theme.of(context).textTheme.bodyLarge?.color,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(
          color: Colors.grey.shade400,
          fontSize: DesignTokens.textBodyLarge,
        ),
        labelText: labelText,
        labelStyle: TextStyle(
          color: Colors.grey.shade500,
          fontSize: DesignTokens.textBodyMedium,
        ),
        filled: true,
        fillColor: Theme.of(context).brightness == Brightness.dark
            ? AppTheme.darkSurfaceColor
            : Colors.grey.shade50,
        contentPadding: EdgeInsets.symmetric(
          horizontal: DesignTokens.space12,
          vertical: DesignTokens.space14,
        ),
        border: OutlineInputBorder(
          borderRadius: DesignTokens.brMd,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: DesignTokens.brMd,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: DesignTokens.brMd,
          borderSide: const BorderSide(color: AppTheme.primaryColor, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: DesignTokens.brMd,
          borderSide: const BorderSide(color: AppTheme.errorColor, width: 1.0),
        ),
        prefixIcon: prefix != null
            ? Padding(
                padding: EdgeInsets.only(right: DesignTokens.space8),
                child: prefix,
              )
            : null,
        suffixIcon: suffix != null
            ? Padding(
                padding: EdgeInsets.only(left: DesignTokens.space8),
                child: suffix,
              )
            : null,
      ),
    );
  }
}

// ============ LIST TILES ============

class AppleListTile extends StatelessWidget {
  final Widget? leading;
  final String? title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showChevron;
  final Color? backgroundColor;
  final EdgeInsets? padding;

  const AppleListTile({
    super.key,
    this.leading,
    this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.showChevron = false,
    this.backgroundColor,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tileColor = backgroundColor ??
        (theme.brightness == Brightness.dark
            ? AppTheme.darkSurfaceColor
            : Colors.grey.shade50);

    Widget tile = Container(
      color: tileColor,
      padding: padding ??
          EdgeInsets.symmetric(
            horizontal: DesignTokens.space16,
            vertical: DesignTokens.space12,
          ),
      child: Row(
        children: [
          if (leading != null) ...[
            leading!,
            SizedBox(width: DesignTokens.space12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (title != null)
                  Text(
                    title!,
                    style: TextStyle(
                      fontSize: DesignTokens.textBodyLarge,
                      fontWeight: FontWeight.w500,
                      color: theme.textTheme.bodyLarge?.color,
                    ),
                  ),
                if (subtitle != null && title != null)
                  SizedBox(height: DesignTokens.space4),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: DesignTokens.textBodyMedium,
                      color: Colors.grey.shade500,
                    ),
                  ),
              ],
            ),
          ),
          if (trailing != null) ...[
            SizedBox(width: DesignTokens.space8),
            trailing!,
          ],
          if (showChevron) ...[
            SizedBox(width: DesignTokens.space4),
            Icon(
              Icons.chevron_left_rounded,
              size: DesignTokens.iconSm,
              color: Colors.grey.shade400,
            ),
          ],
        ],
      ),
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: tile,
      );
    }

    return tile;
  }
}

// ============ SECTION HEADER ============

class AppleSectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const AppleSectionHeader({
    super.key,
    required this.title,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: DesignTokens.space16,
        right: DesignTokens.space16,
        top: DesignTokens.space24,
        bottom: DesignTokens.space8,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: DesignTokens.textTitleMedium,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

// ============ AVATAR ============

class AppleAvatar extends StatelessWidget {
  final String? imageUrl;
  final String? initials;
  final double size;
  final Color? backgroundColor;

  const AppleAvatar({
    super.key,
    this.imageUrl,
    this.initials,
    this.size = 48,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final radius = size / 2;
    final bgColor = backgroundColor ?? AppTheme.primaryColor;

    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Image.network(
          imageUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _buildFallback(radius, bgColor);
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(radius),
              ),
              child: Center(
                child: CircularProgressIndicator(
                  radius: size * 0.15,
                ),
              ),
            );
          },
        ),
      );
    } else {
      return _buildFallback(radius, bgColor);
    }
  }

  Widget _buildFallback(double radius, Color bgColor) {
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Center(
        child: Text(
          initials ?? '?',
          style: TextStyle(
            color: Colors.white,
            fontSize: radius * 0.8,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

// ============ BADGES ============

class AppleBadge extends StatelessWidget {
  final String text;
  final Color? backgroundColor;
  final Color? textColor;
  final double? fontSize;

  const AppleBadge({
    super.key,
    required this.text,
    this.backgroundColor,
    this.textColor,
    this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? AppTheme.primaryColor;
    final fg = textColor ?? Colors.white;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: DesignTokens.space8,
        vertical: DesignTokens.space4,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: DesignTokens.brFull,
      ),
      child: Text(
        text,
        style: TextStyle(
          color: fg,
          fontSize: fontSize ?? DesignTokens.textBodySmall,
          fontWeight: FontWeight.w600,
          height: 1.2,
        ),
      ),
    );
  }
}

// ============ LOADING ============

class AppleLoading extends StatelessWidget {
  final double? size;

  const AppleLoading({super.key, this.size});

  @override
  Widget build(BuildContext context) {
    return CircularProgressIndicator(
      radius: size ?? 12,
      color: AppTheme.primaryColor,
    );
  }
}

class AppleProgressIndicator extends StatelessWidget {
  final double value;
  final Color? color;

  const AppleProgressIndicator({
    super.key,
    required this.value,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return LinearProgressIndicator(
      value: value,
      backgroundColor: Colors.grey.shade200,
      valueColor: AlwaysStoppedAnimation<Color>(
        color ?? AppTheme.primaryColor,
      ),
      borderRadius: DesignTokens.brFull,
      minHeight: 4,
    );
  }
}

// ============ SEPARATORS ============

class AppleDivider extends StatelessWidget {
  final double? thickness;
  final EdgeInsets? margin;
  final bool isVertical;

  const AppleDivider({
    super.key,
    this.thickness,
    this.margin,
    this.isVertical = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final divider = Container(
      width: isVertical ? thickness : double.infinity,
      height: isVertical ? double.infinity : thickness,
      color: theme.brightness == Brightness.dark
          ? AppTheme.darkBorder
          : AppTheme.borderColor,
    );

    if (margin != null) {
      return Padding(padding: margin!, child: divider);
    }

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: DesignTokens.space16,
        vertical: DesignTokens.space8,
      ),
      child: divider,
    );
  }
}

// ============ EMPTY STATE ============

class AppleEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  const AppleEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(DesignTokens.space32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: DesignTokens.iconXl * 1.5,
              color: Colors.grey.shade400,
            ),
            SizedBox(height: DesignTokens.space16),
            Text(
              title,
              style: TextStyle(
                fontSize: DesignTokens.textTitleLarge,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
              textAlign: TextAlign.center,
            ),
            if (message != null) ...[
              SizedBox(height: DesignTokens.space8),
              Text(
                message!,
                style: TextStyle(
                  fontSize: DesignTokens.textBodyMedium,
                  color: Colors.grey.shade500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[
              SizedBox(height: DesignTokens.space24),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

// ============ ALERTS / DIALOGS ============

Future<T?> showAppleAlertDialog<T>({
  required BuildContext context,
  required String title,
  String? message,
  String? cancelActionLabel,
  String? defaultActionLabel,
  bool isDestructive = false,
  VoidCallback? onCancel,
  VoidCallback? onConfirm,
}) {
  return showDialog<T>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: message != null ? Text(message) : null,
      actions: [
        if (cancelActionLabel != null)
          TextButton(
            child: Text(cancelActionLabel),
            onPressed: () {
              if (onCancel != null) {
                onCancel();
              } else {
                Navigator.pop(context);
              }
            },
          ),
        if (defaultActionLabel != null)
          TextButton(
            isDefaultAction: true,
            isDestructiveAction: isDestructive,
            child: Text(defaultActionLabel),
            onPressed: () {
              if (onConfirm != null) {
                onConfirm();
              }
              Navigator.pop(context);
            },
          ),
      ],
    ),
  );
}