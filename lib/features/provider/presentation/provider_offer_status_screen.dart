import 'dart:async';
import '../../../core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/services/supabase_service.dart';
import 'provider_delivery_tracking_screen.dart';

enum OfferStatus { sent, waiting, accepted }

class ProviderOfferStatusScreen extends StatefulWidget {
  final String bookingId;
  final double offeredPrice;
  final String clientName;
  final String clientAddress;
  final String pickupAddress;
  final double distanceKm;
  final double totalDistanceKm;
  final String estimatedTime;
  final String totalEstimatedTime;

  const ProviderOfferStatusScreen({
    super.key,
    required this.bookingId,
    required this.offeredPrice,
    this.clientName = 'عميل',
    this.clientAddress = 'Al Gomhoureya',
    this.pickupAddress = 'المنيرة الحديثة، الطويرات،...',
    this.distanceKm = 4.1,
    this.totalDistanceKm = 11.1,
    this.estimatedTime = '11 دقيقة',
    this.totalEstimatedTime = '23 دقيقة',
  });

  @override
  State<ProviderOfferStatusScreen> createState() =>
      _ProviderOfferStatusScreenState();
}

class _ProviderOfferStatusScreenState extends State<ProviderOfferStatusScreen> {
  OfferStatus _status = OfferStatus.sent;
  StreamSubscription? _bookingSub;
  bool _isCancelling = false;

  @override
  void initState() {
    super.initState();
    _autoTransitionToWaiting();
    _listenForAcceptance();
  }

  void _autoTransitionToWaiting() {
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted && _status == OfferStatus.sent) {
        setState(() => _status = OfferStatus.waiting);
      }
    });
  }

  void _listenForAcceptance() {
    _bookingSub = SupabaseService.db
        .from('bookings')
        .stream(primaryKey: ['id'])
        .eq('id', widget.bookingId)
        .listen((data) {
      if (!mounted || data.isEmpty) return;
      final booking = data.first;
      final status = booking['price_offer_status']?.toString() ?? 'none';
      final bookingStatus = booking['status']?.toString() ?? 'pending';

      if (status == 'accepted' || bookingStatus == 'accepted') {
        setState(() => _status = OfferStatus.accepted);
        _bookingSub?.cancel();
      } else if (status == 'rejected' || bookingStatus == 'rejected') {
        _bookingSub?.cancel();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم رفض العرض من قبل العميل'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
          Navigator.pop(context);
        }
      }
    });
  }

  @override
  void dispose() {
    _bookingSub?.cancel();
    super.dispose();
  }

  Future<void> _cancelOffer() async {
    setState(() => _isCancelling = true);
    try {
      await SupabaseService.db.from('bookings').update({
        'offered_price': null,
        'offered_price_reason': null,
        'price_offer_status': 'none',
        'provider_id': null,
        'status': 'pending',
      }).eq('id', widget.bookingId);

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _isCancelling = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ: ${e.toString()}')),
        );
      }
    }
  }

  void _proceedToClient() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ProviderDeliveryTrackingScreen(bookingId: widget.bookingId),
      ),
    );
  }

  String _formatDistance(double km) {
    if (km < 1) return '${(km * 1000).toStringAsFixed(0)} م';
    return '${km.toStringAsFixed(1)} كم';
  }

  @override
  Widget build(BuildContext context) {
    switch (_status) {
      case OfferStatus.sent:
        return _buildSentScreen();
      case OfferStatus.waiting:
        return _buildWaitingScreen();
      case OfferStatus.accepted:
        return _buildAcceptedScreen();
    }
  }

  // ============================================================
  // SCREEN 4: Offer Sent (full cyan)
  // ============================================================
  Widget _buildSentScreen() {
    return Scaffold(
      backgroundColor: AppTheme.successColor,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.all(DesignTokens.space8.w),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.bolt_rounded, color: Colors.white, size: 22.sp),
                      SizedBox(width: 4.w),
                      Text('Faster',
                          style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 0.5)),
                    ],
                  ),
                  GestureDetector(
                    onTap: _cancelOffer,
                    child: Icon(Icons.close_rounded, color: Colors.white, size: 20.sp),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: DesignTokens.space8.w),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 88.sp,
                        height: 88.sp,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                                color: Colors.white.withValues(alpha: 0.3),
                                blurRadius: 30,
                                spreadRadius: 2),
                          ],
                        ),
                        child: Icon(Icons.check_rounded,
                            color: AppTheme.successColor, size: 40.sp),
                      ),
                      SizedBox(height: DesignTokens.space8.h),
                      Text('تم إرسال عرضك للعميل',
                          style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
                      SizedBox(height: DesignTokens.space2.h),
                      Text('بانتظار رد العميل',
                          style: TextStyle(
                              fontSize: 12.sp,
                              color: Colors.white.withValues(alpha: 0.8))),
                      SizedBox(height: DesignTokens.space8.h),
                      Text('${widget.offeredPrice.toStringAsFixed(0)} EGP',
                          style: TextStyle(
                              fontSize: 40.sp,
                              fontWeight: FontWeight.w900,
                              color: Colors.white)),
                      SizedBox(height: DesignTokens.space8.h),
                      Container(
                        padding: EdgeInsets.only(
                            bottom: DesignTokens.space6.h),
                        decoration: BoxDecoration(
                          border: Border(
                              bottom: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.2))),
                        ),
                        child: Column(
                          children: [
                            _buildRouteItem(
                                AppTheme.infoColor, widget.clientAddress),
                            SizedBox(height: DesignTokens.space4.h),
                            _buildRouteItem(
                                AppTheme.successColor, widget.pickupAddress),
                          ],
                        ),
                      ),
                      SizedBox(height: DesignTokens.space6.h),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatSmall('المسافة',
                              '${_formatDistance(widget.distanceKm)}- ${_formatDistance(widget.totalDistanceKm)}'),
                          _buildStatSmall('الوقت المتوقع',
                              '${widget.estimatedTime} ${widget.totalEstimatedTime}'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(DesignTokens.space8.w),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _isCancelling ? null : _cancelOffer,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.3)),
                    padding: EdgeInsets.symmetric(
                        vertical: DesignTokens.space5.h),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r)),
                  ),
                  child: _isCancelling
                      ? SizedBox(
                          width: 16.sp,
                          height: 16.sp,
                          child: const CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Text('إلغاء العرض',
                          style: TextStyle(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRouteItem(Color dotColor, String address) {
    return Row(
      children: [
        Container(
          width: 14.sp,
          height: 14.sp,
          decoration: BoxDecoration(
            color: dotColor,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
        ),
        SizedBox(width: DesignTokens.space3.w),
        Expanded(
          child: Text(address,
              style: TextStyle(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.white)),
        ),
      ],
    );
  }

  Widget _buildStatSmall(String label, String value) {
    return Column(
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 8.sp,
                color: Colors.white.withValues(alpha: 0.7))),
        SizedBox(height: DesignTokens.space1.h),
        Text(value,
            style: TextStyle(
                fontSize: 11.sp,
                fontWeight: FontWeight.bold,
                color: Colors.white)),
      ],
    );
  }

  // ============================================================
  // SCREEN 5: Waiting for Client (white)
  // ============================================================
  Widget _buildWaitingScreen() {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.fromLTRB(DesignTokens.space8.w,
                  DesignTokens.space6.h, DesignTokens.space8.w, DesignTokens.space4.h),
              decoration: const BoxDecoration(
                border: Border(
                    bottom: BorderSide(color: AppTheme.backgroundColor)),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black,
                      blurRadius: 4,
                      offset: Offset(0, 2)),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('بانتظار العميل',
                      style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.successColor)),
                  GestureDetector(
                    onTap: _cancelOffer,
                    child: Icon(Icons.close_rounded,
                        color: AppTheme.textTertiary, size: 20.sp),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: DesignTokens.space8.w, vertical: DesignTokens.space8.h),
                child: Column(
                  children: [
                    SizedBox(height: DesignTokens.space6.h),
                    Container(
                      width: 72.sp,
                      height: 72.sp,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: AppTheme.warningColor, width: 3),
                      ),
                      child:
                          Icon(Icons.access_time_rounded,
                              color: AppTheme.warningColor, size: 32.sp),
                    ),
                    SizedBox(height: DesignTokens.space6.h),
                    Text('عرضك قيد الانتظار',
                        style: TextStyle(
                            fontSize: 15.sp,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.warningColor)),
                    SizedBox(height: DesignTokens.space6.h),
                    Text('${widget.offeredPrice.toStringAsFixed(0)} EGP',
                        style: TextStyle(
                            fontSize: 32.sp,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.textPrimary)),
                    SizedBox(height: DesignTokens.space8.h),
                    Container(height: 1, color: AppTheme.backgroundColor),
                    SizedBox(height: DesignTokens.space6.h),
                    _buildLocationTimeline(),
                    SizedBox(height: DesignTokens.space6.h),
                    _buildStatsCard(),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(DesignTokens.space8.w),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: _isCancelling ? null : _cancelOffer,
                      child: Text('إلغاء العرض',
                          style: TextStyle(
                              fontSize: 12.sp,
                              color: AppTheme.errorColor,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
                  SizedBox(height: DesignTokens.space1.h),
                  Text('سيتم إلغاء العرض تلقائيا إذا لم يرد العميل',
                      style: TextStyle(
                          fontSize: 7.sp,
                          color: AppTheme.textTertiary)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationTimeline() {
    return Padding(
      padding: EdgeInsets.only(right: DesignTokens.space1.w),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                  width: 14.sp,
                  height: 14.sp,
                  decoration: BoxDecoration(
                      color: AppTheme.infoColor,
                      shape: BoxShape.circle)),
              SizedBox(width: DesignTokens.space3.w),
              Text(widget.clientAddress,
                  style: TextStyle(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textSecondary)),
            ],
          ),
          Container(
            height: 20.h,
            margin: EdgeInsets.only(right: 7.w),
            child: CustomPaint(
                size: const Size(2, 20),
                painter: _WaitingDottedLinePainter()),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                  width: 14.sp,
                  height: 14.sp,
                  decoration: BoxDecoration(
                      color: AppTheme.successColor,
                      shape: BoxShape.circle)),
              SizedBox(width: DesignTokens.space3.w),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.pickupAddress,
                      style: TextStyle(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textSecondary)),
                  Text('(At Towayrat, Qena)',
                      style: TextStyle(
                          fontSize: 8.sp,
                          color: AppTheme.textSecondary)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard() {
    return Container(
      padding: EdgeInsets.all(DesignTokens.space6.w),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor70,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppTheme.backgroundColor),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Column(
            children: [
              Text('المسافة',
                  style: TextStyle(
                      fontSize: 8.sp,
                      color: AppTheme.textTertiary,
                      fontWeight: FontWeight.bold)),
              SizedBox(height: DesignTokens.space1.h),
              Text(
                  '${_formatDistance(widget.distanceKm)}- ${_formatDistance(widget.totalDistanceKm)}',
                  style: TextStyle(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary)),
            ],
          ),
          Container(width: 1, height: 24.h, color: AppTheme.dividerColor),
          Column(
            children: [
              Text('الوقت المتوقع',
                  style: TextStyle(
                      fontSize: 8.sp,
                      color: AppTheme.textTertiary,
                      fontWeight: FontWeight.bold)),
              SizedBox(height: DesignTokens.space1.h),
              Text('${widget.estimatedTime} ${widget.totalEstimatedTime}',
                  style: TextStyle(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary)),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SCREEN 6: Offer Accepted (cyan top + white bottom)
  // ============================================================
  Widget _buildAcceptedScreen() {
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            flex: 4,
            child: Container(
              decoration: const BoxDecoration(color: AppTheme.successColor),
              child: SafeArea(
                child: Column(
                  children: [
                    Padding(
                      padding: EdgeInsets.fromLTRB(DesignTokens.space8.w,
                          DesignTokens.space4.h, DesignTokens.space8.w, 0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          GestureDetector(
                            onTap: _cancelOffer,
                            child: Icon(Icons.close_rounded,
                                color: Colors.white.withValues(alpha: 0.8),
                                size: 20.sp),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Container(
                      width: 72.sp,
                      height: 72.sp,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 12),
                        ],
                      ),
                      child: Icon(Icons.check_rounded,
                          color: AppTheme.successColor, size: 32.sp),
                    ),
                    SizedBox(height: DesignTokens.space4.h),
                    Text('تم قبول عرضك!',
                        style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
                    SizedBox(height: DesignTokens.space4.h),
                    Text('${widget.offeredPrice.toStringAsFixed(0)} EGP',
                        style: TextStyle(
                            fontSize: 36.sp,
                            fontWeight: FontWeight.w900,
                            color: Colors.white)),
                    SizedBox(height: DesignTokens.space6.h),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            flex: 6,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(32),
                    topRight: Radius.circular(32)),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black,
                      blurRadius: 20,
                      offset: Offset(0, -10)),
                ],
              ),
              child: SafeArea(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(DesignTokens.space8.w,
                      DesignTokens.space8.h, DesignTokens.space8.w, DesignTokens.space8.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLocationTimeline(),
                      SizedBox(height: DesignTokens.space6.h),
                      _buildStatsCard(),
                      const Spacer(),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _proceedToClient,
                          icon: Icon(Icons.near_me_rounded, size: 16.sp),
                          label: Text('التوجه إلى العميل',
                              style: TextStyle(
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.warningColor,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(
                                vertical: DesignTokens.space5.h),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12.r)),
                            elevation: 8,
                            shadowColor:
                                AppTheme.warningColor.withValues(alpha: 0.3),
                          ),
                        ),
                      ),
                      SizedBox(height: DesignTokens.space2.h),
                      Center(
                        child: TextButton(
                          onPressed: _cancelOffer,
                          child: Text('إلغاء الرحلة',
                              style: TextStyle(
                                  fontSize: 11.sp,
                                  color: AppTheme.errorColor,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
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

class _WaitingDottedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.borderColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    double y = 0;
    while (y < size.height) {
      final end = (y + 4).clamp(0, size.height);
      canvas.drawLine(Offset(0, y), Offset(0, end.toDouble()), paint);
      y += 8;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
