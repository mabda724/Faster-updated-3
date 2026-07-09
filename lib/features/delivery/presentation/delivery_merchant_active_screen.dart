import 'dart:async';
import '../../../core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../core/services/supabase_service.dart';

class DeliveryMerchantActiveScreen extends StatefulWidget {
  final Map<String, dynamic> bookingData;
  const DeliveryMerchantActiveScreen({super.key, required this.bookingData});
  @override
  State<DeliveryMerchantActiveScreen> createState() =>
      _DeliveryMerchantActiveScreenState();
}

class _DeliveryMerchantActiveScreenState
    extends State<DeliveryMerchantActiveScreen> {
  Map<String, dynamic>? _booking;
  bool _isUpdating = false;
  StreamSubscription? _sub;

  static const Color _purple = AppTheme.primaryColor;
  static const Color _emerald = AppTheme.successColor;

  @override
  void initState() {
    super.initState();
    _booking = widget.bookingData;
    _listen();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _listen() {
    final id = _booking?['id'];
    if (id == null) return;
    _sub = SupabaseService.db
        .from('bookings')
        .stream(primaryKey: ['id'])
        .eq('id', id)
        .listen((data) {
      if (data.isNotEmpty && mounted) {
        setState(() => _booking = data.first);
      }
    });
  }

  Future<void> _updateStatus(String status) async {
    setState(() => _isUpdating = true);
    try {
      await SupabaseService.db
          .from('bookings')
          .update({'status': status})
          .eq('id', _booking!['id']);
      if (mounted) setState(() => _isUpdating = false);
    } catch (e) {
      debugPrint('Update error: $e');
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  void _scanQr() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      shape: const RoundedRectangleBorder(),
      builder: (ctx) {
        bool handled = false;
        return SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
          child: Stack(
            children: [
              MobileScanner(
                onDetect: (capture) {
                  if (handled) return;
                  final raw =
                      capture.barcodes.first.rawValue?.trim();
                  if (raw == null || !raw.startsWith('FASTER-DELIVERY-')) return;
                  handled = true;
                  Navigator.pop(ctx);
                  _updateStatus('on_the_way');
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('تم التحقق! الطلب في الطريق للعميل',
                            style: TextStyle(fontSize: 12.sp)),
                        backgroundColor: _emerald,
                      ),
                    );
                  }
                },
              ),
              Positioned(
                top: 40,
                right: 16,
                child: GestureDetector(
                  onTap: () => Navigator.pop(ctx),
                  child: Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle),
                    child:
                        Icon(Icons.close, color: Colors.white, size: 20),
                  ),
                ),
              ),
              Center(
                child: IgnorePointer(
                  child: Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      border: Border.all(color: _purple, width: 3),
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 40,
                left: 0,
                right: 0,
                child: Text(
                  'امسح QR كود المتجر لاستلام الطلب',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = _booking?['status'] as String? ?? '';
    final store = _booking?['provider_profiles'] as Map<String, dynamic>?;
    final storeName = store?['store_name'] as String? ?? 'المتجر';
    final total = (_booking?['total_price'] as num?)?.toDouble() ?? 0;
    final address = _booking?['address'] as String? ?? '';
    final code = _booking?['order_code'] as String? ?? '';

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded,
                color: AppTheme.darkBackgroundColor),
            onPressed: () => Navigator.pop(context)),
        title: Text('توصيل طلب',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14.sp,
                color: AppTheme.darkBackgroundColor)),
        centerTitle: true,
      ),
      body: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(children: [
          // Store info card
          Container(
            padding: EdgeInsets.all(14.w),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(color: Colors.grey[100]!)),
            child: Row(children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                    color: _purple.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12.r)),
                child: Icon(Icons.store_rounded, color: _purple, size: 22),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(storeName,
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13.sp,
                              color: AppTheme.darkBackgroundColor)),
                      Text(code,
                          style: TextStyle(
                              fontSize: 9.sp,
                              color: Colors.grey[400],
                              fontFamily: 'monospace')),
                    ]),
              ),
              Container(
                padding:
                    EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                decoration: BoxDecoration(
                    color: _statusColor(status).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8.r)),
                child: Text(_statusLabel(status),
                    style: TextStyle(
                        fontSize: 9.sp,
                        fontWeight: FontWeight.bold,
                        color: _statusColor(status))),
              ),
            ]),
          ),
          SizedBox(height: 16.h),
          // Address
          if (address.isNotEmpty)
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(12.r)),
              child: Row(children: [
                Icon(Icons.location_on_rounded,
                    size: 16, color: Colors.red[400]),
                SizedBox(width: 8.w),
                Expanded(
                    child: Text(address,
                        style: TextStyle(
                            fontSize: 11.sp, color: Colors.grey[700]))),
              ]),
            ),
          SizedBox(height: 16.h),
          // Amount
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: Colors.grey[100]!)),
            child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('قيمة الطلب',
                      style: TextStyle(
                          fontSize: 11.sp, color: Colors.grey[500])),
                  Text('$total ج',
                      style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16.sp,
                          color: _purple)),
                ]),
          ),
          const Spacer(),
          // Status flow steps
          _buildSteps(status),
          const Spacer(),
          // Action button
          SizedBox(
            width: double.infinity,
            height: 48.h,
            child: _buildAction(status),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 8.h),
        ]),
      ),
    );
  }

  Widget _buildSteps(String status) {
    final steps = [
      ('جاهز للاستلام', Icons.store_rounded, 'ready_for_pickup'),
      ('تم الاستلام من المتجر', Icons.qr_code_scanner_rounded, 'on_the_way'),
      ('تم التوصيل للعميل', Icons.check_circle_rounded, 'completed'),
    ];

    int currentIdx = status == 'completed'
        ? 2
        : status == 'on_the_way'
            ? 1
            : 0;

    return Column(
        children: List.generate(steps.length, (i) {
      final done = i <= currentIdx;
      final active = i == currentIdx;
      return Row(children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: done ? _emerald : Colors.grey[200],
            shape: BoxShape.circle,
          ),
          child: Icon(done ? Icons.check : steps[i].$2,
              color: Colors.white, size: 14),
        ),
        if (i < steps.length - 1)
          Container(
            width: 2,
            height: 30,
            color: done ? _emerald : Colors.grey[200],
            margin: EdgeInsets.only(left: 13),
          ),
        SizedBox(width: 12.w),
        Text(steps[i].$3,
            style: TextStyle(
                fontSize: 11.sp,
                fontWeight: active ? FontWeight.bold : FontWeight.w500,
                color: done ? AppTheme.darkBackgroundColor : Colors.grey[400])),
      ]);
    }));
  }

  Widget _buildAction(String status) {
    if (status == 'completed') {
      return ElevatedButton(
        onPressed: () => Navigator.pop(context),
        style: ElevatedButton.styleFrom(
            backgroundColor: _purple,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14.r))),
        child: Text('العودة',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13.sp,
                color: Colors.white)),
      );
    }
    if (status == 'ready_for_pickup') {
      return ElevatedButton.icon(
        onPressed: _isUpdating ? null : _scanQr,
        icon: Icon(Icons.qr_code_scanner_rounded,
            size: 20, color: Colors.white),
        label: Text('مسح QR لاستلام الطلب',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12.sp,
                color: Colors.white)),
        style: ElevatedButton.styleFrom(
            backgroundColor: _purple,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14.r))),
      );
    }
    if (status == 'on_the_way') {
      return ElevatedButton.icon(
        onPressed: _isUpdating ? null : () => _updateStatus('completed'),
        icon: Icon(Icons.done_all_rounded,
            size: 20, color: Colors.white),
        label: Text('تم التوصيل للعميل',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12.sp,
                color: Colors.white)),
        style: ElevatedButton.styleFrom(
            backgroundColor: _emerald,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14.r))),
      );
    }
    return const SizedBox.shrink();
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'ready_for_pickup':
        return _purple;
      case 'on_the_way':
        return _emerald;
      case 'completed':
        return _emerald;
      default:
        return Colors.grey;
    }
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'ready_for_pickup':
        return 'جاهز للاستلام';
      case 'on_the_way':
        return 'جاري التوصيل';
      case 'completed':
        return 'مكتمل';
      default:
        return s;
    }
  }
}
