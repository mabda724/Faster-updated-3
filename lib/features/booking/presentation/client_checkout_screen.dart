import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/paymob_service.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/notification_service.dart';
import 'waiting_for_provider_screen.dart';

class ClientCheckoutScreen extends StatefulWidget {
  final String serviceId;
  final String serviceName;
  final String? categoryId;
  final String price;
  final DateTime? scheduledDate;
  final bool isNow; // New parameter for "حالاً" option
  final LatLng location;
  final String? address;

  const ClientCheckoutScreen({
    super.key,
    required this.serviceId,
    required this.serviceName,
    this.categoryId,
    required this.price,
    this.scheduledDate,
    this.isNow = false,
    required this.location,
    this.address,
  });

  @override
  State<ClientCheckoutScreen> createState() => _ClientCheckoutScreenState();
}

class _ClientCheckoutScreenState extends State<ClientCheckoutScreen> {
  bool _isLoading = false;
  String _paymentMethod = 'cash';



  int _extractAmount(String priceStr) {
    final match = RegExp(r'\d+').firstMatch(priceStr);
    return match != null ? (int.tryParse(match.group(0) ?? '0') ?? 0) : 0;
  }

  Future<double> _getCategoryCommission() async {
    String? catId = widget.categoryId;
    if (catId == null) {
      try {
        final service = await SupabaseService.db.from('services').select('category_id').eq('id', widget.serviceId).maybeSingle();
        catId = service?['category_id']?.toString();
      } catch (_) {}
    }
    if (catId != null) {
      try {
        final setting = await SupabaseService.db
            .from('app_settings')
            .select('value')
            .eq('key', 'category_commission_$catId')
            .maybeSingle();
        if (setting != null) {
          return double.tryParse(setting['value'].toString()) ?? 10;
        }
      } catch (_) {}
    }
    return 10;
  }

  Future<void> _processPayment() async {
    final amount = _extractAmount(widget.price);
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('السعر مش مظبوط')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (_paymentMethod == 'cash') {
        await _saveBooking(amount, paymentStatus: 'unpaid', providerId: null);
      } else {
        final uid = SupabaseService.currentUserId;
        if (uid == null) throw Exception('لازم تسجل دخول');

        final profile = await SupabaseService.db
            .from('profiles')
            .select()
            .eq('id', uid)
            .single();
        final name = profile['full_name'] ?? 'Faster User';
        final email = SupabaseService.auth.currentUser?.email ?? 'test@faster.com';
        final phone = profile['phone_number'] ?? profile['phone'] ?? '01010101010';

        final result = await PaymobServiceWrapper.pay(
          amount: amount,
          userId: uid,
          fullName: name,
          email: email,
          phone: phone,
          paymentMethod: _paymentMethod,
          buttonColor: AppTheme.primaryColor,
        );

        if (result.isSuccessful) {
          await _saveBooking(amount, paymentStatus: 'paid', providerId: null);
        } else if (result.isPending) {
          await _saveBooking(amount, paymentStatus: 'pending', providerId: null);
        } else {
          setState(() => _isLoading = false);
          if (mounted) {
            String errorMsg = result.isRejected ? 'البنك رفض العملية' : 'فشلت العملية';
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMsg)));
          }
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        String errorMsg = 'حدث خطأ أثناء الحجز';
        if (e.toString().contains('ClientException') || e.toString().contains('Failed to fetch')) {
          errorMsg = 'لا يمكن الاتصال بالخادم. تأكد من اتصالك بالإنترنت';
        } else if (e.toString().contains('JWT') || e.toString().contains('token')) {
          errorMsg = 'انتهت صلاحية الجلسة. سجل دخولك مرة أخرى';
        } else {
          errorMsg = 'خطأ: $e';
        }
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: AppTheme.errorColor,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'إعادة المحاولة',
              textColor: Colors.white,
              onPressed: _processPayment,
            ),
          ),
        );
      }
    }
  }

  Future<void> _saveBooking(int amount, {
    required String paymentStatus,
    String? transactionId,
    required String? providerId,
  }) async {
    final uid = SupabaseService.currentUserId;
    if (uid == null) throw Exception('User not logged in');

    final commissionRate = await _getCategoryCommission();
    final commissionAmount = (amount * commissionRate / 100);
    final providerEarning = amount - commissionAmount;
    
    // If "حالاً" is selected, use current time and mark as urgent
    final scheduledAt = widget.isNow ? DateTime.now() : (widget.scheduledDate ?? DateTime.now());
    final bookingStatus = 'pending'; // Always use 'pending' status, 'is_urgent' flag handles urgency

    String finalAddress = widget.address ?? 'موقع العميل';
    if (finalAddress == 'موقع العميل') {
      try {
        finalAddress = await LocationService.getAddressFromLatLng(widget.location);
      } catch (_) {}
    }

    final bookingData = {
      'client_id': uid,
      'provider_id': providerId,
      'service_id': int.tryParse(widget.serviceId),
      'status': bookingStatus,
      'payment_method': _paymentMethod,
      'payment_status': paymentStatus,
      'price': amount.toDouble(),
      'total_price': amount.toDouble(),
      'commission_amount': commissionAmount,
      'provider_earning': providerEarning,
      'commission_rate': commissionRate / 100,
      'scheduled_at': scheduledAt.toIso8601String(),
      'address': finalAddress,
      'client_lat': widget.location.latitude,
      'client_lng': widget.location.longitude,
      'is_urgent': widget.isNow, // Mark as urgent if "حالاً" is selected
    };

    if (transactionId != null) {
      bookingData['transaction_id'] = transactionId;
    }

    final booking = await SupabaseService.db.from('bookings').insert(bookingData).select().single();

    // Send broadcast notification to providers in the area
    try {
      await NotificationService.sendPushNotification(
        userId: 'broadcast', // Special user ID for broadcast
        title: 'طلب خدمة جديد',
        body: 'طلب جديد لخدمة ${widget.serviceName}',
        type: 'new_booking',
        data: {
          'booking_id': booking['id'].toString(),
          'service_id': widget.serviceId,
          'service_name': widget.serviceName,
          'category_id': widget.categoryId ?? '',
          'is_urgent': widget.isNow.toString(),
        },
      );
    } catch (e) {
      debugPrint('Broadcast notification error: $e');
    }

    if (!mounted) return;
    // Navigate directly to waiting screen (skip success screen for faster flow)
    Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => WaitingForProviderScreen(
            bookingId: booking['id'],
            serviceName: widget.serviceName,
            totalPrice: amount.toDouble(),
          ),
        ),
        (route) => route.isFirst,
      );
  }

  @override
  Widget build(BuildContext context) {
    final amount = _extractAmount(widget.price);
    final commissionDisplay = (amount * 0.1).toStringAsFixed(0);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'تأكيد الحجز',
          style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.textPrimary, size: 20),
          tooltip: 'العودة',
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
          : SingleChildScrollView(
              padding: EdgeInsets.all(DesignTokens.space24.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSummaryCard(commissionDisplay),
                  SizedBox(height: DesignTokens.space24.h),
                  if (widget.isNow) _buildBroadcastNotice(),
                  SizedBox(height: DesignTokens.space24.h),
                  const Text(
                    'طريقة الدفع',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                  ),
                  SizedBox(height: DesignTokens.space16.h),
                  _paymentOption('card', Icons.credit_card_rounded, 'فيزا أو ماستركارد', 'أسرع وأريح', LinearGradient(colors: [AppTheme.primaryColor, AppTheme.secondaryColor])),
                  SizedBox(height: DesignTokens.space12.h),
                  _paymentOption('wallet', Icons.account_balance_wallet_rounded, 'محفظة موبايل', 'فودافون، اتصالات، أورانج', LinearGradient(colors: [AppTheme.errorColor, AppTheme.errorColor.withValues(alpha: 0.7)])),
                  SizedBox(height: DesignTokens.space12.h),
                  _paymentOption('cash', Icons.money_rounded, 'كاش عند الإتمام', 'ادفع لمقدم الخدمة', LinearGradient(colors: [AppTheme.successColor, AppTheme.successColor.withValues(alpha: 0.7)])),
                  SizedBox(height: 32.h),
                  if (_paymentMethod != 'cash')
                    Container(
                      padding: EdgeInsets.all(DesignTokens.space12.w),
                      margin: EdgeInsets.only(bottom: DesignTokens.space24.h),
                      decoration: BoxDecoration(color: AppTheme.primaryColor.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.2))),
                      child: Row(
                        children: [
                          Icon(Icons.lock_outline, color: AppTheme.primaryColor, size: 20),
                          SizedBox(width: 10.w),
                          Expanded(
                            child: Text('الدفع يتم عبر Paymob الآمنة', style: TextStyle(fontSize: 11, color: AppTheme.primaryColor)),
                          ),
                        ],
                      ),
                    ),
                  SizedBox(
                    width: double.infinity,
                    height: 56.h,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _processPayment,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(_paymentMethod == 'cash' ? Icons.check_circle : Icons.payment, color: Colors.white),
                          SizedBox(width: DesignTokens.space8.w),
                          Text(
                            _paymentMethod == 'cash'
                                ? 'اطلب ونتظر مقدم'
                                : 'ادفع واطلب - $amount جنيه',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: DesignTokens.space16.h),
                  Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.lock_outline, size: 14, color: Colors.grey),
                        SizedBox(width: 6.w),
                        Text('فلوسك في أمان', style: TextStyle(fontSize: 12, color: Colors.grey[400])),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildBroadcastNotice() {
    return Container(
      padding: EdgeInsets.all(DesignTokens.space16.w),
      decoration: BoxDecoration(
        color: AppTheme.infoColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.infoColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(DesignTokens.space8.w),
            decoration: BoxDecoration(color: AppTheme.infoColor.withValues(alpha: 0.2), shape: BoxShape.circle),
            child: const Icon(Icons.flash_on_rounded, color: AppTheme.infoColor, size: 20),
          ),
          SizedBox(width: DesignTokens.space12.w),
          const Expanded(
            child: Text('خدمة فالسريع منه - مقدم الخدمة هيوصلك في أقرب وقت!', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.infoColor)),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String commissionDisplay) {
    return Container(
      padding: EdgeInsets.all(DesignTokens.space20.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: AppTheme.primaryColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.build_rounded, color: AppTheme.primaryColor),
              ),
              SizedBox(width: DesignTokens.space12.w),
              const Text('تفاصيل الطلب', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
            ],
          ),
          SizedBox(height: DesignTokens.space20.h),
          _buildInfoRow('الخدمة', widget.serviceName),
          _buildInfoRow('التاريخ', _formatDate(widget.scheduledDate ?? DateTime.now())),
          _buildInfoRow('الوقت', _formatTime(widget.scheduledDate ?? DateTime.now())),
          _buildInfoRow('الموقع', 'تم تحديد الموقع'),
          const Divider(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('الإجمالي', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
              Text(widget.price, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    const months = ['يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو', 'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'];
    final isToday = DateTime.now().day == date.day && DateTime.now().month == date.month;
    final isTomorrow = DateTime.now().add(const Duration(days: 1)).day == date.day;
    
    if (isToday) return 'اليوم';
    if (isTomorrow) return 'غداً';
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String _formatTime(DateTime date) {
    final hour = date.hour;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'م' : 'ص';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$displayHour:$minute $period';
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _paymentOption(String method, IconData icon, String label, String subtitle, Gradient gradient) {
    final sel = _paymentMethod == method;
    return GestureDetector(
      onTap: () => setState(() => _paymentMethod = method),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: EdgeInsets.all(DesignTokens.space16),
        decoration: BoxDecoration(
          color: sel ? AppTheme.primaryColor.withValues(alpha: 0.05) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: sel ? AppTheme.primaryColor : Colors.grey.shade200, width: sel ? 2 : 1),
          boxShadow: sel ? [BoxShadow(color: AppTheme.primaryColor.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 4))] : [],
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(DesignTokens.space12),
              decoration: BoxDecoration(gradient: gradient, borderRadius: BorderRadius.circular(14)),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            SizedBox(width: 14.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: sel ? AppTheme.primaryColor : AppTheme.textPrimary)),
                  Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 24, height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: sel ? AppTheme.primaryColor : Colors.transparent,
                border: Border.all(color: sel ? AppTheme.primaryColor : Colors.grey.shade300, width: 2),
              ),
              child: sel ? const Icon(Icons.check, color: Colors.white, size: 16) : null,
            ),
          ],
        ),
      ),
    );
  }
}
