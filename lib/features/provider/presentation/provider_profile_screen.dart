import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/services/supabase_service.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/presentation/login_screen.dart';
import 'partner_document_upload_screen.dart';
import 'provider_address_screen.dart';
import 'provider_performance_screen.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/design_tokens.dart';

class ProviderProfileScreen extends StatefulWidget {
  const ProviderProfileScreen({super.key});
  @override
  State<ProviderProfileScreen> createState() => _ProviderProfileScreenState();
}

class _ProviderProfileScreenState extends State<ProviderProfileScreen> {
  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _providerProfile;
  Map<String, dynamic>? _category;
  bool _isLoading = true;
  int _daysSinceRegistration = 0;
  bool _isBanned = false;
  String? _banReason;

  bool get _isProvider => _profile?['role'] == 'provider';

  bool get _isDocumentIncomplete {
    if (!_isProvider || _providerProfile == null) return false;
    final status = _providerProfile!['document_verification_status'] ?? 'pending';
    return status != 'approved';
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = SupabaseService.currentUserId;
    if (uid == null) return;
    try {
      _profile = await SupabaseService.db
          .from('profiles')
          .select()
          .eq('id', uid)
          .single();
      _providerProfile = await SupabaseService.db
          .from('provider_profiles')
          .select('*, categories(name_ar)')
          .eq('id', uid)
          .maybeSingle();

      // Extract category if exists
      if (_providerProfile != null && _providerProfile!['categories'] != null) {
        _category = _providerProfile!['categories'];
      }

      // Check ban status
      final bannedAt = _profile?['banned_at'];
      _isBanned = bannedAt != null;
      _banReason = _profile?['ban_reason'];

      // Calculate days since registration for providers
      if (_isProvider && _providerProfile != null) {
        final createdAtStr = _providerProfile!['created_at'];
        if (createdAtStr != null) {
          try {
            final regDate = DateTime.parse(createdAtStr.toString());
            _daysSinceRegistration = DateTime.now().difference(regDate).inDays;
          } catch (e) {
            debugPrint('Error parsing registration date: $e');
          }
        }
      }

      if (mounted) setState(() => _isLoading = false);

      // After data loaded, check for warnings/ban
      if (mounted && _isProvider) {
        _checkDocumentDeadline();
      }
    } catch (e) {
      debugPrint('Error loading profile: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _checkDocumentDeadline() async {
    if (!_isProvider || _isBanned) return;
    if (!_isDocumentIncomplete) return;

    final warningThresholdDays = 12; // Show warning starting day 12 (3 days before ban)
    final gracePeriodDays = 15;

    if (_daysSinceRegistration >= gracePeriodDays) {
      // Auto-ban
      await _banProvider(
        'لم يتم رفع الوثائق المطلوبة خلال فترة السماح (15 يوم)',
      );
    } else if (_daysSinceRegistration >= warningThresholdDays) {
      // Show urgent warning
      final daysLeft = gracePeriodDays - _daysSinceRegistration;
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            title: const Text('تنبيه هام'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.warning_rounded,
                  color: AppTheme.errorColor,
                  size: DesignTokens.iconAvatar,
                ),
                const SizedBox(height: DesignTokens.space8),
                Text(
                  'متبقي $daysLeft يوم فقط لرفع الوثائق المطلوبة.\nإذا لم تقم برفع الوثائق، سيتم حظر حسابك تلقائياً.',
                ),
              ],
            ),
            actions: [
              TextButton(
                child: const Text('فهمت'),
                onPressed: () => Navigator.pop(context),
              ),
              TextButton(
                child: const Text('رفع الوثائق الآن'),
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PartnerDocumentUploadScreen()),
                  );
                },
              ),
            ],
          ),
        );
      }
    }
  }

  Future<void> _banProvider(String reason) async {
    final uid = SupabaseService.currentUserId;
    if (uid == null) return;
    try {
      await SupabaseService.db
          .from('profiles')
          .update({
            'banned_at': DateTime.now().toIso8601String(),
            'ban_reason': reason,
          })
          .eq('id', uid);

      if (mounted) {
        setState(() => _isBanned = true);
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            title: const Text('حظر الحساب'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.block_rounded, color: AppTheme.errorColor, size: DesignTokens.iconAvatar),
                const SizedBox(height: DesignTokens.space8),
                const Text(
                  'تم حظر حسابك لعدم رفع الوثائق المطلوبة في الوقت المحدد.\nيرجى التواصل مع الإدارة للمزيد من المعلومات.',
                ),
              ],
            ),
            actions: [
              TextButton(
                child: const Text('تسجيل الخروج'),
                onPressed: () async {
                  await AuthRepository().signOut();
                  if (!mounted) return;
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (_) => false,
                  );
                },
              ),
            ],
          ),
        );
      }
    } catch (e) {
      debugPrint('Error banning provider: $e');
    }
  }

  Widget _buildDocumentStatus() {
    final status = _providerProfile?['document_verification_status'] ?? 'pending';
    Color color;
    IconData icon;
    String text;

    switch (status) {
      case 'approved':
        color = AppTheme.successColor;
        icon = Icons.check_circle_rounded;
        text = 'الوثائق موافق عليها';
        break;
      case 'rejected':
        color = AppTheme.errorColor;
        icon = Icons.cancel_rounded;
        text = 'الوثائق مرفوضة - يرجى إعادة الرفع';
        break;
      default:
        color = AppTheme.tertiaryColor;
        icon = Icons.schedule_rounded;
        text = 'بانتظار مراجعة الوثائق';
    }

    return Container(
      padding: EdgeInsets.all(DesignTokens.space12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: DesignTokens.iconMd),
          SizedBox(width: DesignTokens.space8),
          Expanded(
            child: Text(text, style: TextStyle(fontSize: DesignTokens.textBodySmall, color: color)),
          ),
        ],
      ),
    );
  }

  Widget _buildBanner(String type) {
    Color bgColor, iconColor;
    IconData icon;
    String title, message;

    if (type == 'account_banned') {
      bgColor = AppTheme.errorColor.withValues(alpha: 0.08);
      iconColor = AppTheme.errorColor;
      icon = Icons.block_rounded;
      title = 'حظر الحساب';
      message = _banReason ?? 'تم حظر حسابك بسبب انتهاك شروط الاستخدام.';
    } else if (type == 'deadline_imminent') {
      bgColor = AppTheme.errorColor.withValues(alpha: 0.08);
      iconColor = AppTheme.errorColor;
      icon = Icons.timer_rounded;
      final daysLeft = 15 - _daysSinceRegistration;
      title = 'مهلة نهائية';
      message =
          'باقي $daysLeft يوم فقط لرفع الوثائق. بعدها سيتم حظر حسابك تلقائياً.';
    } else {
      // deadline_warning
      bgColor = AppTheme.tertiaryColor.withValues(alpha: 0.08);
      iconColor = AppTheme.tertiaryColor;
      icon = Icons.error_outline_rounded;
      final daysLeft = 15 - _daysSinceRegistration;
      title = 'تنبيه';
      message = 'يرجى رفع الوثائق المطلوبة خلال $daysLeft يوم لتجنب الحظر.';
    }

    return Container(
      margin: EdgeInsets.fromLTRB(DesignTokens.space24, DesignTokens.space24, DesignTokens.space24, 0),
      padding: EdgeInsets.all(DesignTokens.space16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
        border: Border.all(color: iconColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: DesignTokens.iconMd),
          SizedBox(width: DesignTokens.space6.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: iconColor,
                    fontSize: DesignTokens.textBodyMedium,
                  ),
                ),
                SizedBox(height: DesignTokens.space4),
                Text(
                  message,
                  style: TextStyle(
                    color: iconColor.withValues(alpha: 0.8),
                    fontSize: DesignTokens.textBodySmall,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _menuItem(IconData ic, String label, String value, {Color? iconColor, Widget? trailing}) {
    return Container(
      margin: EdgeInsets.only(bottom: DesignTokens.space3.h),
      padding: const EdgeInsets.symmetric(horizontal: DesignTokens.space16, vertical: DesignTokens.space7),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
        border: Border.all(color: AppTheme.textSecondary.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(DesignTokens.space3),
            decoration: BoxDecoration(
              color: (iconColor ?? AppTheme.primaryColor).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
            ),
            child: Icon(ic, color: iconColor ?? AppTheme.primaryColor, size: DesignTokens.iconMd),
          ),
          SizedBox(width: DesignTokens.space6.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: AppTheme.textSecondary, fontSize: DesignTokens.textLabelSmall)),
                SizedBox(height: DesignTokens.space2),
                Text(value, style: TextStyle(fontWeight: FontWeight.w600, fontSize: DesignTokens.textBodyMedium, color: AppTheme.textPrimary)),
              ],
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  Future<void> _showChangeCategoryDialog() async {
    try {
      final cats = await SupabaseService.db
          .from('categories')
          .select()
          .order('created_at');

      // Deduplicate categories by id
      final uniqueCatsMap = <int, Map<String, dynamic>>{};
      for (var c in cats) {
        final id = c['id'] as int;
        if (!uniqueCatsMap.containsKey(id)) {
          uniqueCatsMap[id] = Map<String, dynamic>.from(c);
        }
      }
      final categories = uniqueCatsMap.values.toList();
      if (!mounted) return;

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text(
            'تغيير التخصص',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: 300.h,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final cat = categories[index];
                final isSelected = cat['id'] == _providerProfile?['category_id'];
                return ListTile(
                  leading: Icon(
                    isSelected ? Icons.check_rounded : Icons.circle_outlined,
                    color: isSelected ? AppTheme.primaryColor : AppTheme.textSecondary,
                  ),
                  title: Text(cat['name_ar'] ?? cat['name_en'] ?? ''),
                  trailing: isSelected ? const Icon(Icons.chevron_left_rounded, size: 16) : null,
                  onTap: () async {
                    Navigator.pop(context);
                    await _updateCategory(cat['id'], cat['name_ar'] ?? '');
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              child: const Text('إلغاء'),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      );
    } catch (e) {
      debugPrint('Error loading categories: $e');
    }
  }

  Future<void> _updateCategory(int categoryId, String categoryName) async {
    final uid = SupabaseService.currentUserId;
    if (uid == null) return;

    setState(() => _isLoading = true);

    try {
      // Check if provider_profiles exists
      final existing = await SupabaseService.db
          .from('provider_profiles')
          .select('id')
          .eq('id', uid)
          .maybeSingle();

      if (existing == null) {
        // Create provider profile if doesn't exist
        await SupabaseService.db
            .from('provider_profiles')
            .insert({
              'id': uid,
              'profession': categoryName,
              'category_id': categoryId,
              'rating': 0,
              'is_online': false,
              'wallet_balance': 0,
              'document_verification_status': 'pending',
              'updated_at': DateTime.now().toIso8601String(),
            });
      } else {
        // Update existing provider profile
        await SupabaseService.db
            .from('provider_profiles')
            .update({
              'category_id': categoryId,
              'profession': categoryName,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', uid);
      }

      setState(() {
        _providerProfile?['category_id'] = categoryId;
        _category = {'name_ar': categoryName};
      });

      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            content: Text('تم تحديث التخصص إلى: $categoryName'),
            actions: [
              TextButton(
                child: const Text('حسنا'),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      debugPrint('Error updating category: $e');
      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            content: Text('فشل تحديث التخصص: $e'),
            actions: [
              TextButton(
                child: const Text('حسنا'),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  String get _categoryName {
    if (_category != null) {
      return _category!['name_ar'] ?? _category!['name_en'] ?? 'غير محدد';
    }
    return 'غير محدد';
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('تسجيل الخروج'),
        content: const Text('هل أنت متأكد من تسجيل الخروج؟'),
        actions: [
          TextButton(
            child: const Text('إلغاء'),
            onPressed: () => Navigator.pop(context, false),
          ),
          TextButton(
            child: const Text('تسجيل خروج'),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await AuthRepository().signOut();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('حسابي'),
        backgroundColor: AppTheme.surfaceColor,
        elevation: 0,
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // ===== Profile Header =====
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.only(
                        left: DesignTokens.space14.w,
                        right: DesignTokens.space14.w,
                        top: 28.h,
                        bottom: 18.h,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor,
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(28),
                          bottomRight: Radius.circular(28),
                        ),
                      ),
                      child: Column(
                        children: [
                          const SizedBox(height: DesignTokens.space8),
                          // Avatar
                          Container(
                            width: 80.r,
                            height: 80.r,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                (_profile?['full_name']?.toString()?.isNotEmpty == true ? _profile!['full_name']!.toString()[0] : '?'),
                                style: TextStyle(
                                  fontSize: DesignTokens.textDisplayLarge.sp,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: DesignTokens.space12),
                          Text(
                            _profile?['full_name'] ?? '',
                            style: TextStyle(
                              fontSize: DesignTokens.textTitleLarge.sp,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: DesignTokens.space4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: DesignTokens.space12, vertical: DesignTokens.space4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(DesignTokens.radiusXl),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.work_outline_rounded, color: Colors.white.withValues(alpha: 0.7), size: DesignTokens.iconSm),
                                SizedBox(width: DesignTokens.space4),
                                Text(_categoryName, style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: DesignTokens.textBodySmall.sp)),
                              ],
                            ),
                          ),
                          if (_providerProfile != null && _providerProfile!['latitude'] != null && _providerProfile!['longitude'] != null)
                            Padding(
                              padding: const EdgeInsets.only(top: DesignTokens.space3),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.location_on_rounded, color: AppTheme.successColor.withValues(alpha: 0.7), size: DesignTokens.iconSm),
                                  SizedBox(width: DesignTokens.space2.w),
                                  Text('موقع فعلي', style: TextStyle(color: AppTheme.successColor.withValues(alpha: 0.7), fontSize: DesignTokens.textBodySmall.sp)),
                                ],
                              ),
                            ),
                          SizedBox(height: DesignTokens.space8),
                          // Verification badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: DesignTokens.space12, vertical: DesignTokens.space4),
                            decoration: BoxDecoration(
                              color: _profile?['is_verified'] == true
                                  ? AppTheme.successColor.withValues(alpha: 0.2)
                                  : AppTheme.tertiaryColor.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(DesignTokens.radiusXl),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _profile?['is_verified'] == true
                                      ? Icons.check_circle_rounded
                                      : Icons.schedule_rounded,
                                  color: _profile?['is_verified'] == true
                                      ? AppTheme.successColor.withValues(alpha: 0.7)
                                      : AppTheme.tertiaryColor.withValues(alpha: 0.7),
                                  size: DesignTokens.iconSm,
                                ),
                                const SizedBox(width: DesignTokens.space4),
                                Text(
                                  _profile?['is_verified'] == true ? 'حساب موثق' : 'بانتظار التوثيق',
                                  style: TextStyle(
                                    fontSize: DesignTokens.textBodySmall.sp,
                                    color: _profile?['is_verified'] == true
                                        ? AppTheme.successColor.withValues(alpha: 0.7)
                                        : AppTheme.tertiaryColor.withValues(alpha: 0.7),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Warning banners
                    if (_isBanned) _buildBanner('account_banned'),
                    if (!_isBanned && _isProvider && _isDocumentIncomplete && _daysSinceRegistration >= 12)
                      _buildBanner('deadline_imminent'),
                    if (!_isBanned && _isProvider && _isDocumentIncomplete && _daysSinceRegistration >= 5 && _daysSinceRegistration < 12)
                      _buildBanner('deadline_warning'),

                    SizedBox(height: DesignTokens.space20),

                    // ===== Profile Info Section =====
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: DesignTokens.space20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('المعلومات الشخصية', style: TextStyle(fontSize: DesignTokens.textBodyMedium, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                          SizedBox(height: DesignTokens.space5.h),
                          _menuItem(Icons.person_rounded, 'الاسم', _profile?['full_name'] ?? '', iconColor: AppTheme.primaryColor),
                          _menuItem(Icons.email_rounded, 'البريد', SupabaseService.auth.currentUser?.email ?? '', iconColor: AppTheme.primaryColor),
                          _menuItem(Icons.phone_rounded, 'الهاتف', _profile?['phone_number'] ?? _profile?['phone'] ?? '', iconColor: AppTheme.primaryColor),

                          if (_isProvider) ...[
                            SizedBox(height: DesignTokens.space16),
                            const Text('معلومات العمل', style: TextStyle(fontSize: DesignTokens.textBodyMedium, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                            SizedBox(height: DesignTokens.space5.h),
                            // Category (tappable)
                            GestureDetector(
                              onTap: () => _showChangeCategoryDialog(),
                              child: Container(
                                margin: EdgeInsets.only(bottom: DesignTokens.space3.h),
                                padding: const EdgeInsets.symmetric(horizontal: DesignTokens.space16, vertical: DesignTokens.space7),
                                decoration: BoxDecoration(
                                  color: AppTheme.surfaceColor,
                                  borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
                                  border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.15)),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(DesignTokens.space3),
                                      decoration: BoxDecoration(color: AppTheme.primaryColor.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(DesignTokens.radiusSm)),
                                      child: Icon(Icons.work_history_rounded, color: AppTheme.primaryColor, size: DesignTokens.iconMd),
                                    ),
                                    SizedBox(width: DesignTokens.space6.w),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text('التخصص', style: TextStyle(color: AppTheme.textSecondary, fontSize: DesignTokens.textBodySmall)),
                                          const SizedBox(height: DesignTokens.space2),
                                          Text(_categoryName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: DesignTokens.textBodyMedium)),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: EdgeInsets.symmetric(horizontal: DesignTokens.space8, vertical: DesignTokens.space4),
                                      decoration: BoxDecoration(color: AppTheme.primaryColor.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(DesignTokens.radiusSm)),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text('تعديل', style: TextStyle(color: AppTheme.primaryColor, fontSize: DesignTokens.textLabelSmall, fontWeight: FontWeight.w600)),
                                          SizedBox(width: DesignTokens.space1.w),
                                          Icon(Icons.edit_rounded, size: DesignTokens.iconXs, color: AppTheme.primaryColor),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProviderPerformanceScreen())),
                              child: Container(
                                margin: EdgeInsets.only(bottom: DesignTokens.space3.h),
                                padding: const EdgeInsets.symmetric(horizontal: DesignTokens.space16, vertical: DesignTokens.space7),
                                decoration: BoxDecoration(
                                  color: AppTheme.surfaceColor,
                                  borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
                                  border: Border.all(color: AppTheme.textSecondary.withValues(alpha: 0.1)),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(DesignTokens.space3),
                                      decoration: BoxDecoration(color: AppTheme.tertiaryColor.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(DesignTokens.radiusSm)),
                                      child: Icon(Icons.star_rounded, color: AppTheme.tertiaryColor.withValues(alpha: 0.7), size: DesignTokens.iconMd),
                                    ),
                                    SizedBox(width: DesignTokens.space6.w),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('التقييم', style: TextStyle(color: AppTheme.textSecondary, fontSize: DesignTokens.textLabelSmall)),
                                          const SizedBox(height: DesignTokens.space2),
                                          Text(
                                            '${_providerProfile?['rating'] ?? 0}',
                                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: DesignTokens.textBodyMedium, color: AppTheme.textPrimary),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(Icons.chevron_right_rounded, color: AppTheme.primaryColor, size: DesignTokens.iconMd),
                                  ],
                                ),
                              ),
                            ),
                            // Address
                            GestureDetector(
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProviderAddressScreen())),
                              child: Container(
                                margin: EdgeInsets.only(bottom: DesignTokens.space3.h),
                                padding: const EdgeInsets.symmetric(horizontal: DesignTokens.space16, vertical: DesignTokens.space7),
                                decoration: BoxDecoration(
                                  color: AppTheme.surfaceColor,
                                  borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
                                  border: Border.all(color: AppTheme.textSecondary.withValues(alpha: 0.1)),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(DesignTokens.space3),
                                      decoration: BoxDecoration(color: AppTheme.errorColor.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(DesignTokens.radiusSm)),
                                      child: Icon(Icons.location_off_rounded, color: AppTheme.errorColor.withValues(alpha: 0.7), size: DesignTokens.iconMd),
                                    ),
                                    SizedBox(width: DesignTokens.space6.w),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('عنوان العمل', style: TextStyle(color: AppTheme.textSecondary, fontSize: DesignTokens.textLabelSmall)),
                                          const SizedBox(height: DesignTokens.space2),
                                          Text(
                                            _providerProfile?['address'] ?? 'اضغط لإضافة عنوان',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: DesignTokens.textBodyMedium,
                                              color: _providerProfile?['address'] != null ? AppTheme.textPrimary : AppTheme.primaryColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(Icons.chevron_right_rounded, color: AppTheme.primaryColor, size: DesignTokens.iconMd),
                                  ],
                                ),
                              ),
                            ),

                            // Document verification
                            SizedBox(height: DesignTokens.space16),
                            const Text('حالة الوثائق', style: TextStyle(fontSize: DesignTokens.textBodyMedium, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                            SizedBox(height: DesignTokens.space5.h),
                            _buildDocumentStatus(),
                            if (_isDocumentIncomplete && !_isBanned) ...[
                              SizedBox(height: DesignTokens.space5.h),
                              SizedBox(
                                width: double.infinity,
                                height: DesignTokens.space24,
                                child: ElevatedButton(
                                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PartnerDocumentUploadScreen())),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.tertiaryColor,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DesignTokens.radiusMd)),
                                  ),
                                  child: Padding(
                                    padding: EdgeInsets.zero,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.upload_file_rounded, color: Colors.white, size: DesignTokens.iconMd),
                                        SizedBox(width: DesignTokens.space8),
                                        Text('رفع/تحديث الوثائق', style: TextStyle(color: Colors.white, fontSize: DesignTokens.textBodyMedium, fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],

                          SizedBox(height: DesignTokens.space32),

                          // ===== Logout Button =====
                          SizedBox(
                            width: double.infinity,
                            height: 28.h,
                            child: ElevatedButton(
                              onPressed: _handleLogout,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DesignTokens.radiusLg)),
                              ),
                              child: Padding(
                                padding: EdgeInsets.zero,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.logout_rounded, color: AppTheme.errorColor, size: DesignTokens.iconMd),
                                    SizedBox(width: DesignTokens.space8),
                                    Text('تسجيل الخروج', style: TextStyle(color: AppTheme.errorColor, fontSize: DesignTokens.textBodyLarge, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: DesignTokens.space40),
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
