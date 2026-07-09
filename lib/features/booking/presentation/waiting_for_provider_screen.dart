import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/services/supabase_service.dart';
import 'tracking_screen.dart';
import 'negotiation_screen.dart';
import '../../home/presentation/main_nav_screen.dart';

class WaitingForProviderScreen extends StatefulWidget {
  final String bookingId;
  final String serviceName;
  final double totalPrice;

  const WaitingForProviderScreen({
    super.key,
    required this.bookingId,
    required this.serviceName,
    required this.totalPrice,
  });

  @override
  State<WaitingForProviderScreen> createState() =>
      _WaitingForProviderScreenState();
}

class _WaitingForProviderScreenState extends State<WaitingForProviderScreen> {
  List<Map<String, dynamic>> _offers = [];
  bool _isLoading = true;
  bool _isCancelled = false;
  StreamSubscription? _offersSub;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadOffers();
    _listenForOffers();
    _startRefreshTimer();
  }

  Future<void> _loadOffers() async {
    try {
      final offers = await SupabaseService.db
          .from('bookings')
          .select('''
            id, provider_id, status, offered_price, offered_price_reason,
            provider_profiles!inner(
              id, profession, rating,
              profiles!inner(full_name, avatar_url, phone, is_verified)
            )
          ''')
          .eq('id', widget.bookingId)
          .not('provider_id', 'is', null)
          .single();

      if (offers['provider_id'] != null && mounted) {
        final providerData = await SupabaseService.db
            .from('provider_profiles')
            .select('''
              id, profession, rating,
              profiles!inner(full_name, avatar_url, phone, is_verified)
            ''')
            .eq('id', offers['provider_id'])
            .maybeSingle();

        if (providerData != null && mounted) {
          setState(() {
            _offers = [
              {
                'provider_id': offers['provider_id'],
                'offered_price':
                    offers['offered_price'] ?? widget.totalPrice,
                'offered_price_reason': offers['offered_price_reason'],
                'provider': providerData,
              }
            ];
          });
        }
      } else {
        final allOffers = await SupabaseService.db.rpc(
            'get_booking_offers',
            params: {'p_booking_id': widget.bookingId});
        if (mounted) {
          setState(() {
            _offers = List<Map<String, dynamic>>.from(allOffers ?? []);
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading offers: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  void _listenForOffers() {
    _offersSub = SupabaseService.db
        .from('bookings')
        .stream(primaryKey: ['id'])
        .eq('id', widget.bookingId)
        .listen((data) {
      if (data.isNotEmpty && mounted) {
        final booking = data.first;
        if (booking['provider_id'] != null &&
            booking['status'] == 'accepted') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  TrackingScreen(bookingId: widget.bookingId),
            ),
          );
        }
        if (booking['status'] == 'cancelled' && mounted) {
          setState(() => _isCancelled = true);
        }
        if (booking['provider_id'] != null &&
            booking['status'] == 'pending') {
          _loadOffers();
        }
      }
    });
  }

  void _startRefreshTimer() {
    _refreshTimer =
        Timer.periodic(const Duration(seconds: 15), (_) {
      if (!_isCancelled) _loadOffers();
    });
  }

  void _openNegotiation() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NegotiationScreen(
          bookingId: widget.bookingId,
          serviceName: widget.serviceName,
          totalPrice: widget.totalPrice,
          offers: _offers,
        ),
      ),
    );
  }

  Future<void> _acceptOffer(Map<String, dynamic> offer) async {
    try {
      final offeredPrice =
          offer['offered_price'] ?? widget.totalPrice;
      await SupabaseService.db
          .from('bookings')
          .update({
            'provider_id': offer['provider_id'],
            'status': 'accepted',
            'total_price': offeredPrice,
            'commission_amount': (offeredPrice * 0.1),
            'commission_rate': 0.1,
            'updated_at':
                DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', widget.bookingId);

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) =>
                TrackingScreen(bookingId: widget.bookingId),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error accepting offer: $e');
    }
  }

  void _showCancelDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: DesignTokens.br2xl,
        ),
        title: const Text(
          'إلغاء الطلب',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        content: const Text(
          'هل أنت متأكد من رغبتك في إلغاء البحث عن فني؟',
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 13,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'تراجع',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              _isCancelled = true;
              try {
                await SupabaseService.db
                    .from('bookings')
                    .update({
                      'status': 'cancelled',
                      'cancelled_by':
                          SupabaseService.currentUserId,
                      'cancelled_at':
                          DateTime.now().toIso8601String(),
                    })
                    .eq('id', widget.bookingId);
              } catch (_) {}
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const MainNavScreen()),
                  (route) => false,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                    DesignTokens.radiusSm.r),
              ),
            ),
            child: const Text(
              'إلغاء الطلب',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _offersSub?.cancel();
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: Stack(
                children: [
                  _buildMapBackground(),
                  SingleChildScrollView(
                    child: Column(
                      children: [
                        SizedBox(height: 100.h),
                        _buildSearchingCard(),
                        if (_offers.isNotEmpty) ...[
                          SizedBox(height: DesignTokens.space4.h),
                          _buildNewOffersBanner(),
                        ],
                        SizedBox(height: DesignTokens.space4.h),
                        _buildOrderDetailsCard(),
                      ],
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

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        DesignTokens.space8.w,
        DesignTokens.space6.h,
        DesignTokens.space8.w,
        DesignTokens.space4.h,
      ),
      decoration: const BoxDecoration(
        color: Colors.transparent,
        border: Border(
          bottom: BorderSide(color: AppTheme.surfaceColor70, width: 1),
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: _showCancelDialog,
            child: Container(
              width: 32.sp,
              height: 32.sp,
              alignment: Alignment.center,
              child: Icon(
                Icons.chevron_right_rounded,
                color: AppTheme.textPrimary,
                size: 20.sp,
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                'البحث عن فني',
                style: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.darkSurfaceColor,
                ),
              ),
            ),
          ),
          SizedBox(width: 32.sp),
        ],
      ),
    );
  }

  Widget _buildMapBackground() {
    return Container(
      color: AppTheme.backgroundColor,
      child: Stack(
        children: [
          // Decorative white lines
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Container(
              width: 24.sp,
              color: Colors.white.withValues(alpha: 0.7),
              transform: Matrix4.rotationZ(-0.2),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 24.sp,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
          // Radar animation
          Center(
            child: SizedBox(
              width: 120.sp,
              height: 120.sp,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  _buildRadarCircle(96.sp, 0.2, 2),
                  _buildRadarCircle(96.sp, 0.1, 1),
                  Container(
                    width: 40.sp,
                    height: 40.sp,
                    decoration: BoxDecoration(
                      color: AppTheme.darkBackgroundColor,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white,
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.person_pin_circle_rounded,
                      color: AppTheme.warningColor,
                      size: 18.sp,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRadarCircle(double size, double opacity, int delayMs) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppTheme.primaryColor.withValues(alpha: opacity),
      ),
    );
  }

  Widget _buildSearchingCard() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: DesignTokens.space8.w),
      padding: EdgeInsets.all(DesignTokens.space6.w),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(DesignTokens.radiusLg.r),
        border: Border.all(color: AppTheme.backgroundColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 16.sp,
                height: 16.sp,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppTheme.darkBackgroundColor,
                ),
              ),
              SizedBox(width: DesignTokens.space2.w),
              Text(
                'جاري البحث عن أقرب فني...',
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          SizedBox(height: DesignTokens.space2.h),
          Text(
            'نبحث لك عن فني "${widget.serviceName}" متاح بالقرب من موقعك الحالي',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10.sp,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNewOffersBanner() {
    return GestureDetector(
      onTap: _openNegotiation,
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: DesignTokens.space8.w),
        padding: EdgeInsets.all(DesignTokens.space6.w),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppTheme.primaryColor, AppTheme.darkBackgroundColor],
            begin: Alignment.centerRight,
            end: Alignment.centerLeft,
          ),
          borderRadius: BorderRadius.circular(DesignTokens.radiusLg.r),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryColor.withValues(alpha: 0.3),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(DesignTokens.space3.w),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(DesignTokens.radiusMd.r),
              ),
              child: Icon(
                Icons.assignment_rounded,
                color: Colors.white,
                size: 20.sp,
              ),
            ),
            SizedBox(width: DesignTokens.space4.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'تلقيت (${_offers.length}) عروض جديدة',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13.sp,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'اختر مقدم الخدمة المناسب لك',
                    style: TextStyle(
                      fontSize: 10.sp,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: DesignTokens.space4.w,
                vertical: DesignTokens.space2.h,
              ),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(DesignTokens.radiusSm.r),
              ),
              child: Row(
                children: [
                  Text(
                    'عرض العروض',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(width: DesignTokens.space1.w),
                  Icon(
                    Icons.chevron_left_rounded,
                    color: Colors.white,
                    size: 14.sp,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderDetailsCard() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: DesignTokens.space8.w),
      padding: EdgeInsets.all(DesignTokens.space6.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(DesignTokens.radiusLg.r),
        border: Border.all(color: AppTheme.backgroundColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Service info row
          Row(
            children: [
              Container(
                width: 32.sp,
                height: 32.sp,
                decoration: BoxDecoration(
                  color: AppTheme.dividerColor,
                  borderRadius:
                      BorderRadius.circular(DesignTokens.radiusMd.r),
                ),
                child: Icon(
                  Icons.water_drop_rounded,
                  color: AppTheme.infoColor,
                  size: 16.sp,
                ),
              ),
              SizedBox(width: DesignTokens.space3.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'طلب خدمة ${widget.serviceName}',
                      style: TextStyle(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      'شارع السياحة، الغردقة',
                      style: TextStyle(
                        fontSize: 9.sp,
                        color: AppTheme.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: DesignTokens.space4.w,
                  vertical: DesignTokens.space1.h,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceColor,
                  borderRadius:
                      BorderRadius.circular(DesignTokens.radiusSm.r),
                ),
                child: Text(
                  'في الانتظار',
                  style: TextStyle(
                    fontSize: 9.sp,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.errorColor,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: DesignTokens.space4.h),
          // Time and payment grid
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: EdgeInsets.all(DesignTokens.space4.w),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceColor70,
                    borderRadius:
                        BorderRadius.circular(DesignTokens.radiusMd.r),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'الوقت المختار',
                        style: TextStyle(
                          fontSize: 8.sp,
                          color: AppTheme.textTertiary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        'الآن',
                        style: TextStyle(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(width: DesignTokens.space2.w),
              Expanded(
                child: Container(
                  padding: EdgeInsets.all(DesignTokens.space4.w),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceColor70,
                    borderRadius:
                        BorderRadius.circular(DesignTokens.radiusMd.r),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'طريقة الدفع',
                        style: TextStyle(
                          fontSize: 8.sp,
                          color: AppTheme.textTertiary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        'نقداً (كاش)',
                        style: TextStyle(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: DesignTokens.space4.h),
          // Cancel button
          GestureDetector(
            onTap: _showCancelDialog,
            child: Container(
              width: double.infinity,
              padding:
                  EdgeInsets.symmetric(vertical: DesignTokens.space3.h),
              decoration: BoxDecoration(
                color: AppTheme.backgroundColor,
                borderRadius:
                    BorderRadius.circular(DesignTokens.radiusMd.r),
              ),
              child: Center(
                child: Text(
                  'إلغاء الطلب',
                  style: TextStyle(
                    color: AppTheme.errorColor,
                    fontSize: 11.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

}
