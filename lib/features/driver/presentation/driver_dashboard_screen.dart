import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/location_service.dart';
import '../../../core/widgets/notification_badge.dart';
import 'driver_active_ride_screen.dart';
import 'driver_history_screen.dart';
import '../../../features/provider/presentation/provider_wallet_screen.dart';
import '../../../features/provider/presentation/provider_orders_screen.dart';
import '../../../features/provider/presentation/provider_profile_screen.dart';

class DriverDashboardScreen extends StatefulWidget {
  const DriverDashboardScreen({super.key});
  @override
  State<DriverDashboardScreen> createState() => _DriverDashboardScreenState();
}

class _DriverDashboardScreenState extends State<DriverDashboardScreen> {
  String _name = '';
  bool _isLoading = true;
  bool _isOnline = false;
  double _walletBalance = 0;
  double _todayEarnings = 0;
  int _todayTrips = 0;
  int _totalTrips = 0;
  double _rating = 0;
  int _totalReviews = 0;
  Map<String, dynamic>? _activeRide;
  StreamSubscription? _bookingsSub;

  @override
  void initState() {
    super.initState();
    _load();
    _listenForActiveRide();
  }

  @override
  void dispose() {
    _bookingsSub?.cancel();
    super.dispose();
  }

  void _listenForActiveRide() {
    final uid = SupabaseService.currentUserId;
    if (uid == null) return;
    _bookingsSub = SupabaseService.db
        .from('bookings')
        .stream(primaryKey: ['id'])
        .eq('provider_id', uid)
        .listen((data) {
          final activeStatuses = {'accepted', 'on_the_way', 'arrived', 'in_progress'};
          final filtered = data.where((row) => activeStatuses.contains(row['status'])).toList();
          if (filtered.isNotEmpty && mounted) {
            setState(() => _activeRide = filtered.first);
          } else if (mounted) {
            setState(() => _activeRide = null);
          }
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
          .select('wallet_balance, is_online, rating')
          .eq('id', uid)
          .maybeSingle();
      if (pp != null) {
        _walletBalance =
            double.tryParse(pp['wallet_balance']?.toString() ?? '0') ?? 0;
        _isOnline = pp['is_online'] == true;
        _rating = double.tryParse(pp['rating']?.toString() ?? '0') ?? 0;
      }

      // Today's earnings & trips
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day).toUtc().toIso8601String();
      try {
        final todayBookings = await SupabaseService.db
            .from('bookings')
            .select('total_price, commission_amount, offered_price')
            .eq('provider_id', uid)
            .eq('status', 'completed')
            .gte('created_at', todayStart);
        _todayTrips = todayBookings.length;
        _todayEarnings = 0;
        for (var b in (todayBookings as List)) {
          final price = double.tryParse(
                  (b['offered_price'] ?? b['total_price'])?.toString() ?? '0') ??
              0;
          final comm =
              double.tryParse(b['commission_amount']?.toString() ?? '0') ?? 0;
          _todayEarnings += (price - comm);
        }
      } catch (e) {
        debugPrint('Error loading today stats: $e');
      }

      // Total trips & rating
      try {
        final allBookings = await SupabaseService.db
            .from('bookings')
            .select('id')
            .eq('provider_id', uid)
            .eq('status', 'completed');
        _totalTrips = allBookings.length;
      } catch (e) {
        debugPrint('Error loading total trips: $e');
      }

      // Reviews count
      try {
        final reviews = await SupabaseService.db
            .from('reviews')
            .select('id')
            .eq('provider_id', uid);
        _totalReviews = reviews.length;
      } catch (e) {
        debugPrint('Error loading reviews: $e');
      }

      // Active ride
      try {
        final active = await SupabaseService.db
            .from('bookings')
            .select('*, profiles(full_name, phone)')
            .eq('provider_id', uid)
            .inFilter('status', ['accepted', 'on_the_way', 'arrived', 'in_progress'])
            .order('created_at', ascending: false)
            .limit(1)
            .maybeSingle();
        if (active != null && mounted) {
          setState(() => _activeRide = active);
        }
      } catch (e) {
        debugPrint('Error loading active ride: $e');
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
      if (value) {
        await LocationService.startTracking();
      } else {
        await LocationService.stopTracking();
      }
    } catch (e) {
      debugPrint('Error toggling online: $e');
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'accepted':
        return 'مقبول';
      case 'on_the_way':
        return 'في الطريق';
      case 'arrived':
        return 'وصل';
      case 'in_progress':
        return 'جاري التنفيذ';
      default:
        return status;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'accepted':
        return AppTheme.primaryColor;
      case 'on_the_way':
        return AppTheme.infoColor;
      case 'arrived':
        return AppTheme.tertiaryColor;
      case 'in_progress':
        return AppTheme.successColor;
      default:
        return AppTheme.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppTheme.primaryColor))
            : RefreshIndicator(
                onRefresh: _load,
                color: AppTheme.primaryColor,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(),
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: DesignTokens.space14.w,
                          vertical: DesignTokens.space8.h,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_activeRide != null) ...[
                              _buildActiveRideCard(),
                              SizedBox(height: DesignTokens.space10.h),
                            ],
                            _buildStatsGrid(),
                            SizedBox(height: DesignTokens.space10.h),
                            _buildQuickActions(),
                            SizedBox(height: DesignTokens.space10.h),
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
      padding: EdgeInsets.fromLTRB(
        DesignTokens.space14.w,
        DesignTokens.space10.h + MediaQuery.of(context).padding.top,
        DesignTokens.space14.w,
        DesignTokens.space12.h,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.darkBackgroundColor, AppTheme.darkSurfaceColor, AppTheme.primaryColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'مرحباً، $_name',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: DesignTokens.textBodyLarge,
                    ),
                  ),
                  SizedBox(height: DesignTokens.space1.h),
                  const Text(
                    'لوحة تحكم السائق',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: DesignTokens.textDisplayLarge,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  const NotificationBell(iconColor: Colors.white, iconSize: 28),
                  SizedBox(width: DesignTokens.space8.w),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: DesignTokens.space5,
                      vertical: DesignTokens.space3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: DesignTokens.brMd,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star_rounded, color: Colors.amber, size: 18),
                        SizedBox(width: DesignTokens.space1.w),
                        Text(
                          _rating.toStringAsFixed(1),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: DesignTokens.textBodyLarge,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: DesignTokens.space10.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _isOnline ? 'متاح للرحلات' : 'غير متاح',
                style: TextStyle(
                  color: _isOnline ? AppTheme.successColor : Colors.white.withValues(alpha: 0.5),
                  fontWeight: FontWeight.bold,
                  fontSize: DesignTokens.textBodyLarge,
                ),
              ),
              Switch.adaptive(
                value: _isOnline,
                activeTrackColor: AppTheme.successColor,
                onChanged: _toggleOnline,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActiveRideCard() {
    final ride = _activeRide!;
    final clientProfile = ride['profiles'];
    final clientName = clientProfile is Map ? (clientProfile['full_name'] ?? 'عميل') : 'عميل';
    final status = ride['status'] ?? '';
    final pickup = ride['pickup_address'] ?? 'نقطة الانطلاق';
    final destination = ride['destination_address'] ?? 'الوجهة';
    final price = double.tryParse(
            (ride['offered_price'] ?? ride['total_price'])?.toString() ?? '0') ??
        0;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DriverActiveRideScreen(booking: ride),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(DesignTokens.space8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: DesignTokens.brLg,
          border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryColor.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(DesignTokens.space3),
                  decoration: BoxDecoration(
                    color: _statusColor(status).withValues(alpha: 0.1),
                    borderRadius: DesignTokens.brSm,
                  ),
                  child: Icon(Icons.directions_car_rounded,
                      color: _statusColor(status), size: DesignTokens.iconSm),
                ),
                SizedBox(width: DesignTokens.space4.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(clientName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: DesignTokens.textBodyLarge,
                          )),
                      Text(_statusLabel(status),
                          style: TextStyle(
                            color: _statusColor(status),
                            fontWeight: FontWeight.bold,
                            fontSize: DesignTokens.textBodySmall,
                          )),
                    ],
                  ),
                ),
                Text(
                  '${price.toStringAsFixed(0)} ج.م',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: DesignTokens.textTitleLarge,
                    color: AppTheme.successColor,
                  ),
                ),
              ],
            ),
            SizedBox(height: DesignTokens.space6.h),
            _buildRouteInfo(Icons.circle, pickup, AppTheme.successColor),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: DesignTokens.space4),
              child: Container(width: 1, height: 16, color: AppTheme.textSecondary.withValues(alpha: 0.3)),
            ),
            _buildRouteInfo(Icons.location_on, destination, AppTheme.errorColor),
            SizedBox(height: DesignTokens.space6.h),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DriverActiveRideScreen(booking: ride),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  shape: RoundedRectangleBorder(borderRadius: DesignTokens.brMd),
                  padding: const EdgeInsets.symmetric(vertical: DesignTokens.space5),
                ),
                child: const Text('عرض التفاصيل',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    )),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRouteInfo(IconData icon, String text, Color color) {
    return Row(
      children: [
        Icon(icon, size: 12, color: color),
        SizedBox(width: DesignTokens.space3.w),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: DesignTokens.textBodyMedium,
              color: AppTheme.textSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildStatsGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: DesignTokens.space4.w,
      mainAxisSpacing: DesignTokens.space4.h,
      childAspectRatio: 1.6,
      children: [
        _buildStatCard(
          'رحلات اليوم',
          '$_todayTrips',
          Icons.today_rounded,
          AppTheme.primaryColor,
        ),
        _buildStatCard(
          'إجمالي الأرباح',
          '${_todayEarnings.toStringAsFixed(0)} ج.م',
          Icons.account_balance_wallet_rounded,
          AppTheme.successColor,
        ),
        _buildStatCard(
          'تقييم العملاء',
          '${_rating.toStringAsFixed(1)}',
          Icons.star_rounded,
          AppTheme.tertiaryColor,
        ),
        _buildStatCard(
          'عدد الرحلات',
          '$_totalTrips',
          Icons.route_rounded,
          AppTheme.infoColor,
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(DesignTokens.space6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: DesignTokens.brLg,
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(DesignTokens.space3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: DesignTokens.brSm,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          SizedBox(height: DesignTokens.space4.h),
          Text(
            value,
            style: TextStyle(
              fontSize: DesignTokens.textTitleLarge,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          SizedBox(height: DesignTokens.space1.h),
          Text(
            label,
            style: TextStyle(
              fontSize: DesignTokens.textLabelSmall,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'إجراءات سريعة',
          style: TextStyle(
            fontSize: DesignTokens.textTitleMedium,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        SizedBox(height: DesignTokens.space6.h),
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                'عرض الطلبات',
                Icons.receipt_long_rounded,
                AppTheme.primaryColor,
                () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ProviderOrdersScreen()),
                ),
              ),
            ),
            SizedBox(width: DesignTokens.space4.w),
            Expanded(
              child: _buildActionCard(
                'الخريطة',
                Icons.map_rounded,
                AppTheme.successColor,
                () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ProviderOrdersScreen()),
                ),
              ),
            ),
            SizedBox(width: DesignTokens.space4.w),
            Expanded(
              child: _buildActionCard(
                'المحفظة',
                Icons.account_balance_wallet_rounded,
                AppTheme.tertiaryColor,
                () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ProviderWalletScreen()),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard(
      String label, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: DesignTokens.space8,
          horizontal: DesignTokens.space4,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: DesignTokens.brLg,
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(DesignTokens.space4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            SizedBox(height: DesignTokens.space4.h),
            Text(
              label,
              style: TextStyle(
                fontSize: DesignTokens.textLabelMedium,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
