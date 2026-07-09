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

class PartnerRegistrationScreen extends StatefulWidget {
  const PartnerRegistrationScreen({super.key});

  @override
  State<PartnerRegistrationScreen> createState() => _PartnerRegistrationScreenState();
}

class _PartnerRegistrationScreenState extends State<PartnerRegistrationScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final _authRepo = AuthRepository();

  // Common fields
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  final _referralCtrl = TextEditingController();

  // Provider fields
  final _nationalIdCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();

  // Seller fields
  final _commercialRegCtrl = TextEditingController();
  final _storeNameCtrl = TextEditingController();
  final _storeDescCtrl = TextEditingController();
  final _storeAddressCtrl = TextEditingController();
  final _taxIdCtrl = TextEditingController();

  // Driver/Delivery fields
  final _licenseCtrl = TextEditingController();
  final _carPlateCtrl = TextEditingController();
  final _carModelCtrl = TextEditingController();
  final _carColorCtrl = TextEditingController();

  List<Map<String, dynamic>> _categories = [];
  String? _selectedCategoryId;
  String? _selectedCategoryName;

  bool _isLoading = false;
  int _selectedRoleIndex = -1;
  double _formProgress = 0;

  // Store categories for sellers
  final List<Map<String, dynamic>> _storeCategories = [
    {'id': 'restaurant', 'label': 'مطعم', 'icon': Icons.restaurant_rounded},
    {'id': 'cafe', 'label': 'كافية', 'icon': Icons.local_cafe_rounded},
    {'id': 'supermarket', 'label': 'سوبرماركت', 'icon': Icons.shopping_cart_rounded},
    {'id': 'pharmacy', 'label': 'صيدلية', 'icon': Icons.local_pharmacy_rounded},
    {'id': 'electronics', 'label': 'إلكترونيات', 'icon': Icons.devices_rounded},
    {'id': 'fashion', 'label': 'ملابس', 'icon': Icons.checkroom_rounded},
    {'id': 'other', 'label': 'أخرى', 'icon': Icons.category_rounded},
  ];
  String? _selectedStoreCategory;

  // Vehicle type for delivery
  final List<Map<String, dynamic>> _vehicleTypes = [
    {'id': 'car', 'label': 'سيارة', 'icon': Icons.directions_car_rounded},
    {'id': 'scooter', 'label': 'سكوتر', 'icon': Icons.electric_scooter_rounded},
    {'id': 'bike', 'label': 'دراجة نارية', 'icon': Icons.two_wheeler_rounded},
  ];
  String? _selectedVehicleType;

  final List<Map<String, dynamic>> _partnerTypes = [
    {
      'role': 'provider',
      'label': 'مقدم خدمة',
      'description': 'قدم خدمات منزلية مميزة',
      'icon': Icons.home_repair_service_rounded,
      'color': AppTheme.successColor,
    },
    {
      'role': 'seller',
      'label': 'تاجر',
      'description': 'اعرض منتجاتك وبيها',
      'icon': Icons.shopping_bag_rounded,
      'color': AppTheme.tertiaryColor,
    },
    {
      'role': 'driver',
      'label': 'سائق',
      'description': 'قدم خدمات النقل والرحلات',
      'icon': Icons.drive_eta_rounded,
      'color': AppTheme.primaryColor,
    },
    {
      'role': 'delivery',
      'label': 'سائق دليفري',
      'description': 'توصيل الطلبات بسرعة',
      'icon': Icons.local_shipping_rounded,
      'color': AppTheme.primaryColor,
    },
  ];

  Color get _roleColor {
    if (_selectedRoleIndex < 0) return AppTheme.primaryColor;
    return _partnerTypes[_selectedRoleIndex]['color'] as Color;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 0, vsync: this);
    _loadCategories();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmPassCtrl.dispose();
    _referralCtrl.dispose();
    _nationalIdCtrl.dispose();
    _bioCtrl.dispose();
    _commercialRegCtrl.dispose();
    _storeNameCtrl.dispose();
    _storeDescCtrl.dispose();
    _storeAddressCtrl.dispose();
    _taxIdCtrl.dispose();
    _licenseCtrl.dispose();
    _carPlateCtrl.dispose();
    _carModelCtrl.dispose();
    _carColorCtrl.dispose();
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

  void _selectRole(int index) {
    final old = _tabController;
    setState(() {
      _selectedRoleIndex = index;
      _tabController = TabController(length: 2, vsync: this);
      _formProgress = 0;
    });
    old.dispose();
  }

  Future<void> _register() async {
    final role = _partnerTypes[_selectedRoleIndex]['role'] as String;

    if (_nameCtrl.text.trim().isEmpty) {
      SnackBarUtils.showError(context, 'الرجاء إدخال الاسم الكامل');
      return;
    }
    if (_phoneCtrl.text.trim().isEmpty) {
      SnackBarUtils.showError(context, 'الرجاء إدخال رقم الهاتف');
      return;
    }
    if (_phoneCtrl.text.trim().length < 11) {
      SnackBarUtils.showError(context, 'رقم الهاتف يجب أن يكون 11 رقماً على الأقل');
      return;
    }
    if (_emailCtrl.text.trim().isEmpty || !_emailCtrl.text.trim().contains('@')) {
      SnackBarUtils.showError(context, 'الرجاء إدخال بريد إلكتروني صحيح');
      return;
    }
    if (_passCtrl.text.trim().isEmpty || _passCtrl.text.trim().length < 6) {
      SnackBarUtils.showError(context, 'كلمة المرور يجب أن تكون 6 أحرف على الأقل');
      return;
    }
    if (_passCtrl.text.trim() != _confirmPassCtrl.text.trim()) {
      SnackBarUtils.showError(context, 'كلمتا المرور غير متطابقتين');
      return;
    }

    if (_selectedCategoryId == null && (role == 'provider' || role == 'seller')) {
      SnackBarUtils.showError(context, 'الرجاء اختيار التخصص');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final r = await _authRepo.signUp(
        phone: _phoneCtrl.text.trim(),
        password: _passCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        fullName: _nameCtrl.text.trim(),
        role: role,
        profession: _selectedCategoryName,
        categoryId: _selectedCategoryId != null
            ? int.tryParse(_selectedCategoryId!)
            : null,
        nationalIdNumber: _getNationalId(),
        bio: _getBio(),
        referredBy: null,
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (r['success'] == true) {
        SnackBarUtils.showSuccess(context, 'تم التسجيل بنجاح! جاري تحميل المستندات...');
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const PartnerDocumentUploadScreen()),
        );
      } else {
        SnackBarUtils.showError(context, r['error'] ?? 'حدث خطأ ما');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      SnackBarUtils.showError(context, 'فشل التسجيل، حاول مرة أخرى');
    }
  }

  String _getNationalId() {
    final role = _partnerTypes[_selectedRoleIndex]['role'] as String;
    switch (role) {
      case 'provider':
        return _nationalIdCtrl.text.trim();
      case 'seller':
        return _commercialRegCtrl.text.trim();
      case 'driver':
      case 'delivery':
        return _licenseCtrl.text.trim();
      default:
        return '';
    }
  }

  String _getBio() {
    final role = _partnerTypes[_selectedRoleIndex]['role'] as String;
    switch (role) {
      case 'provider':
        return _bioCtrl.text.trim();
      case 'seller':
        return '${_storeNameCtrl.text.trim()} - ${_storeDescCtrl.text.trim()}';
      case 'driver':
        return 'مركبة: ${_carModelCtrl.text.trim()} - لون: ${_carColorCtrl.text.trim()} - لوحات: ${_carPlateCtrl.text.trim()}';
      case 'delivery':
        return 'مركبة: ${_selectedVehicleType ?? ''} - ${_carModelCtrl.text.trim()} - لون: ${_carColorCtrl.text.trim()}';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: _selectedRoleIndex < 0 ? _buildRoleSelection() : _buildRegistrationForm(),
      ),
    );
  }

  // ──────────────────────────────────────────────
  // Role Selection
  // ──────────────────────────────────────────────

  Widget _buildRoleSelection() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(DesignTokens.space16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: DesignTokens.space8),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          SizedBox(height: DesignTokens.space8),
          _buildRoleHeader(),
          SizedBox(height: DesignTokens.space24),
          _buildSectionBadge('اختر نوع الشراكة'),
          SizedBox(height: DesignTokens.space12),
          ...List.generate(_partnerTypes.length, (index) {
            return Padding(
              padding: EdgeInsets.only(bottom: DesignTokens.space12),
              child: _buildRoleCard(index),
            );
          }),
          SizedBox(height: DesignTokens.space16),
          _buildLoginLink(),
        ],
      ),
    );
  }

  Widget _buildRoleHeader() {
    return Container(
      padding: EdgeInsets.all(DesignTokens.space20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: DesignTokens.brXl,
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(DesignTokens.space6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.business_center_rounded,
              size: 44,
              color: Colors.white,
            ),
          ),
          SizedBox(height: DesignTokens.space12),
          Text(
            'انضم كشريك',
            style: GoogleFonts.cairo(
              fontSize: DesignTokens.textTitleLarge,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          SizedBox(height: DesignTokens.space4),
          Text(
            'اختر نوع الشراكة المناسب لك وابدأ رحلتك',
            style: GoogleFonts.cairo(
              fontSize: DesignTokens.textBodySmall,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionBadge(String title) {
    return Row(
      children: [
        Container(
          height: 24,
          width: 3,
          decoration: BoxDecoration(
            color: AppTheme.primaryColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        SizedBox(width: DesignTokens.space8),
        Text(
          title,
          style: GoogleFonts.cairo(
            fontSize: DesignTokens.textBodyMedium,
            fontWeight: FontWeight.w700,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildRoleCard(int index) {
    final data = _partnerTypes[index];
    final color = data['color'] as Color;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _selectRole(index),
        borderRadius: DesignTokens.brLg,
        child: Container(
          padding: EdgeInsets.all(DesignTokens.space16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: DesignTokens.brLg,
            border: Border.all(color: color.withValues(alpha: 0.25)),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: DesignTokens.brMd,
                ),
                child: Icon(
                  data['icon'] as IconData,
                  size: 26,
                  color: color,
                ),
              ),
              SizedBox(width: DesignTokens.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data['label'] as String,
                      style: GoogleFonts.cairo(
                        fontSize: DesignTokens.textBodyLarge,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      data['description'] as String,
                      style: GoogleFonts.cairo(
                        fontSize: DesignTokens.textBodySmall,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.arrow_back_rounded,
                  size: 16,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoginLink() {
    return Row(
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
    );
  }

  // ──────────────────────────────────────────────
  // Registration Form
  // ──────────────────────────────────────────────

  Widget _buildRegistrationForm() {
    final role = _partnerTypes[_selectedRoleIndex]['role'] as String;

    return Column(
      children: [
        // Top bar
        Container(
          padding: EdgeInsets.only(
            top: DesignTokens.space4,
            bottom: DesignTokens.space2,
          ),
          decoration: BoxDecoration(
            color: _roleColor.withValues(alpha: 0.04),
          ),
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: DesignTokens.space8),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back_rounded, color: _roleColor),
                      onPressed: () => setState(() => _selectedRoleIndex = -1),
                    ),
                    SizedBox(width: DesignTokens.space8),
                    Container(
                      padding: EdgeInsets.all(DesignTokens.space1),
                      decoration: BoxDecoration(
                        color: _roleColor.withValues(alpha: 0.1),
                        borderRadius: DesignTokens.brSm,
                      ),
                      child: Icon(
                        _partnerTypes[_selectedRoleIndex]['icon'] as IconData,
                        size: 20,
                        color: _roleColor,
                      ),
                    ),
                    SizedBox(width: DesignTokens.space8),
                    Text(
                      'تسجيل ${_partnerTypes[_selectedRoleIndex]['label']}',
                      style: GoogleFonts.cairo(
                        fontSize: DesignTokens.textTitleSmall,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => setState(() => _selectedRoleIndex = -1),
                      child: Text(
                        'تغيير',
                        style: TextStyle(
                          color: _roleColor,
                          fontSize: DesignTokens.textBodySmall,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Progress indicator
              Padding(
                padding: EdgeInsets.symmetric(horizontal: DesignTokens.space20),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(100),
                  child: LinearProgressIndicator(
                    value: _tabController.length > 0 ? (_tabController.index + 1) / 2 : 0,
                    backgroundColor: _roleColor.withValues(alpha: 0.1),
                    valueColor: AlwaysStoppedAnimation<Color>(_roleColor),
                    minHeight: 3,
                  ),
                ),
              ),
              SizedBox(height: DesignTokens.space6),
              // Tab labels
              Padding(
                padding: EdgeInsets.symmetric(horizontal: DesignTokens.space32),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'البيانات',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.cairo(
                          fontSize: DesignTokens.textLabelSmall,
                          color: _tabController.length > 0 && _tabController.index == 0
                              ? _roleColor
                              : AppTheme.textTertiary,
                          fontWeight: _tabController.length > 0 && _tabController.index == 0
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'الوثائق',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.cairo(
                          fontSize: DesignTokens.textLabelSmall,
                          color: _tabController.length > 0 && _tabController.index == 1
                              ? _roleColor
                              : AppTheme.textTertiary,
                          fontWeight: _tabController.length > 0 && _tabController.index == 1
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Tab content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildBasicInfoTab(role),
              _buildDocumentsTab(role),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBasicInfoTab(String role) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(DesignTokens.space16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSectionTitle('المعلومات الشخصية', Icons.person_rounded),
          SizedBox(height: DesignTokens.space12),
          AppTextField(
            controller: _nameCtrl,
            label: 'الاسم الكامل',
            hint: 'أدخل اسمك الكامل',
            icon: Icons.person_rounded,
            focusColor: _roleColor,
          ),
          SizedBox(height: DesignTokens.space12),
          AppTextField(
            controller: _phoneCtrl,
            label: 'رقم الهاتف',
            hint: 'أدخل رقم الهاتف',
            icon: Icons.phone_android_rounded,
            type: TextInputType.phone,
            focusColor: _roleColor,
          ),
          SizedBox(height: DesignTokens.space12),
          AppTextField(
            controller: _emailCtrl,
            label: 'البريد الإلكتروني',
            hint: 'example@email.com',
            icon: Icons.email_rounded,
            type: TextInputType.emailAddress,
            focusColor: _roleColor,
          ),
          SizedBox(height: DesignTokens.space12),
          AppPasswordField(
            controller: _passCtrl,
            label: 'كلمة المرور',
            hint: '6 أحرف على الأقل',
            focusColor: _roleColor,
          ),
          SizedBox(height: DesignTokens.space12),
          AppPasswordField(
            controller: _confirmPassCtrl,
            label: 'تأكيد كلمة المرور',
            hint: 'أعد إدخال كلمة المرور',
            focusColor: _roleColor,
          ),
          SizedBox(height: DesignTokens.space12),
          AppTextField(
            controller: _referralCtrl,
            label: 'كود دعوة (اختياري)',
            hint: 'مثال: ABC123',
            icon: Icons.card_giftcard_rounded,
            focusColor: _roleColor,
          ),

          SizedBox(height: DesignTokens.space20),

          // Role-specific fields
          if (role == 'provider') _buildProviderFields(),
          if (role == 'seller') _buildSellerFields(),
          if (role == 'driver') _buildDriverFields(),
          if (role == 'delivery') _buildDeliveryFields(),

          SizedBox(height: DesignTokens.space24),
          ElevatedButton(
            onPressed: () => _tabController.animateTo(1),
            style: ElevatedButton.styleFrom(
              minimumSize: Size(double.infinity, DesignTokens.buttonHeight.h + 4),
              backgroundColor: _roleColor,
              shape: RoundedRectangleBorder(borderRadius: DesignTokens.brMd),
              elevation: 0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'التالي: الوثائق',
                  style: GoogleFonts.cairo(
                    fontSize: DesignTokens.textBodyLarge,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                SizedBox(width: DesignTokens.space6),
                Icon(Icons.arrow_back_rounded, size: 18, color: Colors.white),
              ],
            ),
          ),
          SizedBox(height: DesignTokens.space16),
        ],
      ),
    );
  }

  Widget _buildProviderFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionTitle('معلومات التخصص', Icons.work_rounded),
        SizedBox(height: DesignTokens.space12),
        _buildCategoryDropdown(),
        SizedBox(height: DesignTokens.space12),
        AppTextField(
          controller: _nationalIdCtrl,
          label: 'رقم الهوية الوطنية',
          hint: 'أدخل رقم الهوية',
          icon: Icons.badge_rounded,
          focusColor: _roleColor,
        ),
        SizedBox(height: DesignTokens.space12),
        AppTextField(
          controller: _bioCtrl,
          label: 'نبذة عن خبراتك',
          hint: 'أخبرنا عن خبراتك ومهاراتك',
          icon: Icons.info_outline_rounded,
          maxLines: 3,
          focusColor: _roleColor,
        ),
      ],
    );
  }

  Widget _buildSellerFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionTitle('معلومات المتجر', Icons.store_rounded),
        SizedBox(height: DesignTokens.space12),
        _buildCategoryDropdown(),
        SizedBox(height: DesignTokens.space12),
        _buildStoreCategoryDropdown(),
        SizedBox(height: DesignTokens.space12),
        AppTextField(
          controller: _storeNameCtrl,
          label: 'اسم المتجر',
          hint: 'أدخل اسم المتجر',
          icon: Icons.storefront_rounded,
          focusColor: _roleColor,
        ),
        SizedBox(height: DesignTokens.space12),
        AppTextField(
          controller: _storeDescCtrl,
          label: 'وصف المتجر',
          hint: 'صف متجرك بإيجاز',
          icon: Icons.description_rounded,
          maxLines: 2,
          focusColor: _roleColor,
        ),
        SizedBox(height: DesignTokens.space12),
        AppTextField(
          controller: _commercialRegCtrl,
          label: 'رقم السجل التجاري',
          hint: 'أدخل رقم السجل التجاري',
          icon: Icons.business_rounded,
          focusColor: _roleColor,
        ),
        SizedBox(height: DesignTokens.space12),
        AppTextField(
          controller: _taxIdCtrl,
          label: 'الرقم الضريبي',
          hint: 'أدخل الرقم الضريبي',
          icon: Icons.receipt_long_rounded,
          focusColor: _roleColor,
        ),
        SizedBox(height: DesignTokens.space12),
        AppTextField(
          controller: _storeAddressCtrl,
          label: 'عنوان المتجر',
          hint: 'أدخل عنوان المتجر',
          icon: Icons.location_on_rounded,
          type: TextInputType.streetAddress,
          focusColor: _roleColor,
        ),
      ],
    );
  }

  Widget _buildDriverFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionTitle('معلومات المركبة', Icons.directions_car_rounded),
        SizedBox(height: DesignTokens.space12),
        AppTextField(
          controller: _nationalIdCtrl,
          label: 'رقم الهوية الوطنية',
          hint: 'أدخل رقم الهوية',
          icon: Icons.badge_rounded,
          focusColor: _roleColor,
        ),
        SizedBox(height: DesignTokens.space12),
        AppTextField(
          controller: _licenseCtrl,
          label: 'رقم رخصة القيادة',
          hint: 'أدخل رقم الرخصة',
          icon: Icons.credit_card_rounded,
          focusColor: _roleColor,
        ),
        SizedBox(height: DesignTokens.space12),
        AppTextField(
          controller: _carModelCtrl,
          label: 'نوع/موديل المركبة',
          hint: 'مثال: تويوتا كورولا 2020',
          icon: Icons.time_to_leave_rounded,
          focusColor: _roleColor,
        ),
        SizedBox(height: DesignTokens.space12),
        AppTextField(
          controller: _carColorCtrl,
          label: 'لون المركبة',
          hint: 'مثال: أبيض',
          icon: Icons.palette_rounded,
          focusColor: _roleColor,
        ),
        SizedBox(height: DesignTokens.space12),
        AppTextField(
          controller: _carPlateCtrl,
          label: 'رقم اللوحة',
          hint: 'أدخل رقم اللوحة',
          icon: Icons.confirmation_number_rounded,
          focusColor: _roleColor,
        ),
      ],
    );
  }

  Widget _buildDeliveryFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionTitle('معلومات المركبة', Icons.delivery_dining_rounded),
        SizedBox(height: DesignTokens.space12),
        _buildVehicleTypeDropdown(),
        SizedBox(height: DesignTokens.space12),
        AppTextField(
          controller: _nationalIdCtrl,
          label: 'رقم الهوية الوطنية',
          hint: 'أدخل رقم الهوية',
          icon: Icons.badge_rounded,
          focusColor: _roleColor,
        ),
        SizedBox(height: DesignTokens.space12),
        AppTextField(
          controller: _licenseCtrl,
          label: 'رقم رخصة القيادة',
          hint: 'أدخل رقم الرخصة',
          icon: Icons.credit_card_rounded,
          focusColor: _roleColor,
        ),
        SizedBox(height: DesignTokens.space12),
        AppTextField(
          controller: _carModelCtrl,
          label: 'نوع/موديل المركبة',
          hint: 'مثال: تويوتا كورولا 2020',
          icon: Icons.time_to_leave_rounded,
          focusColor: _roleColor,
        ),
        SizedBox(height: DesignTokens.space12),
        AppTextField(
          controller: _carColorCtrl,
          label: 'لون المركبة',
          hint: 'مثال: أبيض',
          icon: Icons.palette_rounded,
          focusColor: _roleColor,
        ),
        SizedBox(height: DesignTokens.space12),
        AppTextField(
          controller: _carPlateCtrl,
          label: 'رقم اللوحة',
          hint: 'أدخل رقم اللوحة',
          icon: Icons.confirmation_number_rounded,
          focusColor: _roleColor,
        ),
      ],
    );
  }

  Widget _buildDocumentsTab(String role) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(DesignTokens.space16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSectionTitle('الوثائق المطلوبة', Icons.upload_file_rounded),
          SizedBox(height: DesignTokens.space8),
          Container(
            padding: EdgeInsets.all(DesignTokens.space12),
            decoration: BoxDecoration(
              color: _roleColor.withValues(alpha: 0.05),
              borderRadius: DesignTokens.brMd,
              border: Border.all(color: _roleColor.withValues(alpha: 0.1)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: DesignTokens.iconSm,
                  color: _roleColor.withValues(alpha: 0.7),
                ),
                SizedBox(width: DesignTokens.space8),
                Expanded(
                  child: Text(
                    'سيتم طلب رفع هذه الوثائق بعد إكمال التسجيل',
                    style: GoogleFonts.cairo(
                      fontSize: DesignTokens.textBodySmall,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: DesignTokens.space16),

          if (role == 'provider') ...[
            _buildDocumentCard('صورة بطاقة الهوية', Icons.badge_rounded, true),
            _buildDocumentCard('إثبات العنوان (فيش)', Icons.home_work_rounded, true),
            _buildDocumentCard('شهادة الخبرة/المهارة', Icons.workspace_premium_rounded, false),
          ],
          if (role == 'seller') ...[
            _buildDocumentCard('السجل التجاري', Icons.business_rounded, true),
            _buildDocumentCard('شهادة الضرائب', Icons.receipt_long_rounded, false),
            _buildDocumentCard('صورة المتجر من الخارج', Icons.storefront_rounded, false),
            _buildDocumentCard('رخصة الموقع', Icons.location_on_rounded, false),
          ],
          if (role == 'driver') ...[
            _buildDocumentCard('رخصة القيادة', Icons.credit_card_rounded, true),
            _buildDocumentCard('رخصة المركبة', Icons.directions_car_rounded, true),
            _buildDocumentCard('صورة المركبة', Icons.photo_library_rounded, true),
            _buildDocumentCard('التأمين', Icons.security_rounded, false),
          ],
          if (role == 'delivery') ...[
            _buildDocumentCard('رخصة القيادة', Icons.credit_card_rounded, true),
            _buildDocumentCard('رخصة المركبة', Icons.directions_car_rounded, true),
            _buildDocumentCard('صورة المركبة', Icons.photo_library_rounded, true),
            _buildDocumentCard('التأمين', Icons.security_rounded, false),
          ],

          SizedBox(height: DesignTokens.space24),

          OutlinedButton(
            onPressed: () => _tabController.animateTo(0),
            style: OutlinedButton.styleFrom(
              minimumSize: Size(double.infinity, DesignTokens.buttonHeight.h + 4),
              side: BorderSide(color: _roleColor),
              shape: RoundedRectangleBorder(borderRadius: DesignTokens.brMd),
            ),
            child: Text(
              'العودة للبيانات',
              style: GoogleFonts.cairo(
                color: _roleColor,
                fontSize: DesignTokens.textBodyLarge,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SizedBox(height: DesignTokens.space12),
          ElevatedButton(
            onPressed: _isLoading ? null : _register,
            style: ElevatedButton.styleFrom(
              minimumSize: Size(double.infinity, DesignTokens.buttonHeight.h + 4),
              backgroundColor: _roleColor,
              shape: RoundedRectangleBorder(borderRadius: DesignTokens.brMd),
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
                      Icon(Icons.check_circle_outline_rounded, size: 20, color: Colors.white),
                      SizedBox(width: DesignTokens.space6),
                      Text(
                        'إكمال التسجيل',
                        style: GoogleFonts.cairo(
                          fontSize: DesignTokens.textBodyLarge,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
          ),
          SizedBox(height: DesignTokens.space16),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Container(
          height: 20,
          width: 3,
          decoration: BoxDecoration(
            color: _roleColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        SizedBox(width: DesignTokens.space8),
        Container(
          padding: EdgeInsets.all(DesignTokens.space1),
          decoration: BoxDecoration(
            color: _roleColor.withValues(alpha: 0.1),
            borderRadius: DesignTokens.brSm,
          ),
          child: Icon(icon, size: 16, color: _roleColor),
        ),
        SizedBox(width: DesignTokens.space2),
        Text(
          title,
          style: GoogleFonts.cairo(
            fontSize: DesignTokens.textBodyLarge,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
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
          style: GoogleFonts.cairo(
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
                  Icon(Icons.work_outline_rounded, size: DesignTokens.iconMd, color: Colors.grey.shade600),
                  SizedBox(width: DesignTokens.space2),
                  Text('اختر التخصص', style: TextStyle(color: Colors.grey.shade600)),
                ],
              ),
              value: _selectedCategoryId,
              icon: const Icon(Icons.keyboard_arrow_down_rounded),
              items: _categories.map((c) {
                final name = (c['name_ar'] ?? c['name_en'] ?? c['name']).toString();
                return DropdownMenuItem<String>(
                  value: c['id'].toString(),
                  child: Text(name),
                );
              }).toList(),
              onChanged: (v) {
                setState(() {
                  _selectedCategoryId = v;
                  if (v != null) {
                    final cat = _categories.firstWhere(
                      (e) => e['id'].toString() == v,
                      orElse: () => {},
                    );
                    _selectedCategoryName = (cat['name_ar'] ?? cat['name_en'] ?? cat['name'])?.toString();
                  }
                });
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStoreCategoryDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'تصنيف المتجر',
          style: GoogleFonts.cairo(
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
                  Icon(Icons.category_outlined, size: DesignTokens.iconMd, color: Colors.grey.shade600),
                  SizedBox(width: DesignTokens.space2),
                  Text('تصنيف المتجر', style: TextStyle(color: Colors.grey.shade600)),
                ],
              ),
              value: _selectedStoreCategory,
              icon: const Icon(Icons.keyboard_arrow_down_rounded),
              items: _storeCategories.map((c) {
                return DropdownMenuItem<String>(
                  value: c['id'] as String,
                  child: Row(
                    children: [
                      Icon(c['icon'] as IconData, size: 20, color: _roleColor),
                      SizedBox(width: DesignTokens.space8),
                      Text(c['label'] as String),
                    ],
                  ),
                );
              }).toList(),
                onChanged: (v) => setState(() => _selectedStoreCategory = v),
                ),
              ),
            ),
          ],
        );
  }

  Widget _buildVehicleTypeDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'نوع المركبة',
          style: GoogleFonts.cairo(
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
                  Icon(Icons.electric_scooter_rounded, size: DesignTokens.iconMd, color: Colors.grey.shade600),
                  SizedBox(width: DesignTokens.space2),
                  Text('نوع المركبة', style: TextStyle(color: Colors.grey.shade600)),
                ],
              ),
              value: _selectedVehicleType,
              icon: const Icon(Icons.keyboard_arrow_down_rounded),
              items: _vehicleTypes.map((c) {
                return DropdownMenuItem<String>(
                  value: c['id'] as String,
                  child: Row(
                    children: [
                      Icon(c['icon'] as IconData, size: 20, color: _roleColor),
                      SizedBox(width: DesignTokens.space8),
                      Text(c['label'] as String),
                    ],
                  ),
                );
              }).toList(),
                onChanged: (v) => setState(() => _selectedVehicleType = v),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDocumentCard(String title, IconData icon, bool isRequired) {
    return Container(
      margin: EdgeInsets.only(bottom: DesignTokens.space8),
      padding: EdgeInsets.all(DesignTokens.space12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: DesignTokens.brMd,
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(DesignTokens.space2),
            decoration: BoxDecoration(
              color: _roleColor.withValues(alpha: 0.1),
              borderRadius: DesignTokens.brSm,
            ),
            child: Icon(icon, size: 22, color: _roleColor),
          ),
          SizedBox(width: DesignTokens.space8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.cairo(
                        fontSize: DesignTokens.textBodyMedium,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (isRequired) ...[
                      SizedBox(width: DesignTokens.space4),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: DesignTokens.space6, vertical: DesignTokens.space2),
                        decoration: BoxDecoration(
                          color: AppTheme.errorColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'مطلوب',
                          style: GoogleFonts.cairo(
                            fontSize: DesignTokens.textLabelSmall,
                            color: AppTheme.errorColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Icon(
            Icons.cloud_upload_outlined,
            size: 20,
            color: _roleColor.withValues(alpha: 0.5),
          ),
        ],
      ),
    );
  }
}
