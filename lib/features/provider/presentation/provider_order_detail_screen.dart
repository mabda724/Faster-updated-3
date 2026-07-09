import 'dart:async';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/design_tokens.dart';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/compass_service.dart';
import '../../../core/services/notification_service.dart';
import '../../chat/presentation/chat_screen.dart';
import '../../booking/presentation/tracking_screen.dart';
import 'provider_delivery_tracking_screen.dart';

class ProviderOrderDetailScreen extends StatefulWidget {
  final Map<String, dynamic> booking;
  const ProviderOrderDetailScreen({super.key, required this.booking});
  @override
  State<ProviderOrderDetailScreen> createState() =>
      _ProviderOrderDetailScreenState();
}

class _ProviderOrderDetailScreenState extends State<ProviderOrderDetailScreen> {
  static const Color _providerPrimary = AppTheme.primaryColor;
  static const Color _accentYellow = AppTheme.warningColor;
  static const Color _accentGreen = AppTheme.successColor;

  late Map<String, dynamic> _booking;
  bool _isUpdating = false;
  StreamSubscription? _subscription;

  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  double _selectedPrice = 0;

  @override
  void initState() {
    super.initState();
    _booking = widget.booking;
    _listen();
    if (_booking['status'] == 'on_the_way' ||
        _booking['status'] == 'arrived') {
      CompassService.startTracking();
    }
    final total = double.tryParse(
            _booking['total_price']?.toString() ??
                _booking['price']?.toString() ??
                '0') ??
        0;
    _selectedPrice = total > 0 ? total : 100;
    _priceController.text = _selectedPrice.toStringAsFixed(0);
  }

  void _listen() {
    _subscription = SupabaseService.db
        .from('bookings')
        .stream(primaryKey: ['id'])
        .eq('id', _booking['id'])
        .listen((data) {
      if (data.isNotEmpty && mounted) {
        setState(() {
          final newData = data.first;
          final oldProfiles = _booking['profiles'];
          final oldServices = _booking['services'];
          _booking = newData;
          if (oldProfiles != null) _booking['profiles'] = oldProfiles;
          if (oldServices != null) _booking['services'] = oldServices;
        });
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    CompassService.stopTracking();
    _priceController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _updateStatus(String status) async {
    setState(() => _isUpdating = true);
    try {
      final bookingId = _booking['id'];
      final currentUserId = SupabaseService.currentUserId;
      if (currentUserId == null) throw 'يجب تسجيل الدخول أولاً';

      final isBroadcastAccept =
          _booking['provider_id'] == null && status == 'accepted';

      if (isBroadcastAccept) {
        final activeOrders = await SupabaseService.db
            .from('bookings')
            .select('id, status, services(title)')
            .eq('provider_id', currentUserId)
            .inFilter('status',
                ['accepted', 'on_the_way', 'arrived', 'in_progress'])
            .limit(1);

        if (activeOrders.isNotEmpty) {
          final active = activeOrders.first;
          final serviceTitle = active['services']?['title'] ?? 'خدمة';
          if (mounted) {
            setState(() => _isUpdating = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    'لديك طلب نشط بالفعل ($serviceTitle). أكمله أولاً قبل قبول طلب جديد.'),
                backgroundColor: AppTheme.errorColor,
                duration: const Duration(seconds: 4),
              ),
            );
          }
          return;
        }

        final bool accepted = await SupabaseService.db.rpc(
            'accept_broadcast_booking',
            params: {
              'p_booking_id': bookingId,
              'p_provider_id': currentUserId,
            });

        if (!accepted) {
          final check = await SupabaseService.db
              .from('bookings')
              .select('provider_id')
              .eq('id', bookingId)
              .maybeSingle();

          if (check?['provider_id'] != currentUserId) {
            if (mounted) _snack('تم قبول الطلب من قبل مقدم آخر');
            setState(() => _isUpdating = false);
            return;
          }
        }
      } else {
        await SupabaseService.db
            .from('bookings')
            .update({'status': status}).eq('id', bookingId);
      }

      if (mounted) {
        setState(() {
          _booking['status'] = status;
          if (isBroadcastAccept) _booking['provider_id'] = currentUserId;
          _isUpdating = false;
        });
      }

      final clientId = _booking['client_id']?.toString();
      final serviceName = _booking['services']?['title'] ?? 'الخدمة';
      if (clientId != null) {
        try {
          String title = '';
          String body = '';
          String notifType = 'order_status';

          if (isBroadcastAccept) {
            title = 'تم قبول طلبك';
            body = 'قام مقدم الخدمة بقبول طلب $serviceName';
            notifType = 'new_booking';
          } else if (status == 'on_the_way') {
            title = 'مقدم الخدمة في الطريق';
            body = 'مقدم الخدمة في الطريق إليك لتنفيذ $serviceName';
          } else if (status == 'arrived') {
            title = 'مقدم الخدمة وصل';
            body = 'مقدم الخدمة وصل لموقعك لتنفيذ $serviceName';
          } else if (status == 'in_progress') {
            title = 'بدأ العمل';
            body = 'مقدم الخدمة بدأ في تنفيذ $serviceName';
          } else if (status == 'completed') {
            title = 'تم إتمام الخدمة';
            body = 'تم إتمام $serviceName بنجاح';
          } else if (status == 'cancelled') {
            title = 'تم إلغاء الطلب';
            body = 'تم إلغاء طلب $serviceName';
          }

          if (title.isNotEmpty) {
            await NotificationService.sendPushNotification(
              userId: clientId,
              title: title,
              body: body,
              type: notifType,
              data: {
                'booking_id': bookingId.toString(),
                'status': status,
                'service_name': serviceName,
              },
            );
          }
        } catch (e) {
          debugPrint('FCM notification error: $e');
        }
      }

      if (status == 'completed') {
        final total = double.tryParse(
                _booking['total_price']?.toString() ??
                    _booking['price']?.toString() ??
                    '0') ??
            0;
        final profile = await SupabaseService.db
            .from('provider_profiles')
            .select('wallet_balance')
            .eq('id', SupabaseService.currentUserId!)
            .maybeSingle();
        final currentBalance =
            double.tryParse(profile?['wallet_balance']?.toString() ?? '0') ?? 0;
        await SupabaseService.db
            .from('provider_profiles')
            .update({'wallet_balance': currentBalance + total})
            .eq('id', SupabaseService.currentUserId!);

        await SupabaseService.db.from('transactions').insert({
          'provider_id': SupabaseService.currentUserId!,
          'amount': total,
          'type': 'earning',
          'description': 'أرباح الطلب رقم ${_booking['id']}',
          'booking_id': _booking['id'],
        });

        await _checkWalletThreshold();
      }

      if (isBroadcastAccept) {
        final freshData = await SupabaseService.db
            .from('bookings')
            .select(
                '*, services(title, price), profiles!bookings_client_id_fkey(full_name, phone_number, phone, avatar_url)')
            .eq('id', bookingId)
            .maybeSingle();
        if (freshData != null && mounted) {
          setState(() => _booking = freshData);
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isUpdating = false);
      if (mounted) _snack('حدث خطأ: ${e.toString()}');
    }
  }

  Future<void> _checkWalletThreshold() async {
    try {
      final setting = await SupabaseService.db
          .from('app_settings')
          .select('value')
          .eq('key', 'wallet_auto_offline_threshold')
          .maybeSingle();
      if (setting == null) return;
      final enabled = setting['value']?['enabled'] ?? false;
      if (!enabled) return;
      final threshold =
          (setting['value']?['value'] as num?)?.toDouble() ?? -50;

      final profile = await SupabaseService.db
          .from('provider_profiles')
          .select('wallet_balance, is_online')
          .eq('id', SupabaseService.currentUserId!)
          .maybeSingle();
      if (profile == null) return;

      final balance = (profile['wallet_balance'] as num?)?.toDouble() ?? 0;
      if (balance <= threshold && profile['is_online'] == true) {
        await SupabaseService.db
            .from('provider_profiles')
            .update({'is_online': false})
            .eq('id', SupabaseService.currentUserId!);
        if (mounted) {
          _snack('تم إيقاف الاستقبال تلقائياً بسبب رصيد المحفظة');
        }
      }
    } catch (_) {}
  }

  Future<void> _cancelOrder() async {
    final reasonCtrl = TextEditingController();
    final result = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (ctx) => AlertDialog(
              shape:
                  RoundedRectangleBorder(borderRadius: DesignTokens.brXl),
              title: Row(children: [
                Icon(Icons.warning_rounded,
                    color: AppTheme.errorColor, size: 24),
                SizedBox(width: DesignTokens.space5.w),
                Text('إلغاء الطلب',
                    style: TextStyle(color: AppTheme.errorColor)),
              ]),
              content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('هل أنت متأكد من إلغاء هذا الطلب؟',
                        style: TextStyle(
                            fontSize: DesignTokens.textBodyLarge)),
                    SizedBox(height: DesignTokens.space6.h),
                    FutureBuilder<Map<String, dynamic>?>(
                      future: _getCancelInfo(),
                      builder: (_, snap) {
                        if (snap.connectionState != ConnectionState.done)
                          return SizedBox.shrink();
                        if (snap.hasError) return SizedBox.shrink();
                        if (snap.data == null) return SizedBox.shrink();
                        final type = snap.data!['deduction_type'] ?? '';
                        final minutes =
                            snap.data!['minutes_since_accept'] ?? 0;
                        if (type == 'free') {
                          return Container(
                            padding:
                                EdgeInsets.all(DesignTokens.space10),
                            decoration: BoxDecoration(
                                color: AppTheme.successColor
                                    .withValues(alpha: 0.1),
                                borderRadius: DesignTokens.brMd),
                            child: Row(children: [
                              Icon(Icons.check_circle_rounded,
                                  color: AppTheme.successColor,
                                  size: 18),
                              SizedBox(width: DesignTokens.space4.w),
                              Expanded(
                                  child: Text(
                                      'إلغاء مجاني - مر ${minutes.toStringAsFixed(0)} دقيقة من القبول',
                                      style: TextStyle(
                                          color: AppTheme.successColor,
                                          fontSize: DesignTokens
                                              .textBodyMedium))),
                            ]),
                          );
                        }
                        if (type == 'commission') {
                          return Container(
                            padding:
                                EdgeInsets.all(DesignTokens.space10),
                            decoration: BoxDecoration(
                                color: AppTheme.tertiaryColor
                                    .withValues(alpha: 0.1),
                                borderRadius: DesignTokens.brMd),
                            child: Row(children: [
                              Icon(Icons.info_rounded,
                                  color: AppTheme.tertiaryColor,
                                  size: 18),
                              SizedBox(width: DesignTokens.space4.w),
                              Expanded(
                                  child: Text(
                                      'سيتم خصم عمولة - مر ${minutes.toStringAsFixed(0)} دقيقة من القبول',
                                      style: TextStyle(
                                          color: AppTheme.tertiaryColor,
                                          fontSize: DesignTokens
                                              .textBodyMedium))),
                            ]),
                          );
                        }
                        return Container(
                          padding: EdgeInsets.all(DesignTokens.space10),
                          decoration: BoxDecoration(
                              color: AppTheme.errorColor
                                  .withValues(alpha: 0.1),
                              borderRadius: DesignTokens.brMd),
                          child: Row(children: [
                            Icon(Icons.block_rounded,
                                color: AppTheme.errorColor, size: 18),
                            SizedBox(width: DesignTokens.space4.w),
                            Expanded(
                                child: Text(
                                    'لا يمكن الإلغاء - تواصل مع خدمة العملاء',
                                    style: TextStyle(
                                        color: AppTheme.errorColor,
                                        fontSize: DesignTokens
                                            .textBodyMedium))),
                          ]),
                        );
                      },
                    ),
                    SizedBox(height: DesignTokens.space6.h),
                    TextField(
                      controller: reasonCtrl,
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: 'سبب الإلغاء (مطلوب)',
                        border: OutlineInputBorder(
                            borderRadius: DesignTokens.brMd),
                      ),
                    ),
                  ]),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text('تراجع')),
                ElevatedButton(
                  onPressed: () => Navigator.pop(
                      ctx, {'reason': reasonCtrl.text.trim()}),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.errorColor),
                  child: Text('إلغاء الطلب',
                      style:
                          TextStyle(color: AppTheme.surfaceColor)),
                ),
              ],
            ));

    if (result == null ||
        (result['reason'] as String?)?.isEmpty == true) return;

    setState(() => _isUpdating = true);
    try {
      final response = await SupabaseService.db.rpc(
          'cancel_booking_graduated',
          params: {
            'p_booking_id': _booking['id'],
            'p_cancelled_by': SupabaseService.currentUserId!,
            'p_reason': result['reason'],
          });

      if (response?['success'] == true) {
        final type = response?['deduction_type'] ?? '';
        if (type == 'free') {
          if (mounted)
            _snack('تم إلغاء الطلب مجاناً وسيتم تحويله لمقدم آخر');
        } else if (type == 'commission') {
          final deducted = response?['commission_deducted'] ?? 0;
          if (mounted)
            _snack('تم إلغاء الطلب مع خصم عمولة $deducted جنيه');
        }
        if (mounted) Navigator.pop(context, true);
      } else {
        final error = response?['error']?.toString() ?? 'فشل الإلغاء';
        if (mounted) _snack(error);
      }
    } catch (e) {
      if (mounted) _snack('خطأ: $e');
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  Future<Map<String, dynamic>> _getCancelInfo() async {
    final acceptedAt = _booking['accepted_at'];
    if (acceptedAt == null) {
      return {'deduction_type': 'free', 'minutes_since_accept': 0};
    }
    final minutes = DateTime.now()
        .difference(DateTime.parse(acceptedAt.toString()))
        .inMinutes
        .toDouble();
    int freeMinutes = 5;
    int commissionMinutes = 30;
    try {
      final s1 = await SupabaseService.db
          .from('app_settings')
          .select('value')
          .eq('key', 'cancel_free_minutes')
          .maybeSingle();
      freeMinutes = (s1?['value']?['minutes'] as num?)?.toInt() ?? 5;
      final s2 = await SupabaseService.db
          .from('app_settings')
          .select('value')
          .eq('key', 'cancel_commission_minutes')
          .maybeSingle();
      commissionMinutes =
          (s2?['value']?['minutes'] as num?)?.toInt() ?? 30;
    } catch (_) {}

    String type;
    if (minutes <= freeMinutes) {
      type = 'free';
    } else if (minutes <= commissionMinutes) {
      type = 'commission';
    } else {
      type = 'blocked';
    }

    return {'deduction_type': type, 'minutes_since_accept': minutes};
  }

  Future<void> _offerPrice([bool isEdit = false]) async {
    final existingOfferedPrice = _toDouble(_booking['offered_price']);
    final priceCtrl = TextEditingController(
        text: isEdit && (existingOfferedPrice ?? 0) > 0
            ? existingOfferedPrice!.toStringAsFixed(0)
            : '');
    final reasonCtrl = TextEditingController(
        text: isEdit ? (_booking['offered_price_reason'] ?? '') : '');
    final basePrice = double.tryParse(
          _booking['total_price']?.toString() ??
              _booking['price']?.toString() ??
              '0',
        ) ??
        0;

    final result = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: DesignTokens.brXl),
              title: Row(children: [
                Icon(isEdit ? Icons.edit_rounded : Icons.local_offer_rounded,
                    color: _accentYellow, size: 24),
                SizedBox(width: DesignTokens.space5.w),
                Text(isEdit ? 'تعديل عرض السعر' : 'عرض سعر جديد'),
              ]),
              content: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(
                    'السعر الأساسي: ${basePrice.toStringAsFixed(0)} جنيه',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textSecondary)),
                SizedBox(height: DesignTokens.space6.h),
                TextField(
                  controller: priceCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'السعر المقترح',
                    suffixText: 'جنيه',
                    border: OutlineInputBorder(
                        borderRadius: DesignTokens.brMd),
                  ),
                ),
                SizedBox(height: DesignTokens.space6.h),
                TextField(
                  controller: reasonCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'سبب تغيير السعر (اختياري)',
                    border: OutlineInputBorder(
                        borderRadius: DesignTokens.brMd),
                  ),
                ),
              ]),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text('إلغاء')),
                ElevatedButton(
                  onPressed: () {
                    final price = double.tryParse(priceCtrl.text);
                    if (price == null || price <= 0) {
                      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                          content: Text('الرجاء إدخال سعر صحيح'),
                          backgroundColor: AppTheme.errorColor));
                    } else if (price <= basePrice) {
                      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                          content: Text(
                              'السعر يجب أن يكون أعلى من ${basePrice.toStringAsFixed(0)} جنيه'),
                          backgroundColor: AppTheme.errorColor));
                    } else {
                      Navigator.pop(ctx, {
                        'price': price,
                        'reason': reasonCtrl.text.trim()
                      });
                    }
                  },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: _accentGreen),
                  child: Text(isEdit ? 'تحديث العرض' : 'إرسال العرض',
                      style: TextStyle(
                          color: AppTheme.surfaceColor)),
                ),
              ],
            ));

    if (result == null) return;
    setState(() => _isUpdating = true);
    try {
      final response = await SupabaseService.db.rpc(
          'provider_offer_price',
          params: {
            'p_booking_id': _booking['id'],
            'p_provider_id': SupabaseService.currentUserId!,
            'p_offered_price': result['price'],
            'p_reason': result['reason'],
          });
      if (response?['success'] == true) {
        if (mounted) _snack(isEdit ? 'تم تعديل عرض السعر' : 'تم إرسال عرض السعر للعميل');

        final clientId = _booking['client_id']?.toString();
        final serviceName =
            _booking['services']?['title'] ?? 'الخدمة';
        if (clientId != null) {
          try {
            await NotificationService.sendPushNotification(
              userId: clientId,
              title: isEdit ? 'تم تعديل عرض السعر' : 'عرض سعر جديد',
              body:
                  'قام مقدم الخدمة ${isEdit ? 'بتعديل عرض السعر إلى' : 'باقتراح سعر'} ${result['price'].toStringAsFixed(0)} جنيه لخدمة $serviceName',
              type: 'price_offer',
              data: {
                'booking_id': _booking['id'].toString(),
                'offered_price': result['price'].toString(),
                'service_name': serviceName,
              },
            );
          } catch (e) {
            debugPrint('FCM price offer notification error: $e');
          }
        }
      } else {
        if (mounted)
          _snack(response?['error']?.toString() ?? 'فشل إرسال العرض');
      }
    } catch (e) {
      if (mounted) _snack('خطأ: $e');
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  Future<void> _offerFreeService() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: DesignTokens.brXl),
        title: Row(children: [
          Icon(Icons.card_giftcard_rounded,
              color: AppTheme.successColor, size: 24),
          SizedBox(width: DesignTokens.space5.w),
          Text('خدمة مجانية'),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(
              'هل أنت متأكد من تقديم هذه الخدمة مجاناً؟',
              style: TextStyle(
                  fontSize: DesignTokens.textTitleMedium)),
          SizedBox(height: DesignTokens.space6.h),
          Text(
              'سيتم تحديث السعر إلى 0 جنيه ولن يتم خصم أي عمولة.',
              style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: DesignTokens.textBodyLarge)),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('إلغاء')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.successColor),
            child: Text('نعم، خدمة مجانية',
                style:
                    TextStyle(color: AppTheme.surfaceColor)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isUpdating = true);
    try {
      final response = await SupabaseService.db.rpc(
          'provider_offer_free_service',
          params: {
            'p_booking_id': _booking['id'],
            'p_provider_id': SupabaseService.currentUserId!,
          });
      if (response?['success'] == true) {
        if (mounted) _snack('تم تقديم الخدمة مجاناً');

        final clientId = _booking['client_id']?.toString();
        final serviceName =
            _booking['services']?['title'] ?? 'الخدمة';
        if (clientId != null) {
          try {
            await NotificationService.sendPushNotification(
              userId: clientId,
              title: 'خدمة مجانية!',
              body:
                  'قام مقدم الخدمة بتقديم خدمة $serviceName مجاناً',
              type: 'free_service',
              data: {
                'booking_id': _booking['id'].toString(),
                'service_name': serviceName,
              },
            );
          } catch (e) {
            debugPrint('FCM free service notification error: $e');
          }
        }
      } else {
        if (mounted)
          _snack(response?['error']?.toString() ??
              'فشل تقديم الخدمة مجاناً');
      }
    } catch (e) {
      if (mounted) _snack('خطأ: $e');
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  Future<void> _uploadFaultPhoto() async {
    final file = await ImagePicker()
        .pickImage(source: ImageSource.camera, maxWidth: 524, imageQuality: 80);
    if (file == null) return;
    setState(() => _isUpdating = true);
    try {
      final bytes = await file.readAsBytes();
      final name =
          'fault_${_booking['id']}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final bucket = SupabaseService.storage.from('booking-evidence');
      await bucket.uploadBinary(name, bytes);
      final url = bucket.getPublicUrl(name);

      await SupabaseService.db
          .from('bookings')
          .update({
            'fault_photo_url': url,
          })
          .eq('id', _booking['id']);

      if (mounted) _snack('تم رفع صورة العطل بنجاح');
    } catch (e) {
      if (mounted) _snack('خطأ في رفع الصورة: $e');
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg, textAlign: TextAlign.center),
          backgroundColor: _providerPrimary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: DesignTokens.brMd),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final status = _booking['status'] ?? 'pending';
    final client = _booking['profiles'];
    final total = double.tryParse(
            _booking['total_price']?.toString() ??
                _booking['price']?.toString() ??
                '0') ??
        0;
    final orderCode = _booking['order_code'] ?? '';
    final faultPhoto = _booking['fault_photo_url'];
    final offeredPrice = _toDouble(_booking['offered_price']);
    final priceOfferStatus = _booking['price_offer_status'] ?? 'none';
    final isMyBooking =
        _booking['provider_id'] == SupabaseService.currentUserId;
    final clientName = client?['full_name'] ?? 'غير محدد';
    final distance = _booking['distance_km']?.toString() ?? '--';
    final serviceName =
        _booking['services']?['title'] ?? 'الخدمة';
    final clientPhone = (status != 'pending')
        ? (client?['phone_number'] ?? client?['phone'] ?? 'غير محدد')
        : 'يظهر بعد الموافقة';

    if (status == 'completed') return _buildInvoiceView();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close_rounded, color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'عرض سعر',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: DesignTokens.textTitleLarge,
          ),
        ),
        centerTitle: true,
        actions: [
          if (['accepted', 'on_the_way', 'arrived'].contains(status) &&
              isMyBooking)
            IconButton(
              icon: Icon(Icons.cancel_rounded,
                  color: AppTheme.errorColor),
              onPressed: _cancelOrder,
              tooltip: 'إلغاء الطلب',
            ),
        ],
      ),
      bottomNavigationBar: status == 'pending' || status == 'accepted'
          ? _buildBottomBar()
          : null,
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (status == 'pending' || status == 'accepted') ...[
              _buildPriceOfferSection(total, serviceName),
              SizedBox(height: 20.h),
              _buildSummaryBox(clientName, distance, serviceName),
              SizedBox(height: 20.h),
            ],
            if (orderCode.isNotEmpty)
              Center(
                child: Container(
                  margin: EdgeInsets.only(bottom: 16.h),
                  padding: EdgeInsets.symmetric(
                      horizontal: 16.w, vertical: 8.h),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                        colors: [_accentGreen, _providerPrimary]),
                    borderRadius: DesignTokens.brXl,
                    boxShadow: [
                      BoxShadow(
                          color: _providerPrimary.withValues(alpha: 0.3),
                          blurRadius: 8)
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.qr_code_rounded,
                          color: Colors.white, size: 18),
                      SizedBox(width: 8.w),
                      Text(
                        'كود الطلب: $orderCode',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: DesignTokens.textTitleMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: DesignTokens.brXl,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'بيانات العميل',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: DesignTokens.textTitleMedium,
                    ),
                  ),
                  SizedBox(height: 12.h),
                  _infoRow(Icons.person_rounded, 'الاسم', clientName),
                  _infoRow(Icons.phone_rounded, 'الهاتف', clientPhone),
                  if (_booking['address'] != null ||
                      _booking['address_details'] != null)
                    _infoRow(
                        Icons.location_on_rounded,
                        'العنوان',
                        _booking['address_details'] ??
                            _booking['address'] ??
                            ''),
                ],
              ),
            ),
            SizedBox(height: 12.h),
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: DesignTokens.brXl,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'تفاصيل المبلغ',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: DesignTokens.textTitleMedium,
                    ),
                  ),
                  SizedBox(height: 12.h),
                  _priceRow('السعر الإجمالي',
                      '${total.toStringAsFixed(0)} جنيه',
                      isBold: true),
                  if (offeredPrice != null &&
                      priceOfferStatus == 'pending') ...[
                    SizedBox(height: 8.h),
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _accentYellow.withValues(alpha: 0.1),
                        borderRadius: DesignTokens.brMd,
                        border: Border.all(
                            color:
                                _accentYellow.withValues(alpha: 0.3)),
                      ),
                      child: Row(children: [
                        Icon(Icons.local_offer_rounded,
                            color: _accentYellow, size: 18),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: Text(
                            'عرض سعرك: ${offeredPrice.toStringAsFixed(0)} جنيه (بانتظار رد العميل)',
                            style: TextStyle(
                              color: _accentYellow,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ]),
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(height: 8.h),
            _infoRow(Icons.credit_card_rounded, 'طريقة الدفع',
                _booking['payment_method'] == 'cash' ? 'كاش' : 'فيزا'),
            SizedBox(height: 8.h),
            if (status == 'arrived' || status == 'in_progress') ...[
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: faultPhoto != null
                      ? AppTheme.successColor.withValues(alpha: 0.05)
                      : _accentYellow.withValues(alpha: 0.05),
                  borderRadius: DesignTokens.brLg,
                  border: Border.all(
                    color: faultPhoto != null
                        ? AppTheme.successColor.withValues(alpha: 0.2)
                        : _accentYellow.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Icon(
                          faultPhoto != null
                              ? Icons.check_circle_rounded
                              : Icons.camera_alt_rounded,
                          color: faultPhoto != null
                              ? AppTheme.successColor
                              : _accentYellow,
                          size: 20,
                        ),
                        SizedBox(width: 8.w),
                        Text(
                          faultPhoto != null
                              ? 'صورة العطل مرفوعة'
                              : 'صورة العطل (مطلوب قبل البدء)',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: faultPhoto != null
                                ? AppTheme.successColor
                                : _accentYellow,
                            fontSize: DesignTokens.textBodyLarge,
                          ),
                        ),
                      ]),
                      if (faultPhoto != null) ...[
                        SizedBox(height: 8.h),
                        ClipRRect(
                          borderRadius: DesignTokens.brMd,
                          child: Image.network(
                            faultPhoto,
                            height: 60,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                Icon(Icons.photo_rounded),
                          ),
                        ),
                      ],
                      if (faultPhoto == null) ...[
                        SizedBox(height: 8.h),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _uploadFaultPhoto,
                            icon: Icon(Icons.camera_alt_rounded,
                                color: _accentYellow),
                            label: Text(
                              'رفع صورة العطل',
                              style: TextStyle(
                                color: _accentYellow,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: _accentYellow),
                              shape: RoundedRectangleBorder(
                                  borderRadius: DesignTokens.brMd),
                            ),
                          ),
                        ),
                      ],
                    ]),
              ),
              SizedBox(height: 12.h),
            ],
            if (['accepted', 'on_the_way', 'arrived', 'in_progress']
                    .contains(status) &&
                isMyBooking) ...[
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatScreen(
                            partnerName: clientName,
                            partnerId:
                                _booking['client_id']?.toString() ?? '',
                          ),
                        )),
                    icon: Icon(Icons.chat_rounded,
                        color: _providerPrimary, size: 18),
                    label: Text(
                      'كلم العميل',
                      style: TextStyle(
                        color: _providerPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: _providerPrimary),
                      shape: RoundedRectangleBorder(
                          borderRadius: DesignTokens.brMd),
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ProviderDeliveryTrackingScreen(
                              bookingId: _booking['id'].toString()),
                        )),
                    icon: Icon(Icons.location_on_rounded,
                        color: _accentGreen, size: 18),
                    label: Text(
                      'التتبع',
                      style: TextStyle(
                        color: _accentGreen,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: _accentGreen),
                      shape: RoundedRectangleBorder(
                          borderRadius: DesignTokens.brMd),
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ]),
              SizedBox(height: 12.h),
              if (['accepted', 'on_the_way', 'arrived'].contains(status)) ...[
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _offerPrice(priceOfferStatus == 'pending'),
                    icon: Icon(
                      priceOfferStatus == 'pending'
                          ? Icons.edit_rounded
                          : Icons.local_offer_rounded,
                      color: _accentYellow,
                    ),
                    label: Text(
                      priceOfferStatus == 'pending'
                          ? 'تعديل عرض السعر'
                          : 'عرض سعر أعلى',
                      style: TextStyle(
                        color: _accentYellow,
                        fontWeight: FontWeight.bold,
                        fontSize: DesignTokens.textBodyLarge,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: _accentYellow),
                      shape: RoundedRectangleBorder(
                          borderRadius: DesignTokens.brLg),
                      padding:
                          EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                if (priceOfferStatus == 'pending')
                  Padding(
                    padding: EdgeInsets.only(top: 6.h),
                    child: Text(
                      'بانتظار رد العميل — يمكنك تعديل العرض',
                      style: TextStyle(
                        color: _accentYellow,
                        fontSize: DesignTokens.textLabelSmall,
                      ),
                    ),
                  ),
                SizedBox(height: 12.h),
              ],
              if (['accepted', 'on_the_way', 'arrived'].contains(status) &&
                  !(_booking['is_free'] == true)) ...[
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _offerFreeService,
                    icon: Icon(Icons.card_giftcard_rounded,
                        color: AppTheme.successColor),
                    label: Text(
                      'خدمة مجانية',
                      style: TextStyle(
                        color: AppTheme.successColor,
                        fontWeight: FontWeight.bold,
                        fontSize: DesignTokens.textBodyLarge,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AppTheme.successColor),
                      shape: RoundedRectangleBorder(
                          borderRadius: DesignTokens.brLg),
                      padding:
                          EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                SizedBox(height: 12.h),
              ],
            ],
            if (_isUpdating)
              Center(
                child: CircularProgressIndicator(
                    color: _providerPrimary),
              )
            else ...[
              if (status == 'pending')
                Column(children: [
                  _actionBtn(
                      'قبول الطلب',
                      Icons.check_rounded,
                      _accentGreen,
                      () async {
                        await _updateStatus('accepted');
                        if (mounted) Navigator.pop(context, true);
                      }),
                  SizedBox(height: 12.h),
                  _actionBtn('رفض الطلب', Icons.close_rounded,
                      AppTheme.errorColor, () => Navigator.pop(context),
                      outlined: true),
                ]),
              if (status == 'accepted' && isMyBooking)
                _actionBtn(
                    'التتبع - في الطريق',
                    Icons.directions_car_rounded,
                    _accentGreen,
                    () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => ProviderDeliveryTrackingScreen(
                                bookingId: _booking['id'])))),
              if (status != 'pending' && !isMyBooking)
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.errorColor.withValues(alpha: 0.1),
                    borderRadius: DesignTokens.brLg,
                    border: Border.all(
                        color: AppTheme.errorColor
                            .withValues(alpha: 0.3)),
                  ),
                  child: Row(children: [
                    Icon(Icons.info_rounded,
                        color: AppTheme.errorColor),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Text(
                        'تم قبول هذا الطلب من قبل فني آخر.',
                        style: TextStyle(
                            color: AppTheme.errorColor,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ]),
                ),
              if (status == 'on_the_way' && isMyBooking)
                _actionBtn(
                    'التتبع - مسح QR عند الوصول',
                    Icons.qr_code_rounded,
                    _accentGreen,
                    () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => ProviderDeliveryTrackingScreen(
                                bookingId: _booking['id'])))),
              if (status == 'arrived' && isMyBooking)
                _actionBtn(
                    'التتبع - بدء الخدمة',
                    Icons.build_rounded,
                    _accentYellow,
                    () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => ProviderDeliveryTrackingScreen(
                                bookingId: _booking['id'])))),
              if (status == 'in_progress' && isMyBooking)
                _actionBtn(
                    'التتبع - إنهاء الخدمة',
                    Icons.camera_alt_rounded,
                    _accentGreen,
                    () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => ProviderDeliveryTrackingScreen(
                                bookingId: _booking['id'])))),

            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInvoiceView() {
    final client = _booking['profiles'];
    final clientName = client?['full_name'] ?? 'غير محدد';
    final clientAvatar = client?['avatar_url'];
    final clientRating = (client?['rating'] as num?)?.toDouble() ?? 0;
    final total = double.tryParse(
            _booking['total_price']?.toString() ??
                _booking['price']?.toString() ??
                '0') ??
        0;
    final orderCode = _booking['order_code'] ?? '';
    final tripNumber = orderCode.isNotEmpty ? '#$orderCode' : '#${_booking['id']}';
    final address = _booking['address'] ?? 'Al Gomhoureya';
    final addressDetails = _booking['address_details'];
    final destAddress = _booking['destination_address'] ?? 'المنيرة الحديثة';
    final distanceNum = (_booking['distance_km'] as num?)?.toDouble() ?? 0;
    final estimatedTime = (_booking['estimated_time'] as num?)?.toDouble() ??
        (distanceNum > 0 ? (distanceNum / 0.5).roundToDouble() : 23);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'رقم الرحلة',
              style: TextStyle(
                fontSize: DesignTokens.textLabelSmall,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              tripNumber,
              style: TextStyle(
                fontSize: DesignTokens.textTitleMedium,
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: EdgeInsets.only(right: 12.w),
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
            decoration: BoxDecoration(
              color: AppTheme.successColor.withValues(alpha: 0.1),
              borderRadius: DesignTokens.brSm,
              border: Border.all(
                color: AppTheme.successColor.withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              'مكتملة',
              style: TextStyle(
                color: AppTheme.successColor,
                fontWeight: FontWeight.bold,
                fontSize: DesignTokens.textLabelSmall,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 24.h),
              children: [
                _buildClientCard(client, clientName, clientAvatar, clientRating),
                SizedBox(height: 24.h),
                _buildRouteSection(address, addressDetails, destAddress),
                SizedBox(height: 24.h),
                Divider(color: Colors.grey[200]),
                SizedBox(height: 16.h),
                _buildPriceCard(total),
                SizedBox(height: 24.h),
                _buildStatsRow(estimatedTime, distanceNum),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.all(24.w),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey[200]!)),
            ),
            child: SafeArea(
              child: SizedBox(
                width: double.infinity,
                height: 52.h,
                child: ElevatedButton(
                  onPressed: () => _rateClient(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.successColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: DesignTokens.brLg,
                    ),
                    elevation: 4,
                    shadowColor: AppTheme.successColor.withValues(alpha: 0.3),
                  ),
                  child: Text(
                    'تقييم العميل',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: DesignTokens.textTitleMedium,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClientCard(Map<String, dynamic>? client, String clientName,
      String? clientAvatar, double clientRating) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: DesignTokens.brLg,
        border: Border.all(color: Colors.grey[100]!),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: Colors.grey[200],
            backgroundImage: clientAvatar != null
                ? NetworkImage(clientAvatar)
                : null,
            child: clientAvatar == null
                ? Icon(Icons.person_rounded, color: Colors.grey[400])
                : null,
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'العميل',
                  style: TextStyle(
                    fontSize: DesignTokens.textLabelSmall,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  clientName,
                  style: TextStyle(
                    fontSize: DesignTokens.textTitleMedium,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                SizedBox(height: 2.h),
                Row(
                  children: [
                    Text(
                      clientRating.toStringAsFixed(1),
                      style: TextStyle(
                        fontSize: DesignTokens.textLabelSmall,
                        color: AppTheme.tertiaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(width: 2.w),
                    Icon(Icons.star_rounded,
                        size: DesignTokens.iconSm,
                        color: AppTheme.tertiaryColor),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _callClient(client),
            icon: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.successColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.phone_rounded,
                  color: AppTheme.successColor, size: DesignTokens.iconSm),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteSection(
      String address, String? addressDetails, String destAddress) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 8.w),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Column(
              children: [
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: Colors.blue[500],
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
                Expanded(
                  child: Container(
                    width: 2,
                    margin: EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      border: Border(
                        right: BorderSide(
                          color: Colors.grey[300]!,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: Colors.green[500],
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ],
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    address,
                    style: TextStyle(
                      fontSize: DesignTokens.textTitleMedium,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  if (addressDetails != null)
                    Text(
                      addressDetails,
                      style: TextStyle(
                        fontSize: DesignTokens.textLabelSmall,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  SizedBox(height: 24.h),
                  Text(
                    'إلى',
                    style: TextStyle(
                      fontSize: DesignTokens.textLabelSmall,
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    destAddress,
                    style: TextStyle(
                      fontSize: DesignTokens.textTitleMedium,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceCard(double total) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: DesignTokens.brLg,
        border: Border.all(color: Colors.grey[100]!),
      ),
      child: Column(
        children: [
          Text(
            'السعر المتفق عليه',
            style: TextStyle(
              fontSize: DesignTokens.textLabelSmall,
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            '${total.toStringAsFixed(0)} EGP',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: AppTheme.successColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(double minutes, double distanceKm) {
    return Row(
      children: [
        Expanded(
          child: Column(
            children: [
              Text(
                'الوقت',
                style: TextStyle(
                  fontSize: DesignTokens.textLabelSmall,
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                '${minutes.toStringAsFixed(0)} دقيقة',
                style: TextStyle(
                  fontSize: DesignTokens.textTitleMedium,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
        ),
        Container(width: 1, height: 32, color: Colors.grey[200]),
        Expanded(
          child: Column(
            children: [
              Text(
                'المسافة',
                style: TextStyle(
                  fontSize: DesignTokens.textLabelSmall,
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                '${distanceKm.toStringAsFixed(1)} كم',
                style: TextStyle(
                  fontSize: DesignTokens.textTitleMedium,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _rateClient() {
    final ratingCtrl = TextEditingController();
    int selectedStars = 5;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 24.w,
              right: 24.w,
              top: 24.h,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24.h,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                SizedBox(height: 20.h),
                Text(
                  'تقييم العميل',
                  style: TextStyle(
                    fontSize: DesignTokens.textTitleLarge,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 16.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (i) {
                    return IconButton(
                      onPressed: () =>
                          setSheetState(() => selectedStars = i + 1),
                      icon: Icon(
                        i < selectedStars
                            ? Icons.star_rounded
                            : Icons.star_border_rounded,
                        color: AppTheme.tertiaryColor,
                        size: 36,
                      ),
                    );
                  }),
                ),
                SizedBox(height: 8.h),
                TextField(
                  controller: ratingCtrl,
                  maxLines: 3,
                  textDirection: TextDirection.rtl,
                  decoration: InputDecoration(
                    hintText: 'أكتب تعليقاً (اختياري)...',
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: DesignTokens.brMd,
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                SizedBox(height: 20.h),
                SizedBox(
                  width: double.infinity,
                  height: 48.h,
                  child: ElevatedButton(
                    onPressed: () {
                      _submitClientRating(selectedStars, ratingCtrl.text.trim());
                      Navigator.pop(ctx);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.successColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: DesignTokens.brMd,
                      ),
                    ),
                    child: Text(
                      'إرسال التقييم',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        });
      },
    );
  }

  Future<void> _submitClientRating(int stars, String comment) async {
    try {
      await SupabaseService.db.from('reviews').insert({
        'booking_id': _booking['id'],
        'provider_id': SupabaseService.currentUserId,
        'client_id': _booking['client_id'],
        'rating': stars,
        'comment': comment,
        'created_at': DateTime.now().toIso8601String(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم تقييم العميل بنجاح',
                textAlign: TextAlign.center),
            backgroundColor: AppTheme.successColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل التقييم: $e',
                textAlign: TextAlign.center),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _callClient(Map<String, dynamic>? client) {
    final phone = client?['phone_number'] ?? client?['phone'];
    if (phone != null && phone.toString().isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('جاري الاتصال بـ $phone',
              textAlign: TextAlign.center),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _buildPriceOfferSection(double total, String serviceName) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'حدد سعرك المطلوب',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        SizedBox(height: 4.h),
        Text(
          '(السعر المقترح من العميل $total جنيه)',
          style: TextStyle(
            fontSize: 14,
            color: AppTheme.textSecondary,
          ),
        ),
        SizedBox(height: 20.h),
        Center(
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () {
                    if (_selectedPrice > 10) {
                      setState(() {
                        _selectedPrice -= 10;
                        _priceController.text =
                            _selectedPrice.toStringAsFixed(0);
                      });
                    }
                  },
                  child: Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 4),
                      ],
                    ),
                    child: Icon(Icons.remove_rounded,
                        color: _accentGreen, size: 24),
                  ),
                ),
                SizedBox(width: 20.w),
                Text(
                  '${_selectedPrice.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                SizedBox(width: 4.w),
                Text(
                  'ج.م',
                  style: TextStyle(
                    fontSize: 16,
                    color: AppTheme.textSecondary,
                  ),
                ),
                SizedBox(width: 20.w),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedPrice += 10;
                      _priceController.text =
                          _selectedPrice.toStringAsFixed(0);
                    });
                  },
                  child: Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _accentGreen,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                            color: _accentGreen.withValues(alpha: 0.3),
                            blurRadius: 8),
                      ],
                    ),
                    child: Icon(Icons.add_rounded,
                        color: Colors.white, size: 24),
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: 12.h),
        Center(
          child: Text(
            'السعر المقترح من التطبيق للخدمة هو: $total',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textTertiary,
            ),
          ),
        ),
        SizedBox(height: 20.h),
        Text(
          'رسالة للعميل (اختيارية)',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        SizedBox(height: 8.h),
        TextField(
          controller: _noteController,
          maxLines: 3,
          textDirection: TextDirection.rtl,
          decoration: InputDecoration(
            hintText: 'اكتب رسالتك هنا...',
            filled: true,
            fillColor: Colors.grey[100],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryBox(
      String clientName, String distance, String serviceName) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ملخص الطلب',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: AppTheme.textPrimary,
            ),
          ),
          SizedBox(height: 10.h),
          _summaryRow(Icons.person_rounded, 'العميل', clientName),
          SizedBox(height: 6.h),
          _summaryRow(
              Icons.location_on_rounded, 'المسافة', '$distance كم'),
          SizedBox(height: 6.h),
          _summaryRow(
              Icons.build_rounded, 'الخدمة', serviceName),
        ],
      ),
    );
  }

  Widget _summaryRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.textSecondary),
        SizedBox(width: 8.w),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 13,
            color: AppTheme.textSecondary,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: AppTheme.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: 48.h,
          child: ElevatedButton(
            onPressed: () async {
              final price = double.tryParse(_priceController.text);
              if (price == null || price <= 0) {
                _snack('الرجاء إدخال سعر صحيح');
                return;
              }
              if (mounted) await _updateStatus('accepted');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _accentGreen,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'إرسال العرض',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ),
      ),
    );
  }

  double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString());
  }

  Widget _infoRow(IconData ic, String label, String value) => Padding(
        padding: EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Icon(ic, size: 18, color: AppTheme.textSecondary),
            SizedBox(width: 10.w),
            Text('$label: ',
                style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: DesignTokens.textBodyLarge)),
            Expanded(
              child: Text(value,
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: DesignTokens.textBodyLarge,
                      color: AppTheme.textPrimary)),
            ),
          ],
        ),
      );

  Widget _priceRow(String label, String value,
          {bool isBold = false, Color? color}) =>
      Padding(
        padding: EdgeInsets.symmetric(vertical: 2),
        child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label,
                  style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: DesignTokens.textBodyLarge)),
              Text(value,
                  style: TextStyle(
                    fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
                    fontSize: isBold ? 18 : 14,
                    color: color ??
                        (isBold ? _providerPrimary : AppTheme.textPrimary),
                  )),
            ]),
      );

  Widget _actionBtn(String label, IconData icon, Color color,
      VoidCallback onTap, {bool outlined = false}) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: outlined
          ? OutlinedButton.icon(
              onPressed: onTap,
              icon: Icon(icon, color: color),
              label: Text(label,
                  style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: DesignTokens.textTitleMedium)),
              style: OutlinedButton.styleFrom(
                  side: BorderSide(color: color),
                  shape: RoundedRectangleBorder(
                      borderRadius: DesignTokens.brLg)),
            )
          : ElevatedButton.icon(
              onPressed: onTap,
              icon: Icon(icon, color: AppTheme.surfaceColor),
              label: Text(label,
                  style: TextStyle(
                      color: AppTheme.surfaceColor,
                      fontWeight: FontWeight.bold,
                      fontSize: DesignTokens.textTitleMedium)),
              style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  shape: RoundedRectangleBorder(
                      borderRadius: DesignTokens.brLg)),
            ),
    );
  }
}
