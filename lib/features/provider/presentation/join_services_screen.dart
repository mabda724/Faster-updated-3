import 'package:flutter/material.dart';
import 'package:flutter/material.dart' show IconData, Material, Icons, AnimatedBuilder, AnimationController;
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/services/supabase_service.dart';

class JoinServicesScreen extends StatefulWidget {
  final int categoryId;
  const JoinServicesScreen({super.key, required this.categoryId});

  @override
  State<JoinServicesScreen> createState() => _JoinServicesScreenState();
}

class _JoinServicesScreenState extends State<JoinServicesScreen>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _availableServices = [];
  List<int> _joinedServiceIds = [];
  bool _isLoading = true;
  String _categoryName = '';
  String _searchQuery = '';
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
    _load();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final uid = SupabaseService.currentUserId;
    if (uid == null) return;

    try {
      // Load category name
      final category = await SupabaseService.db
          .from('categories')
          .select('name_ar')
          .eq('id', widget.categoryId)
          .maybeSingle();
      _categoryName = category?['name_ar'] ?? 'تخصصك';

      // Load services for this category with booking counts
      final services = await SupabaseService.db
          .from('services')
          .select('*, categories(name_ar, name_en)')
          .eq('category_id', widget.categoryId)
          .eq('is_active', true)
          .order('created_at', ascending: false);

      // Load joined services
      final joined = await SupabaseService.db
          .from('provider_services')
          .select('service_id')
          .eq('provider_id', uid);

      // For each service, count how many providers are offering it
      final enrichedServices = <Map<String, dynamic>>[];
      for (final s in services) {
        final providerCount = await SupabaseService.db
            .from('provider_services')
            .select('provider_id')
            .eq('service_id', s['id']);

        final bookingCount = await SupabaseService.db
            .from('bookings')
            .select('id')
            .eq('service_id', s['id'].toString());

        enrichedServices.add({
          ...s,
          'provider_count': providerCount.length,
          'booking_count': bookingCount.length,
        });
      }

      if (mounted) {
        setState(() {
          _availableServices = enrichedServices;
          _joinedServiceIds =
              List<int>.from(joined.map((j) => j['service_id']));
          _isLoading = false;
        });
        _animController.reset();
        _animController.forward();
      }
    } catch (e) {
      debugPrint('Error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleService(int serviceId, bool currentlyJoined) async {
    final uid = SupabaseService.currentUserId;
    if (uid == null) return;

    try {
      if (currentlyJoined) {
        await SupabaseService.db
            .from('provider_services')
            .delete()
            .eq('provider_id', uid)
            .eq('service_id', serviceId);
        setState(() => _joinedServiceIds.remove(serviceId));
      } else {
        await SupabaseService.db.from('provider_services').insert({
          'provider_id': uid,
          'service_id': serviceId,
        });
        setState(() => _joinedServiceIds.add(serviceId));
      }

      if (mounted) {
        _showMessage(
          currentlyJoined ? 'تم إلغاء الانضمام للخدمة' : 'تم الانضمام للخدمة بنجاح',
          isError: currentlyJoined,
        );
      }
    } catch (e) {
      if (mounted) _showMessage('حدث خطأ: $e', isError: true);
    }
  }

  void _showMessage(String msg, {bool isError = false}) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        content: Text(msg),
        actions: [
          TextButton(
            isDefaultAction: true,
            isDestructiveAction: isError,
            child: const Text('حسنا'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  IconData _getServiceIcon(String name) {
    if (name.contains('تنظيف')) return Icons.auto_awesome_rounded;
    if (name.contains('كهرباء')) return Icons.bolt_rounded;
    if (name.contains('سباكة')) return Icons.water_drop_rounded;
    if (name.contains('صيانة')) return Icons.build_rounded;
    if (name.contains('نقل')) return Icons.inventory_rounded;
    if (name.contains('دهان')) return Icons.paint_rounded;
    if (name.contains('حشر')) return Icons.bug_report_rounded;
    if (name.contains('حدائق')) return Icons.forest_rounded;
    if (name.contains('تكييف')) return Icons.ac_unit_rounded;
    if (name.contains('نجار')) return Icons.build_rounded;
    return Icons.build_rounded;
  }

  List<Map<String, dynamic>> get _filteredServices {
    if (_searchQuery.isEmpty) return _availableServices;
    return _availableServices
        .where((s) =>
            (s['title'] ?? '').toString().contains(_searchQuery) ||
            (s['description'] ?? '').toString().contains(_searchQuery))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final joinedCount =
        _availableServices.where((s) => _joinedServiceIds.contains(s['id'])).length;

    return Scaffold(backgroundColor: AppTheme.backgroundColor, body: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _statBadge(Icons.list_alt_rounded, '${_availableServices.length}', 'خدمة متاحة'),
                        Container(width: 1, height: DesignTokens.space7 * 1.07, color: Colors.white.withValues(alpha: 0.3)),
                        _statBadge(Icons.check_circle_rounded, '$joinedCount', 'منضم إليها'),
                      ],
                    ),
                  ),
                  SizedBox(height: 12.h),
                  // Search bar
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: DesignTokens.space8),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: DesignTokens.brLg),
                    child: TextField(
                      onChanged: (v) => setState(() => _searchQuery = v),
                      decoration: InputDecoration(
                        hintText: 'ابحث عن خدمة...',
                        prefixIcon: Padding(padding: const EdgeInsets.only(left: DesignTokens.space8), child: Icon(Icons.search_rounded, color: AppTheme.textSecondary)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Services list
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredServices.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: EdgeInsets.all(20.w),
                          itemCount: _filteredServices.length,
                          itemBuilder: (context, index) {
                            final s = _filteredServices[index];
                            final isJoined = _joinedServiceIds.contains(s['id']);
                            return _buildServiceCard(s, isJoined, index);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statBadge(IconData icon, String value, String label) {
    return Row(
      children: [
        Icon(icon, color: Colors.white, size: DesignTokens.iconMd),
        SizedBox(width: 8.w),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: DesignTokens.textTitleSmall)),
            Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: DesignTokens.textLabelSmall)),
          ],
        ),
      ],
    );
  }

  Widget _buildServiceCard(
      Map<String, dynamic> service, bool isJoined, int index) {
    final title = service['title'] ?? '';
    final description = service['description'] ?? '';
    final price = service['price']?.toString() ?? '0';
    final providerCount = service['provider_count'] ?? 0;
    final bookingCount = service['booking_count'] ?? 0;
    final imageUrl = service['image_url'];

    return AnimatedBuilder(
      animation: _animController,
      builder: (context, child) {
        final delay = index * 0.06;
        final v = Curves.easeOutBack
            .transform((_animController.value - delay).clamp(0.0, 1.0));
        return Transform.translate(
          offset: Offset(0, 30 * (1 - v)),
          child: Opacity(opacity: v.clamp(0.0, 1.0), child: child),
        );
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 16.h),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isJoined
              ? AppTheme.primaryColor.withValues(alpha: 0.3)
              : Colors.transparent,
            width: isJoined ? 2 : 0,
          ),
          boxShadow: [
            BoxShadow(
              color: isJoined
                  ? AppTheme.primaryColor.withValues(alpha: 0.08)
                  : Colors.grey.withValues(alpha: 0.5),
              blurRadius: 15,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Service image/header
            if (imageUrl != null && imageUrl.toString().startsWith('http'))
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                child: Stack(
                  children: [
                    Image.network(
                      imageUrl,
                      height: 130.h,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      semanticLabel: 'صورة الخدمة',
                      errorBuilder: (_, __, ___) => _buildIconHeader(title),
                    ),
                    if (isJoined)
                      Positioned(
                        top: 12,
                        left: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppTheme.successColor,
                            borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_rounded, color: Colors.white, size: DesignTokens.iconSm),
                              SizedBox(width: DesignTokens.space4),
                              Text('منضم', style: TextStyle(color: Colors.white, fontSize: DesignTokens.textBodySmall, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              )
            else
              _buildIconHeader(title, isJoined: isJoined),

            // Service details
            Padding(
              padding: const EdgeInsets.all(DesignTokens.space16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontWeight: FontWeight.w600, fontSize: DesignTokens.textTitleMedium - 1, color: AppTheme.textPrimary)),
                  if (description.isNotEmpty) ...[
                    SizedBox(height: 6.h),
                    Text(description, style: TextStyle(fontSize: DesignTokens.textBodySmall, color: AppTheme.textSecondary), maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                  SizedBox(height: 12.h),
                  // Stats row
                  Row(
                    children: [
                      _infoChip(Icons.attach_money_rounded, '$price ج', AppTheme.primaryColor),
                      SizedBox(width: 12.w),
                      _infoChip(Icons.person_rounded_2, '$providerCount مقدم', AppTheme.primaryColor),
                      SizedBox(width: DesignTokens.space12),
                      _infoChip(Icons.shopping_bag_rounded, '$bookingCount طلب', AppTheme.tertiaryColor),
                    ],
                  ),
                  SizedBox(height: 16.h),
                  // Join/Leave button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: isJoined
                        ? ElevatedButton(
                            color: AppTheme.errorColor.withValues(alpha: 0.08),
                            onPressed: () => _toggleService(service['id'], isJoined),
                            borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.remove_circle_outline_rounded, size: DesignTokens.iconMd, color: AppTheme.errorColor),
                                const SizedBox(width: 6),
                                Text('إلغاء الانضمام', style: TextStyle(fontWeight: FontWeight.w600, fontSize: DesignTokens.textBodyMedium, color: AppTheme.errorColor)),
                              ],
                            ),
                          )
                        : ElevatedButton(
                            onPressed: () => _toggleService(service['id'], isJoined),
                            borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_circle_rounded, size: DesignTokens.iconMd),
                                const SizedBox(width: 6),
                                Text('انضم لتقديم هذه الخدمة', style: TextStyle(fontWeight: FontWeight.w600, fontSize: DesignTokens.textBodyMedium)),
                              ],
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIconHeader(String title, {bool isJoined = false}) {
    return Container(
      height: 80.h,
      decoration: BoxDecoration(
        color: isJoined ? AppTheme.primaryColor.withValues(alpha: 0.1) : AppTheme.textSecondary.withValues(alpha: 0.08),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(_getServiceIcon(title), color: isJoined ? AppTheme.primaryColor : AppTheme.textSecondary, size: DesignTokens.iconLg),
            if (isJoined) ...[
              SizedBox(width: 8.w),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: DesignTokens.space10, vertical: DesignTokens.space5),
                decoration: BoxDecoration(color: AppTheme.successColor, borderRadius: BorderRadius.circular(DesignTokens.radiusMd)),
                child: Text('منضم', style: TextStyle(color: Colors.white, fontSize: DesignTokens.textBodySmall, fontWeight: FontWeight.w600)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String text, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: DesignTokens.space10, vertical: DesignTokens.space5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: DesignTokens.iconSm, color: color),
          SizedBox(width: DesignTokens.space4),
          Text(text,
              style: TextStyle(
                  fontSize: DesignTokens.textBodySmall, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_rounded, size: DesignTokens.iconDoctorAvatar, color: AppTheme.textTertiary),
          SizedBox(height: DesignTokens.space16),
          Text('لا توجد خدمات مضافة في تخصصك حالياً',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: DesignTokens.textTitleSmall, fontWeight: FontWeight.w600)),
          SizedBox(height: DesignTokens.space8),
          Text('سيتم إضافة خدمات جديدة قريباً',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: DesignTokens.textBodySmall)),
        ],
      ),
    );
  }
}
