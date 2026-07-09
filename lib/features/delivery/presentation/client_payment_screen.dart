import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/cart_service.dart';
import 'client_order_success_screen.dart';

class ClientPaymentScreen extends StatefulWidget {
  final String address;
  final String addressLabel;
  const ClientPaymentScreen({super.key, required this.address, required this.addressLabel});

  @override
  State<ClientPaymentScreen> createState() => _ClientPaymentScreenState();
}

class _ClientPaymentScreenState extends State<ClientPaymentScreen> {
  int _selected = 0;
  bool _saving = false;
  static const Color _purple = AppTheme.primaryColor;
  static const Color _bgGray = AppTheme.surfaceColor70;

  final _methods = [
    {'name': 'الدفع نقداً عند الاستلام', 'value': 'cash', 'icon': Icons.money_rounded, 'color': AppTheme.successColor},
    {'name': 'بطاقة بنكية', 'value': 'card', 'icon': null, 'color': AppTheme.infoColor, 'badge': 'VISA'},
    {'name': 'المحفظة الإلكترونية', 'value': 'wallet', 'icon': Icons.wallet_rounded, 'color': AppTheme.warningColor},
    {'name': 'فودافون كاش', 'value': 'vodafone_cash', 'icon': null, 'color': AppTheme.errorColor, 'badge': 'cash'},
  ];

  Future<Map<String, dynamic>?> _createOrder() async {
    final cart = CartService();
    if (cart.isEmpty) return null;

    try {
      final uid = SupabaseService.currentUserId;
      if (uid == null) return null;

      // Get provider_id from first item's merchant
      final firstItem = cart.items.values.first;
      final providerId = firstItem.merchantId;

      // Calculate totals
      const deliveryFee = 10.0;
      const discountRate = 0.2;
      final itemsTotal = cart.total;
      final discount = itemsTotal * discountRate;
      final grandTotal = itemsTotal - discount + deliveryFee;

      // Generate order code
      final code = 'F';

      // Build items JSON
      final itemsJson = cart.items.values.map((item) => {
        'product_id': item.id,
        'name': item.name,
        'quantity': item.quantity,
        'unit_price': item.price,
        'total_price': item.totalPrice,
        'image_url': item.imageUrl,
      }).toList();

      // Create booking
      final booking = await SupabaseService.db.from('bookings').insert({
        'client_id': uid,
        'provider_id': providerId,
        'booking_type': 'delivery',
        'status': 'pending',
        'total_price': grandTotal,
        'commission_amount': 0,
        'provider_earning': itemsTotal * 0.9,
        'delivery_fee': deliveryFee,
        'items_total': cart.count,
        'address': widget.address,
        'address_details': widget.addressLabel,
        'payment_method': _methods[_selected]['value'],
        'payment_status': _methods[_selected]['value'] == 'cash' ? 'pending' : 'unpaid',
        'order_code': code,
        'notes': itemsJson.toString(),
        'price': grandTotal,
      }).select().single();

      cart.clear();
      return Map<String, dynamic>.from(booking);
    } catch (e) {
      debugPrint('Order creation error: ');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgGray,
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.darkBackgroundColor),
            onPressed: () => Navigator.pop(context)),
        title: Text('طريقة الدفع',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.sp, color: AppTheme.darkBackgroundColor)),
        centerTitle: true,
      ),
      body: _saving
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: ListView(padding: EdgeInsets.all(16.w), children: [
                    ...List.generate(_methods.length, (i) {
                      final m = _methods[i];
                      final active = _selected == i;
                      return Padding(
                        padding: EdgeInsets.only(bottom: 12.h),
                        child: Container(
                          padding: EdgeInsets.all(12.w),
                          decoration: BoxDecoration(
                            color: active ? AppTheme.successColor.withValues(alpha: 0.06) : Colors.white,
                            borderRadius: BorderRadius.circular(16.r),
                            border: Border.all(color: active ? AppTheme.successColor : Colors.grey[100]!, width: active ? 1.5 : 1),
                          ),
                          child: InkWell(
                            onTap: () => setState(() => _selected = i),
                            borderRadius: BorderRadius.circular(16.r),
                            child: Row(children: [
                              Container(
                                width: 36, height: 36,
                                decoration: BoxDecoration(color: m['color'] as Color, borderRadius: BorderRadius.circular(12.r)),
                                child: m['icon'] != null
                                    ? Icon(m['icon'] as IconData, color: Colors.white, size: 16)
                                    : Center(child: Text(m['badge'] as String,
                                        style: TextStyle(color: Colors.white, fontSize: 8.sp, fontWeight: FontWeight.w900))),
                              ),
                              SizedBox(width: 12.w),
                              Expanded(child: Text(m['name'] as String,
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.sp, color: AppTheme.darkBackgroundColor))),
                              Container(
                                width: 16, height: 16,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: active ? AppTheme.successColor : Colors.grey[300]!, width: active ? 4 : 1.5),
                                  color: active ? Colors.white : Colors.transparent,
                                ),
                              ),
                            ]),
                          ),
                        ),
                      );
                    }),
                  ]),
                ),
                Container(
                  padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, MediaQuery.of(context).padding.bottom + 16.h),
                  decoration: BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Colors.grey[50]!))),
                  child: SizedBox(
                    width: double.infinity, height: 48.h,
                    child: ElevatedButton(
                      onPressed: () async {
                        setState(() => _saving = true);
                        final booking = await _createOrder();
                        if (!mounted) return;
                        if (booking != null) {
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(builder: (_) => ClientOrderSuccessScreen(bookingData: booking)),
                            (r) => r.isFirst,
                          );
                        } else {
                          setState(() => _saving = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('فشل إنشاء الطلب. حاول مرة أخرى.',
                                style: TextStyle(fontSize: 12.sp)),
                            backgroundColor: Colors.red,
                          ));
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _purple,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                        elevation: 4, shadowColor: _purple.withValues(alpha: 0.3),
                      ),
                      child: Text('تأكيد الطلب',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.sp, color: Colors.white)),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
