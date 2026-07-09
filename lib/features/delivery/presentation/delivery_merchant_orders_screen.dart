import 'dart:async';
import '../../../core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/services/supabase_service.dart';
import 'delivery_merchant_active_screen.dart';

class DeliveryMerchantOrdersScreen extends StatefulWidget {
  const DeliveryMerchantOrdersScreen({super.key});
  @override
  State<DeliveryMerchantOrdersScreen> createState() =>
      _DeliveryMerchantOrdersScreenState();
}

class _DeliveryMerchantOrdersScreenState
    extends State<DeliveryMerchantOrdersScreen> {
  List<Map<String, dynamic>> _available = [];
  List<Map<String, dynamic>> _active = [];
  List<Map<String, dynamic>> _history = [];
  bool _loading = true;
  int _tab = 0;
  StreamSubscription? _sub;

  static const Color _purple = AppTheme.primaryColor;
  static const Color _emerald = AppTheme.successColor;

  @override
  void initState() {
    super.initState();
    _load();
    _listen();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _listen() {
    final uid = SupabaseService.currentUserId;
    if (uid == null) return;
    _sub = SupabaseService.db
        .from('bookings')
        .stream(primaryKey: ['id'])
        .eq('booking_type', 'delivery')
        .listen((_) => _load());
  }

  Future<void> _load() async {
    final uid = SupabaseService.currentUserId;
    if (uid == null) return;
    try {
      final all = await SupabaseService.db
          .from('bookings')
          .select(
              '*, provider_profiles!bookings_provider_id_fkey(store_name, store_description)')
          .eq('booking_type', 'delivery')
          .not('provider_profiles', 'is', null)
          .order('created_at', ascending: false);

      final list = List<Map<String, dynamic>>.from(all);
      if (mounted) {
        setState(() {
          _available = list
              .where((o) =>
                  o['status'] == 'ready_for_pickup' &&
                  o['delivery_provider_id'] != uid)
              .toList();
          _active = list
              .where((o) =>
                  o['delivery_provider_id'] == uid &&
                  ['accepted', 'ready_for_pickup', 'on_the_way', 'arrived',
                      'in_progress']
                      .contains(o['status']))
              .toList();
          _history = list
              .where((o) =>
                  o['delivery_provider_id'] == uid &&
                  ['completed', 'cancelled'].contains(o['status']))
              .toList();
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Load merchant orders error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _acceptOrder(String id) async {
    final uid = SupabaseService.currentUserId;
    if (uid == null) return;
    try {
      await SupabaseService.db
          .from('bookings')
          .update({
            'delivery_provider_id': uid,
          })
          .eq('id', id)
          .eq('status', 'ready_for_pickup');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('تم قبول الطلب', style: TextStyle(fontSize: 12.sp)),
              backgroundColor: _emerald),
        );
        _load();
      }
    } catch (e) {
      debugPrint('Accept error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final tabs = ['متاح', 'نشط (${_active.length})', 'سابق'];
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text('طلبات المتاجر',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15.sp,
                color: AppTheme.darkBackgroundColor)),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(36.h),
          child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(tabs.length, (i) {
                final s = _tab == i;
                return GestureDetector(
                  onTap: () => setState(() => _tab = i),
                  child: Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                    margin: EdgeInsets.symmetric(horizontal: 4.w),
                    decoration: BoxDecoration(
                      color: s ? _purple : Colors.grey[100],
                      borderRadius: BorderRadius.circular(20.r),
                    ),
                    child: Text(tabs[i],
                        style: TextStyle(
                            fontSize: 10.sp,
                            fontWeight: FontWeight.bold,
                            color: s ? Colors.white : Colors.grey[500])),
                  ),
                );
              })),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _tab == 0
              ? _buildAvailable()
              : _tab == 1
                  ? _buildList(_active, 'لا توجد توصيلات نشطة', true)
                  : _buildList(_history, 'لا توجد توصيلات سابقة', false),
    );
  }

  Widget _buildAvailable() {
    if (_available.isEmpty) {
      return Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.store_mall_directory_rounded,
            size: 48, color: Colors.grey[300]),
        SizedBox(height: 12.h),
        Text('لا توجد طلبات متاحة حالياً',
            style: TextStyle(color: Colors.grey[400])),
      ]));
    }
    return ListView.builder(
      padding: EdgeInsets.all(16.w),
      itemCount: _available.length,
      itemBuilder: (_, i) => _card(_available[i], true),
    );
  }

  Widget _buildList(List<Map<String, dynamic>> items, String empty, bool active) {
    if (items.isEmpty) {
      return Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.receipt_long_rounded, size: 48, color: Colors.grey[300]),
        SizedBox(height: 12.h),
        Text(empty, style: TextStyle(color: Colors.grey[400])),
      ]));
    }
    return ListView.builder(
      padding: EdgeInsets.all(16.w),
      itemCount: items.length,
      itemBuilder: (_, i) => _card(items[i], active),
    );
  }

  Widget _card(Map<String, dynamic> o, bool showAccept) {
    final store = o['provider_profiles'] as Map<String, dynamic>?;
    final storeName = store?['store_name'] as String? ?? 'متجر';
    final status = o['status'] as String? ?? '';
    final total = (o['total_price'] as num?)?.toDouble() ?? 0;
    final address = o['address'] as String? ?? '';
    final code = o['order_code'] as String? ?? '';
    final bookingId = o['id'] as String? ?? '';
    final createdAt = o['created_at'] as String? ?? '';
    final dateStr = createdAt.length >= 10 ? createdAt.substring(0, 10) : '';

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: Colors.grey[100]!)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
                color: _purple.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10.r)),
            child: Icon(Icons.store_rounded, color: _purple, size: 18),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(storeName,
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12.sp,
                          color: AppTheme.darkBackgroundColor)),
                  Text(code,
                      style: TextStyle(
                          fontSize: 9.sp,
                          color: Colors.grey[400],
                          fontFamily: 'monospace')),
                ]),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
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
        if (address.isNotEmpty) ...[
          SizedBox(height: 8.h),
          Row(children: [
            Icon(Icons.location_on_rounded, size: 12, color: Colors.grey[400]),
            SizedBox(width: 4.w),
            Expanded(
                child: Text(address,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 10.sp, color: Colors.grey[500]))),
          ]),
        ],
        SizedBox(height: 8.h),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('$total ج',
              style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 14.sp,
                  color: _purple)),
          Text(dateStr,
              style: TextStyle(fontSize: 10.sp, color: Colors.grey[400])),
        ]),
        if (showAccept && status == 'ready_for_pickup') ...[
          SizedBox(height: 8.h),
          SizedBox(
            width: double.infinity,
            height: 38.h,
            child: ElevatedButton.icon(
              onPressed: () => _acceptOrder(bookingId),
              icon: Icon(Icons.check_circle_outline, size: 16, color: Colors.white),
              label: Text('قبول التوصيل',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 11.sp,
                      color: Colors.white)),
              style: ElevatedButton.styleFrom(
                  backgroundColor: _emerald,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r))),
            ),
          ),
        ],
        if (!showAccept && status == 'ready_for_pickup')
          Padding(
            padding: EdgeInsets.only(top: 8.h),
            child: SizedBox(
              width: double.infinity,
              height: 38.h,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => DeliveryMerchantActiveScreen(
                              bookingData: o)));
                },
                icon: Icon(Icons.delivery_dining_rounded,
                    size: 16, color: Colors.white),
                label: Text('فتح التوصيل',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 11.sp,
                        color: Colors.white)),
                style: ElevatedButton.styleFrom(
                    backgroundColor: _purple,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r))),
              ),
            ),
          ),
      ]),
    );
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'ready_for_pickup':
        return _purple;
      case 'on_the_way':
        return _emerald;
      case 'completed':
        return _emerald;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.blue;
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
      case 'cancelled':
        return 'ملغي';
      default:
        return s;
    }
  }
}
