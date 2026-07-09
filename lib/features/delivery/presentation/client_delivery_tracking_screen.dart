import 'dart:async';
import '../../../core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:collection/collection.dart';
import '../../../core/services/supabase_service.dart';
import 'client_order_details_screen.dart';

class ClientDeliveryTrackingScreen extends StatefulWidget {
  final Map<String, dynamic>? bookingData;
  const ClientDeliveryTrackingScreen({super.key, this.bookingData});

  @override
  State<ClientDeliveryTrackingScreen> createState() => _ClientDeliveryTrackingScreenState();
}

class _ClientDeliveryTrackingScreenState extends State<ClientDeliveryTrackingScreen> {
  Map<String, dynamic>? _booking;
  Map<String, dynamic>? _provider;
  bool _loading = true;
  StreamSubscription? _bookingSub;

  static const Color _purple = AppTheme.primaryColor;
  static const Color _bgGray = AppTheme.surfaceColor70;

  @override
  void initState() {
    super.initState();
    _load();
    _subscribe();
  }

  void _subscribe() {
    final bookingId = widget.bookingData?['id'];
    if (bookingId == null) return;
    _bookingSub = SupabaseService.db
        .from('bookings')
        .stream(primaryKey: ['id'])
        .eq('id', bookingId)
        .listen((List<Map<String, dynamic>> data) {
      if (data.isNotEmpty && mounted) {
        setState(() => _booking = data.first);
      }
    });
  }

  @override
  void dispose() {
    _bookingSub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      _booking = widget.bookingData;
      if (_booking == null) return;
      final pid = _booking!['provider_id'] as String?;
      if (pid != null) {
        final prov = await SupabaseService.db.from('provider_profiles').select('*, profiles!inner(full_name, avatar_url)').eq('id', pid).single();
        if (mounted) _provider = Map<String, dynamic>.from(prov);
      }
    } catch (e) {
      debugPrint('Tracking load error: ');
    }
    if (mounted) setState(() => _loading = false);
  }

  int _statusIndex(String? status) {
    switch (status) {
      case 'completed': return 0;
      case 'on_the_way': return 1;
      case 'ready_for_pickup': return 2;
      case 'accepted': return 3;
      case 'pending': return 3;
      default: return 3;
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = _booking?['status'] as String? ?? 'pending';
    final idx = _statusIndex(status);
    final profile = _provider?['profiles'] as Map<String, dynamic>?;
    final provName = profile?['full_name'] as String? ?? '???? ???????...';
    final provRating = (_provider?['avg_rating'] as num?)?.toDouble() ?? 0;
    final orderCode = _booking?['order_code'] as String? ?? '';
    final storeName = _provider?['store_name'] as String? ?? '??????';

    return Scaffold(
      backgroundColor: Colors.white,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.all(16.w),
                    child: Column(
                      children: [
                        SizedBox(height: MediaQuery.of(context).padding.top),
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          const Text('9:41', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          InkWell(onTap: () => Navigator.pop(context),
                              child: Container(
                                width: 32, height: 32,
                                decoration: BoxDecoration(color: _bgGray, shape: BoxShape.circle),
                                child: const Icon(Icons.arrow_back_rounded, size: 14),
                              )),
                        ]),
                        SizedBox(height: 12.h),
                        Text('???? ?????',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.sp, color: AppTheme.darkBackgroundColor)),
                        SizedBox(height: 4.h),
                        Text(orderCode,
                            style: TextStyle(fontSize: 10.sp, color: Colors.grey[400], fontFamily: 'monospace')),
                        SizedBox(height: 16.h),
                        // Provider card
                        if (_provider != null && status != 'pending')
                          Container(
                            padding: EdgeInsets.all(12.w),
                            decoration: BoxDecoration(color: _bgGray, borderRadius: BorderRadius.circular(16.r), border: Border.all(color: Colors.grey[100]!)),
                            child: Row(children: [
                              Container(
                                width: 40, height: 40,
                                decoration: BoxDecoration(color: Colors.amber[400], borderRadius: BorderRadius.circular(12.r)),
                                child: const Icon(Icons.person_rounded, color: Colors.white, size: 22),
                              ),
                              SizedBox(width: 12.w),
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(provName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.sp, color: AppTheme.darkBackgroundColor)),
                                if (provRating > 0)
                                  Row(children: [
                                    Icon(Icons.star_rounded, size: 10, color: Colors.amber[500]),
                                    SizedBox(width: 2.w),
                                    Text(provRating.toStringAsFixed(1),
                                        style: TextStyle(fontSize: 10.sp, color: Colors.amber[500], fontWeight: FontWeight.bold)),
                                  ]),
                              ])),
                              Row(children: [
                                Container(
                                  width: 32, height: 32,
                                  decoration: BoxDecoration(color: AppTheme.successColor.withValues(alpha: 0.1), shape: BoxShape.circle,
                                      border: Border.all(color: AppTheme.successColor.withValues(alpha: 0.2))),
                                  child: const Icon(Icons.phone_rounded, color: AppTheme.successColor, size: 14),
                                ),
                                SizedBox(width: 8.w),
                                Container(
                                  width: 32, height: 32,
                                  decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.1), shape: BoxShape.circle,
                                      border: Border.all(color: Colors.blue.withValues(alpha: 0.2))),
                                  child: const Icon(Icons.chat_rounded, color: Colors.blue, size: 14),
                                ),
                              ]),
                            ]),
                          ),
                        if (_provider == null && status != 'pending')
                          Padding(
                            padding: EdgeInsets.symmetric(vertical: 8.h),
                            child: const CircularProgressIndicator(strokeWidth: 2),
                          ),
                        if (status == 'pending')
                          Container(
                            padding: EdgeInsets.all(16.w),
                            decoration: BoxDecoration(color: Colors.amber[50], borderRadius: BorderRadius.circular(16.r)),
                            child: Row(children: [
                              const Icon(Icons.hourglass_empty_rounded, color: AppTheme.warningColor, size: 20),
                              SizedBox(width: 12.w),
                              Expanded(child: Text('?? ?????? ????? ?????? ?????',
                                  style: TextStyle(fontSize: 12.sp, color: AppTheme.warningColor, fontWeight: FontWeight.bold))),
                            ]),
                          ),
                        SizedBox(height: 16.h),
                        // Map
                        Container(
                          height: 180.h,
                          decoration: BoxDecoration(color: AppTheme.backgroundColor, borderRadius: BorderRadius.circular(24.r),
                              border: Border.all(color: AppTheme.backgroundColor)),
                          child: Stack(
                            children: [
                              CustomPaint(size: Size.infinite, painter: _DottedRoutePainter()),
                              const Positioned(top: 50, right: 30, child: Icon(Icons.motorcycle_rounded, color: AppTheme.primaryColor, size: 28)),
                              const Positioned(bottom: 80, left: 35, child: Icon(Icons.location_on_rounded, color: Colors.red, size: 24)),
                            ],
                          ),
                        ),
                        SizedBox(height: 24.h),
                        Text(_statusLabel(status),
                            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12.sp, color: AppTheme.darkBackgroundColor)),
                        SizedBox(height: 16.h),
                        Row(children: [
                          _step(Icons.check_rounded, idx <= 0 ? AppTheme.successColor : Colors.grey[300]!, '?? ???????', idx == 0, context),
                          _step(Icons.local_shipping_rounded, idx <= 1 ? _purple : Colors.grey[300]!, '?? ??????', idx == 1, context),
                          _step(Icons.inventory_2_rounded, idx <= 2 ? _purple : Colors.grey[300]!, '?? ???????', idx == 2, context),
                          _step(Icons.receipt_long_rounded, idx <= 3 ? _purple : Colors.grey[300]!, '?? ????????', idx == 3, context),
                        ]),
                      ],
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ClientOrderDetailsScreen(bookingData: _booking))),
                  child: Text('?????? ?????',
                      style: TextStyle(fontSize: 12.sp, color: Colors.grey[400], fontWeight: FontWeight.bold)),
                ),
                SizedBox(height: MediaQuery.of(context).padding.bottom + 8.h),
              ],
            ),
    );
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'pending': return '?? ?????? ????? ??????';
      case 'accepted': return '??? ????? ????';
      case 'ready_for_pickup': return '?? ????? ????? ??????? ???????';
      case 'on_the_way': return '??????? ?? ?????? ????';
      case 'arrived': return '??? ???????';
      case 'in_progress': return '??? ????? ????';
      case 'completed': return '?? ??????? ?????';
      default: return '??? ????? ????';
    }
  }

  Widget _step(IconData icon, Color color, String label, bool active, BuildContext context) {
    return Expanded(
      child: Column(children: [
        Container(
          width: 28, height: 28,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: active ? [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 8)] : null,
          ),
          child: Icon(icon, color: Colors.white, size: 12),
        ),
        SizedBox(height: 6.h),
        Text(label, style: TextStyle(
            fontSize: 9.sp, fontWeight: active ? FontWeight.w800 : FontWeight.bold,
            color: active ? AppTheme.darkBackgroundColor : Colors.grey[400])),
      ]),
    );
  }
}

class _DottedRoutePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.primaryColor.withValues(alpha: 0.3)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    final path = Path()
      ..moveTo(50, size.height * 0.55)
      ..cubicTo(size.width * 0.3, size.height * 0.3, size.width * 0.5, size.height * 0.15, size.width * 0.7, size.height * 0.4)
      ..cubicTo(size.width * 0.8, size.height * 0.5, size.width * 0.75, size.height * 0.25, size.width - 40, size.height * 0.45);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
