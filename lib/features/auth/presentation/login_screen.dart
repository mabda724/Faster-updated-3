import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/design_tokens.dart';
import '../data/auth_repository.dart';
import '../../../core/services/notification_badge_service.dart';
import '../../home/presentation/main_nav_screen.dart';
import '../../admin/presentation/admin_nav_screen.dart';
import '../../provider/presentation/provider_nav_screen.dart';
import '../../seller/presentation/seller_nav_screen.dart';
import '../../driver/presentation/driver_nav_screen.dart';
import '../../delivery/presentation/delivery_nav_screen.dart';
import 'client_register_screen.dart';
import 'partner_registration_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _loginCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _authRepo = AuthRepository();
  bool _isLoading = false;

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
      CurvedAnimation(
        parent: _animCtrl,
        curve: const Interval(0.2, 1.0, curve: Curves.easeIn),
      ),
    );
    _slideContent = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animCtrl,
        curve: const Interval(0.2, 1.0, curve: Curves.easeOutCubic),
      ),
    );
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _loginCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_loginCtrl.text.trim().isEmpty || _passCtrl.text.trim().isEmpty) {
      SnackBarUtils.showError(context, 'الرجاء إدخال البريد الإلكتروني أو رقم الهاتف وكلمة المرور');
      return;
    }
    setState(() => _isLoading = true);
    final r = await _authRepo.signInWithEmailAndPassword(
      identifier: _loginCtrl.text.trim(),
      password: _passCtrl.text.trim(),
    );
    setState(() => _isLoading = false);
    if (!mounted) return;
    if (r['success'] == true) {
      await NotificationBadgeService().initialize();
      final role = r['role'] as String;
      Widget destination;
      switch (role) {
        case 'admin':
          destination = const AdminNavScreen();
          break;
        case 'provider':
        case 'seller':
        case 'driver':
        case 'delivery':
          destination = const ProviderNavScreen();
          break;
        default:
          destination = const MainNavScreen();
          break;
      }
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => destination),
        (_) => false,
      );
    } else {
      SnackBarUtils.showError(context, r['error'] ?? 'حدث خطأ، يرجى المحاولة مرة أخرى');
    }
  }

  Future<void> _showResetPasswordDialog() async {
    final emailCtrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: DesignTokens.brXl),
        title: const Text('استعادة كلمة المرور', textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'أدخل بريدك الإلكتروني وسنرسل لك رابط إعادة التعيين',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: DesignTokens.textBodyMedium,
              ),
            ),
            SizedBox(height: DesignTokens.space16),
            AppTextField(
              controller: emailCtrl,
              hint: 'البريد الإلكتروني',
              icon: Icons.email_outlined,
              type: TextInputType.emailAddress,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (emailCtrl.text.trim().isEmpty) {
                SnackBarUtils.showError(context, 'يرجى إدخال البريد الإلكتروني');
                return;
              }
              Navigator.pop(ctx);
              setState(() => _isLoading = true);
              final r = await _authRepo.resetPassword(emailCtrl.text.trim());
              setState(() => _isLoading = false);
              if (!mounted) return;
              if (r['success'] == true) {
                SnackBarUtils.showSuccess(context, 'تم إرسال رابط إعادة التعيين');
              } else {
                SnackBarUtils.showError(context, r['error'] ?? 'حدث خطأ');
              }
            },
            child: const Text('إرسال'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppTheme.primaryColor,
              AppTheme.primaryColor.withValues(alpha: 0.85),
              AppTheme.backgroundColor,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: const [0.0, 0.3, 1.0],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: DesignTokens.space24),
            child: Column(
              children: [
                SizedBox(height: DesignTokens.space48 + 20.h),
                // Logo + branding
                FadeTransition(
                  opacity: _fadeContent,
                  child: Column(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryColor.withValues(alpha: 0.25),
                              blurRadius: 25,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            'assets/images/logo.png',
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Icon(
                              Icons.flash_on_rounded,
                              size: 40,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: DesignTokens.space12),
                      Text(
                        'FASTER',
                        style: GoogleFonts.cairo(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 4,
                        ),
                      ),
                      SizedBox(height: DesignTokens.space4),
                      Text(
                        'خدمات منزلية تثق فيها',
                        style: GoogleFonts.cairo(
                          fontSize: DesignTokens.textBodyMedium,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: DesignTokens.space32),
                // Login card
                FadeTransition(
                  opacity: _fadeContent,
                  child: SlideTransition(
                    position: _slideContent,
                    child: Container(
                      padding: EdgeInsets.all(DesignTokens.space24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: DesignTokens.brXl,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 40,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'تسجيل الدخول',
                            style: GoogleFonts.cairo(
                              fontSize: DesignTokens.textTitleLarge,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          SizedBox(height: DesignTokens.space4),
                          Text(
                            'أهلاً بعودتك!',
                            style: GoogleFonts.cairo(
                              fontSize: DesignTokens.textBodyMedium,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          SizedBox(height: DesignTokens.space24),
                          AppTextField(
                            controller: _loginCtrl,
                            hint: 'رقم الهاتف أو البريد الإلكتروني',
                            icon: Icons.person_outline_rounded,
                            type: TextInputType.text,
                          ),
                          SizedBox(height: DesignTokens.space14),
                          AppPasswordField(
                            controller: _passCtrl,
                            hint: 'كلمة المرور',
                          ),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton(
                              onPressed: _showResetPasswordDialog,
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                'نسيت كلمة المرور؟',
                                style: GoogleFonts.cairo(
                                  color: AppTheme.primaryColor,
                                  fontWeight: FontWeight.w600,
                                  fontSize: DesignTokens.textBodySmall,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: DesignTokens.space8),
                          ElevatedButton(
                            onPressed: _isLoading ? null : _login,
                            style: ElevatedButton.styleFrom(
                              minimumSize: Size(double.infinity, DesignTokens.buttonHeight.h),
                              backgroundColor: AppTheme.primaryColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: DesignTokens.brMd,
                              ),
                              elevation: 0,
                            ),
                            child: _isLoading
                                ? SizedBox(
                                    width: DesignTokens.iconSm,
                                    height: DesignTokens.iconSm,
                                    child: const CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                : Text(
                                    'دخول',
                                    style: GoogleFonts.cairo(
                                      fontSize: DesignTokens.textBodyLarge,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                          ),
                          SizedBox(height: DesignTokens.space16),
                          Row(
                            children: [
                              Expanded(child: Divider(color: AppTheme.dividerColor)),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: DesignTokens.space8),
                                child: Text(
                                  'أو',
                                  style: GoogleFonts.cairo(
                                    color: AppTheme.textTertiary,
                                    fontSize: DesignTokens.textBodySmall,
                                  ),
                                ),
                              ),
                              Expanded(child: Divider(color: AppTheme.dividerColor)),
                            ],
                          ),
                          SizedBox(height: DesignTokens.space16),
                          OutlinedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const ClientRegisterScreen()),
                              );
                            },
                            icon: const Icon(Icons.person_add_rounded, size: 20),
                            label: Text(
                              'إنشاء حساب جديد',
                              style: GoogleFonts.cairo(fontWeight: FontWeight.w600),
                            ),
                            style: OutlinedButton.styleFrom(
                              minimumSize: Size(double.infinity, DesignTokens.buttonHeight.h),
                              shape: RoundedRectangleBorder(
                                borderRadius: DesignTokens.brMd,
                              ),
                              side: BorderSide(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
                              foregroundColor: AppTheme.primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(height: DesignTokens.space16),
                // Partner registration
                FadeTransition(
                  opacity: _fadeContent,
                  child: SlideTransition(
                    position: _slideContent,
                    child: _buildPartnerSection(),
                  ),
                ),
                SizedBox(height: DesignTokens.space16),
                // Browse as guest
                FadeTransition(
                  opacity: _fadeContent,
                  child: TextButton(
                    onPressed: () => Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const MainNavScreen()),
                      (_) => false,
                    ),
                    child: Text(
                      'تصفح كزائر',
                      style: GoogleFonts.cairo(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: DesignTokens.textBodyMedium,
                      ),
                    ),
                  ),
                ),
                // Terms
                FadeTransition(
                  opacity: _fadeContent,
                  child: Text(
                    'بتسجيل الدخول، أنت توافق على الشروط والأحكام',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.cairo(
                      fontSize: DesignTokens.textLabelSmall,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                  ),
                ),
                SizedBox(height: DesignTokens.space24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPartnerSection() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PartnerRegistrationScreen()),
          );
        },
        borderRadius: DesignTokens.brLg,
        child: Container(
          padding: EdgeInsets.all(DesignTokens.space16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: DesignTokens.brLg,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: DesignTokens.brMd,
                ),
                child: Icon(
                  Icons.business_center_rounded,
                  size: 22,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
              SizedBox(width: DesignTokens.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'تسجيل كشريك',
                      style: GoogleFonts.cairo(
                        color: Colors.white,
                        fontSize: DesignTokens.textBodyLarge,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'مقدم خدمة، تاجر، سائق أو دليفري',
                      style: GoogleFonts.cairo(
                        color: Colors.white.withValues(alpha: 0.65),
                        fontSize: DesignTokens.textLabelMedium,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_back_rounded,
                size: 20,
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
