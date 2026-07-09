import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/services/cart_service.dart';

class ClientCheckoutScreen extends StatefulWidget {
  const ClientCheckoutScreen({super.key});

  @override
  State<ClientCheckoutScreen> createState() => _ClientCheckoutScreenState();
}

class _ClientCheckoutScreenState extends State<ClientCheckoutScreen> {
  final _cart = CartService();
  Map<String, CartItem> _items = {};
  int _paymentMethod = 0;

  static const Color _purple = AppTheme.textSecondary;

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
    const deliveryFee = 15.0;
    final grandTotal = subTotal + deliveryFee;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: Colors.grey[800]),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('????? ?????',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15.sp,
                color: Colors.grey[900])),
        centerTitle: true,
      ),
      body: itemList.isEmpty
          ? const Center(child: Text('????? ?????'))
          : SingleChildScrollView(
              padding: EdgeInsets.all(16.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('????? ???????'),
                  SizedBox(height: 8.h),
                  _buildAddressCard(),
                  SizedBox(height: 24.h),

                  _buildSectionTitle('???? ?????'),
                  SizedBox(height: 8.h),
                  _buildOrderSummary(itemList, subTotal, deliveryFee, grandTotal),
                  SizedBox(height: 24.h),

                  _buildSectionTitle('????? ?????'),
                  SizedBox(height: 8.h),
                  _buildPaymentMethods(),
                  SizedBox(height: 32.h),

                  SizedBox(
                    width: double.infinity,
                    height: 48.h,
                    child: ElevatedButton(
                      onPressed: _showConfirmDialog,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _purple,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16.r)),
                      ),
                      child: Text('????? ????? - \{grandTotal.toStringAsFixed(2)}',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14.sp,
                              color: Colors.white)),
                    ),
                  ),
                  SizedBox(height: 16.h),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title,
        style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14.sp,
            color: Colors.grey[900]));
  }

  Widget _buildAddressCard() {
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.grey[100]!),
      ),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: _purple.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.location_on_rounded, color: _purple, size: 18),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('??????? ???',
                    style: TextStyle(
                        fontSize: 10.sp,
                        color: Colors.grey[400],
                        fontWeight: FontWeight.bold)),
                SizedBox(height: 4.h),
                Text('???? ??????? - ???????',
                    style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800])),
              ],
            ),
          ),
          Icon(Icons.edit_rounded, color: _purple, size: 18),
        ],
      ),
    );
  }

  Widget _buildOrderSummary(List<CartItem> itemList, double subTotal,
      double deliveryFee, double grandTotal) {
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.grey[100]!),
      ),
      child: Column(
        children: [
          ...itemList.map((item) => Padding(
                padding: EdgeInsets.only(bottom: 8.h),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(item.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 12.sp, color: Colors.grey[900])),
                    ),
                    Text('x',
                        style: TextStyle(
                            fontSize: 11.sp, color: Colors.grey[400])),
                    SizedBox(width: 8.w),
                    Text('\{item.totalPrice.toStringAsFixed(2)}',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12.sp,
                            color: Colors.grey[900])),
                  ],
                ),
              )),
          Divider(color: Colors.grey[100]),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('??????? ??????',
                  style: TextStyle(fontSize: 11.sp, color: Colors.grey[500])),
              Text('\{subTotal.toStringAsFixed(2)}',
                  style: TextStyle(fontSize: 11.sp, color: Colors.grey[500])),
            ],
          ),
          SizedBox(height: 6.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('???? ???????',
                  style: TextStyle(fontSize: 11.sp, color: Colors.grey[500])),
              Text('\{deliveryFee.toStringAsFixed(2)}',
                  style: TextStyle(fontSize: 11.sp, color: Colors.grey[500])),
            ],
          ),
          SizedBox(height: 6.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('????????',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14.sp,
                      color: Colors.grey[900])),
              Text('\{grandTotal.toStringAsFixed(2)}',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14.sp,
                      color: _purple)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethods() {
    final methods = ['????? ??? ????????', '????? ?????? / ???', '????? ?????????'];
    final icons = [
      Icons.money_rounded,
      Icons.credit_card_rounded,
      Icons.account_balance_wallet_rounded,
    ];
    return Column(
      children: List.generate(methods.length, (i) {
        final active = _paymentMethod == i;
        return Container(
          margin: EdgeInsets.only(bottom: 10.h),
          padding: EdgeInsets.all(14.w),
          decoration: BoxDecoration(
            color: active ? _purple.withValues(alpha: 0.05) : Colors.white,
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(
                color: active ? _purple : Colors.grey[100]!,
                width: active ? 1.5 : 1),
          ),
          child: InkWell(
            onTap: () => setState(() => _paymentMethod = i),
            borderRadius: BorderRadius.circular(16.r),
            child: Row(
              children: [
                Icon(icons[i],
                    size: 20, color: active ? _purple : Colors.grey[400]),
                SizedBox(width: 12.w),
                Expanded(
                  child: Text(methods[i],
                      style: TextStyle(
                          fontWeight:
                              active ? FontWeight.bold : FontWeight.normal,
                          fontSize: 12.sp,
                          color: active ? _purple : Colors.grey[800])),
                ),
                if (active)
                  Icon(Icons.check_circle_rounded,
                      color: _purple, size: 20),
              ],
            ),
          ),
        );
      }),
    );
  }

  void _showConfirmDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_rounded,
                color: Colors.green[400], size: 48),
            SizedBox(height: 16.h),
            Text('?? ????? ????? ?????!',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16.sp,
                    color: Colors.grey[900])),
            SizedBox(height: 8.h),
            Text('???? ????? ????? ?? ???? ???',
                style: TextStyle(fontSize: 12.sp, color: Colors.grey[500]),
                textAlign: TextAlign.center),
          ],
        ),
        actions: [
          Center(
            child: TextButton(
              onPressed: () {
                _cart.clear();
                Navigator.of(context)
                  ..pop()
                  ..pop();
              },
              child: Text('?????? ??????',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _purple)),
            ),
          ),
        ],
      ),
    );
  }
}
