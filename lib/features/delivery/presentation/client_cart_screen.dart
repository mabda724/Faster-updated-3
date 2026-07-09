import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/cart_service.dart';
import 'client_address_screen.dart';
import 'client_payment_screen.dart';

class ClientCartScreen extends StatefulWidget {
  const ClientCartScreen({super.key});

  @override
  State<ClientCartScreen> createState() => _ClientCartScreenState();
}

class _ClientCartScreenState extends State<ClientCartScreen> {
  final _cart = CartService();
  Map<String, CartItem> _items = {};

  static const Color _purple = AppTheme.primaryColor;
  static const Color _bgGray = AppTheme.surfaceColor70;

  @override
  void initState() {
    super.initState();
    _items = Map.from(_cart.items);
    _cart.stream.listen((m) {
      if (mounted) setState(() => _items = m);
    });
  }

  @override
  Widget build(BuildContext context) {
    final itemList = _items.values.toList();
    final subTotal = _cart.total;
    const deliveryFee = 10.0;
    const discountRate = 0.2;
    final discount = subTotal * discountRate;
    final grandTotal = subTotal - discount + deliveryFee;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.darkBackgroundColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('سلة المشتريات',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.sp, color: AppTheme.darkBackgroundColor)),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: () {},
            child: Text('تعديل', style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.bold, color: Colors.blue[600])),
          ),
        ],
      ),
      body: itemList.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.shopping_cart_outlined, size: 64, color: Colors.grey[300]),
                  SizedBox(height: 16.h),
                  Text('السلة فارغة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.sp, color: Colors.grey[400])),
                ],
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    padding: EdgeInsets.all(16.w),
                    itemCount: itemList.length,
                    itemBuilder: (_, i) => _buildCartItem(itemList[i]),
                  ),
                ),
                _buildBottom(subTotal, discount, deliveryFee, grandTotal),
              ],
            ),
    );
  }

  Widget _buildCartItem(CartItem item) {
    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      padding: EdgeInsets.all(10.w),
      decoration: BoxDecoration(color: _bgGray, borderRadius: BorderRadius.circular(16.r), border: Border.all(color: Colors.grey[100]!)),
      child: Row(
        children: [
          InkWell(
            onTap: () => _cart.remove(item.id),
            child: Padding(
              padding: EdgeInsets.all(4.w),
              child: Icon(Icons.delete_rounded, color: Colors.red[300], size: 16),
            ),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(' - ',
                    maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.sp, color: AppTheme.darkBackgroundColor)),
                SizedBox(height: 4.h),
                Text(' ج',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10.sp, color: Colors.grey[500])),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12.r), border: Border.all(color: Colors.grey[200]!)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(onTap: () => _cart.updateQuantity(item.id, item.quantity + 1),
                    child: Padding(padding: EdgeInsets.all(4.w), child: Icon(Icons.add, color: _purple, size: 12))),
                SizedBox(width: 4.w),
                Text('', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.sp, color: AppTheme.darkBackgroundColor)),
                SizedBox(width: 4.w),
                InkWell(onTap: () => _cart.updateQuantity(item.id, item.quantity - 1),
                    child: Padding(padding: EdgeInsets.all(4.w), child: Icon(Icons.remove, color: Colors.grey[400], size: 12))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottom(double subTotal, double discount, double deliveryFee, double grandTotal) {
    return Container(
      padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, MediaQuery.of(context).padding.bottom + 16.h),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[100]!)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _row('المجموع الفرعي', ' ج', Colors.grey[500]!, AppTheme.darkBackgroundColor),
          SizedBox(height: 6.h),
          _row('رسوم التوصيل', ' ج', Colors.grey[500]!, AppTheme.darkBackgroundColor),
          SizedBox(height: 6.h),
          _row('الخصم', '- ج', AppTheme.successColor, AppTheme.successColor),
          Divider(height: 16.h, color: Colors.grey[200]!),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('الإجمالي', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14.sp, color: AppTheme.darkBackgroundColor)),
              Text(' ج',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16.sp, color: _purple)),
            ],
          ),
          SizedBox(height: 16.h),
          SizedBox(
            width: double.infinity, height: 48.h,
            child: ElevatedButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ClientAddressScreen(
                    onSelected: (address, label) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ClientPaymentScreen(address: address, addressLabel: label),
                        ),
                      );
                    },
                  ),
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _purple,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                elevation: 4,
                shadowColor: _purple.withValues(alpha: 0.3),
              ),
              child: Text('إتمام الطلب',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.sp, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value, Color labelColor, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w500, color: labelColor)),
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.sp, color: valueColor)),
      ],
    );
  }
}
