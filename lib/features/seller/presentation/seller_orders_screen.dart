import 'dart:async';
import '../../../core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/services/supabase_service.dart';

class SellerOrdersScreen extends StatefulWidget {
  const SellerOrdersScreen({super.key});
  @override
  State<SellerOrdersScreen> createState() => _SellerOrdersScreenState();
}

class _SellerOrdersScreenState extends State<SellerOrdersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  List<Map<String, dynamic>> _orders = [];
  bool _loading = true;
  StreamSubscription? _sub;

  static const Color _purple = AppTheme.primaryColor;
  static const Color _emerald = AppTheme.successColor;
  static const Color _bgGray = AppTheme.surfaceColor70;

  static const List<String> _activeStatuses = [
    'pending', 'accepted', 'ready_for_pickup', 'on_the_way'
  ];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _load();
    _listen();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _sub?.cancel();
    super.dispose();
  }

  void _listen() {
    final uid = SupabaseService.currentUserId;
    if (uid == null) return;
    _sub = SupabaseService.db
        .from('bookings')
        .stream(primaryKey: ['id'])
        .eq('provider_id', uid)
        .listen((_) => _load());
  }

  Future<void> _load() async {
    final uid = SupabaseService.currentUserId;
    if (uid == null) return;
    try {
      final res = await SupabaseService.db
          .from('bookings')
          .select(
              '*, profiles!bookings_client_id_fkey(full_name, phone_number)')
          .eq('provider_id', uid)
          .order('created_at', ascending: false);
      if (mounted) _orders = List<Map<String, dynamic>>.from(res);
    } catch (e) {
      debugPrint('Load orders error: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _updateStatus(String id, String status) async {
    try {
      await SupabaseService.db
          .from('bookings')
          .update({'status': status})
          .eq('id', id);
    } catch (e) {
      debugPrint('Update error: $e');
    }
  }

  List<Map<String, dynamic>> _filter(String tab) {
    switch (tab) {
      case 'active':
        return _orders
            .where((o) => _activeStatuses.contains(o['status']))
            .toList();
      case 'completed':
        return _orders.where((o) => o['status'] == 'completed').toList();
      case 'cancelled':
        return _orders.where((o) => o['status'] == 'cancelled').toList();
      default:
        return _orders;
    }
  }

  void _showQrSheet(Map<String, dynamic> order) {
    final bookingId = order['id'] as String? ?? '';
    final code = order['order_code'] as String? ?? '';
    final qrData = 'FASTER-DELIVERY-$bookingId';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28.r))),
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setSheetState) {
          return Padding(
            padding: EdgeInsets.fromLTRB(24.w, 16.h, 24.w, 32.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                    width: 40.w,
                    height: 4.h,
                    decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2)),
                    margin: EdgeInsets.only(bottom: 16.h)),
                Row(children: [
                  Expanded(
                    child: Text('QR ?????? ?????',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14.sp,
                            color: AppTheme.darkBackgroundColor)),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: Container(
                        padding: EdgeInsets.all(6),
                        decoration: BoxDecoration(
                            color: Colors.grey[100],
                            shape: BoxShape.circle),
                        child: Icon(Icons.close, size: 16, color: Colors.grey[600])),
                  ),
                ]),
                SizedBox(height: 12.h),
                Text('???? ?? ??????? ??? ????? ??????? ?????',
                    style: TextStyle(fontSize: 11.sp, color: Colors.grey[500])),
                SizedBox(height: 20.h),
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20.r),
                    border: Border.all(color: _purple.withValues(alpha: 0.3), width: 3),
                    boxShadow: [
                      BoxShadow(
                          color: _purple.withValues(alpha: 0.08),
                          blurRadius: 20,
                          offset: const Offset(0, 4))
                    ],
                  ),
                  child: QrImageView(
                    data: qrData,
                    version: QrVersions.auto,
                    size: 180.w,
                    backgroundColor: Colors.white,
                    eyeStyle: QrEyeStyle(
                        eyeShape: QrEyeShape.square, color: _purple),
                    dataModuleStyle: QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square,
                        color: AppTheme.darkBackgroundColor),
                  ),
                ),
                SizedBox(height: 8.h),
                Text(code,
                    style: TextStyle(
                        fontSize: 10.sp,
                        fontFamily: 'monospace',
                        color: Colors.grey[400])),
                SizedBox(height: 20.h),
                SizedBox(
                  width: double.infinity,
                  height: 44.h,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      _updateStatus(bookingId, 'on_the_way');
                      Navigator.pop(ctx);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('?? ????? ????? ??????? - ?? ?????? ??????',
                                style: TextStyle(fontSize: 12.sp)),
                            backgroundColor: _emerald,
                          ),
                        );
                      }
                    },
                    icon: Icon(Icons.qr_code_scanner_rounded, size: 18, color: Colors.white),
                    label: Text('?? ??? QR - ????? ??????',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12.sp,
                            color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _emerald,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14.r)),
                    ),
                  ),
                ),
              ],
            ),
          );
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text('????? ??????',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15.sp,
                color: AppTheme.darkBackgroundColor)),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: _purple,
          labelColor: _purple,
          unselectedLabelColor: Colors.grey[400],
          labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.sp),
          tabs: const [Tab(text: '????'), Tab(text: '??????'), Tab(text: '?????')],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(controller: _tabCtrl, children: [
              _list(_filter('active'), '?? ???? ????? ????'),
              _list(_filter('completed'), '?? ???? ????? ??????'),
              _list(_filter('cancelled'), '?? ???? ????? ?????'),
            ]),
    );
  }

  Widget _list(List<Map<String, dynamic>> items, String emptyMsg) {
    if (items.isEmpty) {
      return Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.receipt_long_rounded, size: 48, color: Colors.grey[300]),
        SizedBox(height: 12.h),
        Text(emptyMsg, style: TextStyle(color: Colors.grey[400])),
      ]));
    }
    return ListView.builder(
      padding: EdgeInsets.all(16.w),
      itemCount: items.length,
      itemBuilder: (_, i) => _card(items[i]),
    );
  }

  Widget _card(Map<String, dynamic> o) {
    final status = o['status'] as String? ?? 'pending';
    final customer = o['profiles']?['full_name'] as String? ?? '????';
    final phone = o['profiles']?['phone_number'] as String? ?? '';
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
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(customer,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12.sp,
                        color: AppTheme.darkBackgroundColor)),
                if (phone.isNotEmpty) ...[
                  SizedBox(width: 8.w),
                  Text(phone,
                      style: TextStyle(fontSize: 9.sp, color: Colors.grey[400])),
                ],
              ]),
              SizedBox(height: 2.h),
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
          Text('$total ?',
              style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 14.sp,
                  color: _purple)),
          Text(dateStr, style: TextStyle(fontSize: 10.sp, color: Colors.grey[400])),
        ]),
        SizedBox(height: 8.h),
        if (status == 'pending')
          Row(children: [
            Expanded(
              child: SizedBox(
                height: 36.h,
                child: ElevatedButton(
                  onPressed: () => _updateStatus(bookingId, 'accepted'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: _purple,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r))),
                  child: Text('???? ????? ???? ???????',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11.sp,
                          color: Colors.white)),
                ),
              ),
            ),
            SizedBox(width: 8.w),
            Expanded(
              child: SizedBox(
                height: 36.h,
                child: OutlinedButton(
                  onPressed: () => _updateStatus(bookingId, 'cancelled'),
                  style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.red[300]!),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r))),
                  child: Text('???',
                      style: TextStyle(fontSize: 11.sp, color: Colors.red[300])),
                ),
              ),
            ),
          ]),
        if (status == 'accepted')
          SizedBox(
            width: double.infinity,
            height: 36.h,
            child: ElevatedButton.icon(
              onPressed: () => _updateStatus(bookingId, 'ready_for_pickup'),
              icon: Icon(Icons.check_circle_outline, size: 14, color: Colors.white),
              label: Text('?? ??????? - ??????? ???? ??????',
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
        if (status == 'ready_for_pickup')
          SizedBox(
            width: double.infinity,
            height: 36.h,
            child: ElevatedButton.icon(
              onPressed: () => _showQrSheet(o),
              icon: Icon(Icons.qr_code_rounded, size: 14, color: Colors.white),
              label: Text('????? QR ????? ??????',
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
        if (status == 'on_the_way')
          SizedBox(
            width: double.infinity,
            height: 36.h,
            child: ElevatedButton.icon(
              onPressed: () => _updateStatus(bookingId, 'completed'),
              icon: Icon(Icons.done_all_rounded, size: 14, color: Colors.white),
              label: Text('?? ??????? ??????',
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
      ]),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.amber;
      case 'accepted':
        return Colors.indigo;
      case 'ready_for_pickup':
        return _purple;
      case 'on_the_way':
        return _emerald;
      case 'completed':
        return _emerald;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'pending':
        return '????';
      case 'accepted':
        return '???? ???????';
      case 'ready_for_pickup':
        return '???? ???????';
      case 'on_the_way':
        return '???? ???????';
      case 'completed':
        return '?????';
      case 'cancelled':
        return '????';
      default:
        return status;
    }
  }
}
