import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/design_tokens.dart';
import 'waiting_for_provider_screen.dart';

class ClientPaymentSuccessScreen extends StatefulWidget {
  final String? bookingId;
  final String? serviceName;
  final double? totalPrice;

  const ClientPaymentSuccessScreen({
    super.key,
    this.bookingId,
    this.serviceName,
    this.totalPrice,
  });

  @override
  State<ClientPaymentSuccessScreen> createState() => _ClientPaymentSuccessScreenState();
}

class _ClientPaymentSuccessScreenState extends State<ClientPaymentSuccessScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.elasticOut),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeIn),
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(24.w),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ScaleTransition(
                scale: _scaleAnimation,
                child: Container(
                  width: 120.w,
                  height: 120.w,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Container(
                      width: 80.w,
                      height: 80.w,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryColor.withOpacity(0.3),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 50,
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 32.h),
              FadeTransition(
                opacity: _fadeAnimation,
                child: Column(
                  children: [
                    Text(
                      'تم تأكيد حجزك بنجاح!',
                      style: TextStyle(
                        fontSize: DesignTokens.textDisplayLarge,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 16.h),
                    Text(
                      'بانتظار قبول مقدم الخدمة لطلبك...\nستصلك إشعار عند قبول أحد.',
                      style: TextStyle(
                        fontSize: DesignTokens.textBodyLarge,
                        color: AppTheme.textPrimary.withOpacity(0.7),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              SizedBox(height: 24.h),
              FadeTransition(
                opacity: _fadeAnimation,
                child: Container(
                  padding: EdgeInsets.all(16.w),
                  decoration: BoxDecoration(
                    color: AppTheme.warningColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.warningColor.withOpacity(0.2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.access_time, color: AppTheme.warningColor, size: 20),
                      SizedBox(width: 10.w),
                      Text(
                        'مدة الانتظار: 15 دقيقة',
                        style: TextStyle(
                          color: AppTheme.warningColor,
                          fontWeight: FontWeight.w500,
                          fontSize: DesignTokens.textLabelLarge,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 48.h),
              FadeTransition(
                opacity: _fadeAnimation,
                child: Column(
                  children: [
                    if (widget.bookingId != null)
                      SizedBox(
                        width: double.infinity,
                        height: 56.h,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (context) => WaitingForProviderScreen(
                                  bookingId: widget.bookingId!,
                                  serviceName: widget.serviceName ?? 'خدمة',
                                  totalPrice: widget.totalPrice ?? 0,
                                ),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
                          color: AppTheme.primaryColor,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.search, color: Colors.white),
                              SizedBox(width: 8.w),
                              Text(
                                'تابع طلبك',
                                style: TextStyle(
                                  fontSize: DesignTokens.textLabelLarge,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    SizedBox(height: 12.h),
                    SizedBox(
                      width: double.infinity,
                      height: 56.h,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const MainNavScreen(),
                            ),
                            (route) => false,
                          );
                        },
                        borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
                        color: Colors.white,
                      ),
                      child: Text(
                        'العودة للرئيسية',
                        style: TextStyle(
                          fontSize: DesignTokens.textLabelLarge,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
