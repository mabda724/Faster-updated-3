import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/services/supabase_service.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/in_app_notifier.dart';
import '../../../core/widgets/app_report_bottom_sheet.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../../../core/services/compass_service.dart';
import '../../../core/widgets/on_the_way_overlay.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/design_tokens.dart';
import '../../provider/presentation/provider_arrival_qr_scan_screen.dart';
import 'client_arrival_qr_screen.dart';
import 'waiting_for_provider_screen.dart';
import 'widgets/tracking_rating_dialog.dart';
import 'widgets/tracking_chat_overlay.dart';

class TrackingScreen extends StatefulWidget {
  final String bookingId;
  const TrackingScreen({super.key, required this.bookingId});

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  Map<String, dynamic>? _booking;
  bool _isLoading = true;
  LatLng? _providerPos;
  LatLng? _clientPos;
  double? _providerHeading;
  final List<LatLng> _providerTrail = [];
  List<LatLng> _routePoints = [];
  StreamSubscription? _locationSub;
  StreamSubscription? _bookingSub;
  final MapController _mapController = MapController();
  bool _autoFollow = true;
  double _routeDistance = 0;
  int _routeDuration = 0;
  Timer? _routeTimer;

  // Chat
  List<Map<String, dynamic>> _chatMessages = [];
  final TextEditingController _chatCtrl = TextEditingController();
  StreamSubscription? _chatSub;
  final ScrollController _chatScroll = ScrollController();
  bool _showChat = false;

  // Rating
  bool _hasReviewed = false;

  bool get isProvider => _booking?['provider_id'] == SupabaseService.currentUserId;
  String? get _partnerId => isProvider ? (_booking?['client_id']?.toString()) : (_booking?['provider_id']?.toString());
  String get _myName {
    if (isProvider) return _booking?['provider_profiles']?['profiles']?['full_name'] ?? 'مقدم الخدمة';
    return _booking?['profiles']?['full_name'] ?? 'العميل';
  }
  String get _partnerName {
    if (isProvider) return _booking?['profiles']?['full_name'] ?? 'العميل';
    return _booking?['provider_profiles']?['profiles']?['full_name'] ?? 'مقدم الخدمة';
  }

  @override
  void initState() {
    super.initState();
    _loadBooking();
    _listenToBookingChanges();
    if (isProvider) {
      CompassService.startTracking();
    }
  }

  void _listenToBookingChanges() {
    _bookingSub = SupabaseService.db
        .from('bookings')
        .stream(primaryKey: ['id'])
        .eq('id', widget.bookingId)
        .listen((data) {
      if (data.isNotEmpty && mounted) {
        final oldStatus = _booking?['status'];
        setState(() => _booking = data.first);
        final newStatus = data.first['status'];
        if (oldStatus != 'completed' && newStatus == 'completed' && !isProvider && !_hasReviewed) {
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) _showRatingDialog();
          });
        }
      }
    });
  }

  Future<void> _loadBooking() async {
    try {
      final b = await SupabaseService.db
          .from('bookings')
          .select('*, services(title, description, price), profiles!bookings_client_id_fkey(full_name, avatar_url), provider_profiles(id, profession, latitude, longitude, rating, profiles(full_name, avatar_url, phone, is_verified))')
          .eq('id', widget.bookingId)
          .single();

      double? clientLat = b['client_lat'] as double?;
      double? clientLng = b['client_lng'] as double?;
      if (clientLat == null || clientLng == null) {
        final pos = await LocationService.getCurrentPosition();
        if (pos != null) {
          clientLat = pos.latitude;
          clientLng = pos.longitude;
          await SupabaseService.db.from('bookings').update({
            'client_lat': clientLat,
            'client_lng': clientLng,
          }).eq('id', widget.bookingId);
        }
      }

      if (b['status'] == 'completed') {
        try {
          final review = await SupabaseService.db
              .from('reviews')
              .select('id')
              .eq('booking_id', widget.bookingId)
              .maybeSingle();
          _hasReviewed = review != null;
        } catch (_) {}
      }

      if (mounted) setState(() {
        _booking = b; _isLoading = false;
        if (b['provider_profiles']?['latitude'] != null && b['provider_profiles']?['longitude'] != null) {
          final p = LatLng(double.parse(b['provider_profiles']['latitude'].toString()), double.parse(b['provider_profiles']['longitude'].toString()));
          _providerPos = p; _providerTrail.add(p);
        }
        if (clientLat != null && clientLng != null) _clientPos = LatLng(clientLat, clientLng);
      });
      if (b['provider_id'] != null) { _subscribeToLocation(b['provider_id']); _subscribeToChat(); }
      _fetchRoute();
      _routeTimer = Timer.periodic(const Duration(seconds: 30), (_) => _fetchRoute());

      if (b['status'] == 'completed' && !isProvider && !_hasReviewed) {
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) _showRatingDialog();
        });
      }
    } catch (e) { debugPrint('Error: $e'); if (mounted) setState(() => _isLoading = false); }
  }

  Future<void> _updateStatus(String newStatus, {double? lat, double? lng}) async {
    try {
      final update = <String, dynamic>{'status': newStatus, 'provider_status': newStatus};
      final now = DateTime.now().toIso8601String();
      if (newStatus == 'on_the_way') update['started_at'] = now;
      if (newStatus == 'arrived') { update['arrived_at'] = now; if (lat != null) { update['arrived_lat'] = lat; update['arrived_lng'] = lng; } }
      if (newStatus == 'in_progress') update['started_at'] = now;
      if (newStatus == 'completed') { update['completed_at'] = now; if (lat != null) { update['completed_lat'] = lat; update['completed_lng'] = lng; } }
      await SupabaseService.db.from('bookings').update(update).eq('id', widget.bookingId);
      await InAppNotifier.statusChanged(
        bookingId: widget.bookingId, newStatus: newStatus,
        clientId: _booking?['client_id']?.toString(),
        providerId: _booking?['provider_id']?.toString(),
      );

      String? targetUserId;
      if (isProvider) {
        targetUserId = _booking?['client_id']?.toString();
      } else {
        targetUserId = _booking?['provider_id']?.toString();
      }

      final serviceName = _booking?['services']?['title'] ?? 'الخدمة';
      final statusInfo = _getStatusInfo(newStatus);
      final statusText = statusInfo.$3;
      if (targetUserId != null) {
        try {
          await NotificationService.sendPushNotification(
            userId: targetUserId,
            title: 'تحديث حالة الطلب',
            body: 'تم تغيير حالة طلب $serviceName إلى $statusText',
            type: 'order_status',
            data: {
              'booking_id': widget.bookingId,
              'status': newStatus,
              'service_name': serviceName,
            },
          );
        } catch (e) {
          debugPrint('FCM notification error: $e');
        }
      }

      if (newStatus == 'on_the_way') {
        await _sendStatusNotif('مقدم الخدمة في الطريق إليك', 'مقدم الخدمة في الطريق، توقع وصوله خلال ${(_routeDuration / 60).toInt()} دقيقة');
      } else if (newStatus == 'arrived') {
        await _sendStatusNotif('مقدم الخدمة وصل', 'مقدم الخدمة في موقعك، قم بتأكيد الوصول');
      } else if (newStatus == 'in_progress') {
        await _sendStatusNotif('بدأ العمل', 'مقدم الخدمة بدأ في تنفيذ الخدمة');
      } else if (newStatus == 'completed') {
        await _sendStatusNotif('تم إتمام الخدمة', 'قيم تجربتك مع مقدم الخدمة');
        if (mounted && !isProvider) {
          await _promptAction();
        } else if (mounted && isProvider) {
          _snack('تم إتمام الخدمة بنجاح', color: AppTheme.successColor, duration: Duration(seconds: 2));
        }
      }
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('حدث خطأ، يرجى المحاولة مرة أخرى'), backgroundColor: AppTheme.errorColor, duration: Duration(seconds: 5))); }
  }

  void _showRatingDialog() {
    if (_hasReviewed || isProvider) return;
    final pid = _booking?['provider_profiles']?['id']?.toString();
    if (pid == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        bool canPop = false;
        return StatefulBuilder(
          builder: (ctx, setInner) => PopScope(
            canPop: canPop,
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop) setInner(() {});
            },
            child: ImmediateRatingDialog(
              providerName: _partnerName,
              onSubmit: (rating, comment) async {
                try {
                  await SupabaseService.db.from('reviews').insert({
                    'booking_id': widget.bookingId,
                    'client_id': SupabaseService.currentUserId,
                    'provider_id': pid,
                    'rating': rating,
                    'comment': comment.isNotEmpty ? comment : null,
                  });
                  setState(() => _hasReviewed = true);
                  setInner(() => canPop = true);
                  if (ctx.mounted) {
                    Navigator.of(ctx).pop();
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  }
                } catch (e) {
                  debugPrint('Rating error: $e');
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(
                        content: Text('فشل إرسال التقييم، يرجى المحاولة مرة أخرى'),
                        backgroundColor: AppTheme.errorColor,
                        duration: Duration(seconds: 5),
                      ),
                    );
                  }
                }
              },
              onSkip: null,
            ),
          ),
        );
      },
    );
  }

  Future<void> _clientCancelOrder() async {
    final acceptedAt = _booking?['accepted_at'];
    if (acceptedAt == null) return;
    final minutesSinceAccept = DateTime.now().difference(DateTime.parse(acceptedAt.toString())).inMinutes;

    int cancelFreeMinutes = 5;
    int cancelCommissionMinutes = 30;
    try {
      final s1 = await SupabaseService.db.from('app_settings').select('value').eq('key', 'cancel_free_minutes').maybeSingle();
      cancelFreeMinutes = (s1?['value']?['minutes'] as num?)?.toInt() ?? 5;
      final s2 = await SupabaseService.db.from('app_settings').select('value').eq('key', 'cancel_commission_minutes').maybeSingle();
      cancelCommissionMinutes = (s2?['value']?['minutes'] as num?)?.toInt() ?? 30;
    } catch (_) {}

    String deductionType;
    if (minutesSinceAccept <= cancelFreeMinutes) {
      deductionType = 'free';
    } else if (minutesSinceAccept <= cancelCommissionMinutes) {
      deductionType = 'commission';
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('لا يمكن الإلغاء بعد مرور $cancelCommissionMinutes دقائق - تواصل مع الدعم'), backgroundColor: AppTheme.errorColor),
        );
      }
      return;
    }

    if (!mounted) return;
    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: Row(children: [
        Icon(Icons.warning_rounded, color: deductionType == 'free' ? AppTheme.successColor : AppTheme.tertiaryColor, size: DesignTokens.iconMd),
        SizedBox(width: DesignTokens.space12),
        Text('إلغاء الطلب'),
      ]),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(deductionType == 'free'
          ? 'مر $minutesSinceAccept دقيقة من القبول - الإلغاء مجاني'
          : 'مر $minutesSinceAccept دقيقة - سيتم خصم عمولة من مزود الخدمة'),
        SizedBox(height: DesignTokens.space12),
        TextField(
          controller: reasonCtrl,
          maxLines: 2,
          decoration: InputDecoration(
            hintText: 'سبب الإلغاء (مطلوب)',
            filled: true,
            fillColor: Colors.grey.shade100,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.all(DesignTokens.space6),
          ),
        ),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('تراجع')),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: deductionType == 'free' ? AppTheme.successColor : AppTheme.tertiaryColor),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text('تأكيد الإلغاء'),
        ),
      ],
    ));

    if (confirmed != true) return;
    if (!mounted) return;

    try {
      final response = await SupabaseService.db.rpc('cancel_booking_graduated', params: {
        'p_booking_id': widget.bookingId,
        'p_cancelled_by': SupabaseService.currentUserId!,
        'p_reason': reasonCtrl.text.trim(),
      });

      if (response?['success'] == true) {
        final type = response?['deduction_type'] ?? 'free';
        final deducted = response?['commission_deducted'] ?? 0;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(type == 'free' ? 'تم إلغاء الطلب مجاناً' : 'تم الإلغاء مع خصم عمولة $deducted جنيه'),
              backgroundColor: type == 'free' ? AppTheme.successColor : AppTheme.tertiaryColor,
              duration: const Duration(seconds: 3),
            ),
          );
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && Navigator.canPop(context)) {
            Navigator.pop(context);
          }
        });
      } else {
        final error = response?['error']?.toString() ?? 'فشل الإلغاء';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error), backgroundColor: AppTheme.errorColor, duration: Duration(seconds: 5)),
          );
        }
      }
    } catch (e) {
      debugPrint('Cancel error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: AppTheme.errorColor),
        );
      }
    }
  }

  Future<void> _providerCancelOrder() async {
    final acceptedAt = _booking?['accepted_at'];
    if (acceptedAt == null) return;
    final minutesSinceAccept = DateTime.now().difference(DateTime.parse(acceptedAt.toString())).inMinutes;

    int cancelWindowMinutes = 5;
    try {
      final setting = await SupabaseService.db
          .from('app_settings')
          .select('value')
          .eq('key', 'cancel_free_minutes')
          .maybeSingle();
      cancelWindowMinutes = (setting?['value']?['minutes'] as num?)?.toInt() ?? 5;
    } catch (_) {}

    if (minutesSinceAccept > cancelWindowMinutes) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('لا يمكن إلغاء الطلب بعد مرور $cancelWindowMinutes دقائق من القبول'),
            backgroundColor: AppTheme.errorColor,
            duration: const Duration(seconds: 5),
          ),
        );
      }
      return;
    }

    if (!mounted) return;

    final reasons = [
      'العميل لا يرد',
      'الموقع بعيد جداً',
      'أنا مشغول حالياً',
      'المشكلة أكبر من المتوقع',
      'سبب آخر',
    ];
    String? selectedReason;
    final commentCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(context: context, builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        title: Row(children: [
          Icon(Icons.warning_rounded, color: AppTheme.errorColor, size: DesignTokens.iconMd),
          SizedBox(width: DesignTokens.space12),
          Text('إلغاء الطلب'),
        ]),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('هل تريد إلغاء هذا الطلب؟ يمكنك الإلغاء مجاناً خلال أول $cancelWindowMinutes دقائق.'),
              SizedBox(height: DesignTokens.space12),
              Container(
                padding: EdgeInsets.all(DesignTokens.space5),
                decoration: BoxDecoration(color: AppTheme.successColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                child: Row(children: [
                  Icon(Icons.timer_rounded, color: AppTheme.successColor, size: 18),
                  SizedBox(width: DesignTokens.space4),
                  Expanded(child: Text('مر $minutesSinceAccept دقيقة من القبول', style: TextStyle(color: AppTheme.successColor, fontSize: DesignTokens.textBodySmall))),
                ]),
              ),
              SizedBox(height: DesignTokens.space6),
              Text('سبب الإلغاء:', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: DesignTokens.space4),
              ...reasons.map((r) => Semantics(
                label: r,
                child: GestureDetector(
                onTap: () => setDialogState(() => selectedReason = r),
                child: Container(
                  margin: EdgeInsets.only(bottom: DesignTokens.space8),
                  padding: EdgeInsets.all(DesignTokens.space12),
                  decoration: BoxDecoration(
                    color: selectedReason == r ? AppTheme.errorColor.withValues(alpha: 0.08) : AppTheme.backgroundColor,
                    borderRadius: DesignTokens.brMd,
                    border: Border.all(color: selectedReason == r ? AppTheme.errorColor.withValues(alpha: 0.3) : AppTheme.textPrimary.withValues(alpha: 0.08)),
                  ),
                  child: Row(
                    children: [
                      Icon(selectedReason == r ? Icons.circle_rounded : Icons.circle_outlined, color: selectedReason == r ? AppTheme.errorColor : AppTheme.textSecondary, size: 20),
                      SizedBox(width: DesignTokens.space12),
                      Expanded(child: Text(r, style: TextStyle(fontSize: DesignTokens.textBodyMedium))),
                    ],
                  ),
                )),
              ),
              ),
              TextField(
                controller: commentCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'أضف تفاصيل إضافية (اختياري)...',
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.all(DesignTokens.space6),
                ),
              ),
            ],
            ),
            ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('تراجع')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
            onPressed: selectedReason == null ? null : () => Navigator.pop(ctx, true),
            child: Text('إلغاء الطلب'),
          ),
        ],
      ),
    ));

    if (confirmed != true) return;
    if (!mounted) return;

    try {
      await SupabaseService.db.from('bookings').update({
        'status': 'cancelled',
        'cancel_reason': selectedReason,
        'cancellation_reason': commentCtrl.text.trim().isEmpty ? null : commentCtrl.text.trim(),
        'cancelled_by': SupabaseService.currentUserId,
        'cancelled_by_provider_id': SupabaseService.currentUserId,
        'cancelled_at': DateTime.now().toIso8601String(),
        'provider_status': 'cancelled',
      }).eq('id', widget.bookingId);

      final clientId = _booking?['client_id']?.toString();
      if (clientId != null) {
        try {
          await NotificationService.sendPushNotification(
            userId: clientId,
            title: 'تم إلغاء الطلب',
            body: 'تم إلغاء طلب ${_serviceName()}',
            type: 'order_status',
            data: {
              'booking_id': widget.bookingId,
              'status': 'cancelled',
              'service_name': _serviceName(),
            },
          );
        } catch (e) {
          debugPrint('FCM notification error: $e');
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم إلغاء الطلب بنجاح'), backgroundColor: AppTheme.warningColor, duration: Duration(seconds: 3)),
        );
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && Navigator.canPop(context)) {
            Navigator.pop(context);
          }
        });
      }
    } catch (e) {
      if (mounted) _snack('فشل إلغاء الطلب، يرجى المحاولة مرة أخرى');
    }
  }

  Future<void> _handleClientAfterPhoto() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1024, imageQuality: 80);
    if (file == null) { _showRatingDialog(); return; }
    try {
      final bytes = await file.readAsBytes();
      final name = 'after_${widget.bookingId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final bucket = SupabaseService.storage.from('booking-evidence');
      await bucket.uploadBinary(name, bytes);
      final url = bucket.getPublicUrl(name);
      final photos = List<String>.from(_booking?['completion_photo_urls'] as List? ?? []);
      photos.add(url);
      await SupabaseService.db.from('bookings').update({'completion_photo_urls': photos}).eq('id', widget.bookingId);
    } catch (_) {}
    if (mounted) _showRatingDialog();
  }

  Future<void> _handleArrival() async {
    final pos = await LocationService.getCurrentPosition();
    if (pos == null) { if (mounted) _snack('تأكد من تفعيل GPS'); return; }
    if (!mounted) return;
    if (isProvider) {
      final code = _booking?['arrival_verification_code'] as String?;
      if (code == null) { if (mounted) _snack('كود التحقق غير متاح'); return; }
      String? scanned;
      try {
        if (!mounted) return;
        scanned = await Navigator.push<String>(context, MaterialPageRoute(builder: (_) => ProviderArrivalQrScanScreen(bookingId: widget.bookingId)));
      } catch (_) {}
      if (!mounted) return;
      if (scanned == null && mounted) {
        scanned = await showDialog<String>(context: context, builder: (ctx) => AlertDialog(
          title: const Text('إدخال كود التحقق'),
          content: Padding(
            padding: const EdgeInsets.only(top: DesignTokens.space6),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'أدخل الكود',
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.all(DesignTokens.space6),
              ),
              keyboardType: TextInputType.number,
              onSubmitted: (v) => Navigator.pop(ctx, v),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ],
        ));
      }
      if (scanned == null) return;
      if (scanned.trim() != code.trim()) { if (mounted) _snack('الكود غير صحيح!'); return; }
      await _updateStatus('arrived', lat: pos.latitude, lng: pos.longitude);
    } else {
      if (mounted) Navigator.push(context, MaterialPageRoute(builder: (_) => ClientArrivalQrScreen(bookingId: widget.bookingId, arrivalCode: _booking?['arrival_verification_code'] as String? ?? '')));
    }
  }

  Future<void> _handleJobPhoto() async {
    final file = await ImagePicker().pickImage(source: ImageSource.camera, maxWidth: 1024, imageQuality: 80);
    if (file == null) return;

    try {
      final bytes = await file.readAsBytes();
      final name = 'job_${widget.bookingId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final bucket = SupabaseService.storage.from('booking-evidence');
      await bucket.uploadBinary(name, bytes);
      final url = bucket.getPublicUrl(name);

      await SupabaseService.db.from('bookings').update({
        'job_photo_url': url,
        'job_photo_verified': false,
      }).eq('id', widget.bookingId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حفظ صورة العطل بنجاح'), backgroundColor: AppTheme.successColor),
        );
      }
    } catch (e) {
      if (mounted) _snack('خطأ في حفظ الصورة: $e');
    }
  }

  Future<void> _handleComplete() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1024, imageQuality: 80);
    if (file == null) return;
    final pos = await LocationService.getCurrentPosition();
    try {
      final bytes = await file.readAsBytes();
      final name = 'completion_${widget.bookingId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final bucket = SupabaseService.storage.from('booking-evidence');
      await bucket.uploadBinary(name, bytes);
      final url = bucket.getPublicUrl(name);
      final photos = List<String>.from(_booking?['completion_photo_urls'] as List? ?? []);
      photos.add(url);
      await SupabaseService.db.from('bookings').update({'completion_photo_urls': photos}).eq('id', widget.bookingId);
      await _updateStatus('completed', lat: pos?.latitude, lng: pos?.longitude);
    } catch (e) { if (mounted) _snack('$e'); }
  }

  Future<void> _promptAction() async {
    if (isProvider) return;
    final r = await showDialog<bool>(context: context, barrierDismissible: false, builder: (ctx) => AlertDialog(
      title: const Text('تم إتمام الخدمة', textAlign: TextAlign.center),
      content: const Text('هل تريد تصوير المكان بعد الخدمة؟', textAlign: TextAlign.center),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('لا، شكراً')),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: AppTheme.primaryColor),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('تصوير الآن'),
        ),
      ],
    ));
    if (r == true) {
      if (mounted) await _handleClientAfterPhoto();
    } else {
      if (mounted) _showRatingDialog();
    }
  }

  void _subscribeToLocation(String providerId) {
    _locationSub = SupabaseService.client.from('provider_locations').stream(primaryKey: ['provider_id']).eq('provider_id', providerId).listen((data) {
      if (data.isEmpty) return;
      final Map<String, dynamic> pp = Map<String, dynamic>.from(data.first as Map);
      final lat = pp['latitude'];
      final lng = pp['longitude'];
      final heading = pp['heading'];
      if (lat == null || lng == null) return;
      final newPos = LatLng(double.parse(lat.toString()), double.parse(lng.toString()));
      setState(() {
        _providerPos = newPos;
        _providerHeading = heading != null ? double.tryParse(heading.toString()) : null;
        _providerTrail.add(newPos);
        if (_providerTrail.length > 200) _providerTrail.removeRange(0, _providerTrail.length - 200);
      });
      if (_routePoints.isNotEmpty && _providerPos != null && const Distance().distance(_providerPos!, _routePoints[0]) > 200) _fetchRoute();
      if (_autoFollow) _mapController.move(newPos, 14);
    });
  }

  Future<void> _fetchRoute() async {
    if (_providerPos == null || _clientPos == null) return;
    try {
      final res = await http.get(Uri.parse('https://router.project-osrm.org/route/v1/driving/${_providerPos!.longitude},${_providerPos!.latitude};${_clientPos!.longitude},${_clientPos!.latitude}?geometries=geojson&overview=full&alternatives=false')).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return;
      final data = jsonDecode(res.body);
      if (data['code'] != 'Ok' || (data['routes'] as List).isEmpty) return;
      final route = data['routes'][0];
      setState(() { _routePoints = (route['geometry']['coordinates'] as List).map((c) => LatLng(c[1], c[0])).toList(); _routeDistance = (route['distance'] as num).toDouble(); _routeDuration = (route['duration'] as num).toInt(); });
    } catch (_) {}
  }

  void _subscribeToChat() {
    _chatSub?.cancel();
    final uid = SupabaseService.currentUserId;
    final pid = _partnerId;
    if (uid == null || pid == null) return;
    _chatSub = SupabaseService.client.from('chat_messages').stream(primaryKey: ['id']).listen((data) {
      final msgs = data.where((m) {
        final s = m['sender_id'] as String?; final r = m['receiver_id'] as String?;
        return (s == uid && r == pid) || (s == pid && r == uid);
      }).map((m) => {
        'text': m['content'] ?? m['text'] ?? '', 'isMe': m['sender_id'] == uid, 'image_url': m['image_url'], 'time': _fmt(m['created_at']),
      }).toList();
      if (mounted) { setState(() => _chatMessages = msgs); if (_showChat) _scrollToBottom(); }
    });
  }

  void _scrollToBottom() { if (_chatScroll.hasClients) _chatScroll.animateTo(_chatScroll.position.maxScrollExtent, duration: const Duration(milliseconds: 200), curve: Curves.easeOut); }

  Future<void> _sendMessage({String? imageUrl}) async {
    final text = _chatCtrl.text.trim();
    if (text.isEmpty && imageUrl == null) return;
    final uid = SupabaseService.currentUserId;
    final pid = _partnerId;
    if (uid == null || pid == null) return;

    try {
      await SupabaseService.db.from('chat_messages').insert({
        'sender_id': uid,
        'receiver_id': pid,
        'content': text.isNotEmpty ? text : null,
        'image_url': imageUrl,
        'booking_id': widget.bookingId,
        'created_at': DateTime.now().toUtc().toIso8601String()
      });

      await InAppNotifier.newMessage(
        recipientId: pid,
        senderName: _myName,
        bookingId: widget.bookingId,
        messagePreview: imageUrl != null ? 'صورة' : (text.isNotEmpty ? text : null),
      );

      try {
        await NotificationService.sendPushNotification(
          userId: pid,
          title: 'رسالة جديدة من $_myName',
          body: imageUrl != null ? 'صورة' : text,
          type: 'chat_message',
          data: {
            'booking_id': widget.bookingId,
            'sender_name': _myName,
            'sender_id': uid,
          },
        );
      } catch (e) {
        debugPrint('FCM chat notification error: $e');
      }

      _chatCtrl.clear();

      Future.delayed(const Duration(milliseconds: 100), () {
        if (_chatScroll.hasClients) {
          _chatScroll.animateTo(
            _chatScroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      debugPrint('Send error: $e');
      if (mounted) {
        _snack('فشل إرسال الرسالة، يرجى المحاولة مرة أخرى', color: AppTheme.errorColor, duration: Duration(seconds: 5));
      }
    }
  }

  Future<void> _sendPhoto() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1024, imageQuality: 80);
    if (file == null) return;
    try {
      final bytes = await file.readAsBytes();
      final name = 'chat_${widget.bookingId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final bucket = SupabaseService.storage.from('chat-photos');
      await bucket.uploadBinary(name, bytes);
      await _sendMessage(imageUrl: bucket.getPublicUrl(name));
    } catch (e) {
      debugPrint('Photo error: $e');
      if (mounted) {
        _snack('فشل إرسال الصورة، يرجى المحاولة مرة أخرى', color: AppTheme.errorColor, duration: Duration(seconds: 5));
      }
    }
  }

  String _fmt(String? ts) { if (ts == null) return ''; try { final d = DateTime.parse(ts).toLocal(); return '${d.hour}:${d.minute.toString().padLeft(2, '0')}'; } catch (_) { return ''; } }
  void _snack(String msg, {Color? color, Duration? duration}) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color ?? AppTheme.primaryColor, duration: duration ?? Duration(seconds: 2)));

  Future<void> _sendStatusNotif(String title, String body) async {
    final targetId = isProvider ? (_booking?['client_id']?.toString()) : (_booking?['provider_id']?.toString());
    if (targetId != null) {
      await NotificationService.sendPushNotification(userId: targetId, title: title, body: body, type: 'order_status', data: {'booking_id': widget.bookingId});
    }
  }

  double _rating() => double.tryParse(_booking?['provider_profiles']?['rating']?.toString() ?? '0') ?? 0;
  String _serviceName() => _booking?['services']?['title'] ?? _booking?['services']?['description'] ?? 'خدمة';
  double _price() => double.tryParse(_booking?['total_price']?.toString() ?? _booking?['price']?.toString() ?? '0') ?? 0;
  List<String> get _stepLabels => ['قيد الانتظار', 'تم القبول', 'في الطريق', 'تم الوصول', 'اكتمل'];

  @override
  void dispose() {
    _locationSub?.cancel(); _bookingSub?.cancel(); _chatSub?.cancel(); _routeTimer?.cancel();
    _chatCtrl.dispose(); _chatScroll.dispose();
    if (isProvider) {
      CompassService.stopTracking();
    }
    super.dispose();
  }

  // =======================================================================
  // BUILD
  // =======================================================================
  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final mapHeight = screenHeight * 0.45;
    final sheetHeight = screenHeight * 0.55;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('تتبع الطلب'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0.5,
        foregroundColor: AppTheme.primaryColor,
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
          : _booking == null
              ? const Center(child: Text('الطلب غير موجود'))
              : Stack(
                  children: [
                    // Map — top portion
                    Positioned(
                      top: 0, left: 0, right: 0,
                      height: mapHeight,
                      child: FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(initialCenter: _providerPos ?? _clientPos ?? const LatLng(30.0444, 31.2357), initialZoom: 14, onTap: (_, __) => _autoFollow = false),
                        children: [
                          TileLayer(urlTemplate: 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png', subdomains: const ['a', 'b', 'c', 'd']),
                          if (_routePoints.length > 1) PolylineLayer(polylines: [Polyline(points: _routePoints, color: AppTheme.secondaryColor, strokeWidth: 6)]),
                          if (_routePoints.length > 1) PolylineLayer(polylines: [Polyline(points: _routePoints.take((_routePoints.length * 0.4).round()).toList(), color: AppTheme.primaryColor, strokeWidth: 6)]),
                          if (_providerTrail.length > 1) PolylineLayer(polylines: [Polyline(points: _providerTrail, color: AppTheme.primaryColor.withValues(alpha: 0.2), strokeWidth: 3)]),
                          MarkerLayer(markers: [
                            if (_clientPos != null) Marker(point: _clientPos!, width: 44, height: 56, child: _clientMarker()),
                            if (_providerPos != null) Marker(point: _providerPos!, width: 64, height: 64, child: _providerMarker()),
                          ]),
                        ],
                      ),
                    ),

                    // Floating action buttons on map
                    Positioned(
                      top: DesignTokens.space8,
                      left: DesignTokens.space16,
                      right: DesignTokens.space16,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(children: [
                          if (!isProvider && _clientPos != null)
                            _topChip('${(_routeDuration > 0 ? (_routeDuration / 60).toInt() : 0)} د  |  ${(_routeDistance / 1000).toStringAsFixed(1)} كم'),
                          if (!isProvider) SizedBox(width: DesignTokens.space6),
                          if (!isProvider) _topBtn(Icons.phone_rounded, () async { final p = _booking?['provider_profiles']?['profiles']?['phone']?.toString(); if (p != null) await launchUrl(Uri.parse('tel:$p')); }, semanticsLabel: 'اتصال'),
                          if (!isProvider) SizedBox(width: DesignTokens.space6),
                          if (!isProvider) _topBtn(Icons.chat_rounded, () async {
                            try {
                              final setting = await SupabaseService.db.from('app_settings').select('value').eq('key', 'whatsapp_customer_service').maybeSingle();
                              String number = '201000000000';
                              String msg = 'مرحباً، أحتاج مساعدة';
                              if (setting != null && setting['value'] != null) {
                                final value = setting['value'];
                                if (value is Map) {
                                  number = value['number']?.toString() ?? '201000000000';
                                  msg = value['message']?.toString() ?? 'مرحباً، أحتاج مساعدة';
                                } else {
                                  try {
                                    final parsed = jsonDecode(value.toString());
                                    number = parsed['number']?.toString() ?? '201000000000';
                                    msg = parsed['message']?.toString() ?? 'مرحباً، أحتاج مساعدة';
                                  } catch (_) {}
                                }
                              }
                              await launchUrl(Uri.parse('https://wa.me/$number?text=${Uri.encodeComponent(msg)}'));
                            } catch (_) {
                              await launchUrl(Uri.parse('https://wa.me/201000000000'));
                            }
                          }, semanticsLabel: 'خدمة العملاء'),
                          if (!isProvider && ['accepted', 'on_the_way'].contains(_booking?['status'])) ...[
                            SizedBox(width: DesignTokens.space6),
                            _topBtn(Icons.cancel_rounded, _clientCancelOrder, semanticsLabel: 'إلغاء الطلب'),
                          ],
                          if (isProvider && ['accepted', 'on_the_way', 'arrived'].contains(_booking?['status'])) ...[
                            SizedBox(width: DesignTokens.space6),
                            _topBtn(Icons.cancel_rounded, _providerCancelOrder, semanticsLabel: 'إلغاء الطلب'),
                          ],
                          if (!isProvider) SizedBox(width: DesignTokens.space6),
                          if (!isProvider) _topBtn(Icons.flag_rounded, () => _showReportDialog(), semanticsLabel: 'الإبلاغ'),
                        ]),
                      ),
                    ),

                    // Chat overlay
                    if (_showChat)
                      TrackingChatOverlay(
                        messages: _chatMessages,
                        scrollController: _chatScroll,
                        textController: _chatCtrl,
                        partnerName: _partnerName,
                        onClose: () => setState(() => _showChat = false),
                        onSend: () => _sendMessage(),
                        onSendPhoto: _sendPhoto,
                      ),

                    // Bottom sheet card
                    if (!_showChat) Positioned(
                      top: mapHeight,
                      left: 0, right: 0, bottom: 0,
                      child: Container(
                        height: sheetHeight,
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceColor,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(DesignTokens.radiusXl)),
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 25, offset: const Offset(0, -10))],
                        ),
                        child: SingleChildScrollView(
                          padding: EdgeInsets.only(bottom: bottomPadding + DesignTokens.space8),
                          child: _buildBottomSheetContent(),
                        ),
                      ),
                    ),

                    // Auto-follow button
                    if (!_autoFollow && _providerPos != null && !_showChat)
                      Positioned(
                        top: mapHeight - 50,
                        right: DesignTokens.space16,
                        child: Semantics(
                          label: 'تحديث الموقع',
                          child: GestureDetector(
                          onTap: () { _autoFollow = true; _mapController.move(_providerPos!, 14); setState(() {}); },
                          child: Container(
                            padding: const EdgeInsets.all(DesignTokens.space12),
                            decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 8)]),
                            child: const Icon(Icons.location_on_rounded, color: AppTheme.primaryColor, size: 22),
                          ),
                        ),
                        ),
                      ),
                  ],
                ),
    );
  }

  // =======================================================================
  // BOTTOM SHEET CONTENT
  // =======================================================================
  Widget _buildBottomSheetContent() {
    final status = _booking?['status'] as String?;

    return Column(mainAxisSize: MainAxisSize.min, children: [
      // Handle
      Container(margin: const EdgeInsets.only(top: DesignTokens.space5), width: DesignTokens.space48, height: 5, decoration: BoxDecoration(color: AppTheme.textTertiary, borderRadius: BorderRadius.circular(3))),

      // Service info card
      Container(
        margin: const EdgeInsets.fromLTRB(DesignTokens.space8, DesignTokens.space4, DesignTokens.space8, DesignTokens.space4),
        padding: const EdgeInsets.all(DesignTokens.space8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppTheme.primaryColor.withValues(alpha: 0.1), AppTheme.primaryColor.withValues(alpha: 0.05)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.work_rounded, color: AppTheme.primaryColor, size: 20),
                SizedBox(width: DesignTokens.space4),
                Expanded(
                  child: Text(
                    _serviceName(),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primaryColor),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (!isProvider)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: DesignTokens.space6, vertical: DesignTokens.space3),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${_price().toStringAsFixed(0)} ج',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
              ],
            ),
            if (_booking?['address'] != null) ...[
              SizedBox(height: DesignTokens.space4),
              Row(
                children: [
                  Icon(Icons.location_on_rounded, color: AppTheme.textSecondary, size: 16),
                  SizedBox(width: DesignTokens.space3),
                  Expanded(
                    child: Text(
                      _booking!['address'],
                      style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),

      // Status banner
      _buildStatusBanner(status),

      // Visual milestone timeline (3-step dot+line matching design spec)
      _buildMilestoneTimeline(status),

      // Detailed status tracking with times
      _buildDetailedTracking(status),

      // Provider card with Chat button on right
      _buildProviderCardWithChat(),

      // ETA box (yellow) — client only, on_the_way
      if (!isProvider && status == 'on_the_way' && _routeDuration > 0) _buildEtaBox(),

      // Divider before actions
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: DesignTokens.space16, vertical: DesignTokens.space6),
        child: Divider(color: AppTheme.textPrimary.withValues(alpha: 0.08), height: 1),
      ),

      // Action button
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: DesignTokens.space8),
        child: _buildAction(status),
      ),

      SizedBox(height: DesignTokens.space8),

      // Quick actions (chat + call)
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: DesignTokens.space8),
        child: _buildQuickActions(),
      ),

      // Price offer notification (client only)
      if (!isProvider && _booking?['offered_price'] != null && _booking?['price_offer_status'] == 'pending') _buildPriceOfferNotification(),

      // Free service notification (client only)
      if (!isProvider && _booking?['is_free'] == true) _buildFreeServiceNotification(),

      // Client price suggestion (client only)
      if (!isProvider && _booking?['client_suggested_price_status'] == 'pending') _buildClientSuggestionNotification(),

      // Client price suggestion (provider only)
      if (isProvider && _booking?['client_suggested_price_status'] == 'pending') _buildProviderSuggestionResponse(),

      // Suggest price button (client only)
      if (!isProvider && _booking?['client_suggested_price_status'] != 'pending' && _booking?['client_suggested_price_status'] != 'accepted')
        Padding(
          padding: const EdgeInsets.fromLTRB(DesignTokens.space16, DesignTokens.space8, DesignTokens.space16, 0),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: DesignTokens.space6),
                foregroundColor: AppTheme.primaryColor,
                backgroundColor: Colors.transparent,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => _showSuggestPriceDialog(),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.edit_rounded, size: 18, color: AppTheme.primaryColor),
                SizedBox(width: DesignTokens.space4),
                const Text('اقترح سعر أقل', style: TextStyle(fontSize: DesignTokens.textBodySmall, color: AppTheme.primaryColor)),
              ]),
            ),
          ),
        ),

      // Price breakdown (provider only)
      if (isProvider) _buildPriceBreakdown(),

      // Chat preview
      if (_chatMessages.isNotEmpty && _booking?['chat_visible'] != false)
        Semantics(
          label: 'فتح المحادثة',
          child: GestureDetector(
          onTap: () => setState(() => _showChat = true),
          child: Container(
            margin: const EdgeInsets.fromLTRB(DesignTokens.space16, DesignTokens.space8, DesignTokens.space16, DesignTokens.space4),
            padding: const EdgeInsets.symmetric(horizontal: DesignTokens.space7, vertical: DesignTokens.space12),
            decoration: BoxDecoration(
              color: AppTheme.backgroundColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.textPrimary.withValues(alpha: 0.06)),
            ),
            child: Row(children: [
              Container(width: DesignTokens.space32, height: DesignTokens.space32, decoration: BoxDecoration(color: AppTheme.primaryColor.withValues(alpha: 0.1), shape: BoxShape.circle),
                child: const Icon(Icons.chat_rounded, size: 14, color: AppTheme.primaryColor)),
              SizedBox(width: DesignTokens.space12),
              Expanded(child: Text(_lastMsg(), style: const TextStyle(fontSize: DesignTokens.textLabelMedium), maxLines: 1, overflow: TextOverflow.ellipsis)),
              Icon(Icons.keyboard_arrow_up_rounded, color: AppTheme.primaryColor, size: DesignTokens.iconLg),
            ]),
          ),
        ),
        ),
      SizedBox(height: 4.h),

      // Progress stepper (client only) — updated to dot+line visual style
      if (!isProvider) _buildProgressStepper(status) else SizedBox(height: DesignTokens.space4),

      // Rating prompt for completed orders
      if (!isProvider && status == 'completed' && !_hasReviewed)
        Padding(
          padding: const EdgeInsets.fromLTRB(DesignTokens.space8, DesignTokens.space4, DesignTokens.space8, DesignTokens.space2),
          child: _buildRateNowBanner(),
        ),
    ]);
  }

  // =======================================================================
  // VISUAL MILESTONE TIMELINE — 3 dots + lines matching pasted design
  // =======================================================================
  Widget _buildMilestoneTimeline(String? status) {
    int activeSteps = 0;
    switch (status) {
      case 'accepted':
      case 'on_the_way':
        activeSteps = 1;
        break;
      case 'arrived':
      case 'in_progress':
        activeSteps = 2;
        break;
      case 'completed':
        activeSteps = 3;
        break;
    }

    final milestones = ['تم التأكيد', 'جاري التنفيذ', 'مكتمل'];
    const Color activeColor = AppTheme.successColor;

    return Padding(
      padding: const EdgeInsets.fromLTRB(DesignTokens.space24, DesignTokens.space6, DesignTokens.space24, DesignTokens.space4),
      child: SizedBox(
        height: 50,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List.generate(milestones.length, (i) {
            final isActive = i < activeSteps;
            return Expanded(
              child: Row(
                children: [
                  // Dot + label column
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isActive ? activeColor : Colors.grey[300],
                          boxShadow: isActive
                              ? [BoxShadow(color: activeColor.withValues(alpha: 0.3), blurRadius: 6)]
                              : null,
                        ),
                        child: Center(
                          child: isActive
                              ? const Icon(Icons.check, color: Colors.white, size: 16)
                              : Icon(Icons.circle_rounded, color: Colors.grey[400], size: 10),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        milestones[i],
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                          color: isActive ? activeColor : Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                  // Connecting line (except last)
                  if (i < milestones.length - 1)
                    Expanded(
                      child: Container(
                        height: 3,
                        margin: const EdgeInsets.only(bottom: 22),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(2),
                          color: i < activeSteps ? activeColor : Colors.grey[300],
                        ),
                      ),
                    ),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }

  // =======================================================================
  // DETAILED STATUS TRACKING — compact timeline with timestamps
  // =======================================================================
  Widget _buildDetailedTracking(String? status) {
    final steps = [
      _trackStep('قيد الانتظار', Icons.hourglass_empty_rounded, _booking?['created_at']?.toString(), status != null),
      _trackStep('تم القبول', Icons.check_circle_rounded, _booking?['accepted_at']?.toString(), ['accepted', 'on_the_way', 'arrived', 'in_progress', 'completed'].contains(status)),
      _trackStep('في الطريق', Icons.directions_car_rounded, _booking?['started_at']?.toString(), ['on_the_way', 'arrived', 'in_progress', 'completed'].contains(status)),
      _trackStep('تم الوصول', Icons.location_on_rounded, _booking?['arrived_at']?.toString(), ['arrived', 'in_progress', 'completed'].contains(status)),
      _trackStep('جاري التنفيذ', Icons.build_rounded, _booking?['started_at']?.toString(), ['in_progress', 'completed'].contains(status)),
      _trackStep('تم الإكمال', Icons.check_circle_rounded, _booking?['completed_at']?.toString(), status == 'completed'),
    ];

    final visibleSteps = steps.where((s) => s['visible'] == true).toList();
    if (visibleSteps.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(DesignTokens.space24, DesignTokens.space4, DesignTokens.space24, DesignTokens.space2),
      child: Container(
        padding: const EdgeInsets.all(DesignTokens.space7),
        decoration: BoxDecoration(
          color: AppTheme.backgroundColor,
          borderRadius: DesignTokens.brLg,
          border: Border.all(color: AppTheme.textPrimary.withValues(alpha: 0.06)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.timeline_rounded, size: 14, color: AppTheme.primaryColor),
                SizedBox(width: DesignTokens.space4),
                Text('تفاصيل التتبع', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
              ],
            ),
            SizedBox(height: DesignTokens.space4),
            ...List.generate(visibleSteps.length, (i) {
              final step = visibleSteps[i];
              final isLast = i == visibleSteps.length - 1;
              final isActive = step['active'] as bool;
              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Timeline line + dot
                    SizedBox(
                      width: 20,
                      child: Column(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isActive ? AppTheme.successColor : Colors.grey[300],
                            ),
                          ),
                          if (!isLast)
                            Expanded(
                              child: Container(
                                width: 2,
                                color: isActive ? AppTheme.successColor.withValues(alpha: 0.3) : Colors.grey[200],
                              ),
                            ),
                        ],
                      ),
                    ),
                    SizedBox(width: DesignTokens.space8),
                    // Content
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(bottom: isLast ? 0 : DesignTokens.space6),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              step['label'] as String,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                                color: isActive ? AppTheme.textPrimary : AppTheme.textTertiary,
                              ),
                            ),
                            if (step['time'] != null && (step['time'] as String).isNotEmpty)
                              Text(
                                _formatTime(step['time'] as String),
                                style: TextStyle(
                                  fontSize: 9,
                                  color: AppTheme.textTertiary,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Map<String, dynamic> _trackStep(String label, IconData icon, String? time, bool active) {
    return {
      'label': label,
      'icon': icon,
      'time': time,
      'active': active,
      'visible': time != null || active,
    };
  }

  String _formatTime(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 1) return 'الآن';
      if (diff.inHours < 1) return 'منذ ${diff.inMinutes} د';
      if (diff.inDays < 1) return 'منذ ${diff.inHours} س';
      return '${dt.day}/${dt.month} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }

  // =======================================================================
  // PROVIDER CARD WITH CHAT BUTTON — matching pasted design
  // =======================================================================
  Widget _buildProviderCardWithChat() {
    final partnerPic = isProvider ? (_booking?['profiles']?['avatar_url'] as String?) : (_booking?['provider_profiles']?['profiles']?['avatar_url'] as String?);
    final name = isProvider ? (_booking?['profiles']?['full_name'] ?? 'العميل') : (_booking?['provider_profiles']?['profiles']?['full_name'] ?? 'مقدم الخدمة');
    final prof = _booking?['provider_profiles']?['profession'] ?? '';
    final rating = _rating();

    return Padding(
      padding: const EdgeInsets.fromLTRB(DesignTokens.space16, DesignTokens.space6, DesignTokens.space16, DesignTokens.space6),
      child: Container(
        padding: const EdgeInsets.all(DesignTokens.space7),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
          border: Border.all(color: AppTheme.textPrimary.withValues(alpha: 0.08)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Left side: Avatar + Name + Rating
            Expanded(
              child: Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.2), width: 2),
                    ),
                    child: ClipRRect(
                      borderRadius: DesignTokens.br2xl,
                      child: partnerPic != null
                          ? Image.network(partnerPic, width: 48, height: 48, fit: BoxFit.cover, semanticLabel: 'صورة مقدم الخدمة', errorBuilder: (_, __, ___) => _defaultAvatar(name))
                          : _defaultAvatar(name),
                    ),
                  ),
                  SizedBox(width: DesignTokens.space12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: DesignTokens.textTitleSmall), maxLines: 1, overflow: TextOverflow.ellipsis),
                            ),
                            if (!isProvider && _booking?['provider_profiles']?['profiles']?['is_verified'] == true) ...[
                              SizedBox(width: DesignTokens.space2),
                              Icon(Icons.verified_rounded, size: 14, color: AppTheme.primaryColor),
                            ],
                          ],
                        ),
                        SizedBox(height: DesignTokens.space2),
                        if (!isProvider && _providerHeading != null) ...[
                          Row(children: [
                            Icon(Icons.near_me_rounded, size: 14, color: AppTheme.primaryColor),
                            SizedBox(width: DesignTokens.space2),
                            Text(_getDirectionText(_providerHeading!), style: TextStyle(fontSize: DesignTokens.textLabelSmall, color: AppTheme.primaryColor)),
                          ]),
                          SizedBox(height: DesignTokens.space2),
                        ],
                        Row(children: [
                          if (!isProvider) ...[
                            Flexible(child: Text(prof, style: TextStyle(fontSize: DesignTokens.textBodySmall, color: AppTheme.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis)),
                            if (rating > 0) ...[
                              const SizedBox(width: DesignTokens.space8),
                              const Icon(Icons.star_rounded, color: AppTheme.tertiaryColor, size: 14),
                              Text(' ${rating.toStringAsFixed(1)}', style: const TextStyle(fontSize: DesignTokens.textBodySmall, fontWeight: FontWeight.bold)),
                            ],
                          ],
                          if (isProvider)
                            Flexible(child: Text(_booking?['address'] ?? 'موقع العميل', style: TextStyle(fontSize: DesignTokens.textBodySmall, color: AppTheme.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis)),
                        ]),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Right side: Chat button
            SizedBox(width: DesignTokens.space8),
            Semantics(
              label: 'فتح المحادثة',
              child: ElevatedButton.icon(
                icon: const Icon(Icons.chat_rounded, size: 18),
                label: const Text('تواصل'),
                onPressed: () => setState(() => _showChat = true),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: DesignTokens.space12, vertical: DesignTokens.space8),
                  backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                  foregroundColor: AppTheme.primaryColor,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
                    side: BorderSide(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =======================================================================
  // ETA BOX — yellow highlight box
  // =======================================================================
  Widget _buildEtaBox() {
    final etaMinutes = (_routeDuration / 60).toInt().clamp(1, 999);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: DesignTokens.space16),
      padding: const EdgeInsets.symmetric(horizontal: DesignTokens.space16, vertical: DesignTokens.space12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
        border: Border.all(color: AppTheme.warningColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.access_time_rounded, color: AppTheme.warningColor, size: 22),
          SizedBox(width: DesignTokens.space8),
          Text(
            'الوقت المتوقع للوصول',
            style: TextStyle(color: Colors.grey[700], fontSize: DesignTokens.textBodySmall),
          ),
          const Spacer(),
          Text(
            '$etaMinutes دقيقة',
            style: const TextStyle(
              color: AppTheme.warningColor,
              fontWeight: FontWeight.bold,
              fontSize: DesignTokens.textTitleSmall,
            ),
          ),
        ],
      ),
    );
  }

  // =======================================================================
  // EXISTING HELPER WIDGETS (preserved)
  // =======================================================================

  Widget _buildStatusBanner(String? status) {
    final statusInfo = _getStatusInfo(status);
    return Container(
      margin: const EdgeInsets.fromLTRB(DesignTokens.space16, DesignTokens.space12, DesignTokens.space16, 0),
      padding: const EdgeInsets.symmetric(horizontal: DesignTokens.space16, vertical: DesignTokens.space5),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [statusInfo.$1.withValues(alpha: 0.1), statusInfo.$1.withValues(alpha: 0.05)],
          begin: Alignment.centerRight,
          end: Alignment.centerLeft,
        ),
        borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
        border: Border.all(color: statusInfo.$1.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(DesignTokens.space8),
            decoration: BoxDecoration(
              color: statusInfo.$1.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(statusInfo.$2, color: statusInfo.$1, size: DesignTokens.iconSm),
          ),
          SizedBox(width: DesignTokens.space12),
          Expanded(
            child: Text(
              statusInfo.$3,
              style: TextStyle(
                color: statusInfo.$1,
                fontWeight: FontWeight.w600,
                fontSize: DesignTokens.textLabelMedium,
              ),
            ),
          ),
          if (_booking?['order_code'] != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: DesignTokens.space10, vertical: DesignTokens.space4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
                border: Border.all(color: statusInfo.$1.withValues(alpha: 0.2)),
              ),
              child: Text(
                '#${_booking?['order_code']}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: statusInfo.$1,
                  fontWeight: FontWeight.bold,
                  fontSize: DesignTokens.textBodySmall,
                ),
              ),
            ),
        ],
      ),
    );
  }

  (Color, IconData, String) _getStatusInfo(String? status) {
    switch (status) {
      case 'pending':
        return (AppTheme.warningColor, Icons.hourglass_empty_rounded, 'جاري البحث عن مقدم خدمة...');
      case 'accepted':
        return (AppTheme.infoColor, Icons.check_circle_rounded, 'تم قبول طلبك - في انتظار التحرك');
      case 'on_the_way':
        return (AppTheme.primaryColor, Icons.directions_car_rounded, 'مقدم الخدمة في الطريق إليك');
      case 'arrived':
        return (AppTheme.primaryColor, Icons.location_on_rounded, 'مقدم الخدمة وصل لموقعك');
      case 'in_progress':
        return (AppTheme.successColor, Icons.build_rounded, 'جاري تنفيذ الخدمة');
      case 'completed':
        return (AppTheme.successColor, Icons.check_circle_rounded, 'تم إتمام الخدمة بنجاح');
      case 'cancelled':
        return (AppTheme.errorColor, Icons.cancel_rounded, 'تم إلغاء الطلب');
      default:
        return (AppTheme.textSecondary, Icons.help_outline_rounded, 'جاري التحميل...');
    }
  }

  Widget _buildRateNowBanner() {
    return Semantics(
      label: 'تقييم',
      child: GestureDetector(
      onTap: () => _showRatingDialog(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: DesignTokens.space16, vertical: DesignTokens.space7),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [AppTheme.tertiaryColor, AppTheme.warningColor]),
          borderRadius: DesignTokens.brLg,
          boxShadow: [
            BoxShadow(color: AppTheme.warningColor.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.star_rounded, color: Colors.white, size: DesignTokens.iconMd),
            SizedBox(width: DesignTokens.space8),
            const Text('قيّم تجربتك الآن', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: DesignTokens.textTitleSmall)),
            SizedBox(width: DesignTokens.space8),
            Container(
              padding: const EdgeInsets.all(DesignTokens.space4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
              ),
              child: const Icon(Icons.arrow_circle_right_rounded, color: Colors.white, size: DesignTokens.iconSm),
            ),
          ],
        ),
      ),
    ),
    );
  }

  Widget _defaultAvatar(String name) {
    return Container(width: DesignTokens.iconAvatar, height: DesignTokens.iconAvatar, color: AppTheme.primaryColor.withValues(alpha: 0.1),
      child: Center(child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold, fontSize: DesignTokens.textTitleLarge))));
  }

  Widget _buildPriceBreakdown() {
    final isFree = _booking?['is_free'] == true;
    final total = isFree ? 0.0 : _price();
    final commRate = double.tryParse(_booking?['commission_rate']?.toString() ?? '0') ?? 0.1;
    final commission = isFree ? 0.0 : total * (commRate > 1 ? commRate / 100 : commRate);
    final earning = total - commission;

    return Padding(
      padding: const EdgeInsets.fromLTRB(DesignTokens.space16, DesignTokens.space8, DesignTokens.space16, 0),
      child: Container(
        padding: const EdgeInsets.all(DesignTokens.space7),
        decoration: BoxDecoration(
          color: isFree ? AppTheme.successColor.withValues(alpha: 0.1) : AppTheme.backgroundColor,
          borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
          border: Border.all(color: isFree ? AppTheme.successColor : AppTheme.dividerColor),
        ),
        child: Column(children: [
          if (isFree) ...[
            Row(children: [
              Icon(Icons.card_giftcard_rounded, color: AppTheme.successColor, size: 20),
              SizedBox(width: DesignTokens.space4),
              Text('خدمة مجانية', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.successColor)),
            ]),
            SizedBox(height: DesignTokens.space8),
            _priceRow('سعر الخدمة', 0, bold: true, color: AppTheme.successColor),
            _priceRow('عمولة المنصة', 0, color: AppTheme.successColor),
            Divider(color: AppTheme.successColor.withValues(alpha: 0.3), height: 1),
            SizedBox(height: DesignTokens.space8),
            _priceRow('صافي أرباحك', 0, bold: true, color: AppTheme.successColor, icon: Icons.attach_money_rounded),
          ] else ...[
            _priceRow('سعر الخدمة', total, bold: true),
            SizedBox(height: DesignTokens.space8),
            _priceRow('عمولة المنصة (${(commRate * 100).toStringAsFixed(0)}%)', commission, color: AppTheme.warningColor, icon: Icons.note_add_rounded),
            SizedBox(height: DesignTokens.space8),
            Divider(color: AppTheme.dividerColor, height: 1),
            SizedBox(height: DesignTokens.space8),
            _priceRow('صافي أرباحك', earning, bold: true, color: AppTheme.successColor, icon: Icons.attach_money_rounded),
          ],
        ]),
      ),
    );
  }

  Widget _priceRow(String label, double amount, {bool bold = false, Color? color, IconData? icon}) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Row(children: [
        if (icon != null) ...[
          Icon(icon, size: DesignTokens.iconSm, color: color ?? AppTheme.textSecondary),
          SizedBox(width: DesignTokens.space8),
        ],
        Text(label, style: TextStyle(color: color ?? AppTheme.textSecondary, fontSize: DesignTokens.textBodySmall, fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
      ]),
      Text('${amount.toStringAsFixed(0)} ج', style: TextStyle(color: color ?? AppTheme.textPrimary, fontSize: DesignTokens.textLabelMedium, fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
    ]);
  }

  Widget _buildPriceOfferNotification() {
    final offeredPrice = double.tryParse(_booking?['offered_price']?.toString() ?? '0') ?? 0;
    final currentPrice = _price();
    final reason = _booking?['offered_price_reason'] ?? '';

    return Container(
      margin: const EdgeInsets.fromLTRB(DesignTokens.space16, DesignTokens.space8, DesignTokens.space16, 0),
      padding: const EdgeInsets.all(DesignTokens.space8),
      decoration: BoxDecoration(
        color: AppTheme.warningColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
        border: Border.all(color: AppTheme.warningColor.withValues(alpha: 0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.local_offer_rounded, color: AppTheme.warningColor, size: DesignTokens.iconMd),
          SizedBox(width: DesignTokens.space8),
          Expanded(child: Text('عرض سعر جديد من مقدم الخدمة', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.warningColor, fontSize: DesignTokens.textBodyMedium))),
        ]),
        SizedBox(height: DesignTokens.space12),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('السعر الحالي:', style: TextStyle(color: AppTheme.textSecondary, fontSize: DesignTokens.textBodySmall)),
          Text('${currentPrice.toStringAsFixed(0)} ج', style: TextStyle(color: AppTheme.textSecondary, fontSize: DesignTokens.textBodySmall, fontWeight: FontWeight.bold)),
        ]),
        SizedBox(height: DesignTokens.space4),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('السعر المقترح:', style: TextStyle(color: AppTheme.warningColor, fontSize: DesignTokens.textBodySmall, fontWeight: FontWeight.bold)),
          Text('${offeredPrice.toStringAsFixed(0)} ج', style: TextStyle(color: AppTheme.warningColor, fontSize: DesignTokens.textBodySmall, fontWeight: FontWeight.bold)),
        ]),
        if (reason.isNotEmpty) ...[
          SizedBox(height: DesignTokens.space8),
          Text('السبب: $reason', style: TextStyle(color: AppTheme.textSecondary, fontSize: DesignTokens.textLabelSmall)),
        ],
        SizedBox(height: DesignTokens.space12),
          Row(children: [
            Expanded(child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: DesignTokens.space6),
                foregroundColor: Colors.white,
                backgroundColor: AppTheme.successColor,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => _respondToPriceOffer(true),
              child: Text('موافق', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: DesignTokens.textBodySmall)),
            )),
            SizedBox(width: DesignTokens.space8),
            Expanded(child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: DesignTokens.space6),
                foregroundColor: AppTheme.errorColor,
                backgroundColor: Colors.transparent,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => _respondToPriceOffer(false),
              child: Text('رفض', style: TextStyle(color: AppTheme.errorColor, fontWeight: FontWeight.bold, fontSize: DesignTokens.textBodySmall)),
            )),
          ]),
        ]),
    );
  }

  Future<void> _respondToPriceOffer(bool accept) async {
    try {
      final response = await SupabaseService.db.rpc('client_respond_price_offer', params: {
        'p_booking_id': widget.bookingId,
        'p_client_id': SupabaseService.currentUserId,
        'p_accept': accept,
      });

      if (response == null || response['success'] != true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل الرد على عرض السعر'), backgroundColor: AppTheme.errorColor),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(accept ? 'تم قبول عرض السعر بنجاح' : 'تم رفض عرض السعر'),
          backgroundColor: accept ? AppTheme.successColor : AppTheme.warningColor,
          duration: Duration(seconds: accept ? 2 : 3),
        ),
      );

      _loadBooking();

      final providerId = _booking?['provider_id']?.toString();
      final serviceName = _booking?['services']?['title'] ?? 'الخدمة';
      if (providerId != null) {
        try {
          await NotificationService.sendPushNotification(
            userId: providerId,
            title: accept ? 'تم قبول عرض السعر' : 'تم رفض عرض السعر',
            body: accept
              ? 'قام العميل بقبول عرض السعر لخدمة $serviceName'
              : 'قام العميل برفض عرض السعر لخدمة $serviceName',
            type: 'price_offer_response',
            data: {
              'booking_id': widget.bookingId,
              'accepted': accept.toString(),
              'service_name': serviceName,
            },
          );
        } catch (e) {
          debugPrint('FCM price offer response notification error: $e');
        }
      }

      if (!accept) {
        try {
          await SupabaseService.db.from('bookings').update({
            'provider_id': null,
            'status': 'pending',
            'provider_status': null,
            'offered_price': null,
            'offered_price_reason': null,
            'price_offer_status': 'none',
          }).eq('id', widget.bookingId);

          final serviceId = _booking?['service_id']?.toString();
          final categoryId = _booking?['services']?['category_id']?.toString();
          if (serviceId != null) {
            await NotificationService.sendPushNotification(
              userId: 'broadcast',
              title: 'طلب خدمة جديد',
              body: 'طلب جديد لخدمة $serviceName',
              type: 'new_booking',
              data: {
                'booking_id': widget.bookingId,
                'service_id': serviceId,
                'service_name': serviceName,
                'category_id': categoryId ?? '',
                'is_urgent': 'true',
              },
            );
          }

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('جاري البحث عن مقدم خدمة بديل...'),
                backgroundColor: AppTheme.infoColor,
                duration: Duration(seconds: 3),
              ),
            );

            final totalPrice = (_booking?['price'] ?? 0).toDouble();
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && Navigator.canPop(context)) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => WaitingForProviderScreen(
                      bookingId: widget.bookingId,
                      serviceName: serviceName,
                      totalPrice: totalPrice,
                    ),
                  ),
                );
              }
            });
          }
        } catch (e) {
          debugPrint('Error searching for alternative provider: $e');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('حدث خطأ، يرجى المحاولة مرة أخرى'),
          backgroundColor: AppTheme.errorColor,
          duration: Duration(seconds: 5),
        ));
      }
    }
  }

  void _showSuggestPriceDialog() {
    final currentPrice = _price();
    final TextEditingController priceController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('اقترح سعر أقل'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('السعر الحالي: ${currentPrice.toStringAsFixed(0)} جنيه'),
            SizedBox(height: DesignTokens.space8),
            const Text('أدخل السعر المقترح (لا يمكن أن يكون أقل من 10% من السعر الحالي):'),
            SizedBox(height: DesignTokens.space4),
            TextField(
              controller: priceController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: 'السعر المقترح',
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.all(DesignTokens.space6),
                suffix: const Padding(
                  padding: EdgeInsets.only(right: DesignTokens.space4),
                  child: Text('جنيه'),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppTheme.primaryColor),
            onPressed: () async {
              final suggestedPrice = double.tryParse(priceController.text);
              if (suggestedPrice == null || suggestedPrice <= 0) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('ير起见 إدخال سعر صحيح أكبر من صفر'), backgroundColor: AppTheme.errorColor, duration: Duration(seconds: 5)),
                  );
                }
                return;
              }

              Navigator.pop(context);
              await _submitPriceSuggestion(suggestedPrice);
            },
            child: const Text('إرسال'),
          ),
        ],
      ),
    );
  }

  Future<void> _submitPriceSuggestion(double suggestedPrice) async {
    try {
      final response = await SupabaseService.db.rpc('client_suggest_price', params: {
        'p_booking_id': widget.bookingId,
        'p_suggested_price': suggestedPrice,
      });

      if (response?['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم إرسال اقتراح السعر'), backgroundColor: AppTheme.successColor),
          );
          _loadBooking();
        }

        final providerId = _booking?['provider_id']?.toString();
        final serviceName = _booking?['services']?['title'] ?? 'الخدمة';
        if (providerId != null) {
          try {
            await NotificationService.sendPushNotification(
              userId: providerId,
              title: 'اقتراح سعر من العميل',
              body: 'اقترح العميل سعر ${suggestedPrice.toStringAsFixed(0)} جنيه لخدمة $serviceName',
              type: 'price_suggestion',
              data: {
                'booking_id': widget.bookingId,
                'suggested_price': suggestedPrice.toString(),
                'service_name': serviceName,
              },
            );
          } catch (e) {
            debugPrint('FCM price suggestion notification error: $e');
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('فشل إرسال الاقتراح، يرجى المحاولة مرة أخرى'),
            backgroundColor: AppTheme.errorColor,
            duration: Duration(seconds: 5),
          ));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('حدث خطأ، يرجى المحاولة مرة أخرى'),
          backgroundColor: AppTheme.errorColor,
          duration: Duration(seconds: 5),
        ));
      }
    }
  }

  Widget _buildClientSuggestionNotification() {
    final suggestedPrice = double.tryParse(_booking?['client_suggested_price']?.toString() ?? '0') ?? 0;
    final currentPrice = _price();

    return Container(
      margin: const EdgeInsets.fromLTRB(DesignTokens.space16, DesignTokens.space8, DesignTokens.space16, 0),
      padding: const EdgeInsets.all(DesignTokens.space8),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
        border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.schedule_rounded, color: AppTheme.primaryColor, size: DesignTokens.iconMd),
          SizedBox(width: DesignTokens.space8),
          Expanded(child: Text('اقتراحك قيد المراجعة', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor, fontSize: DesignTokens.textBodyMedium))),
        ]),
        SizedBox(height: DesignTokens.space12),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('السعر الحالي:', style: TextStyle(color: AppTheme.textSecondary, fontSize: DesignTokens.textBodySmall)),
          Text('${currentPrice.toStringAsFixed(0)} ج', style: TextStyle(color: AppTheme.textSecondary, fontSize: DesignTokens.textBodySmall, fontWeight: FontWeight.bold)),
        ]),
        SizedBox(height: DesignTokens.space4),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('السعر المقترح:', style: TextStyle(color: AppTheme.primaryColor, fontSize: DesignTokens.textBodySmall, fontWeight: FontWeight.bold)),
          Text('${suggestedPrice.toStringAsFixed(0)} ج', style: TextStyle(color: AppTheme.primaryColor, fontSize: DesignTokens.textBodySmall, fontWeight: FontWeight.bold)),
        ]),
        SizedBox(height: DesignTokens.space8),
        Text('بانتظار رد مقدم الخدمة...', style: TextStyle(color: AppTheme.textSecondary, fontSize: DesignTokens.textLabelSmall)),
      ]),
    );
  }

  Widget _buildProviderSuggestionResponse() {
    final suggestedPrice = double.tryParse(_booking?['client_suggested_price']?.toString() ?? '0') ?? 0;
    final currentPrice = _price();

    return Container(
      margin: const EdgeInsets.fromLTRB(DesignTokens.space16, DesignTokens.space8, DesignTokens.space16, 0),
      padding: const EdgeInsets.all(DesignTokens.space8),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
        border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.attach_money_rounded, color: AppTheme.primaryColor, size: DesignTokens.iconMd),
          SizedBox(width: DesignTokens.space8),
          Expanded(child: Text('اقتراح سعر من العميل', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor, fontSize: DesignTokens.textBodyMedium))),
        ]),
        SizedBox(height: DesignTokens.space12),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('السعر الحالي:', style: TextStyle(color: AppTheme.textSecondary, fontSize: DesignTokens.textBodySmall)),
          Text('${currentPrice.toStringAsFixed(0)} ج', style: TextStyle(color: AppTheme.textSecondary, fontSize: DesignTokens.textBodySmall, fontWeight: FontWeight.bold)),
        ]),
        SizedBox(height: DesignTokens.space4),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('السعر المقترح:', style: TextStyle(color: AppTheme.primaryColor, fontSize: DesignTokens.textBodySmall, fontWeight: FontWeight.bold)),
          Text('${suggestedPrice.toStringAsFixed(0)} ج', style: TextStyle(color: AppTheme.primaryColor, fontSize: DesignTokens.textBodySmall, fontWeight: FontWeight.bold)),
        ]),
        SizedBox(height: DesignTokens.space12),
          Row(children: [
            Expanded(child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: DesignTokens.space6),
                foregroundColor: Colors.white,
                backgroundColor: AppTheme.successColor,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => _respondToClientSuggestion(true),
              child: Text('قبول', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: DesignTokens.textBodySmall)),
            )),
            SizedBox(width: DesignTokens.space8),
            Expanded(child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: DesignTokens.space6),
                foregroundColor: AppTheme.errorColor,
                backgroundColor: Colors.transparent,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => _respondToClientSuggestion(false),
              child: Text('رفض', style: TextStyle(color: AppTheme.errorColor, fontWeight: FontWeight.bold, fontSize: DesignTokens.textBodySmall)),
            )),
        ]),
      ]),
    );
  }

  Future<void> _respondToClientSuggestion(bool accept) async {
    try {
      final response = await SupabaseService.db.rpc('provider_respond_client_suggestion', params: {
        'p_booking_id': widget.bookingId,
        'p_provider_id': SupabaseService.currentUserId,
        'p_accept': accept,
      });

      if (response?['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(accept ? 'تم قبول اقتراح السعر' : 'تم رفض اقتراح السعر'),
            backgroundColor: accept ? AppTheme.successColor : AppTheme.errorColor,
          ));
          _loadBooking();
        }

        if (!accept && isProvider) {
          try {
            await SupabaseService.db.from('bookings').update({
              'provider_id': null,
              'status': 'pending',
              'provider_status': null,
              'client_suggested_price': null,
              'client_suggested_price_status': 'none',
            }).eq('id', widget.bookingId);

            final serviceId = _booking?['service_id']?.toString();
            final serviceName = _booking?['services']?['title'] ?? 'الخدمة';
            final categoryId = _booking?['services']?['category_id']?.toString();
            if (serviceId != null) {
              await NotificationService.sendPushNotification(
                userId: 'broadcast',
                title: 'طلب خدمة جديد',
                body: 'طلب جديد لخدمة $serviceName',
                type: 'new_booking',
                data: {
                  'booking_id': widget.bookingId,
                  'service_id': serviceId,
                  'service_name': serviceName,
                  'category_id': categoryId ?? '',
                  'is_urgent': 'true',
                },
              );
            }

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('تم إلغاء الطلب وإعادة البحث عن مقدم خدمة بديل'),
                  backgroundColor: AppTheme.infoColor,
                  duration: Duration(seconds: 3),
                ),
              );

              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && Navigator.canPop(context)) {
                  Navigator.pop(context);
                }
              });
            }
          } catch (e) {
            debugPrint('Error searching for alternative provider: $e');
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('فشل الرد على الاقتراح، يرجى المحاولة مرة أخرى'),
            backgroundColor: AppTheme.errorColor,
            duration: Duration(seconds: 5),
          ));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('حدث خطأ، يرجى المحاولة مرة أخرى'),
          backgroundColor: AppTheme.errorColor,
          duration: Duration(seconds: 5),
        ));
      }
    }
  }

  Widget _buildFreeServiceNotification() {
    return Container(
      margin: const EdgeInsets.fromLTRB(DesignTokens.space16, DesignTokens.space8, DesignTokens.space16, 0),
      padding: const EdgeInsets.all(DesignTokens.space8),
      decoration: BoxDecoration(
        color: AppTheme.successColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
        border: Border.all(color: AppTheme.successColor.withValues(alpha: 0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.card_giftcard_rounded, color: AppTheme.successColor, size: DesignTokens.iconMd),
          SizedBox(width: DesignTokens.space8),
          Expanded(child: Text('خدمة مجانية!', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.successColor, fontSize: DesignTokens.textBodyMedium))),
        ]),
        SizedBox(height: DesignTokens.space12),
        Text('قدم مقدم الخدمة هذه الخدمة مجاناً', style: TextStyle(color: AppTheme.textSecondary, fontSize: DesignTokens.textBodySmall)),
        SizedBox(height: DesignTokens.space4),
        Text('السعر: 0 جنيه', style: TextStyle(color: AppTheme.successColor, fontSize: DesignTokens.textBodySmall, fontWeight: FontWeight.bold)),
      ]),
    );
  }

  Widget _buildAction(String? status) {
    if (isProvider) {
      if (status == 'accepted') {
        return _mainBtn(Icons.directions_car_rounded, 'أنا في الطريق', () async {
          await _updateStatus('on_the_way');
          if (mounted) {
            await showDialog(
              context: context,
              barrierDismissible: false,
              builder: (_) => OnTheWayOverlay(
                providerName: _myName,
                serviceName: _serviceName(),
                onDismiss: () => Navigator.of(context, rootNavigator: true).pop(),
              ),
            );
          }
        });
      }
      if (status == 'on_the_way') {
        return _mainBtn(Icons.qr_code_scanner_rounded, 'مسح QR عند الوصول', _handleArrival);
      }
      if (status == 'arrived') {
        final jobPhotoUrl = _booking?['job_photo_url'] as String?;
        if (jobPhotoUrl == null) {
          return _mainBtn(Icons.camera_alt_rounded, 'صور العطل قبل البدء', _handleJobPhoto);
        }
        return _mainBtn(Icons.play_arrow_rounded, 'بدء الخدمة', () => _updateStatus('in_progress'));
      }
      if (status == 'in_progress') {
        return _mainBtn(Icons.camera_alt_rounded, 'إنهاء الخدمة + تصوير', _handleComplete);
      }
    }
    if (!isProvider) {
      if (status == 'pending' || status == 'accepted') {
        return _mainBtn(Icons.hourglass_empty_rounded, 'بانتظار وصول مقدم الخدمة', () {});
      }
      if (status == 'on_the_way') {
        return _mainBtn(Icons.qr_code_rounded, 'جهّز باركود الوصول', _handleArrival);
      }
      if (status == 'arrived') {
        return _mainBtn(Icons.qr_code_rounded, 'إظهار باركود الوصول', _handleArrival);
      }
      if (status == 'in_progress') {
        return _mainBtn(Icons.build_rounded, 'جاري العمل', () {});
      }
      if (status == 'completed') {
        if (_hasReviewed) {
          return _mainBtn(Icons.check_circle_rounded, 'تم التقييم - شكراً!', () {});
        }
        return _mainBtn(Icons.star_rounded, 'تقييم مقدم الخدمة', () => _showRatingDialog());
      }
    }
    return const SizedBox.shrink();
  }

  Widget _buildQuickActions() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: DesignTokens.space8, vertical: DesignTokens.space6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _quickActionButton(
              Icons.chat_rounded,
              'محادثة',
              AppTheme.primaryColor,
              () => setState(() => _showChat = true),
              semanticsLabel: 'فتح المحادثة',
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: _quickActionButton(
              Icons.phone_rounded,
              'اتصال',
              AppTheme.successColor,
              _makePhoneCall,
              semanticsLabel: 'اتصال',
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickActionButton(IconData icon, String label, Color color, VoidCallback onTap, {String? semanticsLabel}) {
    final btn = GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: DesignTokens.space6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            SizedBox(height: DesignTokens.space2),
            Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
    if (semanticsLabel != null) {
      return Semantics(label: semanticsLabel, child: btn);
    }
    return btn;
  }

  Future<void> _makePhoneCall() async {
    final phone = isProvider
        ? _booking?['profiles']?['phone_number']?.toString()
        : _booking?['provider_profiles']?['phone_number']?.toString();

    if (phone == null || phone.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('رقم الهاتف غير متوفر')),
        );
      }
      return;
    }

    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لا يمكن إجراء الاتصال')),
        );
      }
    }
  }

  Widget _mainBtn(IconData icon, String label, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      height: DesignTokens.buttonHeight,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.zero,
          foregroundColor: Colors.white,
          backgroundColor: AppTheme.primaryColor,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: DesignTokens.brLg),
        ),
        onPressed: onTap,
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            padding: const EdgeInsets.all(DesignTokens.space4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
            ),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          SizedBox(width: DesignTokens.space12),
          Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
        ]),
      ),
    );
  }

  // Progress stepper — updated to dot+line visual style matching design
  Widget _buildProgressStepper(String? status) {
    int activeStep = 0;
    switch (status) {
      case 'accepted': activeStep = 1; break;
      case 'on_the_way': activeStep = 2; break;
      case 'arrived': activeStep = 3; break;
      case 'in_progress': activeStep = 3; break;
      case 'completed': activeStep = 4; break;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(DesignTokens.space16, DesignTokens.space4, DesignTokens.space16, DesignTokens.space8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: DesignTokens.space12, vertical: DesignTokens.space7),
        decoration: BoxDecoration(
          color: AppTheme.backgroundColor,
          borderRadius: DesignTokens.brLg,
        ),
        child: Column(children: [
          Row(children: List.generate(5, (i) {
            final stepIdx = 4 - i;
            final isActive = stepIdx <= activeStep;
            final isCurrent = stepIdx == activeStep;

            final stepIcons = [
              Icons.hourglass_empty_rounded,
              Icons.check_circle_rounded,
              Icons.directions_car_rounded,
              Icons.location_on_rounded,
              Icons.check_circle_rounded,
            ];
            final dotSize = isCurrent ? 28.0 : 22.0;

            return Expanded(child: Row(children: [
              // Dot
              Container(
                width: dotSize,
                height: dotSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isActive ? AppTheme.successColor : Colors.grey[300],
                  border: isCurrent
                      ? Border.all(color: AppTheme.successColor.withValues(alpha: 0.3), width: 3)
                      : null,
                  boxShadow: isCurrent
                      ? [BoxShadow(color: AppTheme.successColor.withValues(alpha: 0.3), blurRadius: 8)]
                      : null,
                ),
                child: Center(
                  child: isActive
                      ? Icon(Icons.check, color: Colors.white, size: isCurrent ? 14 : 12)
                      : Icon(Icons.circle_rounded, color: Colors.grey[400], size: 8),
                ),
              ),
              // Connecting line
              if (i < 4)
                Expanded(
                  child: Container(
                    height: 3,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      color: stepIdx <= activeStep && stepIdx < activeStep
                          ? AppTheme.successColor
                          : Colors.grey[300],
                    ),
                  ),
                ),
            ]));
          })),
          SizedBox(height: DesignTokens.space8),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: List.generate(5, (i) {
            final stepIdx = 4 - i;
            final isActive = stepIdx <= activeStep;
            return Expanded(
              child: Text(_stepLabels[stepIdx], textAlign: TextAlign.center, style: TextStyle(
                fontSize: DesignTokens.textLabelSmall, fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                color: isActive ? AppTheme.successColor : AppTheme.textSecondary,
              )),
            );
          })),
        ]),
      ),
    );
  }

  // Report dialog
  void _showReportDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(DesignTokens.radiusXl)),
      ),
      builder: (_) => AppReportBottomSheet(
        bookingId: widget.bookingId,
        providerId: _booking?['provider_id']?.toString(),
        reportedById: SupabaseService.currentUserId,
      ),
    );
  }

  String _lastMsg() {
    if (_chatMessages.isEmpty) return '';
    final last = _chatMessages.last;
    return last['image_url'] != null ? 'أرسل صورة' : (last['text'] as String? ?? '');
  }

  Widget _topBtn(IconData icon, VoidCallback onTap, {String? semanticsLabel}) {
    final btn = GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(DesignTokens.space12),
        decoration: BoxDecoration(color: AppTheme.surfaceColor.withValues(alpha: 0.9), shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10)]),
        child: Icon(icon, color: AppTheme.primaryColor, size: 20),
      ),
    );
    if (semanticsLabel != null) {
      return Semantics(label: semanticsLabel, child: btn);
    }
    return btn;
  }

  Widget _topChip(String text) {
    return Flexible(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: DesignTokens.space16, vertical: DesignTokens.space5),
        decoration: BoxDecoration(color: AppTheme.surfaceColor.withValues(alpha: 0.9), borderRadius: BorderRadius.circular(28), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10)]),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: DesignTokens.textBodySmall), overflow: TextOverflow.ellipsis),
      ),
    );
  }

  Widget _providerMarker() {
    return Stack(alignment: Alignment.center, children: [
      Container(width: 64, height: 64, decoration: BoxDecoration(shape: BoxShape.circle, color: AppTheme.primaryColor.withValues(alpha: 0.2)),
        child: Center(child: Container(width: 48, height: 48, decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: AppTheme.primaryColor, width: 2)),
          child: Transform.rotate(
            angle: (_providerHeading ?? 0) * 3.14159 / 180,
            child: const Icon(Icons.near_me_rounded, color: AppTheme.primaryColor, size: 24),
          )))),
    ]);
  }

  String _getDirectionText(double heading) {
    final directions = ['شمال', 'شمال شرق', 'شرق', 'جنوب شرق', 'جنوب', 'جنوب غرب', 'غرب', 'شمال غرب'];
    final index = ((heading + 22.5) / 45).floor() % 8;
    return directions[index];
  }

  Widget _clientMarker() {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 40, height: 40, decoration: BoxDecoration(color: AppTheme.successColor, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.26), blurRadius: 6)]),
        child: const Icon(Icons.home_rounded, color: Colors.white, size: 22)),
      Container(width: 0, height: 0, decoration: BoxDecoration(
        border: Border(top: BorderSide(color: AppTheme.successColor, width: 10), left: BorderSide(color: Colors.transparent, width: 8), right: BorderSide(color: Colors.transparent, width: 8)),
      )),
    ]);
  }
}

// Immediate Rating Dialog
