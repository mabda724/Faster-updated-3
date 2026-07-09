import '../../../core/theme/app_theme.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/widgets/glowing_button.dart';
import '../../home/presentation/main_nav_screen.dart';

class OtpScreen extends StatefulWidget {
  final String phoneNumber;
  const OtpScreen({super.key, required this.phoneNumber});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> with SingleTickerProviderStateMixin {
  final List<TextEditingController> _controllers = List.generate(4, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(4, (_) => FocusNode());
  late AnimationController _animController;
  late Animation<double> _slideAnimation;
  int _resendSeconds = 30;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _slideAnimation = Tween<double>(begin: 50, end: 0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );
    _animController.forward();
    _startResendTimer();
  }

  void _startResendTimer() {
    _timer?.cancel();
    setState(() => _resendSeconds = 30);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendSeconds > 0) {
        setState(() => _resendSeconds--);
      } else {
        timer.cancel();
      }
    });
  }

  void _onOtpChanged(int index, String value) {
    if (value.isNotEmpty && index < 3) {
      _focusNodes[index + 1].requestFocus();
    }
    if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
    // Auto-verify when all fields are filled
    final otp = _controllers.map((c) => c.text).join();
    if (otp.length == 4) {
      _verifyOtp(otp);
    }
  }

  void _verifyOtp(String otp) {
    Navigator.pushAndRemoveUntil(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const MainNavScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
      (route) => false,
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _animController.dispose();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Stack(
        children: [
          // Background glows
          Positioned(
            top: -80,
            right: -60,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.secondaryColor.withValues(alpha: 0.05),
                    AppTheme.secondaryColor.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            left: -40,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.primaryColor.withValues(alpha: 0.05),
                    AppTheme.primaryColor.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.w),
              child: AnimatedBuilder(
                animation: _slideAnimation,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(0, _slideAnimation.value),
                    child: Opacity(
                      opacity: _animController.value,
                      child: child,
                    ),
                  );
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 16.h),
                    // Back Button
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: DesignTokens.brMd,
                          border: Border.all(color: AppTheme.textPrimary.withValues(alpha: 0.05)),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4),
                          ],
                        ),
                        child: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: AppTheme.textPrimary),
                      ),
                    ),
                    SizedBox(height: 32.h),

                    Text(
                      'تأكيد الرقم',
                      style: Theme.of(context).textTheme.displayLarge,
                    ),
                    SizedBox(height: 8.h),
                      Text(
                        'بعتنالك كود التفعيل على رقمك\n${widget.phoneNumber}',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: DesignTokens.textTitleSmall,
                          height: 1.5,
                        ),
                      ),
                    SizedBox(height: DesignTokens.space48),

                    // OTP Input Fields
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(4, (index) {
                          return Container(
                            margin: EdgeInsets.symmetric(horizontal: 8.w),
                            width: 64.w,
                            height: 64.w,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: DesignTokens.brLg,
                              border: Border.all(color: AppTheme.textPrimary.withValues(alpha: 0.1)),
                              boxShadow: [
                                BoxShadow(color: Colors.black.withValues(alpha: 0.01), blurRadius: 4),
                              ],
                            ),
                            child: Center(
                              child: TextField(
                                controller: _controllers[index],
                                focusNode: _focusNodes[index],
                                textAlign: TextAlign.center,
                                keyboardType: TextInputType.number,
                                maxLength: 1,
                                style: TextStyle(
                                  fontSize: DesignTokens.textDisplayMedium,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textPrimary,
                                ),
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                decoration: const InputDecoration(
                                  counterText: '',
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  filled: false,
                                ),
                                onChanged: (value) => _onOtpChanged(index, value),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                    SizedBox(height: DesignTokens.space32),

                    // Resend Timer
                    Center(
                      child: _resendSeconds > 0
                            ? Text(
                                'إعادة إرسال الكود بعد $_resendSeconds ثانية',
                                style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: DesignTokens.textBodyMedium,
                                ),
                              )
                            : GestureDetector(
                                onTap: _startResendTimer,
                                child: Text(
                                  'ابعت الكود تاني',
                                  style: TextStyle(
                                    color: AppTheme.primaryColor,
                                    fontSize: DesignTokens.textBodyMedium,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                    ),
                    const Spacer(),

                    // Verify Button
                    GlowingButton(
                      text: 'أكد الدخول',
                      onPressed: () {
                        final otp = _controllers.map((c) => c.text).join();
                        if (otp.length == 4) {
                          _verifyOtp(otp);
                        }
                      },
                    ),
                    SizedBox(height: DesignTokens.space32),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
