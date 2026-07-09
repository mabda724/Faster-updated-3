import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/services/supabase_service.dart';
import '../../core/utils/snackbar_utils.dart';

class AppReportBottomSheet extends StatefulWidget {
  final String? bookingId;
  final String? providerId;
  final String? reportedByName;
  final String? reportedById;

  const AppReportBottomSheet({
    super.key,
    this.bookingId,
    this.providerId,
    this.reportedByName,
    this.reportedById,
  });

  @override
  State<AppReportBottomSheet> createState() => _AppReportBottomSheetState();
}

class _AppReportBottomSheetState extends State<AppReportBottomSheet> {
  final _commentCtrl = TextEditingController();
  String? _selectedReason;
  bool _isSubmitting = false;

  static const List<String> _reasons = [
    'سلوك غير لائق',
    'لم يحضر في الوقت المحدد',
    'خدمة سيئة',
    'تجاهل التواصل',
    'طلب مبلغ إضافي',
    'شخص آخر غير المذكور',
    'إزعاج ومضايقات',
    'سبب آخر',
  ];

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selectedReason == null) {
      SnackBarUtils.showError(context, 'الرجاء اختيار سبب التقرير');
      return;
    }
    setState(() => _isSubmitting = true);

    try {
      final data = {
        'is_report': true,
        'reported_by': widget.reportedById ?? SupabaseService.currentUserId,
        'reported_by_name': widget.reportedByName,
        'reason': _selectedReason,
        'comment': _commentCtrl.text.trim(),
        'created_at': DateTime.now().toIso8601String(),
      };
      if (widget.bookingId != null) data['booking_id'] = widget.bookingId;
      if (widget.providerId != null) data['provider_id'] = widget.providerId;

      await SupabaseService.db.from('admin_warnings').insert(data);

      if (!mounted) return;
      Navigator.pop(context);
      SnackBarUtils.showSuccess(context, 'تم إرسال التقرير، سنقوم بالمراجعة');
    } catch (e) {
      if (!mounted) return;
      SnackBarUtils.showError(context, 'فشل إرسال التقرير');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(DesignTokens.space20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(DesignTokens.radiusXl)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          SizedBox(height: DesignTokens.space16),
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(DesignTokens.space3),
                decoration: BoxDecoration(
                  color: AppTheme.errorColor.withValues(alpha: 0.1),
                  borderRadius: DesignTokens.brMd,
                ),
                child: Icon(Icons.flag_rounded, color: AppTheme.errorColor),
              ),
              SizedBox(width: DesignTokens.space12),
              Text(
                'الإبلاغ عن مشكلة',
                style: GoogleFonts.cairo(
                  fontSize: DesignTokens.textTitleMedium,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          SizedBox(height: DesignTokens.space16),
          Text(
            'ما سبب الإبلاغ؟',
            style: GoogleFonts.cairo(
              fontSize: DesignTokens.textBodyMedium,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          SizedBox(height: DesignTokens.space8),
          ..._reasons.map((r) => RadioListTile<String>(
                title: Text(r),
                value: r,
                groupValue: _selectedReason,
                onChanged: (v) => setState(() => _selectedReason = v),
                activeColor: AppTheme.errorColor,
                contentPadding: EdgeInsets.zero,
                dense: true,
              )),
          if (_selectedReason != null) ...[
            SizedBox(height: DesignTokens.space8),
            TextField(
              controller: _commentCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'تفاصيل إضافية (اختياري)',
                border: OutlineInputBorder(
                  borderRadius: DesignTokens.brMd,
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
            ),
          ],
          SizedBox(height: DesignTokens.space16),
          ElevatedButton(
            onPressed: _isSubmitting ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
              minimumSize: Size(double.infinity, DesignTokens.buttonHeight.h),
              shape: RoundedRectangleBorder(
                borderRadius: DesignTokens.brMd,
              ),
            ),
            child: _isSubmitting
                ? SizedBox(
                    width: DesignTokens.iconMd,
                    height: DesignTokens.iconMd,
                    child: const CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.send_rounded, color: Colors.white),
                      SizedBox(width: 8),
                      Text('إرسال التقرير',
                          style: TextStyle(color: Colors.white)),
                    ],
                  ),
          ),
          SizedBox(height: DesignTokens.space8),
        ],
      ),
    );
  }
}
