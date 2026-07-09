import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/notification_service.dart';
import 'provider_delivery_tracking_screen.dart';
import 'provider_offer_status_screen.dart';

class ProviderNewRequestScreen extends StatefulWidget {
  final Map<String, dynamic> booking;
  const ProviderNewRequestScreen({super.key, required this.booking});
  @override
  State<ProviderNewRequestScreen> createState() =>
      _ProviderNewRequestScreenState();
}

class _ProviderNewRequestScreenState extends State<ProviderNewRequestScreen> {
  Map<String, dynamic> get _booking => widget.booking;
  bool _isUpdating = false;
  int _countdownSeconds = 45;
  Timer? _countdownTimer;
  bool _isExpired = false;
  bool _showPriceScreen = false;
  double _offerPrice = 123;
  final TextEditingController _noteController = TextEditingController();

  String get _orderNumber =>
      '#${_booking['id']?.toString().padLeft(5, '0') ?? '12567'}';

  double get _totalPrice {
    return double.tryParse(
          _booking['total_price']?.toString() ??
              _booking['price']?.toString() ??
              '0',
        ) ??
        0;
  }

  double get _clientPrice {
    return double.tryParse(
          _booking['client_price']?.toString() ??
              _booking['total_price']?.toString() ??
              '0',
        ) ??
        0;
  }

  String get _serviceName =>
      _booking['services']?['title'] ?? _booking['service_title'] ?? 'خدمة';
  String get _clientName =>
      _booking['profiles']?['full_name'] ??
      _booking['client_name'] ??
      'عميل';
  String get _clientAddress =>
      _booking['client_address']?.toString() ?? 'Al Gomhoureya';
  String get _pickupAddress =>
      _booking['pickup_address']?.toString() ?? 'المنيرة الحديثة، الطويرات،...';
  String get _pickupName =>
      _booking['pickup_name']?.toString() ?? 'موقع الانطلاق';
  double get _distanceKm =>
      double.tryParse(_booking['distance_km']?.toString() ?? '') ?? 4.1;
  double get _totalDistanceKm =>
      double.tryParse(_booking['total_distance_km']?.toString() ?? '') ??
      11.1;
  String get _estimatedTime =>
      _booking['estimated_time']?.toString() ?? '11 دقيقة';
  String get _totalEstimatedTime =>
      _booking['total_estimated_time']?.toString() ?? '23 دقيقة';
  String get _notes =>
      _booking['notes']?.toString() ??
      _booking['client_notes']?.toString() ??
      '';

  @override
  void initState() {
    super.initState();
    _offerPrice = _clientPrice > 0 ? _clientPrice + 23 : 123;
    _startCountdown();
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdownSeconds <= 0) {
        timer.cancel();
        if (mounted) setState(() => _isExpired = true);
        return;
      }
      if (mounted) setState(() => _countdownSeconds--);
    });
  }

  String get _countdownText => '$_countdownSeconds ثانية';

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _noteController.dispose();
    super.dispose();
  }

  void _updatePrice(double amount) {
    setState(() {
      _offerPrice += amount;
      if (_offerPrice < _clientPrice) _offerPrice = _clientPrice;
    });
  }

  Future<void> _acceptOrder() async {
    setState(() => _isUpdating = true);
    try {
      final bookingId = _booking['id'];
      final currentUserId = SupabaseService.currentUserId;
      if (currentUserId == null) throw 'يجب تسجيل الدخول أولاً';

      final activeOrders = await SupabaseService.db
          .from('bookings')
          .select('id, status, services(title)')
          .eq('provider_id', currentUserId)
          .inFilter(
              'status', ['accepted', 'on_the_way', 'arrived', 'in_progress'])
          .limit(1);

      if (activeOrders.isNotEmpty) {
        final active = activeOrders.first;
        final serviceTitle = active['services']?['title'] ?? 'خدمة';
        if (mounted) {
          setState(() => _isUpdating = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'لديك طلب نشط بالفعل ($serviceTitle). أكمله أولاً قبل قبول طلب جديد.'),
              backgroundColor: AppTheme.errorColor,
              duration: const Duration(seconds: 4),
            ),
          );
        }
        return;
      }

      final bool accepted = await SupabaseService.db.rpc(
          'accept_broadcast_booking',
          params: {
            'p_booking_id': bookingId,
            'p_provider_id': currentUserId,
          });

      if (!accepted) {
        final check = await SupabaseService.db
            .from('bookings')
            .select('provider_id')
            .eq('id', bookingId)
            .maybeSingle();

        if (check?['provider_id'] != currentUserId) {
          if (mounted) {
            setState(() => _isUpdating = false);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('تم قبول الطلب من قبل مقدم آخر')),
            );
          }
          return;
        }
      }

      final clientId = _booking['client_id']?.toString();
      final serviceName = _serviceName;
      if (clientId != null) {
        try {
          await NotificationService.sendPushNotification(
            userId: clientId,
            title: 'تم قبول طلبك',
            body: 'قام مقدم الخدمة بقبول طلب $serviceName',
            type: 'new_booking',
            data: {
              'booking_id': bookingId.toString(),
              'status': 'accepted',
              'service_name': serviceName,
            },
          );
        } catch (e) {
          debugPrint('FCM notification error: $e');
        }
      }

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) =>
                ProviderDeliveryTrackingScreen(bookingId: bookingId.toString()),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUpdating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ: ${e.toString()}')),
        );
      }
    }
  }

  void _rejectOrder() {
    Navigator.pop(context);
  }

  Future<void> _sendPriceOffer() async {
    setState(() => _isUpdating = true);
    try {
      final bookingId = _booking['id'];
      final currentUserId = SupabaseService.currentUserId;
      if (currentUserId == null) throw 'يجب تسجيل الدخول أولاً';

      if (_offerPrice <= _clientPrice) {
        await _acceptOrder();
        return;
      }

      final result = await SupabaseService.db.rpc(
        'provider_offer_price',
        params: {
          'p_booking_id': bookingId,
          'p_provider_id': currentUserId,
          'p_offered_price': _offerPrice,
          'p_reason': _noteController.text.isNotEmpty
              ? _noteController.text
              : null,
        },
      );

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ProviderOfferStatusScreen(
              bookingId: bookingId.toString(),
              offeredPrice: _offerPrice,
              clientName: _clientName,
              clientAddress: _clientAddress,
              pickupAddress: _pickupAddress,
              distanceKm: _distanceKm,
              totalDistanceKm: _totalDistanceKm,
              estimatedTime: _estimatedTime,
              totalEstimatedTime: _totalEstimatedTime,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUpdating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ: ${e.toString()}')),
        );
      }
    }
  }

  String _formatDistance(double km) {
    if (km < 1) return '${(km * 1000).toStringAsFixed(0)} م';
    return '${km.toStringAsFixed(1)} كم';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: _buildMapArea()),
            _buildBottomSheet(),
          ],
        ),
      ),
    );
  }

  Widget _buildMapArea() {
    return Stack(
      children: [
        Container(
          color: AppTheme.backgroundColor,
          child: CustomPaint(
            painter: _DashedRoutePainter(),
            size: Size.infinite,
          ),
        ),
        Positioned(
          top: 180.h,
          right: 100.w,
          child: Column(
            children: [
              Container(
                padding: EdgeInsets.symmetric(
                    horizontal: DesignTokens.space3.w,
                    vertical: DesignTokens.space1.h),
                decoration: BoxDecoration(
                  color: AppTheme.dividerColor,
                  borderRadius: BorderRadius.circular(8.r),
                  border: Border.all(color: AppTheme.accentColor),
                ),
                child: Text(
                  '$_estimatedTime\n${_formatDistance(_distanceKm)}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 8.sp,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                    height: 1.3,
                  ),
                ),
              ),
              SizedBox(height: 4.h),
              Container(
                width: 22.sp,
                height: 22.sp,
                decoration: BoxDecoration(
                  color: AppTheme.infoColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 4),
                  ],
                ),
                child: Center(
                  child: Text('A',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 9.sp,
                          fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
        Positioned(
          top: 520.h,
          left: 120.w,
          child: Column(
            children: [
              Container(
                padding: EdgeInsets.symmetric(
                    horizontal: DesignTokens.space3.w,
                    vertical: DesignTokens.space1.h),
                decoration: BoxDecoration(
                  color: AppTheme.dividerColor,
                  borderRadius: BorderRadius.circular(8.r),
                  border: Border.all(color: AppTheme.dividerColor),
                ),
                child: Text(
                  '$_totalEstimatedTime\n${_formatDistance(_totalDistanceKm)}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 8.sp,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.darkSurfaceColor,
                    height: 1.3,
                  ),
                ),
              ),
              SizedBox(height: 4.h),
              Container(
                width: 22.sp,
                height: 22.sp,
                decoration: BoxDecoration(
                  color: AppTheme.successColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 4),
                  ],
                ),
                child: Center(
                  child: Text('B',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 9.sp,
                          fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: EdgeInsets.fromLTRB(
                DesignTokens.space8.w, DesignTokens.space6.h, DesignTokens.space8.w, DesignTokens.space4.h),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.surfaceColor, AppTheme.surfaceColor],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _showPriceScreen ? 'تحديد سعرك' : 'طلب ركوب جديد',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                GestureDetector(
                  onTap: _rejectOrder,
                  child: Container(
                    width: 32.sp,
                    height: 32.sp,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 8),
                      ],
                    ),
                    child: Icon(Icons.close_rounded,
                        color: AppTheme.errorColor, size: 16.sp),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomSheet() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(32.r),
          topRight: Radius.circular(32.r),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 25,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48.sp,
            height: 6.sp,
            margin: EdgeInsets.only(top: DesignTokens.space3.h),
            decoration: BoxDecoration(
              color: AppTheme.dividerColor,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          if (_showPriceScreen) _buildPriceContent() else _buildRequestContent(),
        ],
      ),
    );
  }

  Widget _buildRequestContent() {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          DesignTokens.space8.w, DesignTokens.space6.h, DesignTokens.space8.w, DesignTokens.space8.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildLocationPoints(),
          SizedBox(height: DesignTokens.space6.h),
          Container(height: 1, color: AppTheme.backgroundColor),
          SizedBox(height: DesignTokens.space6.h),
          Row(
            children: [
              Icon(Icons.attach_money_rounded,
                  color: AppTheme.successColor, size: 14.sp),
              SizedBox(width: DesignTokens.space2.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('السعر المقترح من العميل',
                        style: TextStyle(
                            fontSize: 8.sp, color: AppTheme.textSecondary,
                            fontWeight: FontWeight.bold)),
                    SizedBox(height: 2.h),
                    Row(
                      children: [
                        Icon(Icons.access_time_rounded,
                            size: 10.sp, color: AppTheme.warningColor),
                        SizedBox(width: 4.w),
                        Text('متبقي $_countdownText',
                            style: TextStyle(
                                fontSize: 9.sp,
                                color: AppTheme.warningColor,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ),
              Text('${_clientPrice.toStringAsFixed(0)} EGP',
                  style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.textPrimary)),
            ],
          ),
          if (_isExpired) ...[
            SizedBox(height: DesignTokens.space3.h),
            Text('انتهى الوقت المحدد للطلب',
                style: TextStyle(
                    fontSize: 10.sp,
                    color: AppTheme.errorColor,
                    fontWeight: FontWeight.bold)),
          ],
          SizedBox(height: DesignTokens.space5.h),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed:
                  (_isUpdating || _isExpired) ? null : () => setState(() => _showPriceScreen = true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.successColor,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: DesignTokens.space5.h),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r)),
                elevation: 0,
              ),
              child: Text('تحديد سعر',
                  style: TextStyle(
                      fontSize: 12.sp, fontWeight: FontWeight.bold)),
            ),
          ),
          SizedBox(height: DesignTokens.space2.h),
          TextButton(
            onPressed: _isUpdating ? null : _rejectOrder,
            child: Text('رفض الطلب',
                style: TextStyle(
                    fontSize: 11.sp,
                    color: AppTheme.textTertiary,
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationPoints() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 18.sp,
              height: 18.sp,
              decoration: BoxDecoration(
                color: AppTheme.infoColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Center(
                  child: Text('A',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 8.sp,
                          fontWeight: FontWeight.bold))),
            ),
            SizedBox(width: DesignTokens.space3.w),
            Expanded(
              child: Text(_clientAddress,
                  style: TextStyle(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary)),
            ),
          ],
        ),
        Padding(
          padding: EdgeInsets.only(right: 9.w),
          child: Container(
            height: 20.h,
            width: 2.w,
            margin: EdgeInsets.only(right: 9.w),
            child: CustomPaint(painter: _DottedLinePainter()),
          ),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 18.sp,
              height: 18.sp,
              decoration: BoxDecoration(
                color: AppTheme.successColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Center(
                  child: Text('B',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 8.sp,
                          fontWeight: FontWeight.bold))),
            ),
            SizedBox(width: DesignTokens.space3.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_pickupAddress,
                      style: TextStyle(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary)),
                  if (_pickupName != 'موقع الانطلاق')
                    Text(_pickupName,
                        style: TextStyle(
                            fontSize: 9.sp, color: AppTheme.textSecondary)),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPriceContent() {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          DesignTokens.space8.w, DesignTokens.space6.h, DesignTokens.space8.w, DesignTokens.space8.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('سعرك المقترح',
              style: TextStyle(
                  fontSize: 9.sp,
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.bold)),
          SizedBox(height: DesignTokens.space4.h),
          Container(
            padding: EdgeInsets.all(DesignTokens.space3.w),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor70,
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: AppTheme.backgroundColor),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: () => _updatePrice(-5),
                  child: Container(
                    width: 44.sp,
                    height: 44.sp,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10.r),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 4),
                      ],
                    ),
                    child: Icon(Icons.remove_rounded,
                        color: AppTheme.textSecondary, size: 20.sp),
                  ),
                ),
                Text('${_offerPrice.toStringAsFixed(0)} EGP',
                    style: TextStyle(
                        fontSize: 22.sp,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.textPrimary)),
                GestureDetector(
                  onTap: () => _updatePrice(5),
                  child: Container(
                    width: 44.sp,
                    height: 44.sp,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10.r),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 4),
                      ],
                    ),
                    child: Icon(Icons.add_rounded,
                        color: AppTheme.textSecondary, size: 20.sp),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: DesignTokens.space2.h),
          Text('السعر المقترح من العميل ${_clientPrice.toStringAsFixed(0)} EGP',
              style: TextStyle(
                  fontSize: 8.sp, color: AppTheme.textTertiary,
                  fontWeight: FontWeight.w600)),
          SizedBox(height: DesignTokens.space5.h),
          TextField(
            controller: _noteController,
            textAlign: TextAlign.right,
            decoration: InputDecoration(
              hintText: 'اكتب ملاحظة للعميل (اختياري)',
              hintStyle: TextStyle(
                  fontSize: 10.sp, color: AppTheme.textTertiary),
              filled: true,
              fillColor: AppTheme.surfaceColor70,
              contentPadding: EdgeInsets.symmetric(
                  horizontal: DesignTokens.space6.w,
                  vertical: DesignTokens.space4.h),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10.r),
                borderSide: const BorderSide(color: AppTheme.dividerColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10.r),
                borderSide: const BorderSide(color: AppTheme.dividerColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10.r),
                borderSide: const BorderSide(color: AppTheme.successColor),
              ),
            ),
            style: TextStyle(fontSize: 11.sp),
          ),
          SizedBox(height: DesignTokens.space5.h),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 44.sp,
                  child: ElevatedButton(
                    onPressed: _isUpdating ? null : _sendPriceOffer,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.successColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r)),
                      elevation: 0,
                    ),
                    child: _isUpdating
                        ? SizedBox(
                            width: 16.sp,
                            height: 16.sp,
                            child: const CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : Text('إرسال العرض',
                            style: TextStyle(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
              SizedBox(width: DesignTokens.space3.w),
              GestureDetector(
                onTap: () => setState(() => _showPriceScreen = false),
                child: Container(
                  width: 44.sp,
                  height: 44.sp,
                  decoration: BoxDecoration(
                    color: AppTheme.backgroundColor,
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: const Icon(Icons.undo_rounded,
                      color: AppTheme.textSecondary, size: 20),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DashedRoutePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.successColor
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final path = Path();
    path.moveTo(size.width * 0.65, size.height * 0.28);
    path.quadraticBezierTo(
      size.width * 0.5, size.height * 0.45,
      size.width * 0.35, size.height * 0.65,
    );

    final dashed = Path();
    for (final metric in path.computeMetrics()) {
      double dist = 0;
      while (dist < metric.length) {
        final end = (dist + 8).clamp(0, metric.length);
        dashed.addPath(metric.extractPath(dist.toDouble(), end.toDouble()), Offset.zero);
        dist += 14;
      }
    }
    canvas.drawPath(dashed, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DottedLinePainter extends CustomPainter {
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
