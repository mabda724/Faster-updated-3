import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/design_tokens.dart';
class PaymentSuccessScreen extends StatelessWidget {
  final String tier;

  const PaymentSuccessScreen({super.key, required this.tier});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(DesignTokens.space24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Success icon
                Icon(
                  Icons.check_rounded_circle_fill,
                  size: 100.sp,
                  color: AppTheme.successColor,
                ),
                SizedBox(height: 24.h),
                Text(
                  'تمت عملية الدفع بنجاح!',
                  style: TextStyle(
                    fontSize: DesignTokens.textDisplayLarge,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                SizedBox(height: 12.h),
                    Text(
                      'تم ترقية حسابك إلى الفئة $tier بنجاح. استمتع بمميزاتك الجديدة الآن.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: DesignTokens.textBodyLarge,
                        color: AppTheme.textPrimary.withOpacity(0.7),
                  ),
                ),
                SizedBox(height: 48.h),
                SizedBox(
                  width: double.infinity,
                  height: 55.h,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
                    color: AppTheme.primaryColor,
                    child: const Text(
                      'العودة للرئيسية',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
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
