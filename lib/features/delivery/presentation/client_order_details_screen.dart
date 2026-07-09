import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/theme/app_theme.dart';

class ClientOrderDetailsScreen extends StatelessWidget {
  final Map<String, dynamic>? bookingData;
  const ClientOrderDetailsScreen({super.key, this.bookingData});

  static const Color _purple = AppTheme.primaryColor;
  static const Color _bgGray = AppTheme.surfaceColor70;

  @override
  Widget build(BuildContext context) {
    final code = bookingData?['order_code'] as String? ?? '#F25847';
    final status = bookingData?['status'] as String? ?? 'pending';
    final total = (bookingData?['total_price'] as num?)?.toDouble() ?? 0;
    final deliveryFee = (bookingData?['delivery_fee'] as num?)?.toDouble() ?? 10;
    final address = bookingData?['address'] as String? ?? '';
    final paymentMethod = bookingData?['payment_method'] as String? ?? 'cash';
    final itemsTotal = (bookingData?['items_total'] as num?)?.toInt() ?? 0;

    // Parse items from notes
    List<Map<String, dynamic>> items = [];
    try {
      final notes = bookingData?['notes'] as String?;
      if (notes != null) {
        final parsed = jsonDecode(notes);
        items = List<Map<String, dynamic>>.from(parsed as List);
      }
    } catch (_) {}

    final subTotal = items.fold<double>(0.0, (s, i) => s + ((i['total_price'] as num?)?.toDouble() ?? 0));
    const discountRate = 0.2;
    final discount = subTotal * discountRate;
    final grandTotal = subTotal - discount + deliveryFee;

    String statusLabel;
    if (status == 'completed') {
      statusLabel = 'تم التوصيل';
    } else if (status == 'on_the_way') {
      statusLabel = 'في الطريق';
    } else if (status == 'ready_for_pickup') {
      statusLabel = 'جاهز للتوصيل';
    } else if (status == 'accepted') {
      statusLabel = 'جاري التجهيز';
    } else {
      statusLabel = 'قيد التنفيذ';
    }
    final statusColor = status == 'completed' ? AppTheme.successColor : _purple;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.darkBackgroundColor),
            onPressed: () => Navigator.pop(context)),
        title: Text('تفاصيل الطلب',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.sp, color: AppTheme.darkBackgroundColor)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(padding: EdgeInsets.all(16.w), children: [
              // Header card
              Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(color: _bgGray, borderRadius: BorderRadius.circular(16.r), border: Border.all(color: Colors.grey[100]!)),
                child: Column(children: [
                  Row(children: [
                    Container(
                      width: 28, height: 28,
                      decoration: BoxDecoration(color: Colors.blue[600], borderRadius: BorderRadius.circular(10.r)),
                      child: Center(child: Text('FD', style: TextStyle(color: Colors.white, fontSize: 8.sp, fontWeight: FontWeight.w900))),
                    ),
                    SizedBox(width: 8.w),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Faster Delivery', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.sp, color: AppTheme.darkBackgroundColor)),
                      Text(code, style: TextStyle(fontSize: 9.sp, color: Colors.grey[400], fontFamily: 'monospace')),
                    ])),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                      decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8.r),
                          border: Border.all(color: statusColor.withValues(alpha: 0.2))),
                      child: Text(statusLabel, style: TextStyle(fontSize: 9.sp, color: statusColor, fontWeight: FontWeight.bold)),
                    ),
                  ]),
                  SizedBox(height: 8.h),
                  if (address.isNotEmpty)
                    Row(children: [
                      Icon(Icons.location_on_rounded, size: 12, color: Colors.grey[400]),
                      SizedBox(width: 4.w),
                      Expanded(child: Text(address, style: TextStyle(fontSize: 10.sp, color: Colors.grey[500]))),
                    ]),
                  if (paymentMethod.isNotEmpty)
                    Row(children: [
                      Icon(Icons.payment_rounded, size: 12, color: Colors.grey[400]),
                      SizedBox(width: 4.w),
                      Text(_paymentLabel(paymentMethod), style: TextStyle(fontSize: 10.sp, color: Colors.grey[500])),
                    ]),
                ]),
              ),
              SizedBox(height: 16.h),
              // Items
              Text('المنتجات ()', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.sp, color: AppTheme.darkBackgroundColor)),
              SizedBox(height: 8.h),
              ...items.map((item) => Container(
                margin: EdgeInsets.only(bottom: 6.h),
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(color: _bgGray.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(12.r)),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Expanded(
                    child: Text(item['name']?.toString() ?? '',
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11.sp, color: Colors.grey[600])),
                  ),
                  Text('x',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.sp, color: _purple)),
                  SizedBox(width: 8.w),
                  Text(' ج',
                      style: TextStyle(fontSize: 11.sp, color: Colors.grey[600])),
                ]),
              )),
              if (items.isEmpty) ...[
                Container(
                  padding: EdgeInsets.all(8.w),
                  decoration: BoxDecoration(color: _bgGray, borderRadius: BorderRadius.circular(12.r)),
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text(' منتج', style: TextStyle(fontSize: 11.sp, color: Colors.grey[500])),
                  ]),
                ),
              ],
              SizedBox(height: 16.h),
              // Totals
              Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16.r)),
                child: Column(children: [
                  _row('المجموع الفرعي', ' ج', Colors.grey[500]!, Colors.grey[800]!, false),
                  SizedBox(height: 6.h),
                  _row('الخصم (20%)', '- ج', AppTheme.successColor, AppTheme.successColor, false),
                  SizedBox(height: 6.h),
                  _row('رسوم التوصيل', ' ج', Colors.grey[500]!, Colors.grey[800]!, false),
                  Divider(height: 16.h, color: Colors.grey[200]!),
                  _row('الإجمالي', ' ج', AppTheme.darkBackgroundColor, _purple, true),
                ]),
              ),
            ]),
          ),
          Container(
            padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, MediaQuery.of(context).padding.bottom + 16.h),
            decoration: BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Colors.grey[50]!))),
            child: SizedBox(
              width: double.infinity, height: 48.h,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _purple,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                  elevation: 4, shadowColor: _purple.withValues(alpha: 0.3),
                ),
                child: Text('طلب مرة أخرى',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.sp, color: Colors.white)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value, Color labelColor, Color valueColor, bool bold) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: TextStyle(fontSize: 12.sp, fontWeight: bold ? FontWeight.w800 : FontWeight.w500, color: labelColor)),
      Text(value, style: TextStyle(fontSize: bold ? 14.sp : 12.sp, fontWeight: bold ? FontWeight.w900 : FontWeight.bold, color: valueColor)),
    ]);
  }

  String _paymentLabel(String method) {
    switch (method) {
      case 'cash': return 'الدفع عند الاستلام';
      case 'card': return 'بطاقة بنكية';
      case 'wallet': return 'محفظة إلكترونية';
      case 'vodafone_cash': return 'فودافون كاش';
      default: return method;
    }
  }
}
