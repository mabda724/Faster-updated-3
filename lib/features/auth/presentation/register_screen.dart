import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/design_tokens.dart';
import '../data/auth_repository.dart';
import '../../../core/services/supabase_service.dart';
import '../../provider/presentation/partner_document_upload_screen.dart';

class RegisterScreen extends StatefulWidget {
  final String? role;
  const RegisterScreen({super.key, this.role});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with SingleTickerProviderStateMixin {
  final _authRepo = AuthRepository();

  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  final _referralCtrl = TextEditingController();
  final _nationalIdCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();

  List<Map<String, dynamic>> _categories = [];
  String? _selectedCategoryId;
  String? _selectedCategoryName;

  String? _role;
  bool _showForm = false;
  bool _isLoading = false;

  late AnimationController _animCtrl;
  late Animation<double> _fadeContent;
  late Animation<Offset> _slideContent;

  static const List<Map<String, dynamic>> _roleOptions = [
    {'value': 'client', 'label': 'عميل'},
    {'value': 'provider', 'label': 'مقدم خدمة'},
    {'value': 'seller', 'label': 'تاجر'},
    {'value': 'driver', 'label': 'سائق'},
    {'value': 'delivery', 'label': 'سائق دليفري'},
    {'value': 'admin', 'label': 'مدير'},
  ];

  bool get isProvider => _role == 'provider';
  bool get isSeller => _role == 'seller';
  bool get isDriver => _role == 'driver';
  bool get isDelivery => _role == 'delivery';
  bool get isPartner => isProvider || isSeller || isDriver || isDelivery;
  bool get isClient => _role == 'client';
  bool get isAdmin => _role == 'admin';

  String get _title {
    switch (_role) {
      case 'provider': return 'تسجيل مقدم خدمة';
      case 'seller': return 'تسجيل تاجر';
      case 'driver': return 'تسجيل سائق';
      case 'delivery': return 'تسجيل سائق دليفري';
      case 'client': return 'إنشاء حساب جديد';
      case 'admin': return 'تسجيل مدير';
      default: return 'إنشاء حساب';
    }
  }

  String get _subtitle {
    switch (_role) {
      case 'provider': return 'قدم خدمات منزلية مميزة للعملاء';
      case 'seller': return 'اعرض منتجاتك وبيعها عبر المتجر';
      case 'driver': return 'افتح رحلاتك واستقبل طلبات النقل';
      case 'delivery': return 'استقبل طلبات التوصيل وأنجزها بسرعة';
      case 'client': return 'سجل حسابك للوصول لجميع الخدمات';
      case 'admin': return 'لوحة التحكم الخاصة بالمدير';
      default: return 'ابدأ رحلتك داخل التطبيق';
    }
  }

  IconData get _roleIcon {
    switch (_role) {
      case 'provider': return Icons.home_repair_service_rounded;
      case 'seller': return Icons.shopping_bag_rounded;
      case 'driver': return Icons.drive_eta_rounded;
      case 'delivery': return Icons.local_shipping_rounded;
      case 'client': return Icons.person_rounded;
      case 'admin': return Icons.admin_panel_settings_rounded;
      default: return Icons.person_add_rounded;
    }
  }

  Color get _roleColor {
    switch (_role) {
      case 'provider': return AppTheme.successColor;
      case 'seller': return AppTheme.warningColor;
      case 'driver': return AppTheme.primaryColor;
      case 'delivery': return AppTheme.infoColor;
      case 'admin': return AppTheme.errorColor;
      default: return AppTheme.primaryColor;
    }
  }

  @override
  void initState() {
    super.initState();
    _role = widget.role;
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeContent = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _animCtrl,
        curve: const Interval(0.2, 1.0, curve: Curves.easeIn),
      ),
    );
    _slideContent = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animCtrl,
        curve: const Interval(0.2, 1.0, curve: Curves.easeOutCubic),
      ),
    );
    _animCtrl.forward();

    if (isProvider || isSeller) {
      _loadCategories();
    }
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
    _nationalIdCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final data = await SupabaseService.db
          .from('categories')
          .select('id, name_ar, name_en, name')
          .order('id');
      if (!mounted) return;
      setState(() {
        _categories = List<Map<String, dynamic>>.from(data);
      });
    } catch (e) {
      debugPrint('Error loading categories: $e');
    }
  }

  void _onRoleChanged(String? value) {
    setState(() {
      _role = value;
      _selectedCategoryId = null;
      _selectedCategoryName = null;
    });
    if (isProvider || isSeller) {
      _loadCategories();
    }
  }

  Future<void> _register() async {
    final name = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text.trim();
    final confirmPass = _confirmPassCtrl.text.trim();

    if (_role == null) {
      SnackBarUtils.showError(context, 'الرجاء اختيار نوع الحساب');
      return;
    }
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

    if ((isProvider || isSeller) && _selectedCategoryId == null) {
      SnackBarUtils.showError(context, 'الرجاء اختيار التخصص');
      return;
    }

    if (isPartner && _nationalIdCtrl.text.trim().isEmpty) {
      SnackBarUtils.showError(context, 'الرجاء إدخال رقم الهوية');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final r = await _authRepo.signUp(
        phone: phone,
        password: pass,
        email: email,
        fullName: name,
        role: _role!,
        profession: _selectedCategoryName,
        categoryId: _selectedCategoryId != null
            ? int.tryParse(_selectedCategoryId!)
            : null,
        nationalIdNumber: _nationalIdCtrl.text.trim(),
        bio: _bioCtrl.text.trim(),
        referredBy: null,
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (r['success'] == true) {
        String referralMessage = '';
        if (_referralCtrl.text.trim().isNotEmpty) {
          try {
            final uid = SupabaseService.currentUserId;
            if (uid != null) {
              final referralResult = await _authRepo.applyReferralCode(
                uid,
                _referralCtrl.text.trim().toUpperCase(),
              );
              if (referralResult['success'] == true) {
                referralMessage = referralResult['message'] ?? 'تم تطبيق كود الدعوة';
              }
            }
          } catch (e) {
            debugPrint('Error applying referral code: $e');
          }
        }

        if (isPartner) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => const PartnerDocumentUploadScreen(),
            ),
          );
        } else {
          String msg = 'تم التسجيل بنجاح!';
          if (referralMessage.isNotEmpty) msg += '\n$referralMessage';
          SnackBarUtils.showSuccess(context, msg);
          Navigator.pushReplacementNamed(context, '/login');
        }
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
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_forward_rounded, color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _showForm ? _title : 'إنشاء حساب',
          style: GoogleFonts.cairo(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        child: _showForm ? _buildFormView() : _buildIntroView(),
      ),
    );
  }

  Widget _buildIntroView() {
    return Container(
      key: const ValueKey('intro'),
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor.withValues(alpha: 0.06),
            Colors.white,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(DesignTokens.space24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FadeTransition(
                opacity: _fadeContent,
                child: Container(
                  width: 110.w,
                  height: 110.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppTheme.primaryGradient,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryColor.withValues(alpha: 0.3),
                        blurRadius: 24,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.person_add_rounded,
                    size: 52,
                    color: Colors.white,
                  ),
                ),
              ),
              SizedBox(height: DesignTokens.space32),
              FadeTransition(
                opacity: _fadeContent,
                child: Column(
                  children: [
                    Text(
                      'انضم إلينا الآن',
                      style: GoogleFonts.cairo(
                        fontSize: DesignTokens.textTitleLarge,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    SizedBox(height: DesignTokens.space8),
                    Text(
                      'سجّل حسابك للاستفادة من جميع الخدمات والمزايا',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.cairo(
                        fontSize: DesignTokens.textBodyMedium,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: DesignTokens.space40),
              FadeTransition(
                opacity: _fadeContent,
                child: SlideTransition(
                  position: _slideContent,
                  child: InkWell(
                    onTap: () => setState(() => _showForm = true),
                    borderRadius: DesignTokens.brXl,
                    child: Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(vertical: DesignTokens.space16),
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius: DesignTokens.brXl,
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryColor.withValues(alpha: 0.35),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.app_registration_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                          SizedBox(width: DesignTokens.space10),
                          Text(
                            'سجل كشري',
                            style: GoogleFonts.cairo(
                              fontSize: DesignTokens.textTitleMedium,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: DesignTokens.space24),
              _buildLoginLink(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormView() {
    return Container(
      key: const ValueKey('form'),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _roleColor.withValues(alpha: 0.05),
            Colors.white,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(DesignTokens.space20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(),
              SizedBox(height: DesignTokens.space24),
              _buildFormCard(),
              SizedBox(height: DesignTokens.space20),
              _buildLoginLink(),
              SizedBox(height: DesignTokens.space12),
              _buildTerms(),
              SizedBox(height: DesignTokens.space24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.all(DesignTokens.space20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_roleColor, _roleColor.withValues(alpha: 0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: DesignTokens.brXl,
        boxShadow: [
          BoxShadow(
            color: _roleColor.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(DesignTokens.space4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(_roleIcon, size: 40, color: Colors.white),
          ),
          SizedBox(width: DesignTokens.space16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _title,
                  style: GoogleFonts.cairo(
                    fontSize: DesignTokens.textTitleLarge,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: DesignTokens.space2),
                Text(
                  _subtitle,
                  style: GoogleFonts.cairo(
                    fontSize: DesignTokens.textBodySmall,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormCard() {
    return Container(
      padding: EdgeInsets.all(DesignTokens.space20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: DesignTokens.brXl,
        boxShadow: DesignTokens.shadow2(Colors.black),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildRoleDropdown(),
          SizedBox(height: DesignTokens.space14),
          AppTextField(
            controller: _nameCtrl,
            label: 'الاسم الكامل',
            hint: 'أدخل اسمك الكامل',
            icon: Icons.person_rounded,
            focusColor: _roleColor,
          ),
          SizedBox(height: DesignTokens.space14),
          AppTextField(
            controller: _phoneCtrl,
            label: 'رقم الهاتف',
            hint: 'رقم الهاتف (11 رقماً)',
            icon: Icons.phone_android_rounded,
            type: TextInputType.phone,
            focusColor: _roleColor,
          ),
          SizedBox(height: DesignTokens.space14),
          AppTextField(
            controller: _emailCtrl,
            label: 'البريد الإلكتروني',
            hint: 'example@email.com',
            icon: Icons.email_rounded,
            type: TextInputType.emailAddress,
            focusColor: _roleColor,
          ),
          SizedBox(height: DesignTokens.space14),
          AppPasswordField(
            controller: _passCtrl,
            label: 'كلمة المرور',
            hint: '6 أحرف على الأقل',
            focusColor: _roleColor,
          ),
          SizedBox(height: DesignTokens.space14),
          AppPasswordField(
            controller: _confirmPassCtrl,
            label: 'تأكيد كلمة المرور',
            hint: 'أعد إدخال كلمة المرور',
            focusColor: _roleColor,
          ),
          SizedBox(height: DesignTokens.space14),
          AppTextField(
            controller: _referralCtrl,
            label: 'كود دعوة صديق (اختياري)',
            hint: 'مثال: ABC123',
            icon: Icons.card_giftcard_rounded,
            focusColor: _roleColor,
          ),
          if (isProvider || isSeller) ...[
            SizedBox(height: DesignTokens.space14),
            _buildCategoryDropdown(),
          ],
          if (isPartner) ...[
            SizedBox(height: DesignTokens.space14),
            AppTextField(
              controller: _nationalIdCtrl,
              label: isSeller
                  ? 'رقم السجل التجاري'
                  : isDriver || isDelivery
                      ? 'رقم رخصة القيادة'
                      : 'رقم الهوية',
              hint: isSeller
                  ? 'أدخل رقم السجل التجاري'
                  : isDriver || isDelivery
                      ? 'أدخل رقم رخصة القيادة'
                      : 'أدخل رقم الهوية الوطنية',
              icon: Icons.badge_rounded,
              focusColor: _roleColor,
            ),
          ],
          if (isPartner) ...[
            SizedBox(height: DesignTokens.space14),
            AppTextField(
              controller: _bioCtrl,
              label: isDriver || isDelivery
                  ? 'معلومات المركبة'
                  : 'نبذة عنك',
              hint: isDriver || isDelivery
                  ? 'نوع المركبة، رقم اللوحة'
                  : 'أخبرنا عن خبراتك',
              icon: Icons.info_outline_rounded,
              maxLines: 3,
              focusColor: _roleColor,
            ),
          ],
          if (isAdmin) ...[
            SizedBox(height: DesignTokens.space14),
            AppTextField(
              controller: _bioCtrl,
              label: 'المنصب الإداري',
              hint: 'مثال: مشرف عام، دعم فني',
              icon: Icons.work_outline_rounded,
              focusColor: _roleColor,
            ),
          ],
          SizedBox(height: DesignTokens.space24),
          _buildRegisterButton(),
        ],
      ),
    );
  }

  Widget _buildRoleDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'نوع الحساب',
          style: TextStyle(
            fontSize: DesignTokens.textBodySmall,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        SizedBox(height: DesignTokens.space2),
        Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: DesignTokens.brMd,
            border: Border.all(color: Colors.grey.shade300),
          ),
          padding: EdgeInsets.symmetric(horizontal: DesignTokens.space4),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              hint: Row(
                children: [
                  Icon(Icons.account_circle_outlined,
                      size: DesignTokens.iconMd, color: Colors.grey.shade600),
                  SizedBox(width: DesignTokens.space2),
                  Text(
                    'اختر نوع الحساب',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),
              value: _role,
              icon: const Icon(Icons.keyboard_arrow_down_rounded),
              items: _roleOptions.map((r) {
                return DropdownMenuItem<String>(
                  value: r['value'] as String,
                  child: Text(r['label'] as String),
                );
              }).toList(),
              onChanged: _onRoleChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'التخصص',
          style: TextStyle(
            fontSize: DesignTokens.textBodySmall,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        SizedBox(height: DesignTokens.space2),
        Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: DesignTokens.brMd,
            border: Border.all(color: Colors.grey.shade300),
          ),
          padding: EdgeInsets.symmetric(horizontal: DesignTokens.space4),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              hint: Row(
                children: [
                  Icon(Icons.work_outline_rounded,
                      size: DesignTokens.iconMd, color: Colors.grey.shade600),
                  SizedBox(width: DesignTokens.space2),
                  Text(
                    'اختر التخصص',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),
              value: _selectedCategoryId,
              icon: const Icon(Icons.keyboard_arrow_down_rounded),
              items: _categories.map((c) {
                final name =
                    (c['name_ar'] ?? c['name_en'] ?? c['name']).toString();
                return DropdownMenuItem<String>(
                  value: c['id'].toString(),
                  child: Text(name),
                );
              }).toList(),
              onChanged: (v) {
                setState(() {
                  _selectedCategoryId = v;
                  if (v == null) return;
                  final cat = _categories.firstWhere(
                    (e) => e['id'].toString() == v,
                    orElse: () => {},
                  );
                  _selectedCategoryName =
                      (cat['name_ar'] ?? cat['name_en'] ?? cat['name'])
                          ?.toString();
                });
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRegisterButton() {
    return ElevatedButton(
      onPressed: _isLoading ? null : _register,
      style: ElevatedButton.styleFrom(
        minimumSize: Size(double.infinity, DesignTokens.buttonHeight.h + 4),
        backgroundColor: _roleColor,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: DesignTokens.brMd,
        ),
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
                const Icon(Icons.check_circle_outline_rounded),
                SizedBox(width: DesignTokens.space2),
                Text(
                  'تسجيل الحساب',
                  style: TextStyle(
                    fontSize: DesignTokens.textBodyLarge,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildLoginLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'لديك حساب بالفعل؟',
          style: TextStyle(
            fontSize: DesignTokens.textBodyMedium,
            color: AppTheme.textSecondary,
          ),
        ),
        TextButton(
          onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
          child: Text(
            'سجل دخول',
            style: TextStyle(
              fontSize: DesignTokens.textBodyMedium,
              fontWeight: FontWeight.w600,
              color: _roleColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTerms() {
    return Text(
      'بتسجيل الدخول، أنت توافق على الشروط والأحكام',
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: DesignTokens.textLabelSmall,
        color: AppTheme.textTertiary,
      ),
    );
  }
}
