import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/design_tokens.dart';

class AppTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final IconData? icon;
  final TextInputType type;
  final int maxLines;
  final bool obscureText;
  final bool readOnly;
  final VoidCallback? onTap;
  final Widget? suffix;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;
  final FocusNode? focusNode;
  final Color? focusColor;

  const AppTextField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.icon,
    this.type = TextInputType.text,
    this.maxLines = 1,
    this.obscureText = false,
    this.readOnly = false,
    this.onTap,
    this.suffix,
    this.validator,
    this.onChanged,
    this.focusNode,
    this.focusColor,
  });

  @override
  Widget build(BuildContext context) {
    final baseDecoration = InputDecoration(
      hintText: hint,
      prefixIcon: icon != null ? Icon(icon, size: DesignTokens.iconMd) : null,
      suffixIcon: suffix,
      border: OutlineInputBorder(
        borderRadius: DesignTokens.brMd,
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: DesignTokens.brMd,
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: DesignTokens.brMd,
        borderSide: BorderSide(color: focusColor ?? AppTheme.primaryColor, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: DesignTokens.brMd,
        borderSide: BorderSide(color: AppTheme.errorColor),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: DesignTokens.brMd,
        borderSide: BorderSide(color: AppTheme.errorColor, width: 2),
      ),
      filled: true,
      fillColor: Colors.grey.shade50,
      contentPadding: EdgeInsets.symmetric(
        horizontal: DesignTokens.space4,
        vertical: DesignTokens.space3,
      ),
    );

    final child = maxLines > 1
        ? TextFormField(
            controller: controller,
            keyboardType: type,
            maxLines: maxLines,
            readOnly: readOnly,
            onTap: onTap,
            validator: validator,
            onChanged: onChanged,
            focusNode: focusNode,
            obscureText: obscureText,
            decoration: baseDecoration,
          )
        : TextFormField(
            controller: controller,
            keyboardType: type,
            readOnly: readOnly,
            onTap: onTap,
            validator: validator,
            onChanged: onChanged,
            focusNode: focusNode,
            obscureText: obscureText,
            decoration: baseDecoration,
          );

    if (label == null) return child;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label!,
          style: TextStyle(
            fontSize: DesignTokens.textBodySmall,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        SizedBox(height: DesignTokens.space2),
        child,
      ],
    );
  }
}

class AppPasswordField extends StatefulWidget {
  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;
  final Color? focusColor;

  const AppPasswordField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.validator,
    this.onChanged,
    this.focusColor,
  });

  @override
  State<AppPasswordField> createState() => _AppPasswordFieldState();
}

class _AppPasswordFieldState extends State<AppPasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      controller: widget.controller,
      label: widget.label,
      hint: widget.hint,
      icon: Icons.lock_outline_rounded,
      type: TextInputType.visiblePassword,
      obscureText: _obscure,
      focusColor: widget.focusColor,
      validator: widget.validator,
      onChanged: widget.onChanged,
      suffix: IconButton(
        icon: Icon(
          _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
          size: DesignTokens.iconSm,
        ),
        onPressed: () => setState(() => _obscure = !_obscure),
      ),
    );
  }
}
