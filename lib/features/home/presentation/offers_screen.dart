import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/design_tokens.dart';
import '../../booking/presentation/tracking_screen.dart';

class OffersScreen extends StatefulWidget {
  const OffersScreen({super.key});

  @override
  State<OffersScreen> createState() => _OffersScreenState();
}

class _OffersScreenState extends State<OffersScreen> {
  String _address = 'جاري تحميل العنوان...';

  final List<Map<String, dynamic>> _offers = [
    {
      'name': 'محمد أحمد',
      'image': null,
      'rating': 4.9,
      'jobs': 342,
      'price': 150,
      'eta': '٢٠ دقيقة',
      'isClosest': true,
    },
    {
      'name': 'أحمد علي',
      'image': null,
      'rating': 4.8,
      'jobs': 215,
      'price': 175,
      'eta': '٣٥ دقيقة',
      'isClosest': false,
    },
    {
      'name': 'خالد محمود',
      'image': null,
      'rating': 4.7,
      'jobs': 189,
      'price': 200,
      'eta': '٤٠ دقيقة',
      'isClosest': false,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: AppTheme.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          children: [
            Text(
              'عروض الأسعار',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 16.sp,
              ),
            ),
            Text(
              'اختر أفضل عرض',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 11.sp,
              ),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: DesignTokens.space6.w,
              vertical: DesignTokens.space4.h,
            ),
            color: Colors.white,
            child: Row(
              children: [
                Icon(Icons.my_location_rounded,
                    color: AppTheme.primaryColor, size: 18),
                SizedBox(width: DesignTokens.space3.w),
                Expanded(
                  child: Text(
                    _address,
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: AppTheme.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppTheme.dividerColor),
          Expanded(
            child: ListView.separated(
              padding: EdgeInsets.all(DesignTokens.space6.w),
              itemCount: _offers.length,
              separatorBuilder: (_, __) => SizedBox(height: DesignTokens.space4.h),
              itemBuilder: (_, i) => _buildOfferCard(_offers[i]),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(
          DesignTokens.space6.w,
          DesignTokens.space4.h,
          DesignTokens.space6.w,
          MediaQuery.of(context).padding.bottom + DesignTokens.space4.h,
        ),
        color: Colors.white,
        child: SizedBox(
          width: double.infinity,
          height: 48.h,
          child: OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.errorColor,
              side: BorderSide(color: AppTheme.errorColor.withValues(alpha: 0.3)),
              shape: RoundedRectangleBorder(
                borderRadius: DesignTokens.brSm,
              ),
            ),
            child: Text(
              'إلغاء الطلب',
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOfferCard(Map<String, dynamic> offer) {
    final isClosest = offer['isClosest'] == true;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: DesignTokens.brLg,
        border: Border.all(
          color: isClosest
              ? AppTheme.tertiaryColor.withValues(alpha: 0.5)
              : AppTheme.dividerColor,
        ),
      ),
      child: Stack(
        children: [
          if (isClosest)
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: DesignTokens.space3.w,
                  vertical: 2.h,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.tertiaryColor,
                  borderRadius: BorderRadius.only(
                    topRight: const Radius.circular(16),
                    bottomLeft: const Radius.circular(8),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.location_on_rounded,
                        color: Colors.white, size: 10),
                    SizedBox(width: 2.w),
                    Text(
                      'الأقرب إليك',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Padding(
            padding: EdgeInsets.all(DesignTokens.space4.w),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28.r,
                  backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.12),
                  child: Text(
                    (offer['name'] as String).isNotEmpty
                        ? (offer['name'] as String)[0]
                        : '?',
                    style: TextStyle(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 18.sp,
                    ),
                  ),
                ),
                SizedBox(width: DesignTokens.space3.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        offer['name'] ?? '',
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Row(
                        children: [
                          Icon(Icons.star_rounded,
                              color: AppTheme.tertiaryColor, size: 14),
                          SizedBox(width: 2.w),
                          Text(
                            offer['rating'].toString(),
                            style: TextStyle(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          SizedBox(width: 4.w),
                          Text(
                            '${offer['jobs']} مهمة',
                            style: TextStyle(
                              fontSize: 10.sp,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(width: DesignTokens.space3.w),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${offer['price']} ج.م',
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      offer['eta'] ?? '',
                      style: TextStyle(
                        fontSize: 10.sp,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    SizedBox(height: DesignTokens.space2.h),
                    SizedBox(
                      height: 32.h,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const TrackingScreen(
                                bookingId: '123',
                              ),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: DesignTokens.brSm,
                          ),
                          padding: EdgeInsets.symmetric(horizontal: 16.w),
                          minimumSize: Size(0, 32.h),
                        ),
                        child: Text(
                          'قبول',
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
