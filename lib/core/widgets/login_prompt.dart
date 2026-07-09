import '../../core/theme/app_theme.dart';
import '../theme/design_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
// import '../../features/auth/presentation/login_screen.dart'; // Removed to avoid direct dependency

class LoginPrompt extends StatelessWidget {
  const LoginPrompt({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(DesignTokens.radiusXl))),
      builder: (context) => const LoginPrompt(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(DesignTokens.space24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_outline_rounded, size: DesignTokens.iconAvatar, color: AppTheme.primaryColor),
          SizedBox(height: DesignTokens.space16),
          Text('تسجيل الدخول مطلوب', style: TextStyle(fontSize: DesignTokens.textTitleMedium, fontWeight: FontWeight.bold)),
          SizedBox(height: DesignTokens.space8),
          Text('عفواً، يجب تسجيل الدخول للوصول إلى هذه الميزة.', textAlign: TextAlign.center, style: TextStyle(color: AppTheme.textSecondary)),
          SizedBox(height: DesignTokens.space24),
          ElevatedButton(
            onPressed: () => Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, minimumSize: Size(double.infinity, DesignTokens.buttonHeight.h), shape: RoundedRectangleBorder(borderRadius: DesignTokens.brMd)),
            child: Text('تسجيل الدخول الآن', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          TextButton(onPressed: () => Navigator.pop(context), child: Text('إلغاء', style: TextStyle(color: AppTheme.textSecondary))),
        ],
      ),
    );
  }
}
