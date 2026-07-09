import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/theme/design_tokens.dart';
import '../../../core/services/supabase_service.dart';
import '../../services/presentation/services_screen.dart';

class CategoriesScreen extends StatefulWidget {
  final String? initialTitle;

  const CategoriesScreen({super.key, this.initialTitle});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  int? _selectedIndex;
  List<Map<String, dynamic>> _categories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final cats = await SupabaseService.db
          .from('categories')
          .select()
          .order('sort_order');
      if (mounted) {
        setState(() {
          if ((cats as List).isNotEmpty) {
            _categories = List<Map<String, dynamic>>.from(cats);
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading categories: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  IconData _iconForCategory(String name) {
    final n = name.toLowerCase();
    if (n.contains('سباكة') || n.contains('plumb')) return Icons.water_drop_rounded;
    if (n.contains('كهرباء') || n.contains('electrical') || n.contains('electric')) return Icons.lightbulb_rounded;
    if (n.contains('نجارة') || n.contains('carpentry') || n.contains('wood')) return Icons.build_rounded;
    if (n.contains('دهانات') || n.contains('painting') || n.contains('paint')) return Icons.format_paint_rounded;
    if (n.contains('تكييف') || n.contains('تبريد') || n.contains('ac') || n.contains('cold')) return Icons.ac_unit_rounded;
    if (n.contains('أجهزة') || n.contains('appliance') || n.contains('home') || n.contains('device')) return Icons.blender_rounded;
    if (n.contains('حدادة') || n.contains('أبواب') || n.contains('metal') || n.contains('door') || n.contains('iron')) return Icons.door_front_door_rounded;
    if (n.contains('زجاج') || n.contains('مرايا') || n.contains('glass') || n.contains('mirror')) return Icons.window_rounded;
    if (n.contains('أعمال') || n.contains('عامة') || n.contains('general') || n.contains('work')) return Icons.construction_rounded;
    return Icons.build_rounded;
  }

  Color _iconBgForCategory(String name) {
    final n = name.toLowerCase();
    if (n.contains('سباكة') || n.contains('plumb')) return AppTheme.dividerColor;
    if (n.contains('كهرباء') || n.contains('electric')) return AppTheme.dividerColor;
    if (n.contains('نجارة') || n.contains('carpentry')) return AppTheme.dividerColor;
    if (n.contains('دهانات') || n.contains('painting')) return AppTheme.backgroundColor;
    if (n.contains('تكييف') || n.contains('تبريد')) return AppTheme.dividerColor;
    if (n.contains('أجهزة') || n.contains('appliance')) return AppTheme.dividerColor;
    if (n.contains('حدادة') || n.contains('أبواب') || n.contains('metal')) return AppTheme.dividerColor;
    if (n.contains('زجاج') || n.contains('مرايا')) return AppTheme.dividerColor;
    if (n.contains('أعمال') || n.contains('عامة')) return AppTheme.dividerColor;
    return AppTheme.dividerColor;
  }

  Color _iconColorForCategory(String name) {
    final n = name.toLowerCase();
    if (n.contains('سباكة') || n.contains('plumb')) return AppTheme.infoColor;
    if (n.contains('كهرباء') || n.contains('electric')) return AppTheme.warningColor;
    if (n.contains('نجارة') || n.contains('carpentry')) return AppTheme.errorColor;
    if (n.contains('دهانات') || n.contains('painting')) return AppTheme.errorColor;
    if (n.contains('تكييف') || n.contains('تبريد')) return AppTheme.successColor;
    if (n.contains('أجهزة') || n.contains('appliance')) return AppTheme.successColor;
    if (n.contains('حدادة') || n.contains('أبواب') || n.contains('metal')) return AppTheme.errorColor;
    if (n.contains('زجاج') || n.contains('مرايا')) return AppTheme.primaryColor;
    if (n.contains('أعمال') || n.contains('عامة')) return AppTheme.whatsappColor;
    return AppTheme.primaryColor;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildHeader(),
                    Padding(
                      padding: EdgeInsets.all(DesignTokens.space8.w),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLocationCard(),
                          SizedBox(height: DesignTokens.space6.h),
                          _buildSearchBar(),
                          SizedBox(height: DesignTokens.space6.h),
                          Text(
                            'اختر فئة الخدمة',
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          SizedBox(height: DesignTokens.space4.h),
                          _buildCategoryGrid(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _buildBottomButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        DesignTokens.space8.w,
        DesignTokens.space6.h,
        DesignTokens.space8.w,
        DesignTokens.space4.h,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: AppTheme.backgroundColor, width: 1),
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 32.sp,
              height: 32.sp,
              alignment: Alignment.center,
              child: Icon(
                Icons.arrow_forward_rounded,
                color: AppTheme.textSecondary,
                size: 18.sp,
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                widget.initialTitle ?? 'طلب خدمة صناعية',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
          ),
          SizedBox(width: 32.sp),
        ],
      ),
    );
  }

  Widget _buildLocationCard() {
    return Container(
      padding: EdgeInsets.all(DesignTokens.space6.w),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor70,
        borderRadius: BorderRadius.circular(DesignTokens.radiusMd.r),
        border: Border.all(color: AppTheme.backgroundColor),
      ),
      child: Row(
        children: [
          Icon(
            Icons.location_on_rounded,
            color: AppTheme.primaryColor,
            size: 20.sp,
          ),
          SizedBox(width: DesignTokens.space3.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'الموقع',
                  style: TextStyle(
                    fontSize: 10.sp,
                    color: AppTheme.textTertiary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'شارع السياحة - الغردقة',
                  style: TextStyle(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {},
            child: Text(
              'تغيير',
              style: TextStyle(
                fontSize: 11.sp,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor70,
        borderRadius: BorderRadius.circular(DesignTokens.radiusMd.r),
        border: Border.all(color: AppTheme.dividerColor),
      ),
      child: TextField(
        textDirection: TextDirection.rtl,
        decoration: InputDecoration(
          hintText: 'ابحث عن نوع الخدمة...',
          hintTextDirection: TextDirection.rtl,
          hintStyle: TextStyle(
            color: AppTheme.textTertiary,
            fontSize: 11.sp,
          ),
          suffixIcon: Icon(
            Icons.search_rounded,
            color: AppTheme.textTertiary,
            size: 16.sp,
          ),
          filled: true,
          fillColor: AppTheme.surfaceColor70,
          contentPadding: EdgeInsets.symmetric(
            horizontal: DesignTokens.space4.w,
            vertical: DesignTokens.space3.h,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(DesignTokens.radiusMd.r),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(DesignTokens.radiusMd.r),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(DesignTokens.radiusMd.r),
            borderSide: BorderSide(
              color: AppTheme.primaryColor,
            ),
          ),
        ),
        onChanged: (v) {
          setState(() {});
        },
      ),
    );
  }

  Widget _buildCategoryGrid() {
    final items = _categories.isNotEmpty
        ? _categories
        : _defaultCategoryItems;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: DesignTokens.space3.w,
        mainAxisSpacing: DesignTokens.space3.h,
        childAspectRatio: 0.78,
      ),
      itemCount: items.length,
      itemBuilder: (_, i) => _buildCategoryCard(items[i], i),
    );
  }

  Widget _buildCategoryCard(Map<String, dynamic> cat, int index) {
    final catName = (cat['name_ar'] ?? cat['name'] ?? '').toString();
    final isSelected = _selectedIndex == index;
    final icon = _iconForCategory(catName);
    final iconBg = _iconBgForCategory(catName);
    final iconColor = _iconColorForCategory(catName);

    return GestureDetector(
      onTap: () {
        setState(() => _selectedIndex = index);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.backgroundColor.withValues(alpha: 0.3)
              : AppTheme.surfaceColor70.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(DesignTokens.radiusMd.r),
          border: Border.all(
            color: isSelected
                ? AppTheme.primaryColor
                : AppTheme.backgroundColor,
            width: isSelected ? 2 : 1,
          ),
        ),
        padding: EdgeInsets.all(DesignTokens.space4.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 48.sp,
              height: 48.sp,
              decoration: BoxDecoration(
                color: iconBg,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: iconColor,
                size: 20.sp,
              ),
            ),
            SizedBox(height: DesignTokens.space2.h),
            Text(
              catName,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11.sp,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomButton() {
    return Container(
      padding: EdgeInsets.all(DesignTokens.space8.w),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: AppTheme.surfaceColor70, width: 1),
        ),
      ),
      child: GestureDetector(
        onTap: () {
          if (_selectedIndex == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('الرجاء اختيار فئة الخدمة'),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: DesignTokens.brSm,
                ),
              ),
            );
            return;
          }

          final items = _categories.isNotEmpty
              ? _categories
              : _defaultCategoryItems;
          final selectedCat = items[_selectedIndex!];
          final catId = selectedCat['id'];

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ServicesScreen(
                initialCategoryId: catId is int ? catId : null,
              ),
            ),
          );
        },
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(vertical: DesignTokens.space4.h),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor,
            borderRadius: BorderRadius.circular(DesignTokens.radiusMd.r),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryColor.withValues(alpha: 0.2),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: Text(
              'التالي',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  static const _defaultCategoryItems = [
    {'name_ar': 'سباكة'},
    {'name_ar': 'كهرباء'},
    {'name_ar': 'نجارة'},
    {'name_ar': 'دهانات'},
    {'name_ar': 'تكييف وتبريد'},
    {'name_ar': 'أجهزة منزلية'},
    {'name_ar': 'حدادة وأبواب'},
    {'name_ar': 'زجاج ومرايا'},
    {'name_ar': 'أعمال عامة'},
  ];
}
