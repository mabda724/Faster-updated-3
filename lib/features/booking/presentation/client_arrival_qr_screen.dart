import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/design_tokens.dart';

class ClientArrivalQrScreen extends StatelessWidget {
  final String bookingId;
  final String arrivalCode;

  const ClientArrivalQrScreen({
    super.key,
    required this.bookingId,
    required this.arrivalCode,
  });

  @override
  Widget build(BuildContext context) {
    final payload = 'FASTER_ARRIVAL:$bookingId:$arrivalCode';

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Column(
        children: [
          SizedBox(height: 24.h),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 14.h),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
            ),
            child: Row(children: [
              Icon(Icons.info_rounded, color: AppTheme.primaryColor, size: 22.sp),
              SizedBox(width: 12.w),
              Expanded(
                child: Text(
                  'اعرض هذا الباركود لمقدم الخدمة عند الوصول',
                  style: TextStyle(
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 13.sp,
                  ),
                ),
              ),
            ]),
          ),
          SizedBox(height: 32.h),
          Container(
            padding: EdgeInsets.all(DesignTokens.space24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.textPrimary.withOpacity(0.06),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(children: [
              Container(
                padding: EdgeInsets.all(DesignTokens.space16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.primaryColor.withOpacity(0.15)),
                ),
                child: QrImageView(
                  data: payload,
                  version: QrVersions.auto,
                  size: 240,
                  eyeStyle: QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: AppTheme.primaryColor,
                  ),
                  dataModuleStyle: QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              SizedBox(height: 20.h),
              Text(
                'اكود الاحتياطي',
                style: TextStyle(
                  color: AppTheme.textPrimary.withOpacity(0.7),
                  fontSize: 12.sp,
                ),
              ),
              SizedBox(height: 8.h),
              Container(
                padding: EdgeInsets.symmetric(horizontal: DesignTokens.space20, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Text(
                  arrivalCode,
                  style: TextStyle(
                    fontSize: 22.sp,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 4,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
            ]),
          ),
          SizedBox(height: 24.h),
          Container(
            padding: EdgeInsets.symmetric(horizontal: DesignTokens.space16, vertical: DesignTokens.space12),
            decoration: BoxDecoration(
              color: AppTheme.warningColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.timer_rounded, color: AppTheme.warningColor, size: 18.sp),
                SizedBox(width: 8.w),
                Text(
                  'ينتهي صلاحية الباركود بعد ساعة من وصول المقدم',
                  style: TextStyle(
                    color: AppTheme.warningColor,
                    fontSize: 12.sp,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
