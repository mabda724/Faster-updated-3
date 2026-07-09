import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/location_service.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';

import '../../../core/widgets/notification_badge.dart';
import 'provider_orders_screen.dart';
import 'provider_trip_history_screen.dart';
import 'provider_requests_map_screen.dart';
import 'provider_order_detail_screen.dart';
import 'provider_wallet_screen.dart';
import 'provider_dashboard_controller.dart';

class ProviderDashboardScreen extends StatefulWidget {
  const ProviderDashboardScreen({super.key});
  @override
  State<ProviderDashboardScreen> createState() =>
      _ProviderDashboardScreenState();
}

class _ProviderDashboardScreenState extends State<ProviderDashboardScreen> {
  static const Color _providerPrimary = AppTheme.primaryColor;
  static const Color _accentYellow = AppTheme.warningColor;
  static const Color _accentGreen = AppTheme.successColor;

  int _totalOrders = 0, _pendingOrders = 0, _completedOrders = 0;
  double _walletBalance = 0, _rating = 0;
  String _name = '';
  bool _isLoading = true;
  bool _isOnline = false;
  bool _isBanned = false;
  String _docStatus = 'pending';
  int _daysSinceReg = 0;
  List<String> _portfolioImages = [];
  bool _needsProfessionUpdate = false;
  String? _categoryId;
  String? _referralCode;
  int _matchingRequestCount = 0;
  StreamSubscription? _requestsSub;
  Timer? _requestCheckTimer;
  StreamSubscription? _settlementsSub;
  double _completedCashServices = 0;
  double _totalCommissionCalculated = 0;
  double _settledAmount = 0;
  XFile? _proofImage;
  bool _isSettling = false;

  late ProviderDashboardController _controller;
  String? _providerType;
  int _totalProducts = 0;
  int _totalStock = 0;
  double _totalSales = 0;
  int _totalTrips = 0;
  double _totalKilometers = 0;

  Map<String, dynamic>? _firstMatchingRequest;
  double _dailyEarnings = 0;
  int _dailyOrders = 0;
  double _acceptanceRate = 0;
  List<double> _weeklyEarnings = List.filled(7, 0);

  @override
  void initState() {
    super.initState();
    _controller = ProviderDashboardController();
    _controller.load();
  }

  @override
  void dispose() {
    _controller.dispose();
    _requestsSub?.cancel();
    _requestCheckTimer?.cancel();
    _settlementsSub?.cancel();
    super.dispose();
  }

  void _listenForNewRequests() {
    _requestsSub = SupabaseService.db
        .from('bookings')
        .stream(primaryKey: ['id'])
        .eq('status', 'pending')
        .listen((data) {
      if (mounted && _isOnline) {
        _checkMatchingRequestCount();
      }
    });
  }

  void _startRequestCheckTimer() {
    _requestCheckTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_isOnline) _checkMatchingRequestCount();
    });
  }

  void _listenForSettlementUpdates() {
    final uid = SupabaseService.currentUserId;
    if (uid == null) return;
    _settlementsSub = SupabaseService.db
        .from('commission_settlements')
        .stream(primaryKey: ['id'])
        .eq('provider_id', uid)
        .listen((data) async {
      if (mounted && data.any((s) => s['status'] == 'verified')) {
        try {
          final verifiedSettlements = await SupabaseService.db
              .from('commission_settlements')
              .select('amount')
              .eq('provider_id', uid)
              .eq('status', 'verified');

          double totalVerified = 0;
          for (var s in (verifiedSettlements as List)) {
            totalVerified +=
                double.tryParse(s['amount']?.toString() ?? '0') ?? 0;
          }

          await SupabaseService.db.from('provider_profiles').update({
            'settled_amount': totalVerified,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          }).eq('id', uid);
        } catch (e) {
          debugPrint('Error updating settled_amount: $e');
        }
        _load();
      }
    });
  }

  Future<void> _checkMatchingRequestCount() async {
    try {
      final uid = SupabaseService.currentUserId;
      if (uid == null || _categoryId == null) return;

      final result = await SupabaseService.db.rpc(
        'find_matching_requests_for_provider',
        params: {'p_provider_id': uid},
      );
      final count = (result as List).length;
      if (count > _matchingRequestCount && count > 0 && mounted) {
        _showRequestNotification(count);
      }
      if (count > 0 && mounted) {
        _firstMatchingRequest = (result as List).first;
      } else {
        _firstMatchingRequest = null;
      }
      if (mounted) setState(() => _matchingRequestCount = count);
    } catch (e) {
      debugPrint('Error checking matching requests: $e');
    }
  }

  void _showRequestNotification(int count) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.notifications_rounded, color: Colors.white),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                '$count طلب جديد متاح ضمن تخصصك ونطاقك!',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        backgroundColor: _providerPrimary,
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'عرض',
          textColor: Colors.white,
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ProviderOrdersScreen()),
          ),
        ),
      ),
    );
  }

  Future<void> _load() async {
    final uid = SupabaseService.currentUserId;
    if (uid == null) return;
    try {
      final profile = await SupabaseService.db
          .from('profiles')
          .select('full_name, banned_at, avatar_url')
          .eq('id', uid)
          .single();
      _name = profile['full_name'] ?? '';
      _isBanned = profile['banned_at'] != null;

      final pp = await _ensureProviderProfile(uid);
      if (pp != null) {
        _walletBalance =
            double.tryParse(pp['wallet_balance']?.toString() ?? '0') ?? 0;
        _rating = double.tryParse(pp['rating']?.toString() ?? '0') ?? 0;
        _isOnline = pp['is_online'] == true;
        _docStatus = pp['document_verification_status'] ?? 'pending';
        _portfolioImages = List<String>.from(pp['portfolio_images'] ?? []);
        final regDateStr = pp['created_at'];
        if (regDateStr != null) {
          try {
            final regDate = DateTime.parse(regDateStr);
            _daysSinceReg = DateTime.now().difference(regDate).inDays;
          } catch (e) {
            debugPrint('Error parsing registration date: $e');
          }
        }
        _categoryId = pp['category_id']?.toString();
        _needsProfessionUpdate = _categoryId == null;
        _settledAmount =
            double.tryParse(pp['settled_amount']?.toString() ?? '0') ?? 0;
        _providerType = pp['provider_type'] as String?;
      }

      await _loadProviderTypeStats(uid);

      try {
        final bookings = await SupabaseService.db
            .from('bookings')
            .select('id, status')
            .eq('provider_id', uid);
        _totalOrders = bookings.length;
        _pendingOrders = bookings
            .where((b) =>
                b['status'] == 'pending' ||
                b['status'] == 'accepted' ||
                b['status'] == 'on_the_way' ||
                b['status'] == 'arrived' ||
                b['status'] == 'in_progress')
            .length;
        _completedOrders =
            bookings.where((b) => b['status'] == 'completed').length;
      } catch (e) {
        debugPrint('Error loading bookings stats: $e');
      }

      try {
        final cashBookingsRes = await SupabaseService.db
            .from('bookings')
            .select('total_price, commission_amount, offered_price, created_at')
            .eq('provider_id', uid)
            .eq('status', 'completed');

        double totalCashPrice = 0;
        double totalComm = 0;
        double dailyCash = 0;
        int dailyCount = 0;
        final today = DateTime.now();
        final todayStart = DateTime(today.year, today.month, today.day);

        for (var b in (cashBookingsRes as List)) {
          final price = double.tryParse(
                  (b['offered_price'] ?? b['total_price'])?.toString() ??
                      '0') ??
              0;
          final comm =
              double.tryParse(b['commission_amount']?.toString() ?? '0') ?? 0;
          totalCashPrice += price;
          totalComm += comm;

          final createdAt = b['created_at']?.toString();
          if (createdAt != null) {
            try {
              final bDate = DateTime.parse(createdAt);
              if (bDate.isAfter(todayStart)) {
                dailyCash += price;
                dailyCount++;
              }
            } catch (_) {}
          }
        }

      _completedCashServices = totalCashPrice;
      _totalCommissionCalculated = totalComm;
      _dailyEarnings = dailyCash;
      _dailyOrders = dailyCount;

      _weeklyEarnings = List.filled(7, 0);
      final now = DateTime.now();
      final weekStart = now.subtract(Duration(days: now.weekday % 7));
      for (var b in (cashBookingsRes as List)) {
        final price = double.tryParse(
            (b['offered_price'] ?? b['total_price'])?.toString() ?? '0') ?? 0;
        final createdAt = b['created_at']?.toString();
        if (createdAt != null) {
          try {
            final bDate = DateTime.parse(createdAt);
            if (bDate.isAfter(weekStart.subtract(const Duration(days: 1)))) {
              final dayIndex = bDate.weekday % 7;
              _weeklyEarnings[dayIndex] += price;
            }
          } catch (_) {}
        }
      }
      } catch (e) {
        debugPrint('Error loading cash stats: $e');
      }

      if (_totalOrders > 0) {
        _acceptanceRate = ((_totalOrders - _pendingOrders) / _totalOrders) * 100;
      }

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Dashboard load error: $e');
      if (mounted) setState(() => _isLoading = false);
    }

    _loadReferralCode();
    _checkWalletThreshold();
    _loadFirstMatchingRequest();
  }

  Future<void> _loadFirstMatchingRequest() async {
    try {
      final uid = SupabaseService.currentUserId;
      if (uid == null || _categoryId == null) return;
      final result = await SupabaseService.db.rpc(
        'find_matching_requests_for_provider',
        params: {'p_provider_id': uid},
      ) as List;
      if (result.isNotEmpty && mounted) {
        setState(() {
          _matchingRequestCount = result.length;
          _firstMatchingRequest = result.first;
        });
      }
    } catch (e) {
      debugPrint('Error loading first request: $e');
    }
  }

  Future<void> _loadReferralCode() async {
    try {
      final uid = SupabaseService.currentUserId;
      if (uid == null) return;
      final ref = await SupabaseService.db
          .from('referral_codes')
          .select('code, promo_value, uses_count')
          .eq('user_id', uid)
          .maybeSingle();
      if (ref != null && mounted) {
        setState(() => _referralCode = ref['code']?.toString());
      }
    } catch (e) {
      debugPrint('Error loading referral code: $e');
    }
  }

  Future<void> _loadProviderTypeStats(String uid) async {
    try {
      switch (_providerType) {
        case 'merchant':
          final products = await SupabaseService.db
              .from('products')
              .select('stock, price')
              .eq('provider_id', uid);
          _totalProducts = products.length;
          _totalStock = products.fold<int>(
              0, (sum, p) => sum + (p['stock'] as int? ?? 0));
          _totalSales = products.fold<double>(
              0, (sum, p) => sum + (p['price'] as num? ?? 0).toDouble());
          break;
        case 'driver':
          final trips = await SupabaseService.db
              .from('bookings')
              .select('distance_km')
              .eq('provider_id', uid)
              .eq('status', 'completed');
          _totalTrips = trips.length;
          _totalKilometers = trips.fold<double>(
              0, (sum, t) => sum + (t['distance_km'] as num? ?? 0).toDouble());
          break;
        case 'handyman':
          break;
        default:
          break;
      }
    } catch (e) {
      debugPrint('Error loading provider type stats: $e');
    }
  }

  Future<void> _checkWalletThreshold() async {
    try {
      final setting = await SupabaseService.db
          .from('app_settings')
          .select('value')
          .eq('key', 'wallet_auto_offline_threshold')
          .maybeSingle();
      if (setting == null) return;
      final enabled = setting['value']?['enabled'] ?? false;
      if (!enabled) return;
      final threshold = (setting['value']?['value'] as num?)?.toDouble() ?? -50;

      if (_walletBalance <= threshold && _isOnline) {
        await SupabaseService.db.from('provider_profiles').update(
            {'is_online': false}).eq('id', SupabaseService.currentUserId!);
        if (mounted) {
          setState(() => _isOnline = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text('تم إيقاف الاستقبال تلقائياً بسبب رصيد المحفظة ($threshold ج)'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error checking wallet threshold: $e');
    }
  }

  Future<Map<String, dynamic>?> _ensureProviderProfile(String uid) async {
    try {
      var pp = await SupabaseService.db
          .from('provider_profiles')
          .select('''
            id, profession, rating, wallet_balance, is_online,
            category_id, city, is_banned,
            document_verification_status, portfolio_images,
            created_at, search_radius_km, settled_amount,
            provider_type
          ''')
          .eq('id', uid)
          .maybeSingle();

      if (pp == null) {
        await SupabaseService.db.from('provider_profiles').insert({'id': uid});
        pp = await SupabaseService.db
            .from('provider_profiles')
            .select('''
              id, profession, rating, wallet_balance, is_online,
              category_id, city, is_banned,
              document_verification_status, portfolio_images,
              created_at, search_radius_km, settled_amount,
              provider_type
            ''')
            .eq('id', uid)
            .single();
      }
      return pp;
    } catch (e) {
      debugPrint('Error ensuring provider profile: $e');
      return null;
    }
  }

  Future<void> _toggleOnline(bool val) async {
    final uid = SupabaseService.currentUserId;
    if (uid == null) return;
    if (_needsProfessionUpdate && val) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى تحديث بيانات تخصصك أولاً')),
      );
      return;
    }

    if (val && !kIsWeb) {
      bool has = await LocationService.handleLocationPermission();
      if (!has) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('صلاحية الوصول للموقع مطلوبة')),
        );
        return;
      }
    }

    setState(() => _isOnline = val);
    await SupabaseService.db
        .from('provider_profiles')
        .update({'is_online': val}).eq('id', uid!);
  }

  Future<void> _loadMore() async {}

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildTopBar(),
              _buildProfileCard(),
              _buildSummaryCard(),
              _buildEarningsCard(),
              SizedBox(height: DesignTokens.space4.h),
              _buildStatsRow(),
              _buildStartButton(),
              _buildWeeklyChart(),
              SizedBox(height: DesignTokens.space8.h),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // TOP BAR
  // ============================================================
  Widget _buildTopBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        DesignTokens.space8.w,
        DesignTokens.space4.h,
        DesignTokens.space8.w,
        DesignTokens.space2.h,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () {},
            child: Icon(Icons.menu_rounded, color: AppTheme.darkSurfaceColor, size: 22.sp),
          ),
          Row(
            children: [
              Icon(Icons.bolt_rounded, color: AppTheme.successColor, size: 22.sp),
              SizedBox(width: DesignTokens.space1.w),
              Text(
                'Faster',
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.darkBackgroundColor,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          Stack(
            children: [
              Icon(Icons.notifications_outlined, color: AppTheme.textSecondary, size: 22.sp),
              if (_matchingRequestCount > 0)
                Positioned(
                  top: 2.sp,
                  right: 2.sp,
                  child: Container(
                    width: 8.sp,
                    height: 8.sp,
                    decoration: const BoxDecoration(
                      color: AppTheme.errorColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // PROFILE CARD
  // ============================================================
  Widget _buildProfileCard() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: DesignTokens.space8.w),
      padding: EdgeInsets.all(DesignTokens.space8.w),
      decoration: BoxDecoration(
        color: AppTheme.textPrimary,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52.sp,
            height: 52.sp,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppTheme.warningColor,
                width: 2.5,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.network(
              'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&q=80&w=150',
              width: double.infinity,
              height: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: AppTheme.textSecondary,
                child: Icon(Icons.person_rounded, color: Colors.white, size: 26.sp),
              ),
            ),
          ),
          SizedBox(width: DesignTokens.space4.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _name,
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 2.h),
                Row(
                  children: [
                    Icon(Icons.star_rounded, color: AppTheme.warningColor, size: 12.sp),
                    SizedBox(width: 2.w),
                    Text(
                      _rating.toStringAsFixed(1),
                      style: TextStyle(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.warningColor,
                      ),
                    ),
                    SizedBox(width: DesignTokens.space2.w),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 6.w,
                        vertical: 2.h,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.successColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4.r),
                      ),
                      child: Text(
                        'كابتن فاستر',
                        style: TextStyle(
                          fontSize: 8.sp,
                          color: AppTheme.successColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            children: [
              Icon(Icons.directions_car_rounded, color: AppTheme.textSecondary, size: 20.sp),
              SizedBox(height: 2.h),
              Text(
                'س ج ب 2578',
                style: TextStyle(
                  fontSize: 7.sp,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SUMMARY CARD — total orders, rating, earnings, completed
  // ============================================================
  Widget _buildSummaryCard() {
    return Container(
      margin: EdgeInsets.fromLTRB(
        DesignTokens.space8.w,
        DesignTokens.space5.h,
        DesignTokens.space8.w,
        0,
      ),
      padding: EdgeInsets.symmetric(vertical: DesignTokens.space6.h, horizontal: DesignTokens.space6.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(DesignTokens.radiusLg.r),
        border: Border.all(color: AppTheme.dividerColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          _summaryItem(Icons.shopping_bag_rounded, '$_totalOrders', 'إجمالي الطلبات', AppTheme.primaryColor),
          _summaryDivider(),
          _summaryItem(Icons.check_circle_rounded, '$_completedOrders', 'مكتملة', AppTheme.successColor),
          _summaryDivider(),
          _summaryItem(Icons.star_rounded, _rating.toStringAsFixed(1), 'التقييم', AppTheme.warningColor),
          _summaryDivider(),
          _summaryItem(Icons.monetization_on_rounded, '${_completedCashServices.toStringAsFixed(0)} ج', 'الأرباح', AppTheme.primaryColor),
        ],
      ),
    );
  }

  Widget _summaryItem(IconData icon, String value, String label, Color color) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 20.sp),
          SizedBox(height: DesignTokens.space1.h),
          Text(
            value,
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          SizedBox(height: 1.h),
          Text(
            label,
            style: TextStyle(
              fontSize: 9.sp,
              color: AppTheme.textTertiary,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _summaryDivider() {
    return Container(
      width: 1,
      height: 40.h,
      color: AppTheme.dividerColor,
    );
  }

  // ============================================================
  // EARNINGS CARD
  // ============================================================
  Widget _buildEarningsCard() {
    return Container(
      margin: EdgeInsets.fromLTRB(
        DesignTokens.space8.w,
        DesignTokens.space5.h,
        DesignTokens.space8.w,
        0,
      ),
      padding: EdgeInsets.all(DesignTokens.space8.w),
      decoration: BoxDecoration(
        color: AppTheme.successColor,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: AppTheme.successColor.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'أرباح اليوم',
                style: TextStyle(
                  fontSize: 10.sp,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: DesignTokens.space3.w,
                  vertical: 2.h,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  children: [
                    Icon(Icons.trending_up_rounded, color: Colors.white, size: 10.sp),
                    SizedBox(width: 2.w),
                    Text(
                      '+15%',
                      style: TextStyle(
                        fontSize: 9.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: DesignTokens.space3.h),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _dailyEarnings.toStringAsFixed(0),
                style: TextStyle(
                  fontSize: 28.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(width: DesignTokens.space2.w),
              Padding(
                padding: EdgeInsets.only(bottom: 4.h),
                child: Text(
                  'جنيه',
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: DesignTokens.space1.h),
          Text(
            '$_dailyOrders طلبات',
            style: TextStyle(
              fontSize: 9.sp,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // STATS ROW
  // ============================================================
  Widget _buildStatsRow() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: DesignTokens.space8.w),
      child: Row(
        children: [
          _buildStatTile('الرحلات', '$_completedOrders', Icons.route_rounded),
          SizedBox(width: DesignTokens.space4.w),
          _buildStatTile('معدل القبول', '${_acceptanceRate.toStringAsFixed(0)}%', Icons.check_circle_rounded),
          SizedBox(width: DesignTokens.space4.w),
          _buildStatTile('التقييم', _rating.toStringAsFixed(1), Icons.star_rounded),
        ],
      ),
    );
  }

  Widget _buildStatTile(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(DesignTokens.space6.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: AppTheme.successColor, size: 16.sp),
            SizedBox(height: DesignTokens.space2.h),
            Text(
              value,
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.bold,
                color: AppTheme.darkSurfaceColor,
              ),
            ),
            SizedBox(height: 2.h),
            Text(
              label,
              style: TextStyle(
                fontSize: 8.sp,
                color: AppTheme.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // START RECEIVING BUTTON
  // ============================================================
  Widget _buildStartButton() {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        DesignTokens.space8.w,
        DesignTokens.space6.h,
        DesignTokens.space8.w,
        0,
      ),
      child: SizedBox(
        width: double.infinity,
        height: 44.sp,
        child: ElevatedButton(
          onPressed: () => _toggleOnline(!_isOnline),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.warningColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.r),
            ),
            elevation: 0,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _isOnline ? Icons.pause_rounded : Icons.play_arrow_rounded,
                size: 18.sp,
              ),
              SizedBox(width: DesignTokens.space2.w),
              Text(
                _isOnline ? 'إيقاف استقبال الطلبات' : 'بدء استقبال الطلبات',
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // WEEKLY PERFORMANCE CHART
  // ============================================================
  Widget _buildWeeklyChart() {
    const dayNames = ['الأحد', 'الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت'];
    final maxVal = _weeklyEarnings.reduce((a, b) => a > b ? a : b);
    const maxBarHeight = 80.0;

    return Container(
      margin: EdgeInsets.all(DesignTokens.space8.w),
      padding: EdgeInsets.all(DesignTokens.space8.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'أداء هذا الأسبوع',
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.darkSurfaceColor,
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const ProviderTripHistoryScreen()),
                ),
                child: Text(
                  'تاريخ الرحلات',

                  style: TextStyle(
                    fontSize: 9.sp,
                    color: AppTheme.successColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: DesignTokens.space6.h),
          SizedBox(
            height: maxBarHeight.h + 24.h,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (i) {
                final val = _weeklyEarnings[i];
                final barH = maxVal > 0 ? (val / maxVal) * maxBarHeight : 0.0;
                return Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        height: barH.h,
                        width: 20.sp,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppTheme.successColor, AppTheme.successColor],
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                          ),
                          borderRadius: BorderRadius.circular(4.r),
                        ),
                      ),
                      SizedBox(height: DesignTokens.space2.h),
                      Text(
                        dayNames[i].substring(0, 2),
                        style: TextStyle(
                          fontSize: 7.sp,
                          color: AppTheme.textTertiary,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}
