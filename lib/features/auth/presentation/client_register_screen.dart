import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/design_tokens.dart';
import '../data/auth_repository.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/widgets/app_report_bottom_sheet.dart';

class ClientRegisterScreen extends StatefulWidget {
  const ClientRegisterScreen({super.key});

  @override
  State<ClientRegisterScreen> createState() => _ClientRegisterScreenState();
}

class _ClientRegisterScreenState extends State<ClientRegisterScreen>
    with SingleTickerProviderStateMixin {
  final _authRepo = AuthRepository();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  final _referralCtrl = TextEditingController();

  bool _isLoading = false;
  bool _obscurePass = true;
  bool _obscureConfirm = true;

  late AnimationController _animCtrl;
  late Animation<double> _fadeContent;
  late Animation<Offset> _slideContent;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _fadeContent = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animCtrl, curve: const Interval(0.1, 1.0, curve: Curves.easeIn)),
    );
    _slideContent = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animCtrl, curve: const Interval(0.1, 1.0, curve: Curves.easeOutCubic)),
    );
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmPassCtrl.dispose();
    _referralCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    final name = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text.trim();
    final confirmPass = _confirmPassCtrl.text.trim();

    if (name.isEmpty) {
      SnackBarUtils.showError(context, 'الرجاء إدخال الاسم الكامل');
      return;
    }
    if (phone.isEmpty) {
      SnackBarUtils.showError(context, 'الرجاء إدخال رقم الهاتف');
      return;
    }
    if (phone.length < 11) {
      SnackBarUtils.showError(context, 'رقم الهاتف يجب أن يكون 11 رقماً على الأقل');
      return;
    }
    if (email.isEmpty || !email.contains('@')) {
      SnackBarUtils.showError(context, 'الرجاء إدخال بريد إلكتروني صحيح');
      return;
    }
    if (pass.isEmpty || pass.length < 6) {
      SnackBarUtils.showError(context, 'كلمة المرور يجب أن تكون 6 أحرف على الأقل');
      return;
    }
    if (pass != confirmPass) {
      SnackBarUtils.showError(context, 'كلمتا المرور غير متطابقتين');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final r = await _authRepo.signUp(
        phone: phone,
        password: pass,
        email: email,
        fullName: name,
        role: 'client',
        referredBy: null,
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (r['success'] == true) {
        String msg = 'تم التسجيل بنجاح!';
        if (_referralCtrl.text.trim().isNotEmpty) {
          try {
            final uid = SupabaseService.currentUserId;
            if (uid != null) {
              final referralResult = await _authRepo.applyReferralCode(
                uid,
                _referralCtrl.text.trim().toUpperCase(),
              );
              if (referralResult['success'] == true) {
                msg += '\n${referralResult['message']}';
              }
            }
          } catch (e) {
            debugPrint('Error applying referral code: $e');
          }
        }
        SnackBarUtils.showSuccess(context, msg);
        Navigator.pushReplacementNamed(context, '/login');
      } else {
        SnackBarUtils.showError(context, r['error'] ?? 'حدث خطأ ما');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      SnackBarUtils.showError(context, 'فشل التسجيل، حاول مرة أخرى');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppTheme.primaryColor,
              AppTheme.primaryColor.withValues(alpha: 0.9),
            ],
            begin: Alignment.topCenter,
            end: Alignment(0, 0.35),
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // App Bar area
              Padding(
                padding: EdgeInsets.symmetric(horizontal: DesignTokens.space8),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Spacer(),
                    Text(
                      'إنشاء حساب',
                      style: GoogleFonts.cairo(
                        fontSize: DesignTokens.textTitleMedium,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const Spacer(),
                    SizedBox(width: 48),
                  ],
                ),
              ),
              SizedBox(height: DesignTokens.space32),
              // Header icon
              FadeTransition(
                opacity: _fadeContent,
                child: Column(
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.person_add_rounded,
                        size: 36,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: DesignTokens.space12),
                    Text(
                      'مرحباً بك في FASTER',
                      style: GoogleFonts.cairo(
                        fontSize: DesignTokens.textTitleLarge,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: DesignTokens.space4),
                    Text(
                      'سجل حسابك للاستفادة من جميع الخدمات',
                      style: GoogleFonts.cairo(
                        fontSize: DesignTokens.textBodySmall,
                        color: Colors.white.withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: DesignTokens.space32),
              // Form card
              Expanded(
                child: FadeTransition(
                  opacity: _fadeContent,
                  child: SlideTransition(
                    position: _slideContent,
                    child: Container(
                      width: double.infinity,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(DesignTokens.radiusXl * 1.5),
                          topRight: Radius.circular(DesignTokens.radiusXl * 1.5),
                        ),
                      ),
                      child: SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(
                          DesignTokens.space20,
                          DesignTokens.space24,
                          DesignTokens.space20,
                          DesignTokens.space32,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.all(DesignTokens.space2),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                                    borderRadius: DesignTokens.brSm,
                                  ),
                                  child: Icon(
                                    Icons.person_rounded,
                                    size: DesignTokens.iconSm,
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                                SizedBox(width: DesignTokens.space8),
                                Text(
                                  'المعلومات الشخصية',
                                  style: GoogleFonts.cairo(
                                    fontSize: DesignTokens.textBodyLarge,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: DesignTokens.space16),
                            AppTextField(
                              controller: _nameCtrl,
                              label: 'الاسم الكامل',
                              hint: 'أدخل اسمك الكامل',
                              icon: Icons.person_rounded,
                            ),
                            SizedBox(height: DesignTokens.space12),
                            AppTextField(
                              controller: _phoneCtrl,
                              label: 'رقم الهاتف',
                              hint: 'أدخل رقم الهاتف (11 رقماً)',
                              icon: Icons.phone_android_rounded,
                              type: TextInputType.phone,
                            ),
                            SizedBox(height: DesignTokens.space12),
                            AppTextField(
                              controller: _emailCtrl,
                              label: 'البريد الإلكتروني',
                              hint: 'example@email.com',
                              icon: Icons.email_rounded,
                              type: TextInputType.emailAddress,
                            ),
                            SizedBox(height: DesignTokens.space12),
                            AppPasswordField(
                              controller: _passCtrl,
                              label: 'كلمة المرور',
                              hint: '6 أحرف على الأقل',
                            ),
                            SizedBox(height: DesignTokens.space12),
                            AppPasswordField(
                              controller: _confirmPassCtrl,
                              label: 'تأكيد كلمة المرور',
                              hint: 'أعد إدخال كلمة المرور',
                            ),
                            SizedBox(height: DesignTokens.space12),
                            AppTextField(
                              controller: _referralCtrl,
                              label: 'كود دعوة (اختياري)',
                              hint: 'أدخل كود الدعوة إن وجد',
                              icon: Icons.card_giftcard_rounded,
                            ),
                            SizedBox(height: DesignTokens.space24),
                            Container(
                              padding: EdgeInsets.all(DesignTokens.space12),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withValues(alpha: 0.05),
                                borderRadius: DesignTokens.brMd,
                                border: Border.all(
                                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.info_outline_rounded,
                                    size: DesignTokens.iconSm,
                                    color: AppTheme.primaryColor.withValues(alpha: 0.7),
                                  ),
                                  SizedBox(width: DesignTokens.space8),
                                  Expanded(
                                    child: Text(
                                      'بعد التسجيل، يمكنك طلب الخدمات المنزلية والتوصيل والمشاوير بكل سهولة',
                                      style: GoogleFonts.cairo(
                                        fontSize: DesignTokens.textLabelMedium,
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: DesignTokens.space24),
                            ElevatedButton(
                              onPressed: _isLoading ? null : _register,
                              style: ElevatedButton.styleFrom(
                                minimumSize: Size(double.infinity, DesignTokens.buttonHeight.h + 4),
                                backgroundColor: AppTheme.primaryColor,
                                shape: RoundedRectangleBorder(
                                  borderRadius: DesignTokens.brMd,
                                ),
                                elevation: 0,
                              ),
                              child: _isLoading
                                  ? SizedBox(
                                      width: DesignTokens.iconMd,
                                      height: DesignTokens.iconMd,
                                      child: const CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2.5,
                                      ),
                                    )
                                  : Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.check_circle_outline_rounded, size: 20),
                                        SizedBox(width: DesignTokens.space6),
                                        Text(
                                          'إنشاء الحساب',
                                          style: GoogleFonts.cairo(
                                            fontSize: DesignTokens.textBodyLarge,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                            SizedBox(height: DesignTokens.space16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'لديك حساب بالفعل؟ ',
                                  style: GoogleFonts.cairo(
                                    fontSize: DesignTokens.textBodyMedium,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => Navigator.pop(context),
                                  child: Text(
                                    'سجل دخول',
                                    style: GoogleFonts.cairo(
                                      fontSize: DesignTokens.textBodyMedium,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.primaryColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: DesignTokens.space12),
                            Wrap(
                              alignment: WrapAlignment.center,
                              children: [
                                Text(
                                  'بالتسجيل، أنت توافق على ',
                                  style: GoogleFonts.cairo(
                                    fontSize: DesignTokens.textLabelSmall,
                                    color: AppTheme.textTertiary,
                                  ),
                                ),
                                Text(
                                  'الشروط والأحكام',
                                  style: GoogleFonts.cairo(
                                    fontSize: DesignTokens.textLabelSmall,
                                    color: AppTheme.primaryColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
