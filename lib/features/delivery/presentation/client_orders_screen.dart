import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/services/supabase_service.dart';
import 'client_order_details_screen.dart';
import 'client_delivery_tracking_screen.dart';

class ClientOrdersScreen extends StatefulWidget {
  const ClientOrdersScreen({super.key});

  @override
  State<ClientOrdersScreen> createState() => _ClientOrdersScreenState();
}

class _ClientOrdersScreenState extends State<ClientOrdersScreen> {
  List<Map<String, dynamic>> _orders = [];
  bool _loading = true;

  static const Color _purple = AppTheme.primaryColor;
  static const Color _bgGray = AppTheme.surfaceColor70;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final uid = SupabaseService.currentUserId;
      if (uid == null) return;
      final res = await SupabaseService.db
          .from('bookings')
          .select()
          .eq('client_id', uid)
          .eq('booking_type', 'delivery')
          .order('created_at', ascending: false);
      if (mounted) _orders = List<Map<String, dynamic>>.from(res);
    } catch (e) {
      debugPrint('Orders load error: ');
    }
    if (mounted) setState(() => _loading = false);
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'pending': return '??? ????????';
      case 'accepted': return '??? ???????';
      case 'ready_for_pickup': return '???? ???????';
      case 'on_the_way': return '?? ??????';
      case 'arrived': return '???';
      case 'in_progress': return '????';
      case 'completed': return '?? ???????';
      case 'cancelled': return '????';
      default: return s;
    }
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'completed': return AppTheme.successColor;
      case 'cancelled': return Colors.red;
      case 'on_the_way': return _purple;
      case 'ready_for_pickup': return AppTheme.primaryColor;
      case 'accepted': case 'in_progress': return Colors.blue;
      default: return Colors.amber;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0,
        title: Text('??????', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15.sp, color: AppTheme.darkBackgroundColor)),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _orders.isEmpty
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.receipt_long_rounded, size: 48, color: Colors.grey[300]),
                  SizedBox(height: 12.h),
                  Text('?? ???? ?????', style: TextStyle(color: Colors.grey[400])),
                ]))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: EdgeInsets.all(16.w),
                    itemCount: _orders.length,
                    itemBuilder: (_, i) {
                      final o = _orders[i];
                      final code = o['order_code'] as String? ?? '';
                      final status = o['status'] as String? ?? '';
                      final total = (o['total_price'] as num?)?.toDouble() ?? 0;
                      final items = (o['items_total'] as num?)?.toInt() ?? 0;
                      final date = o['created_at'] as String? ?? '';
                      final dateStr = date.length >= 16 ? date.substring(0, 16).replaceAll('T', ' ') : date;
                      return Container(
                        margin: EdgeInsets.only(bottom: 10.h),
                        padding: EdgeInsets.all(12.w),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16.r),
                            border: Border.all(color: Colors.grey[100]!)),
                        child: InkWell(
                          onTap: () {
                            if (status == 'completed') {
                              Navigator.push(context, MaterialPageRoute(builder: (_) => ClientOrderDetailsScreen(bookingData: o)));
                            } else {
                              Navigator.push(context, MaterialPageRoute(builder: (_) => ClientDeliveryTrackingScreen(bookingData: o)));
                            }
                          },
                          borderRadius: BorderRadius.circular(16.r),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                              Text(code, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.sp, color: AppTheme.darkBackgroundColor)),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                                decoration: BoxDecoration(color: _statusColor(status).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8.r)),
                                child: Text(_statusLabel(status),
                                    style: TextStyle(fontSize: 9.sp, color: _statusColor(status), fontWeight: FontWeight.bold)),
                              ),
                            ]),
                            SizedBox(height: 6.h),
                            Row(children: [
                              Icon(Icons.inventory_2_rounded, size: 12, color: Colors.grey[400]),
                              SizedBox(width: 4.w),
                              Text(' ??????', style: TextStyle(fontSize: 10.sp, color: Colors.grey[500])),
                              SizedBox(width: 16.w),
                              Icon(Icons.access_time_rounded, size: 12, color: Colors.grey[400]),
                              SizedBox(width: 4.w),
                              Expanded(child: Text(dateStr, style: TextStyle(fontSize: 10.sp, color: Colors.grey[500]))),
                            ]),
                            Divider(height: 12.h, color: Colors.grey[100]!),
                            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                              Text(' ?',
                                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13.sp, color: _purple)),
                              Icon(Icons.arrow_back_ios_rounded, size: 12, color: Colors.grey[400]),
                            ]),
                          ]),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
