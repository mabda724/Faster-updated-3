
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/design_tokens.dart';

class AdminProvidersScreen extends StatefulWidget {
  const AdminProvidersScreen({super.key});
  @override
  State<AdminProvidersScreen> createState() => _AdminProvidersScreenState();
}

class _AdminProvidersScreenState extends State<AdminProvidersScreen>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _providers = [];
  List<Map<String, dynamic>> _filteredProviders = [];
  bool _isLoading = true;
  late AnimationController _animController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: DesignTokens.durationSlow,
    );
    _searchController.addListener(_onSearchChanged);
    _load();
  }

  @override
  void dispose() {
    _animController.dispose();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.trim().toLowerCase();
      _applyFilter();
    });
  }

  void _applyFilter() {
    if (_searchQuery.isEmpty) {
      _filteredProviders = List.from(_providers);
    } else {
      _filteredProviders = _providers.where((p) {
        final name = (p['full_name'] ?? '').toString().toLowerCase();
        final phone = (p['phone_number'] ?? '').toString().toLowerCase();
        final provider = _pp(p);
        final category = provider?['categories'];
        final catName = category is Map
            ? (category['name_ar'] ?? '').toString().toLowerCase()
            : '';
        return name.contains(_searchQuery) ||
            phone.contains(_searchQuery) ||
            catName.contains(_searchQuery);
      }).toList();
    }
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final data = await SupabaseService.db
          .from('profiles')
          .select('*, provider_profiles(*, categories(*))')
          .eq('role', 'provider')
          .order('created_at', ascending: false);
      if (mounted) {
        setState(() {
          _providers = List<Map<String, dynamic>>.from(data);
          _applyFilter();
          _isLoading = false;
        });
        _animController.forward(from: 0);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _snack('خطأ: $e');
      }
    }
  }

  Map<String, dynamic>? _pp(Map<String, dynamic> p) {
    final pp = p['provider_profiles'];
    if (pp is List && pp.isNotEmpty) return Map<String, dynamic>.from(pp.first);
    if (pp is Map<String, dynamic>) return pp;
    return null;
  }

  void _snack(String msg, {Color? bg}) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg, textAlign: TextAlign.center),
          backgroundColor: bg ?? AppTheme.primaryColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: DesignTokens.brMd),
        ),
      );

  Future<void> _updateDocStatus(String id, String status) async {
    try {
      String? rejectionReason;
      if (status == 'rejected') {
        final reasonCtrl = TextEditingController();
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.shield_rounded, color: AppTheme.errorColor, size: DesignTokens.iconSm),
                SizedBox(width: DesignTokens.space4),
                const Text('سبب الرفض', style: TextStyle(fontWeight: FontWeight.bold, fontSize: DesignTokens.textBodyMedium)),
              ],
            ),
            content: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: TextField(
                controller: reasonCtrl,
                textAlign: TextAlign.right,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'اكتب سبب رفض المستندات...',
                  filled: true,
                  fillColor: Colors.grey.shade200,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('إلغاء'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('رفض'),
              ),
            ],
          ),
        );
        if (confirmed != true) return;
        rejectionReason = reasonCtrl.text.trim().isNotEmpty ? reasonCtrl.text.trim() : 'مستندات غير صحيحة';
      }

      await SupabaseService.client.rpc('verify_provider_documents', params: {
        'p_provider_id': id,
        'p_approved': status == 'approved',
        'p_rejection_reason': rejectionReason,
      });

      try {
        await NotificationService.sendPushNotification(
          userId: id,
          title: status == 'approved' ? 'تم توثيق المستندات' : 'تم رفض المستندات',
          body: status == 'approved'
            ? 'تمت الموافقة على مستنداتك بنجاح.'
            : 'لم تتم الموافقة على مستنداتك. ${rejectionReason ?? 'يرجى إعادة رفع المستندات الصحيحة.'}',
          type: status == 'approved' ? 'document_verified' : 'document_rejected',
        );
      } catch (_) {}

      _snack(
        status == 'approved' ? 'تم قبول الوثائق' : 'تم رفض الوثائق',
        bg: status == 'approved' ? AppTheme.successColor : AppTheme.errorColor,
      );
      _load();
    } catch (e) {
      _snack('خطأ: $e');
    }
  }

  Future<void> _changeRole(String id, String newRole) async {
    try {
      await SupabaseService.db
          .from('profiles')
          .update({'role': newRole})
          .eq('id', id);
      _snack('تم تغيير الدور إلى $newRole', bg: AppTheme.successColor);
      _load();
    } catch (e) {
      _snack('خطأ: $e');
    }
  }

  Future<void> _banProvider(String id, bool ban) async {
    if (ban) {
      final reason = TextEditingController();
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.shield_rounded, size: DesignTokens.iconSm, color: AppTheme.errorColor),
              SizedBox(width: DesignTokens.space4),
              const Text('حظر مقدم الخدمة',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: DesignTokens.textBodyMedium)),
            ],
          ),
          content: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: TextField(
              controller: reason,
              decoration: InputDecoration(
                hintText: 'سبب الحظر',
                filled: true,
                fillColor: Colors.grey.shade200,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('حظر'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      await SupabaseService.db.from('profiles').update({
        'banned_at': DateTime.now().toUtc().toIso8601String(),
        'ban_reason': reason.text.isNotEmpty ? reason.text : 'مخالفة السياسات',
        'is_verified': false,
      }).eq('id', id);
      await SupabaseService.db
          .from('provider_profiles')
          .update({'is_online': false})
          .eq('id', id);
    } else {
      await SupabaseService.db
          .from('profiles')
          .update({'banned_at': null, 'ban_reason': null})
          .eq('id', id);
    }
    _snack(
      ban ? 'تم حظر الحساب' : 'تم إلغاء الحظر',
      bg: ban ? AppTheme.errorColor : AppTheme.successColor,
    );
    _load();
  }

  void _showProviderDetails(Map<String, dynamic> p) {
    final provider = _pp(p);
    final docStatus = provider?['document_verification_status'] ?? 'pending';
    final isBanned = p['banned_at'] != null;
    final category = provider?['categories'];
    final catName =
        category is Map ? (category['name_ar'] ?? '') : 'غير محدد';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(DesignTokens.radiusLg)),
          boxShadow: DesignTokens.shadow4(AppTheme.glassShadow),
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: DesignTokens.space32,
                  height: DesignTokens.space3,
                  margin: EdgeInsets.only(
                    top: DesignTokens.space6,
                    bottom: DesignTokens.space8,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.textSecondary.withValues(alpha: 0.15),
                    borderRadius: DesignTokens.brSm,
                  ),
                ),
              ),
              // Gradient header
              Container(
                width: double.infinity,
                margin: EdgeInsets.symmetric(horizontal: DesignTokens.space8),
                padding: EdgeInsets.all(DesignTokens.space8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.primaryColor,
                      AppTheme.primaryColor.withValues(alpha: 0.85),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: DesignTokens.brLg,
                  boxShadow: DesignTokens.shadow3(AppTheme.primaryColor),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Stack(
                          children: [
                            CircleAvatar(
                              radius: DesignTokens.iconAvatar / 2,
                              backgroundImage: p['avatar_url'] != null
                                  ? NetworkImage(p['avatar_url'])
                                  : null,
                              backgroundColor:
                                  AppTheme.surfaceColor.withValues(alpha: 0.2),
                              child: p['avatar_url'] == null
                                  ? Text(
                                      (p['full_name'] ?? '?')[0],
                                      style: const TextStyle(
                                        color: AppTheme.surfaceColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: DesignTokens.textTitleMedium,
                                      ),
                                    )
                                  : null,
                            ),
                            if (provider?['is_online'] == true)
                              Positioned(
                                bottom: DesignTokens.space0,
                                right: DesignTokens.space0,
                                child: Container(
                                  width: DesignTokens.space6,
                                  height: DesignTokens.space6,
                                  decoration: BoxDecoration(
                                    color: AppTheme.successColor,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: AppTheme.surfaceColor, width: DesignTokens.space1),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        SizedBox(width: DesignTokens.space6),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                p['full_name'] ?? 'بدون اسم',
                                style: const TextStyle(
                                  color: AppTheme.surfaceColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: DesignTokens.textTitleSmall,
                                ),
                              ),
                              SizedBox(height: DesignTokens.space1),
                              Row(
                                children: [
                                  Icon(Icons.phone_rounded,
                                      size: DesignTokens.iconXs,
                                      color: AppTheme.surfaceColor.withValues(alpha: 0.8)),
                                  SizedBox(width: DesignTokens.space2),
                                  Text(
                                    p['phone_number'] ?? '',
                                    style: TextStyle(
                                      color: AppTheme.surfaceColor.withValues(alpha: 0.8),
                                      fontSize: DesignTokens.textBodySmall,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: DesignTokens.space1),
                              Row(
                                children: [
                                  Icon(Icons.category_rounded,
                                      size: DesignTokens.iconXs,
                                      color: AppTheme.surfaceColor.withValues(alpha: 0.8)),
                                  SizedBox(width: DesignTokens.space2),
                                  Text(
                                    catName,
                                    style: TextStyle(
                                      color: AppTheme.surfaceColor.withValues(alpha: 0.9),
                                      fontSize: DesignTokens.textLabelSmall,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: DesignTokens.space6),
                    // Stats row in header
                    Row(
                      children: [
                        Expanded(
                          child: _headerStatBox(
                              'التقييم',
                              '${provider?['rating'] ?? 0}',
                              Icons.star_rounded),
                        ),
                        SizedBox(width: DesignTokens.space4),
                        Expanded(
                          child: _headerStatBox(
                              'المحفظة',
                              '${provider?['wallet_balance'] ?? 0} ج',
                              Icons.account_balance_wallet_rounded),
                        ),
                        SizedBox(width: DesignTokens.space4),
                        Expanded(
                          child: _headerStatBox(
                              'المديونية',
                              '${provider?['debt_amount'] ?? 0} ج',
                              Icons.receipt_long_rounded),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(height: DesignTokens.space6),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: DesignTokens.space8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Document verification section
                    _sectionTitle(Icons.description_rounded, 'حالة الوثائق'),
                    SizedBox(height: DesignTokens.space4),
                    _docStatusWidget(docStatus),
                    SizedBox(height: DesignTokens.space6),

                    // Document images
                    if (provider?['id_document_url'] != null) ...[
                      _sectionTitle(Icons.badge_rounded, 'صورة الهوية'),
                      SizedBox(height: DesignTokens.space4),
                      ClipRRect(
                        borderRadius: DesignTokens.brMd,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: DesignTokens.brMd,
                            border: Border.all(
                                color: AppTheme.textTertiary.withValues(alpha: 0.2)),
                          ),
                          child: Image.network(
                            provider!['id_document_url'],
                            height: DesignTokens.space64 * 2.5,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            semanticLabel: 'صورة المستند',
                            errorBuilder: (_, __, ___) => Container(
                              height: DesignTokens.space40,
                              color: AppTheme.backgroundColor,
                              child: const Center(
                                child: Text('خطأ في تحميل الصورة'),
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: DesignTokens.space6),
                    ],
                    if (provider?['profile_document_url'] != null) ...[
                      _sectionTitle(Icons.person_rounded, 'الصورة الشخصية'),
                      SizedBox(height: DesignTokens.space4),
                      ClipRRect(
                        borderRadius: DesignTokens.brMd,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: DesignTokens.brMd,
                            border: Border.all(
                                color: AppTheme.textTertiary.withValues(alpha: 0.2)),
                          ),
                          child: Image.network(
                            provider!['profile_document_url'],
                            height: DesignTokens.space64 * 2.5,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            semanticLabel: 'صورة المستند',
                            errorBuilder: (_, __, ___) => Container(
                              height: DesignTokens.space40,
                              color: AppTheme.backgroundColor,
                              child: const Center(
                                child: Text('خطأ في تحميل الصورة'),
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: DesignTokens.space6),
                    ],
                    if (provider?['national_id_number'] != null &&
                        provider!['national_id_number'].toString().isNotEmpty) ...[
                      _infoRow(
                        Icons.credit_card_rounded,
                        'رقم الهوية',
                        provider['national_id_number'].toString(),
                      ),
                      SizedBox(height: DesignTokens.space6),
                    ],

                    // Document review actions
                    if (docStatus == 'pending') ...[
                      _sectionTitle(Icons.rate_review_rounded, 'مراجعة الوثائق'),
                      SizedBox(height: DesignTokens.space4),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pop(ctx);
                                _updateDocStatus(p['id'], 'approved');
                              },
                              icon: const Icon(Icons.check_rounded,
                                  color: AppTheme.surfaceColor, size: DesignTokens.iconSm),
                              label: const Text('قبول',
                                  style: TextStyle(
                                      color: AppTheme.surfaceColor,
                                      fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.successColor,
                                padding: EdgeInsets.symmetric(
                                    vertical: DesignTokens.space6),
                                shape: RoundedRectangleBorder(
                                    borderRadius: DesignTokens.brSm),
                              ),
                            ),
                          ),
                          SizedBox(width: DesignTokens.space4),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pop(ctx);
                                _updateDocStatus(p['id'], 'rejected');
                              },
                              icon: const Icon(Icons.close_rounded,
                                  color: AppTheme.surfaceColor, size: DesignTokens.iconSm),
                              label: const Text('رفض',
                                  style: TextStyle(
                                      color: AppTheme.surfaceColor,
                                      fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.errorColor,
                                padding: EdgeInsets.symmetric(
                                    vertical: DesignTokens.space6),
                                shape: RoundedRectangleBorder(
                                    borderRadius: DesignTokens.brSm),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: DesignTokens.space6),
                    ],

                    // Role change
                    _sectionTitle(Icons.swap_horiz_rounded, 'تغيير الدور'),
                    SizedBox(height: DesignTokens.space4),
                    Row(
                      children: [
                        _roleBtn('client', 'عميل', p['id'], ctx),
                        SizedBox(width: DesignTokens.space3),
                        _roleBtn('provider', 'مقدم خدمة', p['id'], ctx),
                        SizedBox(width: DesignTokens.space3),
                        _roleBtn('admin', 'أدمن', p['id'], ctx),
                      ],
                    ),
                    SizedBox(height: DesignTokens.space6),

                    // Ban / Unban
                    SizedBox(
                      width: double.infinity,
                      height: DesignTokens.buttonHeightSmall,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _banProvider(p['id'], !isBanned);
                        },
                        icon: Icon(
                          isBanned ? Icons.lock_open_rounded : Icons.block_rounded,
                          color: AppTheme.surfaceColor,
                          size: DesignTokens.iconSm,
                        ),
                        label: Text(
                          isBanned ? 'إلغاء الحظر' : 'حظر الحساب',
                          style: const TextStyle(
                              color: AppTheme.surfaceColor, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isBanned
                              ? AppTheme.successColor
                              : AppTheme.errorColor,
                          shape:
                              RoundedRectangleBorder(borderRadius: DesignTokens.brSm),
                        ),
                      ),
                    ),
                    SizedBox(height: DesignTokens.space10),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _headerStatBox(String label, String value, IconData icon) {
    return Container(
      padding: EdgeInsets.symmetric(
          vertical: DesignTokens.space3, horizontal: DesignTokens.space4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor.withValues(alpha: 0.15),
        borderRadius: DesignTokens.brSm,
      ),
      child: Column(
        children: [
          Icon(icon, color: AppTheme.surfaceColor, size: DesignTokens.iconSm),
          SizedBox(height: DesignTokens.space1),
          Text(
            value,
            style: const TextStyle(
              color: AppTheme.surfaceColor,
              fontWeight: FontWeight.bold,
              fontSize: DesignTokens.textBodyMedium,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: AppTheme.surfaceColor.withValues(alpha: 0.75),
              fontSize: DesignTokens.textLabelSmall,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Container(
      padding: EdgeInsets.all(DesignTokens.space4),
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: DesignTokens.brSm,
      ),
      child: Row(
        children: [
          Icon(icon, size: DesignTokens.iconSm, color: AppTheme.primaryColor),
          SizedBox(width: DesignTokens.space4),
          Text(
            '$label: ',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: DesignTokens.textLabelSmall,
              color: AppTheme.textPrimary,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: DesignTokens.textLabelSmall,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _roleBtn(String role, String label, String userId, BuildContext ctx) {
    return Expanded(
      child: OutlinedButton(
        onPressed: () {
          Navigator.pop(ctx);
          _changeRole(userId, role);
        },
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppTheme.primaryColor),
          shape: RoundedRectangleBorder(borderRadius: DesignTokens.brSm),
          padding: EdgeInsets.symmetric(vertical: DesignTokens.space5),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: DesignTokens.textLabelSmall,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(IconData icon, String title) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(DesignTokens.space2),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.1),
            borderRadius: DesignTokens.brSm,
          ),
          child: Icon(icon,
              size: DesignTokens.iconSm, color: AppTheme.primaryColor),
        ),
        SizedBox(width: DesignTokens.space4),
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: DesignTokens.textBodySmall,
            color: AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _docStatusWidget(String s) {
    Color c;
    String t;
    IconData ic;
    switch (s) {
      case 'approved':
        c = AppTheme.successColor;
        t = 'مقبولة';
        ic = Icons.verified_rounded;
        break;
      case 'rejected':
        c = AppTheme.errorColor;
        t = 'مرفوضة';
        ic = Icons.gpp_bad_rounded;
        break;
      default:
        c = AppTheme.tertiaryColor;
        t = 'قيد المراجعة';
        ic = Icons.hourglass_empty_rounded;
    }
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: DesignTokens.space6, vertical: DesignTokens.space4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [c.withValues(alpha: 0.08), c.withValues(alpha: 0.02)],
          begin: Alignment.centerRight,
          end: Alignment.centerLeft,
        ),
        borderRadius: DesignTokens.brSm,
        border: Border.all(color: c.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(ic, color: c, size: DesignTokens.iconSm),
          SizedBox(width: DesignTokens.space4),
          Text(
            t,
            style: TextStyle(
              fontSize: DesignTokens.textLabelSmall,
              color: c,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          Container(
            padding: EdgeInsets.symmetric(
                horizontal: DesignTokens.space3, vertical: DesignTokens.space1),
            decoration: BoxDecoration(
              color: c.withValues(alpha: 0.12),
              borderRadius: DesignTokens.brFull,
            ),
            child: Text(
              s == 'approved'
                  ? 'موثقة'
                  : s == 'rejected'
                      ? 'مرفوض'
                      : 'معلق',
              style: TextStyle(
                fontSize: DesignTokens.textLabelSmall - 1,
                color: c,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceColor,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: true,
        title: const Text(
          'إدارة مقدمي الخدمة',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: DesignTokens.textBodyMedium,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppTheme.textPrimary, size: DesignTokens.iconSm),
          tooltip: 'العودة',
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? _buildLoadingState()
          : Column(
              children: [
                // Search bar
                Container(
                  color: AppTheme.surfaceColor,
                  padding: EdgeInsets.fromLTRB(
                    DesignTokens.space8,
                    DesignTokens.space2,
                    DesignTokens.space8,
                    DesignTokens.space6,
                  ),
                  child: Container(
                    height: DesignTokens.searchBarHeight,
                    decoration: BoxDecoration(
                      color: AppTheme.backgroundColor,
                      borderRadius:
                          BorderRadius.circular(DesignTokens.searchBarRadius),
                      border: Border.all(
                        color: AppTheme.textTertiary.withValues(alpha: 0.15),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      textAlign: TextAlign.right,
                      decoration: InputDecoration(
                        hintText: 'بحث بالاسم أو رقم الهاتف أو التصنيف...',
                        hintStyle: TextStyle(
                          color: AppTheme.textTertiary,
                          fontSize: DesignTokens.textBodySmall,
                        ),
                        prefixIcon: Padding(
                          padding: EdgeInsets.only(left: DesignTokens.space4),
                          child: Icon(
                            Icons.search_rounded,
                            color: AppTheme.textTertiary,
                            size: DesignTokens.iconSm,
                          ),
                        ),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? Padding(
                                padding: EdgeInsets.only(
                                    right: DesignTokens.space2),
                                child: GestureDetector(
                                  onTap: () {
                                    _searchController.clear();
                                  },
                                  child: Icon(
                                    Icons.close_rounded,
                                    color: AppTheme.textTertiary,
                                    size: DesignTokens.iconSm,
                                  ),
                                ),
                              )
                            : null,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          vertical: DesignTokens.space2,
                          horizontal: DesignTokens.space6,
                        ),
                      ),
                      style: TextStyle(
                        fontSize: DesignTokens.textBodySmall,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                ),
                // Stats summary row
                Container(
                  color: AppTheme.surfaceColor,
                  padding: EdgeInsets.fromLTRB(
                    DesignTokens.space8,
                    0,
                    DesignTokens.space8,
                    DesignTokens.space4,
                  ),
                  child: Row(
                    children: [
                      _summaryChip(
                        Icons.people_rounded,
                        '${_providers.length}',
                        AppTheme.primaryColor,
                      ),
                      SizedBox(width: DesignTokens.space4),
                      _summaryChip(
                        Icons.verified_rounded,
                        '${_providers.where((p) => p['is_verified'] == true).length}',
                        AppTheme.successColor,
                      ),
                      SizedBox(width: DesignTokens.space4),
                      if (_searchQuery.isNotEmpty)
                        _summaryChip(
                          Icons.search_rounded,
                          '${_filteredProviders.length}',
                          AppTheme.infoColor,
                        ),
                    ],
                  ),
                ),
                // Providers list
                Expanded(
                  child: _filteredProviders.isEmpty
                      ? _buildEmptyState()
                      : RefreshIndicator(
                          onRefresh: _load,
                          color: AppTheme.primaryColor,
                          child: ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: EdgeInsets.fromLTRB(
                              DesignTokens.space8,
                              DesignTokens.space4,
                              DesignTokens.space8,
                              DesignTokens.space16,
                            ),
                            itemCount: _filteredProviders.length,
                            itemBuilder: (_, i) {
                              return _buildProviderCard(i);
                            },
                          ),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _summaryChip(IconData icon, String count, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: DesignTokens.space4, vertical: DesignTokens.space3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: DesignTokens.brSm,
        border: Border.all(color: color.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: DesignTokens.iconXs, color: color),
          SizedBox(width: DesignTokens.space2),
          Text(
            count,
            style: TextStyle(
              fontSize: DesignTokens.textBodySmall,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProviderCard(int index) {
    final p = _filteredProviders[index];
    final provider = _pp(p);
    final docStatus = provider?['document_verification_status'] ?? 'pending';
    final isApproved = p['is_verified'] == true && docStatus == 'approved';
    final isBanned = p['banned_at'] != null;
    final category = provider?['categories'];
    final catName = category is Map ? (category['name_ar'] ?? '') : '';
    final isOnline = provider?['is_online'] == true;

    Color statusColor;
    String statusText;
    IconData statusIcon;
    if (isBanned) {
      statusColor = AppTheme.errorColor;
      statusText = 'محظور';
      statusIcon = Icons.block_rounded;
    } else if (isApproved) {
      statusColor = AppTheme.successColor;
      statusText = 'مفعل';
      statusIcon = Icons.verified_rounded;
    } else {
      statusColor = AppTheme.tertiaryColor;
      statusText = 'قيد المراجعة';
      statusIcon = Icons.hourglass_bottom_rounded;
    }

    // Stagger entrance animation
    final staggerDelay = (index * 60).clamp(0, 600);
    final animDelay = Duration(milliseconds: staggerDelay);

    return AnimatedBuilder(
      animation: _animController,
      builder: (context, child) {
        final animValue = _animController.value;
        final delayFraction = animDelay.inMilliseconds /
            DesignTokens.durationSlow.inMilliseconds;
        final start = delayFraction.clamp(0.0, 0.7);
        final end = (start + 0.3).clamp(0.0, 1.0);
        final t = ((animValue - start) / (end - start)).clamp(0.0, 1.0);
        final opacity = Curves.easeOut.transform(t);
        final translateY = DesignTokens.space8 * (1 - Curves.easeOut.transform(t));

        if (animValue < start) {
          return SizedBox(height: 50.h);
        }

        return Opacity(
          opacity: opacity,
          child: Transform.translate(
            offset: Offset(0, translateY),
            child: child,
          ),
        );
      },
      child: GestureDetector(
        onTap: () => _showProviderDetails(p),
        child: Container(
          margin: EdgeInsets.only(bottom: DesignTokens.space6),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: DesignTokens.brLg,
            boxShadow: DesignTokens.shadow2(AppTheme.glassShadow),
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: DesignTokens.brLg,
              border: Border(
                right: BorderSide(
                  color: statusColor.withValues(alpha: 0.5),
                  width: 3,
                ),
              ),
            ),
            child: Padding(
              padding: EdgeInsets.all(DesignTokens.space6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Avatar with online indicator
                      Stack(
                        children: [
                          CircleAvatar(
                            radius: DesignTokens.space10,
                            backgroundImage: p['avatar_url'] != null
                                ? NetworkImage(p['avatar_url'])
                                : null,
                            backgroundColor:
                                AppTheme.primaryColor.withValues(alpha: 0.08),
                            child: p['avatar_url'] == null
                                ? Text(
                                    (p['full_name'] ?? '?')[0],
                                    style: const TextStyle(
                                      color: AppTheme.primaryColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: DesignTokens.textTitleSmall,
                                    ),
                                  )
                                : null,
                          ),
                          if (isOnline)
                            Positioned(
                              bottom: DesignTokens.space0,
                              right: DesignTokens.space0,
                              child: Container(
                                width: DesignTokens.space5,
                                height: DesignTokens.space5,
                                decoration: BoxDecoration(
                                  color: AppTheme.successColor,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: AppTheme.surfaceColor, width: DesignTokens.space1),
                                ),
                              ),
                            ),
                        ],
                      ),
                      SizedBox(width: DesignTokens.space6),
                      // Name and category
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p['full_name'] ?? 'بدون اسم',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: DesignTokens.textBodyMedium,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            SizedBox(height: DesignTokens.space2),
                            if (catName.isNotEmpty)
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: DesignTokens.space4,
                                  vertical: DesignTokens.space1,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor
                                      .withValues(alpha: 0.06),
                                  borderRadius: DesignTokens.brSm,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.category_rounded,
                                        size: DesignTokens.iconXs - 2,
                                        color: AppTheme.primaryColor
                                            .withValues(alpha: 0.7)),
                                    SizedBox(width: DesignTokens.space2),
                                    Text(
                                      catName,
                                      style: const TextStyle(
                                        fontSize: DesignTokens.textLabelSmall,
                                        color: AppTheme.primaryColor,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                      // Status chip with gradient
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: DesignTokens.space4,
                          vertical: DesignTokens.space3,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              statusColor.withValues(alpha: 0.12),
                              statusColor.withValues(alpha: 0.04),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: DesignTokens.brFull,
                          border: Border.all(
                            color: statusColor.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(statusIcon,
                                size: DesignTokens.iconXs - 2,
                                color: statusColor),
                            SizedBox(width: DesignTokens.space2),
                            Text(
                              statusText,
                              style: TextStyle(
                                fontSize: DesignTokens.textLabelSmall,
                                fontWeight: FontWeight.bold,
                                color: statusColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: DesignTokens.space4),
                  // Info row
                  Container(
                    padding: EdgeInsets.all(DesignTokens.space4),
                    decoration: BoxDecoration(
                      color: AppTheme.backgroundColor,
                      borderRadius: DesignTokens.brSm,
                    ),
                    child: Row(
                      children: [
                        _infoBadge(
                          Icons.star_rounded,
                          '${provider?['rating'] ?? 0}',
                          AppTheme.tertiaryColor,
                          provider?['reviews_count'] != null
                              ? '(${provider!['reviews_count']})'
                              : null,
                        ),
                        SizedBox(width: DesignTokens.space6),
                        _infoBadge(
                          Icons.description_rounded,
                          docStatus == 'approved'
                              ? 'موثقة'
                              : docStatus == 'rejected'
                                  ? 'مرفوضة'
                                  : 'معلق',
                          docStatus == 'approved'
                              ? AppTheme.successColor
                              : docStatus == 'rejected'
                                  ? AppTheme.errorColor
                                  : AppTheme.tertiaryColor,
                        ),
                        if (p['phone_number'] != null &&
                            p['phone_number'].toString().isNotEmpty)
                          Padding(
                            padding:
                                EdgeInsets.only(right: DesignTokens.space4),
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: DesignTokens.space3, vertical: DesignTokens.space1),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor
                                    .withValues(alpha: 0.05),
                                borderRadius: DesignTokens.brSm,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.phone_rounded,
                                    size: DesignTokens.iconXs - 2,
                                    color: AppTheme.primaryColor
                                        .withValues(alpha: 0.6),
                                  ),
                                  SizedBox(width: DesignTokens.space2),
                                  Text(
                                    p['phone_number'].toString(),
                                    style: const TextStyle(
                                      fontSize: DesignTokens.textLabelSmall - 1,
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        const Spacer(),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: DesignTokens.iconXs - 2,
                          color: AppTheme.textSecondary.withValues(alpha: 0.3),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoBadge(IconData icon, String text, Color color,
      [String? suffix]) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon,
            size: DesignTokens.iconXs, color: color.withValues(alpha: 0.8)),
        SizedBox(width: DesignTokens.space2),
        Text(
          text,
          style: TextStyle(
            fontSize: DesignTokens.textLabelSmall,
            fontWeight: FontWeight.w600,
            color: AppTheme.textSecondary,
          ),
        ),
        if (suffix != null) ...[
          SizedBox(width: DesignTokens.space1),
          Text(
            suffix,
            style: TextStyle(
              fontSize: DesignTokens.textLabelSmall - 1,
              color: AppTheme.textTertiary,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildLoadingState() {
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(
        DesignTokens.space8,
        DesignTokens.space8,
        DesignTokens.space8,
        DesignTokens.space16,
      ),
      itemCount: 5,
      itemBuilder: (_, __) => Container(
        margin: EdgeInsets.only(bottom: DesignTokens.space6),
        padding: EdgeInsets.all(DesignTokens.space6),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: DesignTokens.brLg,
        ),
        child: Row(
          children: [
            Container(
              width: DesignTokens.iconAvatar,
              height: DesignTokens.iconAvatar,
              decoration: BoxDecoration(
                color: AppTheme.textTertiary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
            ),
            SizedBox(width: DesignTokens.space6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: DesignTokens.space7,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppTheme.textTertiary.withValues(alpha: 0.08),
                      borderRadius: DesignTokens.brSm,
                    ),
                  ),
                  SizedBox(height: DesignTokens.space4),
                  Container(
                    height: DesignTokens.space5,
                    width: DesignTokens.space64,
                    decoration: BoxDecoration(
                      color: AppTheme.textTertiary.withValues(alpha: 0.06),
                      borderRadius: DesignTokens.brSm,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: DesignTokens.space4),
            Container(
              height: DesignTokens.space8,
              width: DesignTokens.space32,
              decoration: BoxDecoration(
                color: AppTheme.textTertiary.withValues(alpha: 0.08),
                borderRadius: DesignTokens.brFull,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final hasSearch = _searchQuery.isNotEmpty;
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(DesignTokens.space8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: DesignTokens.space64,
              height: DesignTokens.space64,
              decoration: BoxDecoration(
                color: hasSearch
                    ? AppTheme.infoColor.withValues(alpha: 0.06)
                    : AppTheme.tertiaryColor.withValues(alpha: 0.06),
                shape: BoxShape.circle,
              ),
              child: Icon(
                hasSearch
                    ? Icons.search_off_rounded
                    : Icons.engineering_outlined,
                size: DesignTokens.iconLg,
                color: (hasSearch
                        ? AppTheme.infoColor
                        : AppTheme.textSecondary)
                    .withValues(alpha: 0.35),
              ),
            ),
            SizedBox(height: DesignTokens.space8),
            Text(
              hasSearch ? 'لا توجد نتائج للبحث' : 'لا يوجد مقدمي خدمة',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: DesignTokens.textBodyMedium,
                color: AppTheme.textPrimary,
              ),
            ),
            SizedBox(height: DesignTokens.space4),
            Text(
              hasSearch
                  ? 'حاول تغيير كلمات البحث'
                  : 'لم يتم تسجيل أي مقدم خدمة بعد',
              style: const TextStyle(
                fontSize: DesignTokens.textBodySmall,
                color: AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            if (hasSearch) ...[
              SizedBox(height: DesignTokens.space6),
              TextButton.icon(
                onPressed: () {
                  _searchController.clear();
                },
                icon: const Icon(Icons.refresh_rounded,
                    size: DesignTokens.iconSm),
                label: const Text('مسح البحث'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}