import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/theme/design_tokens.dart';
import '../../../core/services/supabase_service.dart';
import 'waiting_for_provider_screen.dart';

class BookingLocationTimeScreen extends StatefulWidget {
  final String serviceId;
  final String serviceName;
  final String servicePrice;
  final String serviceImage;

  const BookingLocationTimeScreen({
    super.key,
    required this.serviceId,
    required this.serviceName,
    required this.servicePrice,
    required this.serviceImage,
  });

  @override
  State<BookingLocationTimeScreen> createState() =>
      _BookingLocationTimeScreenState();
}

class _BookingLocationTimeScreenState extends State<BookingLocationTimeScreen> {
  String _selectedTime = 'now';
  DateTime? _customDate;
  String _paymentMethod = 'cash';
  final _notesController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _createBooking() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('يرجى تسجيل الدخول أولاً'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      String timeSlot;
      switch (_selectedTime) {
        case 'today':
          timeSlot = _customDate != null
              ? '${_customDate!.day}/${_customDate!.month}/${_customDate!.year}'
              : 'اليوم';
          break;
        case 'another_day':
          timeSlot = _customDate != null
              ? '${_customDate!.day}/${_customDate!.month}/${_customDate!.year}'
              : 'يوم آخر';
          break;
        default:
          timeSlot = 'الآن';
      }

      final bookingData = {
        'client_id': userId,
        'service_id': widget.serviceId,
        'status': 'pending',
        'total_price': double.tryParse(widget.servicePrice) ?? 0,
        'notes': _notesController.text,
        'time_slot': timeSlot,
        'payment_method': _paymentMethod == 'cash' ? 'cash' : 'online',
        'scheduled_at': DateTime.now().toUtc().toIso8601String(),
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

      final response = await SupabaseService.db
          .from('bookings')
          .insert(bookingData)
          .select()
          .single();

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => WaitingForProviderScreen(
              bookingId: response['id'].toString(),
              serviceName: widget.serviceName,
              totalPrice: double.tryParse(widget.servicePrice) ?? 0,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error creating booking: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ: $e'),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildHeader(),
                    Padding(
                      padding: EdgeInsets.all(DesignTokens.space8.w),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLocationSection(),
                          SizedBox(height: DesignTokens.space6.h),
                          _buildMapPlaceholder(),
                          SizedBox(height: DesignTokens.space6.h),
                          _buildTimeSelection(),
                          SizedBox(height: DesignTokens.space6.h),
                          _buildNotesField(),
                          SizedBox(height: DesignTokens.space6.h),
                          _buildPaymentMethod(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _buildBottomButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        DesignTokens.space8.w,
        DesignTokens.space6.h,
        DesignTokens.space8.w,
        DesignTokens.space4.h,
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 32.sp,
              height: 32.sp,
              alignment: Alignment.center,
              child: Icon(
                Icons.chevron_right_rounded,
                color: AppTheme.textPrimary,
                size: 20.sp,
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                'تأكيد الموقع والوقت',
                style: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.darkSurfaceColor,
                ),
              ),
            ),
          ),
          SizedBox(width: 32.sp),
        ],
      ),
    );
  }

  Widget _buildLocationSection() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(top: 2.sp),
          child: Icon(
            Icons.location_on_rounded,
            color: AppTheme.darkBackgroundColor,
            size: 22.sp,
          ),
        ),
        SizedBox(width: DesignTokens.space3.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'شارع السياحة - الغردقة',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              SizedBox(height: 2.h),
              Text(
                'بجوار السوبر المصرى الجديد',
                style: TextStyle(
                  fontSize: 11.sp,
                  color: AppTheme.textTertiary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMapPlaceholder() {
    return Container(
      width: double.infinity,
      height: 160.h,
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: BorderRadius.circular(DesignTokens.radiusLg.r),
        border: Border.all(color: AppTheme.dividerColor),
      ),
      child: Stack(
        children: [
          // Decorative lines
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Container(
              width: 16.sp,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 16.sp,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 32.sp,
                  height: 32.sp,
                  decoration: const BoxDecoration(
                    color: AppTheme.darkBackgroundColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.location_on_rounded,
                    color: AppTheme.warningColor,
                    size: 16.sp,
                  ),
                ),
                SizedBox(height: DesignTokens.space1.h),
                Container(
                  width: 8.sp,
                  height: 4.sp,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'اختر الموعد المناسب',
          style: TextStyle(
            fontSize: 13.sp,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        SizedBox(height: DesignTokens.space4.h),
        Row(
          children: [
            Expanded(child: _buildTimeCard('now', 'الآن', Icons.flash_on_rounded, 'فوري')),
            SizedBox(width: DesignTokens.space3.w),
            Expanded(child: _buildTimeCard('today', 'اليوم', Icons.calendar_today_rounded, 'خلال اليوم')),
            SizedBox(width: DesignTokens.space3.w),
            Expanded(child: _buildTimeCard('another_day', 'يوم آخر', Icons.date_range_rounded, 'اختر تاريخ')),
          ],
        ),
        if (_selectedTime == 'another_day') ...[
          SizedBox(height: DesignTokens.space4.h),
          GestureDetector(
            onTap: () => _showDatePicker(),
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: DesignTokens.space4.h, horizontal: DesignTokens.space6.w),
              decoration: BoxDecoration(
                color: AppTheme.darkBackgroundColor.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(DesignTokens.radiusMd.r),
                border: Border.all(color: AppTheme.darkBackgroundColor.withValues(alpha: 0.2)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.calendar_month_rounded, color: AppTheme.darkBackgroundColor, size: 18.sp),
                  SizedBox(width: DesignTokens.space3.w),
                  Text(
                    _customDate != null
                        ? '${_customDate!.day}/${_customDate!.month}/${_customDate!.year}'
                        : 'اضغط لتحديد التاريخ',
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                      color: _customDate != null
                          ? AppTheme.darkBackgroundColor
                          : AppTheme.textTertiary,
                    ),
                  ),
                  if (_customDate != null) ...[
                    SizedBox(width: DesignTokens.space4.w),
                    GestureDetector(
                      onTap: () => setState(() => _customDate = null),
                      child: Icon(Icons.close_rounded, size: 16.sp, color: AppTheme.errorColor),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTimeCard(String value, String label, IconData icon, String subtitle) {
    final isSelected = _selectedTime == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTime = value;
          if (value != 'another_day') _customDate = null;
        });
        if (value == 'another_day') _showDatePicker();
      },
      child: Container(
        padding: EdgeInsets.symmetric(vertical: DesignTokens.space5.h, horizontal: DesignTokens.space3.w),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.darkBackgroundColor : Colors.white,
          borderRadius: BorderRadius.circular(DesignTokens.radiusLg.r),
          border: Border.all(
            color: isSelected ? AppTheme.darkBackgroundColor : AppTheme.dividerColor,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: AppTheme.darkBackgroundColor.withValues(alpha: 0.15), blurRadius: 8, offset: const Offset(0, 3))]
              : [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4, offset: const Offset(0, 2))],
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? Colors.white : AppTheme.darkBackgroundColor, size: 24.sp),
            SizedBox(height: DesignTokens.space2.h),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : AppTheme.textPrimary,
              ),
            ),
            SizedBox(height: 2.h),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 8.sp,
                color: isSelected ? Colors.white.withValues(alpha: 0.7) : AppTheme.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showDatePicker() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 60)),
      helpText: 'اختر موعد',
      cancelText: 'إلغاء',
      confirmText: 'تأكيد',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: AppTheme.primaryColor,
                ),
          ),
          child: child!,
        );
      },
    );
    if (date != null) {
      setState(() {
        _selectedTime = 'another_day';
        _customDate = date;
      });
    }
  }

  Widget _buildNotesField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ملاحظات إضافية (اختياري)',
          style: TextStyle(
            fontSize: 11.sp,
            fontWeight: FontWeight.bold,
            color: AppTheme.textSecondary,
          ),
        ),
        SizedBox(height: DesignTokens.space2.h),
        TextField(
          controller: _notesController,
          textDirection: TextDirection.rtl,
          decoration: InputDecoration(
            hintText: 'اكتب أي ملاحظات إضافية هنا',
            hintTextDirection: TextDirection.rtl,
            hintStyle: TextStyle(
              color: AppTheme.borderColor,
              fontSize: 11.sp,
            ),
            border: const UnderlineInputBorder(
              borderSide: BorderSide(color: AppTheme.dividerColor),
            ),
            enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: AppTheme.dividerColor),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: AppTheme.darkBackgroundColor),
            ),
            contentPadding: EdgeInsets.symmetric(
              vertical: DesignTokens.space3.h,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentMethod() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'طريقة الدفع',
          style: TextStyle(
            fontSize: 11.sp,
            fontWeight: FontWeight.bold,
            color: AppTheme.textSecondary,
          ),
        ),
        SizedBox(height: DesignTokens.space3.h),
        Row(
          children: [
            _buildPaymentRadio('cash', 'دفع كاش', Icons.money_rounded),
            SizedBox(width: DesignTokens.space6.w),
            _buildPaymentRadio('online', 'دفع إلكتروني', null),
          ],
        ),
      ],
    );
  }

  Widget _buildPaymentRadio(String value, String label, IconData? icon) {
    final isSelected = _paymentMethod == value;
    return GestureDetector(
      onTap: () => setState(() => _paymentMethod = value),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 16.sp,
            height: 16.sp,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected
                    ? AppTheme.darkBackgroundColor
                    : AppTheme.borderColor,
                width: 2,
              ),
            ),
            child: isSelected
                ? Center(
                    child: Container(
                      width: 8.sp,
                      height: 8.sp,
                      decoration: const BoxDecoration(
                        color: AppTheme.darkBackgroundColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  )
                : null,
          ),
          SizedBox(width: DesignTokens.space2.w),
          if (icon != null) ...[
            Icon(
              icon,
              color: AppTheme.darkBackgroundColor,
              size: 14.sp,
            ),
            SizedBox(width: DesignTokens.space1.w),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 11.sp,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
              color: isSelected
                  ? AppTheme.textSecondary
                  : AppTheme.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomButton() {
    return Container(
      padding: EdgeInsets.all(DesignTokens.space8.w),
      decoration: const BoxDecoration(
        color: Colors.white,
      ),
      child: GestureDetector(
        onTap: _isSubmitting ? null : _createBooking,
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(vertical: DesignTokens.space4.h),
          decoration: BoxDecoration(
            color: AppTheme.darkBackgroundColor,
            borderRadius: BorderRadius.circular(DesignTokens.radiusMd.r),
            boxShadow: [
              BoxShadow(
                color: AppTheme.darkBackgroundColor.withValues(alpha: 0.2),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: _isSubmitting
                ? SizedBox(
                    width: 20.sp,
                    height: 20.sp,
                    child: const CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Text(
                    'اطلب صنايعي',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
