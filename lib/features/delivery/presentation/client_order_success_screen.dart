import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/theme/app_theme.dart';
import 'client_delivery_tracking_screen.dart';

class ClientOrderSuccessScreen extends StatelessWidget {
  final Map<String, dynamic>? bookingData;
  const ClientOrderSuccessScreen({super.key, this.bookingData});

  static const Color _purple = AppTheme.primaryColor;
  static const Color _bgGray = AppTheme.surfaceColor70;

  @override
  Widget build(BuildContext context) {
    final code = bookingData?['order_code'] as String? ?? '#F25847';
    final total = (bookingData?['total_price'] as num?)?.toDouble() ?? 0;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                Positioned(top: 60, left: 48, child: Container(width: 8, height: 8, decoration: BoxDecoration(color: Colors.green[400], shape: BoxShape.circle))),
                Positioned(top: 128, right: 64, child: Container(width: 10, height: 10, decoration: BoxDecoration(color: Colors.blue[400], shape: BoxShape.circle))),
                Positioned(bottom: 200, left: 80, child: Container(width: 12, height: 12, decoration: BoxDecoration(color: Colors.amber[400], shape: BoxShape.circle))),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(height: MediaQuery.of(context).padding.top + 60),
                    Container(
                      width: 80, height: 80,
                      decoration: BoxDecoration(
                        color: AppTheme.successColor, shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: AppTheme.successColor.withValues(alpha: 0.3), blurRadius: 20)],
                      ),
                      child: const Icon(Icons.check_rounded, color: Colors.white, size: 36),
                    ),
                    SizedBox(height: 24.h),
                    Text('تم استلام طلبك بنجاح',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16.sp, color: AppTheme.darkBackgroundColor)),
                    SizedBox(height: 8.h),
                    Text('رقم الطلب', style: TextStyle(fontSize: 11.sp, color: Colors.grey[400])),
                    SizedBox(height: 4.h),
                    Text(code,
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14.sp, color: _purple, letterSpacing: 1)),
                    SizedBox(height: 32.h),
                    Container(
                      margin: EdgeInsets.symmetric(horizontal: 24.w),
                      padding: EdgeInsets.all(16.w),
                      decoration: BoxDecoration(
                        color: _bgGray, borderRadius: BorderRadius.circular(16.r),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.local_shipping_rounded, color: _purple, size: 24),
                          SizedBox(width: 12.w),
                          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('إجمالي المبلغ', style: TextStyle(fontSize: 10.sp, color: Colors.grey[400])),
                            SizedBox(height: 4.h),
                            Text(' ج',
                                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.sp, color: AppTheme.darkBackgroundColor)),
                          ]),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, MediaQuery.of(context).padding.bottom + 16.h),
            child: Column(children: [
              SizedBox(
                width: double.infinity, height: 48.h,
                child: ElevatedButton(
                  onPressed: () => Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => ClientDeliveryTrackingScreen(bookingData: bookingData)),
                    (r) => false,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _purple,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                    elevation: 4, shadowColor: _purple.withValues(alpha: 0.3),
                  ),
                  child: Text('متابعة الطلب',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.sp, color: Colors.white)),
                ),
              ),
              SizedBox(height: 8.h),
              TextButton(
                onPressed: () => Navigator.popUntil(context, (r) => r.isFirst),
                child: Text('العودة للرئيسية',
                    style: TextStyle(fontSize: 12.sp, color: Colors.grey[400], fontWeight: FontWeight.bold)),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}
