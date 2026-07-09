import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/document_deadline_service.dart';
import 'delivery_history_screen.dart';

class DeliveryDashboardScreen extends StatefulWidget {
  const DeliveryDashboardScreen({super.key});
  @override
  State<DeliveryDashboardScreen> createState() => _DeliveryDashboardScreenState();
}

class _DeliveryDashboardScreenState extends State<DeliveryDashboardScreen> {
  String _name = '';
  bool _isLoading = true;
  bool _isOnline = false;
  int _todayDeliveries = 0;
  double _totalEarnings = 0;
  double _rating = 0;
  int _totalDeliveries = 0;
  Map<String, dynamic>? _activeDelivery;
  StreamSubscription? _ordersSub;

  @override
  void initState() {
    super.initState();
    _load();
    _listenForOrders();
  }

  @override
  void dispose() {
    _ordersSub?.cancel();
    super.dispose();
  }

  void _listenForOrders() {
    final uid = SupabaseService.currentUserId;
    if (uid == null) return;
    _ordersSub = SupabaseService.db
        .from('bookings')
        .stream(primaryKey: ['id'])
        .eq('delivery_provider_id', uid ?? '')
        .listen((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    final uid = SupabaseService.currentUserId;
    if (uid == null) return;
    try {
      final profile = await SupabaseService.db
          .from('profiles')
          .select('full_name')
          .eq('id', uid)
          .single();
      _name = profile['full_name'] ?? '';

      final pp = await SupabaseService.db
          .from('provider_profiles')
          .select('is_online, rating')
          .eq('id', uid)
          .maybeSingle();
      if (pp != null) {
        _isOnline = pp['is_online'] == true;
        _rating = double.tryParse(pp['rating']?.toString() ?? '0') ?? 0;
      }

      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day).toUtc().toIso8601String();
      final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59).toUtc().toIso8601String();

      _todayDeliveries = 0;
      _totalDeliveries = 0;
      _totalEarnings = 0;

      try {
        final todayBookings = await SupabaseService.db
            .from('bookings')
            .select('id, total_price')
            .or('provider_id.eq.$uid,delivery_provider_id.eq.$uid')
            .eq('status', 'completed')
            .gte('created_at', todayStart)
            .lte('created_at', todayEnd);
        _todayDeliveries = todayBookings.length;
      } catch (e) {
        debugPrint('Error loading today deliveries: $e');
      }

      try {
        final completedBookings = await SupabaseService.db
            .from('bookings')
            .select('id, total_price')
            .or('provider_id.eq.$uid,delivery_provider_id.eq.$uid')
            .eq('status', 'completed');
        _totalDeliveries = completedBookings.length;
        for (var b in (completedBookings as List)) {
          final price = double.tryParse(b['total_price']?.toString() ?? '0') ?? 0;
          _totalEarnings += price;
        }
      } catch (e) {
        debugPrint('Error loading total earnings: $e');
      }

      try {
        final active = await SupabaseService.db
            .from('bookings')
            .select('*, services(name_ar), profiles!bookings_client_id_fkey(full_name)')
            .or('provider_id.eq.$uid,delivery_provider_id.eq.$uid')
            .inFilter('status', ['accepted', 'on_the_way', 'arrived', 'in_progress', 'ready_for_pickup'])
            .order('created_at', ascending: false)
            .limit(1)
            .maybeSingle();
        _activeDelivery = active;
      } catch (e) {
        debugPrint('Error loading active delivery: $e');
      }

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Dashboard load error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleOnline(bool value) async {
    final uid = SupabaseService.currentUserId;
    if (uid == null) return;
    setState(() => _isOnline = value);
    try {
      await SupabaseService.db.from('provider_profiles').update({
        'is_online': value,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', uid);
    } catch (e) {
      debugPrint('Error toggling online: $e');
    }
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'صباح الخير';
    if (hour < 18) return 'مساء الخير';
    return 'مساء الخير';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
            : RefreshIndicator(
                onRefresh: _load,
                color: AppTheme.primaryColor,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    children: [
                      _buildHeader(),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20.w),
                        child: Column(
                          children: [
                            SizedBox(height: 20.h),
                            _buildStatsGrid(),
                            SizedBox(height: 20.h),
                            if (_activeDelivery != null) ...[
                              _buildActiveDeliveryCard(),
                              SizedBox(height: 20.h),
                            ],
                            _buildQuickActions(),
                            SizedBox(height: 24.h),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(24.w, 20.h, 24.w, 32.h),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.darkBackgroundColor, AppTheme.darkSurfaceColor, AppTheme.primaryColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_greeting()}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: DesignTokens.textBodyMedium,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      '$_name 👋',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: DesignTokens.textTitleLarge,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              _buildOnlineToggle(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOnlineToggle() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: _isOnline
            ? AppTheme.successColor.withValues(alpha: 0.2)
            : Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _isOnline
              ? AppTheme.successColor.withValues(alpha: 0.5)
              : Colors.white.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8.w,
            height: 8.h,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _isOnline ? AppTheme.successColor : Colors.white.withValues(alpha: 0.5),
            ),
          ),
          SizedBox(width: 8.w),
          Text(
            _isOnline ? 'متاح' : 'غير متاح',
            style: TextStyle(
              color: Colors.white,
              fontSize: DesignTokens.textLabelMedium,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(width: 8.w),
          Switch.adaptive(
            value: _isOnline,
            activeTrackColor: AppTheme.successColor,
            inactiveTrackColor: Colors.white.withValues(alpha: 0.2),
            onChanged: _toggleOnline,
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12.w,
      mainAxisSpacing: 12.h,
      childAspectRatio: 1.5,
      children: [
        _buildStatCard(
          'توصيلات اليوم',
          '$_todayDeliveries',
          Icons.local_shipping_rounded,
          AppTheme.infoColor,
        ),
        _buildStatCard(
          'إجمالي الأرباح',
          '${_totalEarnings.toStringAsFixed(0)} ج.م',
          Icons.account_balance_wallet_rounded,
          AppTheme.successColor,
        ),
        _buildStatCard(
          'تقييم العملاء',
          '${_rating.toStringAsFixed(1)} ⭐',
          Icons.star_rounded,
          AppTheme.tertiaryColor,
        ),
        _buildStatCard(
          'عدد التوصيلات',
          '$_totalDeliveries',
          Icons.receipt_long_rounded,
          AppTheme.primaryColor,
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(DesignTokens.space12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: DesignTokens.brLg,
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: DesignTokens.shadow1(Colors.black),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(DesignTokens.space4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: DesignTokens.brSm,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          SizedBox(height: 8.h),
          Text(
            value,
            style: TextStyle(
              fontSize: DesignTokens.textTitleMedium,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: 2.h),
          Text(
            label,
            style: TextStyle(
              fontSize: DesignTokens.textLabelSmall,
              color: AppTheme.textSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildActiveDeliveryCard() {
    final booking = _activeDelivery!;
    final service = booking['services'] as Map<String, dynamic>?;
    final client = booking['profiles'] as Map<String, dynamic>?;
    final status = booking['status'] as String? ?? '';
    final address = booking['address'] as String? ?? '';
    final totalPrice = double.tryParse(booking['total_price']?.toString() ?? '0') ?? 0;

    Color statusColor;
    String statusText;
    switch (status) {
      case 'accepted':
        statusColor = AppTheme.tertiaryColor;
        statusText = 'مقبول';
        break;
      case 'on_the_way':
        statusColor = AppTheme.infoColor;
        statusText = 'في الطريق';
        break;
      case 'arrived':
        statusColor = AppTheme.primaryColor;
        statusText = 'وصل';
        break;
      case 'in_progress':
        statusColor = AppTheme.successColor;
        statusText = 'جاري التنفيذ';
        break;
      default:
        statusColor = AppTheme.textSecondary;
        statusText = status;
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(DesignTokens.space16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: DesignTokens.brLg,
        border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.2)),
        boxShadow: DesignTokens.shadow2(Colors.black),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'توصيل نشط',
                style: TextStyle(
                  fontSize: DesignTokens.textTitleMedium,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: DesignTokens.brFull,
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    fontSize: DesignTokens.textLabelSmall,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          _buildDeliveryInfoRow(Icons.person_rounded, 'العميل', client?['full_name'] ?? ''),
          SizedBox(height: 8.h),
          _buildDeliveryInfoRow(Icons.location_on_rounded, 'العنوان', address),
          SizedBox(height: 8.h),
          _buildDeliveryInfoRow(Icons.local_offer_rounded, 'الخدمة', service?['name_ar'] ?? ''),
          SizedBox(height: 12.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'أجرة التوصيل',
                style: TextStyle(
                  fontSize: DesignTokens.textBodyMedium,
                  color: AppTheme.textSecondary,
                ),
              ),
              Text(
                '${totalPrice.toStringAsFixed(0)} ج.م',
                style: TextStyle(
                  fontSize: DesignTokens.textTitleMedium,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.successColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.textSecondary),
        SizedBox(width: 8.w),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: DesignTokens.textBodySmall,
            color: AppTheme.textSecondary,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: DesignTokens.textBodySmall,
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'إجراءات سريعة',
          style: TextStyle(
            fontSize: DesignTokens.textTitleMedium,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        SizedBox(height: 12.h),
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                'عرض الطلبات',
                Icons.receipt_long_rounded,
                AppTheme.infoColor,
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: _buildActionCard(
                'الخريطة',
                Icons.map_rounded,
                AppTheme.primaryColor,
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: _buildActionCard(
                'المحفظة',
                Icons.account_balance_wallet_rounded,
                AppTheme.successColor,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard(String label, IconData icon, Color color) {
    return GestureDetector(
      onTap: () {
        // Parent nav screen handles tab switching
      },
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 16.h),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: DesignTokens.brLg,
          border: Border.all(color: Colors.grey.shade100),
          boxShadow: DesignTokens.shadow1(Colors.black),
        ),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(DesignTokens.space8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            SizedBox(height: 8.h),
            Text(
              label,
              style: TextStyle(
                fontSize: DesignTokens.textLabelMedium,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
