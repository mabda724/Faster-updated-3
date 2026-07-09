import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/design_tokens.dart';

class RatingsScreen extends StatefulWidget {
  const RatingsScreen({super.key});

  @override
  State<RatingsScreen> createState() => _RatingsScreenState();
}

class _RatingsScreenState extends State<RatingsScreen> {
  int _rating = 0;
  final _notesController = TextEditingController();

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close_rounded,
              color: AppTheme.textPrimary, size: 22),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'تقييم الخدمة',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 16.sp,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: DesignTokens.space8.w),
        child: Column(
          children: [
            SizedBox(height: 24.h),
            CircleAvatar(
              radius: 45.r,
              backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.12),
              child: Text(
                'ف',
                style: TextStyle(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 28.sp,
                ),
              ),
            ),
            SizedBox(height: DesignTokens.space4.h),
            Text(
              'فني الصيانة',
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              'خدمة منزلية',
              style: TextStyle(
                fontSize: 13.sp,
                color: AppTheme.textSecondary,
              ),
            ),
            SizedBox(height: 24.h),
            Text(
              'كيف كانت تجربتك مع الفني؟',
              style: TextStyle(
                fontSize: 15.sp,
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: DesignTokens.space6.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) {
                final starIndex = i + 1;
                return GestureDetector(
                  onTap: () => setState(() => _rating = starIndex),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4.w),
                    child: Icon(
                      starIndex <= _rating
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                      color: AppTheme.tertiaryColor,
                      size: 40.sp,
                    ),
                  ),
                );
              }),
            ),
            SizedBox(height: DesignTokens.space8.h),
            TextField(
              controller: _notesController,
              textDirection: TextDirection.rtl,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'ملاحظات إضافية...',
                hintTextDirection: TextDirection.rtl,
                filled: true,
                fillColor: Colors.grey[50],
                border: OutlineInputBorder(
                  borderRadius: DesignTokens.brLg,
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: DesignTokens.brLg,
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: DesignTokens.brLg,
                  borderSide: BorderSide(
                    color: AppTheme.primaryColor.withValues(alpha: 0.3),
                  ),
                ),
                contentPadding: EdgeInsets.all(DesignTokens.space6.w),
              ),
            ),
            SizedBox(height: DesignTokens.space8.h),
            SizedBox(
              width: double.infinity,
              height: 52.h,
              child: ElevatedButton(
                onPressed: _rating == 0
                    ? null
                    : () {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('تم إرسال التقييم، شكراً لك!'),
                            backgroundColor: AppTheme.successColor,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: DesignTokens.brSm,
                            ),
                          ),
                        );
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppTheme.primaryColor.withValues(alpha: 0.3),
                  shape: RoundedRectangleBorder(
                    borderRadius: DesignTokens.brSm,
                  ),
                ),
                child: Text(
                  'إرسال التقييم',
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            SizedBox(height: 40.h),
          ],
        ),
      ),
    );
  }
}
