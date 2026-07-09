import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:latlong2/latlong.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgresChangeEvent, PostgresChangeFilter, PostgresChangeFilterType, RealtimeChannel;

import '../../../core/services/supabase_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/compass_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/design_tokens.dart';

class ProviderDeliveryTrackingScreen extends StatefulWidget {
  final String bookingId;
  const ProviderDeliveryTrackingScreen({super.key, required this.bookingId});

  @override
  State<ProviderDeliveryTrackingScreen> createState() =>
      _ProviderDeliveryTrackingScreenState();
}

class _ProviderDeliveryTrackingScreenState
    extends State<ProviderDeliveryTrackingScreen> {
  Map<String, dynamic>? _booking;
  bool _isLoading = true;

  // Map
  LatLng? _providerPos;
  LatLng? _clientPos;
  LatLng? _shopPos;
  double? _providerHeading;
  Timer? _locationTimer;
  RealtimeChannel? _bookingSub;

  // UI state
  int _deliveryStep = 1;
  bool _showQrModal = false;
  bool _showSuccessModal = false;
  String _qrModalTitle = '';
  bool _qrHandled = false;

  // Chat
  bool _showChat = false;
  final TextEditingController _chatCtrl = TextEditingController();
  final ScrollController _chatScroll = ScrollController();
  List<Map<String, dynamic>> _chatMessages = [];
  RealtimeChannel? _chatSub;

  bool get _isPickupStep => _deliveryStep == 1;
  bool get _isDeliveryStep => _deliveryStep == 3;

  String get _partnerName =>
      _booking?['profiles']?['full_name'] ?? 'العميل';
  String get _partnerPhone =>
      _booking?['profiles']?['phone']?.toString() ?? '';
  String get _shopName =>
      _booking?['service_name']?.toString() ?? 'المتجر';

  String get _shopAddress =>
      _booking?['shop_address']?.toString() ?? '';

  String get _clientAddress =>
      _booking?['address']?.toString() ?? '';

  @override
  void initState() {
    super.initState();
    _loadBooking();
    _listenToBookingChanges();
    CompassService.startTracking();
    _pollProviderLocation();
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    _bookingSub?.unsubscribe();
    _chatSub?.unsubscribe();
    _chatCtrl.dispose();
    _chatScroll.dispose();
    CompassService.stopTracking();
    super.dispose();
  }

  // ───── Data Loading ─────

  Future<void> _loadBooking() async {
    try {
      final res = await SupabaseService.client
          .from('bookings')
          .select('*, profiles!bookings_client_id_fkey(*), provider_profiles!bookings_provider_id_fkey(profiles(*))')
          .eq('id', widget.bookingId)
          .single();
      if (!mounted) return;
      setState(() {
        _booking = res;
        _isLoading = false;
        _initStepFromStatus();
        _loadClientLocation();
        _loadChatMessages();
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _loadClientLocation() {
    final clientId = _booking?['client_id']?.toString();
    if (clientId == null) return;
    SupabaseService.client
        .from('profiles')
        .select('lat, lng')
        .eq('id', clientId)
        .single()
        .then((r) {
      if (r['lat'] != null && r['lng'] != null && mounted) {
        setState(() {
          _clientPos = LatLng(
            double.parse(r['lat'].toString()),
            double.parse(r['lng'].toString()),
          );
        });
      }
    });
  }

  void _pollProviderLocation() {
    _locationTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      final pos = CompassService.currentPosition;
      if (pos != null && mounted) {
        setState(() {
          _providerPos = LatLng(pos.latitude, pos.longitude);
        });
      }
      final h = CompassService.currentHeading;
      if (h != null && mounted) {
        setState(() => _providerHeading = h);
      }
    });
  }

  void _listenToBookingChanges() {
    _bookingSub = SupabaseService.client
        .channel('booking-delivery-${widget.bookingId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'bookings',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: widget.bookingId,
          ),
          callback: (payload) {
            if (!mounted) return;
            final newData = payload.newRecord;
            setState(() {
              if (_booking != null) _booking!.addAll(newData);
              _initStepFromStatus();
            });
          },
        )
        .subscribe();
  }

  void _initStepFromStatus() {
    final status = _booking?['status']?.toString() ?? 'pending';
    switch (status) {
      case 'accepted':
      case 'on_the_way':
        _deliveryStep = 1;
        break;
      case 'arrived':
        _deliveryStep = 2;
        break;
      case 'in_progress':
        _deliveryStep = 3;
        break;
      case 'completed':
        _deliveryStep = 4;
        _showSuccessModal = true;
        break;
    }
  }

  // ───── Chat ─────

  Future<void> _loadChatMessages() async {
    try {
      final res = await SupabaseService.client
          .from('chat_messages')
          .select('*, profiles(full_name, avatar_url)')
          .eq('booking_id', widget.bookingId)
          .order('created_at');
      if (mounted) setState(() => _chatMessages = List.from(res));
    } catch (_) {}
    _chatSub = SupabaseService.client
        .channel('chat-delivery-${widget.bookingId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'chat_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'booking_id',
            value: widget.bookingId,
          ),
          callback: (payload) {
            if (mounted) {
              setState(() => _chatMessages.add(payload.newRecord));
              WidgetsBinding.instance.addPostFrameCallback(
                  (_) => _chatScroll.jumpTo(_chatScroll.position.maxScrollExtent));
            }
          },
        )
        .subscribe();
  }

  Future<void> _sendMessage() async {
    final text = _chatCtrl.text.trim();
    if (text.isEmpty) return;
    _chatCtrl.clear();
    try {
      await SupabaseService.client.from('chat_messages').insert({
        'booking_id': widget.bookingId,
        'sender_id': SupabaseService.currentUserId,
        'message': text,
      });
    } catch (_) {}
  }

  // ───── Status Update ─────

  Future<void> _updateStatus(String newStatus) async {
    try {
      final now = DateTime.now().toIso8601String();
      final update = <String, dynamic>{'status': newStatus};
      if (newStatus == 'on_the_way') update['started_at'] = now;
      if (newStatus == 'arrived') {
        update['arrived_at'] = now;
        if (_providerPos != null) {
          update['arrived_lat'] = _providerPos!.latitude;
          update['arrived_lng'] = _providerPos!.longitude;
        }
      }
      if (newStatus == 'completed') {
        update['completed_at'] = now;
        if (_providerPos != null) {
          update['completed_lat'] = _providerPos!.latitude;
          update['completed_lng'] = _providerPos!.longitude;
        }
      }
      await SupabaseService.client
          .from('bookings')
          .update(update)
          .eq('id', widget.bookingId);

      final clientId = _booking?['client_id']?.toString();
      if (clientId != null) {
        String? title, body;
        switch (newStatus) {
          case 'on_the_way':
            title = 'مقدم الخدمة في الطريق';
            body = 'مقدم الخدمة في طريقه إليك';
            break;
          case 'arrived':
            title = 'تم الوصول';
            body = 'وصل مقدم الخدمة إلى الموقع';
            break;
          case 'completed':
            title = 'تم إكمال الخدمة';
            body = 'تم إتمام الخدمة بنجاح';
            break;
        }
        if (title != null && body != null) {
          await NotificationService.sendPushNotification(
            userId: clientId,
            title: title,
            body: body,
            type: 'order_status',
            data: {'booking_id': widget.bookingId},
          );
        }
      }
    } catch (_) {}
  }

  // ───── QR Handling ─────

  void _showQrScan(String title) {
    setState(() {
      _qrModalTitle = title;
      _showQrModal = true;
      _qrHandled = false;
    });
  }

  void _onQrDetect(BarcodeCapture capture) {
    if (_qrHandled) return;
    final raw = capture.barcodes.first.rawValue?.trim();
    if (raw == null || raw.isEmpty) return;
    final parts = raw.split(':');
    if (parts.length != 3 || parts[0] != 'FASTER_ARRIVAL') return;
    if (parts[1] != widget.bookingId) return;

    _qrHandled = true;
    setState(() => _showQrModal = false);

    if (_isPickupStep) {
      _confirmPickup();
    } else if (_isDeliveryStep) {
      _confirmDelivery();
    }
  }

  Future<void> _confirmPickup() async {
    await _updateStatus('arrived');
    if (!mounted) return;
    setState(() {
      _deliveryStep = 2;
    });
  }

  Future<void> _startTrip() async {
    await _updateStatus('in_progress');
    if (!mounted) return;
    setState(() {
      _deliveryStep = 3;
    });
  }

  Future<void> _confirmDelivery() async {
    await _updateStatus('completed');
    if (!mounted) return;
    setState(() {
      _deliveryStep = 4;
      _showSuccessModal = true;
    });
  }

  // ───── Earnings ─────

  double get _deliveryEarnings {
    final total = double.tryParse(
            _booking?['total_price']?.toString() ?? '0') ??
        0;
    final commission = double.tryParse(
            _booking?['commission_amount']?.toString() ?? '0') ??
        0;
    return total - commission;
  }

  double get _bonusEarnings => 0.0;

  double get _totalEarnings => _deliveryEarnings + _bonusEarnings;

  // ──── Helper ────

  String _serviceName() {
    return _booking?['services']?['name']?.toString() ??
        _booking?['service_name']?.toString() ??
        'خدمة';
  }

  // ───── Trip State Helpers ─────

  bool get _isHeading => _deliveryStep == 1;
  bool get _isArrived => _deliveryStep == 2;
  bool get _isInTransit => _deliveryStep == 3;
  bool get _isDone => _deliveryStep == 4;

  String get _headerTitle {
    if (_isHeading) return 'في الطريق للعميل';
    if (_isArrived) return 'وصلت للعميل';
    if (_isInTransit) return 'أثناء الرحلة';
    return 'وصلت للوجهة';
  }

  String get _orderIdLabel => '#${widget.bookingId.substring(0, 5)}';

  // ───── Build ─────

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator(color: AppTheme.successColor)),
      );
    }
    if (_booking == null) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(title: const Text('غير متاح')),
        body: const Center(child: Text('بيانات الطلب غير متوفرة')),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Stack(
        children: [
          // ── Map Area ──
          Positioned.fill(child: _buildMapArea()),

          // ── Header Bar ──
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildHeaderBar(),
          ),

          // ── Floating Info ──
          if (_isHeading || _isInTransit) _buildFloatingInfo(),

          // ── Bottom Sheet ──
          _buildBottomSheet(),

          // ── QR Modal ──
          if (_showQrModal) _buildQrModal(),

          // ── Success Modal ──
          if (_showSuccessModal) _buildSuccessModal(),

          // ── Chat Overlay ──
          if (_showChat) _buildChatOverlay(),
        ],
      ),
    );
  }

  // ───── Header Bar ─────

  Widget _buildHeaderBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(
          DesignTokens.space4.w, MediaQuery.of(context).padding.top + 8,
          DesignTokens.space4.w, DesignTokens.space4.h),
      decoration: const BoxDecoration(color: AppTheme.successColor),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 32.sp, height: 32.sp,
              alignment: Alignment.center,
              child: const Icon(Icons.chevron_right_rounded, color: Colors.white, size: 20),
            ),
          ),
          Expanded(
            child: Text(_headerTitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
          ),
          GestureDetector(
            onTap: () => setState(() => _showChat = !_showChat),
            child: Container(
              width: 32.sp, height: 32.sp,
              alignment: Alignment.center,
              child: const Icon(Icons.menu_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  // ───── Floating Info ─────

  Widget _buildFloatingInfo() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 60,
      left: 16.w,
      right: 16.w,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: DesignTokens.space4.w, vertical: DesignTokens.space3.h),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: AppTheme.dividerColor),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8)],
        ),
        child: _isInTransit
            ? Row(children: [
                Expanded(child: _infoBlock('الوقت المتبقي', '16 دقيقة')),
                Container(width: 1, height: 24, color: AppTheme.dividerColor),
                Expanded(child: _infoBlock('المسافة المتبقية', '7.3 كم')),
              ])
            : _infoBlock('الوقت المتوقع للوصول', '12 دقيقة'),
      ),
    );
  }

  Widget _infoBlock(String label, String value) {
    return Column(
      children: [
        Text(label,
            style: TextStyle(fontSize: 8.sp, color: AppTheme.textSecondary, fontWeight: FontWeight.bold)),
        Text(value,
            style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.bold, color: AppTheme.successColor)),
      ],
    );
  }

  // ───── Map ─────

  Widget _buildMapArea() {
    return Stack(
      children: [
        Positioned.fill(child: CustomPaint(painter: _MapGridPainter())),
        Positioned.fill(
          child: CustomPaint(
            painter: _RouteLinePainter(markerPositions: _getMarkerLayout()),
          ),
        ),
        ..._buildMarkers(),
      ],
    );
  }

  Map<String, Offset> _getMarkerLayout() {
    final size = MediaQuery.of(context).size;
    return {
      'driver': Offset(
        size.width * (_isDone ? 0.7 : _isArrived ? 0.55 : 0.35),
        size.height * (_isHeading ? 0.28 : 0.45),
      ),
      'client': Offset(size.width * 0.55, size.height * 0.5),
      'destination': Offset(size.width * 0.3, size.height * 0.22),
    };
  }

  List<Widget> _buildMarkers() {
    final layout = _getMarkerLayout();
    final markers = <Widget>[];

    // Car marker
    markers.add(Positioned(
      left: layout['driver']!.dx - 16,
      top: layout['driver']!.dy - 16,
      child: Container(
        padding: EdgeInsets.all(4.sp),
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: AppTheme.dividerColor),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8)],
        ),
        child: const Icon(Icons.directions_car_rounded, color: AppTheme.successColor, size: 22),
      ),
    ));

    // Client marker (person icon)
    if (!_isInTransit && !_isDone) {
      markers.add(Positioned(
        left: layout['client']!.dx - 16,
        top: layout['client']!.dy - 16,
        child: Column(children: [
          const Icon(Icons.accessibility_rounded, color: AppTheme.infoColor, size: 28),
          Container(
            width: 6, height: 3,
            margin: const EdgeInsets.only(top: 2),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
          ),
        ]),
      ));
    }

    // Destination marker (B)
    if (_isInTransit || _isDone) {
      markers.add(Positioned(
        left: layout['destination']!.dx - 14,
        top: layout['destination']!.dy - 14,
        child: Column(children: [
          Container(
            width: 22.sp, height: 22.sp,
            decoration: BoxDecoration(
              color: AppTheme.successColor,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 4)],
            ),
            child: Center(child: Text('B',
                style: TextStyle(color: Colors.white, fontSize: 9.sp, fontWeight: FontWeight.bold))),
          ),
          const Icon(Icons.flag_rounded, color: AppTheme.textSecondary, size: 20),
        ]),
      ));
    }

    return markers;
  }

  // ───── Bottom Sheet ─────

  Widget _buildBottomSheet() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(32),
            topRight: Radius.circular(32),
          ),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 25, offset: const Offset(0, -5))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48.sp, height: 6.sp,
              margin: EdgeInsets.only(top: DesignTokens.space3.h),
              decoration: BoxDecoration(
                color: AppTheme.dividerColor,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            if (_isHeading) _buildHeadingContent(),
            if (_isArrived) _buildArrivedContent(),
            if (_isInTransit) _buildTransitContent(),
            if (_isDone) _buildDoneContent(),
          ],
        ),
      ),
    );
  }

  // ───── Step 1: Heading to client (HTML 7) ─────

  Widget _buildHeadingContent() {
    return Padding(
      padding: EdgeInsets.fromLTRB(DesignTokens.space8.w, DesignTokens.space5.h, DesignTokens.space8.w, DesignTokens.space6.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Client card
          Container(
            padding: EdgeInsets.all(DesignTokens.space4.w),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor70,
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: AppTheme.backgroundColor),
            ),
            child: Row(
              children: [
                Container(
                  width: 44.sp, height: 44.sp,
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                  clipBehavior: Clip.antiAlias,
                  child: Image.network(
                    'https://i.pravatar.cc/150?img=33',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: AppTheme.dividerColor,
                      child: Icon(Icons.person_rounded, color: AppTheme.textTertiary, size: 22.sp),
                    ),
                  ),
                ),
                SizedBox(width: DesignTokens.space3.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_partnerName,
                          style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                      SizedBox(height: 2.h),
                      Row(children: [
                        Icon(Icons.star_rounded, color: AppTheme.warningColor, size: 10.sp),
                        SizedBox(width: 2.w),
                        Text('5.0',
                            style: TextStyle(fontSize: 8.sp, fontWeight: FontWeight.bold, color: AppTheme.warningColor)),
                      ]),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: _partnerPhone.isNotEmpty ? () {} : null,
                  child: Container(
                    width: 36.sp, height: 36.sp,
                    decoration: BoxDecoration(
                      color: AppTheme.dividerColor,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.phone_rounded, color: AppTheme.successColor, size: 16),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: DesignTokens.space5.h),
          // Client location
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.location_on_rounded, color: AppTheme.infoColor, size: 14.sp),
              SizedBox(width: DesignTokens.space3.w),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_clientAddress,
                      style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                  Text(_shopAddress.isNotEmpty ? _shopAddress : _clientAddress,
                      style: TextStyle(fontSize: 9.sp, color: AppTheme.textSecondary)),
                ],
              ),
            ],
          ),
          SizedBox(height: DesignTokens.space5.h),
          Container(height: 1, color: AppTheme.backgroundColor),
          SizedBox(height: DesignTokens.space5.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildContactButton(Icons.phone_rounded, 'مكالمة', null),
              _buildContactButton(Icons.chat_bubble_outline_rounded, 'رسالة', () => setState(() => _showChat = true)),
              _buildContactButton(Icons.near_me_rounded, 'ملاحة', null),
            ],
          ),
          SizedBox(height: DesignTokens.space5.h),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _showQrScan('تأكيد الوصول للعميل'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.successColor,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: DesignTokens.space5.h),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                elevation: 0,
              ),
              child: Text('تأكيد الوصول',
                  style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactButton(IconData icon, String label, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, color: onTap != null ? AppTheme.successColor : AppTheme.textSecondary, size: 18.sp),
          SizedBox(height: DesignTokens.space1.h),
          Text(label, style: TextStyle(fontSize: 8.sp, fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
        ],
      ),
    );
  }

  // ───── Step 2: Arrived at client (HTML 8) ─────

  Widget _buildArrivedContent() {
    return Padding(
      padding: EdgeInsets.fromLTRB(DesignTokens.space8.w, DesignTokens.space5.h, DesignTokens.space8.w, DesignTokens.space6.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('لقد وصلت إلى العميل',
              style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.bold, color: AppTheme.successColor)),
          SizedBox(height: DesignTokens.space6.h),
          Column(children: [
            Text(_partnerName,
                style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w900, color: AppTheme.textPrimary)),
            SizedBox(height: 2.h),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.star_rounded, color: AppTheme.warningColor, size: 11.sp),
              SizedBox(width: 2.w),
              Text('5.0',
                  style: TextStyle(fontSize: 9.sp, fontWeight: FontWeight.bold, color: AppTheme.warningColor)),
            ]),
          ]),
          SizedBox(height: DesignTokens.space6.h),
          Container(
            padding: EdgeInsets.all(DesignTokens.space4.w),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor70,
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: AppTheme.backgroundColor),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.location_on_rounded, color: AppTheme.infoColor, size: 14.sp),
                SizedBox(width: DesignTokens.space3.w),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_clientAddress,
                        style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                    Text(_shopAddress.isNotEmpty ? _shopAddress : _clientAddress,
                        style: TextStyle(fontSize: 9.sp, color: AppTheme.textSecondary)),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: DesignTokens.space6.h),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _showQrScan('مسح رمز QR لتأكيد التسليم'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.successColor,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: DesignTokens.space5.h),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                elevation: 0,
              ),
              child: Text('تأكيد التسليم',
                  style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.bold)),
            ),
          ),
          SizedBox(height: DesignTokens.space2.h),
          TextButton(
            onPressed: _cancelTrip,
            child: Text('إلغاء الرحلة',
                style: TextStyle(fontSize: 10.sp, color: AppTheme.textTertiary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ───── Step 3: In Transit (HTML 9) ─────

  Widget _buildTransitContent() {
    return Padding(
      padding: EdgeInsets.fromLTRB(DesignTokens.space8.w, DesignTokens.space5.h, DesignTokens.space8.w, DesignTokens.space6.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.all(DesignTokens.space4.w),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor70,
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: AppTheme.backgroundColor),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.location_on_rounded, color: AppTheme.textSecondary, size: 14.sp),
                SizedBox(width: DesignTokens.space3.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('الوجهة',
                          style: TextStyle(fontSize: 8.sp, color: AppTheme.textTertiary, fontWeight: FontWeight.bold)),
                      SizedBox(height: 2.h),
                      Text(_clientAddress,
                          style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                      Text('(At Towayrat, Qena)',
                          style: TextStyle(fontSize: 9.sp, color: AppTheme.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: DesignTokens.space5.h),
          Column(children: [
            Text('السعر المتفق عليه',
                style: TextStyle(fontSize: 8.sp, color: AppTheme.textTertiary, fontWeight: FontWeight.bold)),
            Text(
              '${double.tryParse(_booking?['total_price']?.toString() ?? '0')?.toStringAsFixed(0) ?? '0'} EGP',
              style: TextStyle(fontSize: 24.sp, fontWeight: FontWeight.w900, color: AppTheme.textPrimary),
            ),
          ]),
          SizedBox(height: DesignTokens.space5.h),
          Container(height: 1, color: AppTheme.backgroundColor),
          SizedBox(height: DesignTokens.space5.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildContactButton(Icons.phone_rounded, 'مكالمة', null),
              _buildContactButton(Icons.chat_bubble_outline_rounded, 'رسالة', () => setState(() => _showChat = true)),
              _buildContactButton(Icons.shield_rounded, 'طوارئ', null),
            ],
          ),
        ],
      ),
    );
  }

  // ───── Step 4: Done (HTML 10) ─────

  Widget _buildDoneContent() {
    return Padding(
      padding: EdgeInsets.fromLTRB(DesignTokens.space8.w, DesignTokens.space5.h, DesignTokens.space8.w, DesignTokens.space6.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('لقد وصلت إلى الوجهة',
              style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.bold, color: AppTheme.successColor)),
          SizedBox(height: DesignTokens.space6.h),
          Column(children: [
            Text(_partnerName,
                style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w900, color: AppTheme.textPrimary)),
            SizedBox(height: 2.h),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.star_rounded, color: AppTheme.warningColor, size: 11.sp),
              Text(' 5.0',
                  style: TextStyle(fontSize: 9.sp, fontWeight: FontWeight.bold, color: AppTheme.warningColor)),
            ]),
          ]),
          SizedBox(height: DesignTokens.space6.h),
          Container(
            padding: EdgeInsets.all(DesignTokens.space4.w),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor70,
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: AppTheme.backgroundColor),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.location_on_rounded, color: AppTheme.successColor, size: 14.sp),
                SizedBox(width: DesignTokens.space3.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_clientAddress,
                          style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                      Text('(At Towayrat, Qena)',
                          style: TextStyle(fontSize: 8.sp, color: AppTheme.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: DesignTokens.space4.h),
          Column(children: [
            Text('السعر المتفق عليه',
                style: TextStyle(fontSize: 8.sp, color: AppTheme.textTertiary, fontWeight: FontWeight.bold)),
            Text(
              '${double.tryParse(_booking?['total_price']?.toString() ?? '0')?.toStringAsFixed(0) ?? '0'} EGP',
              style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.w900, color: AppTheme.textPrimary),
            ),
          ]),
          SizedBox(height: DesignTokens.space5.h),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.warningColor,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: DesignTokens.space5.h),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                elevation: 8,
                shadowColor: AppTheme.warningColor.withValues(alpha: 0.3),
              ),
              child: Text('إنهاء الرحلة',
                  style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.bold)),
            ),
          ),
          SizedBox(height: DesignTokens.space2.h),
          TextButton(
            onPressed: _cancelTrip,
            child: Text('إلغاء الرحلة',
                style: TextStyle(fontSize: 10.sp, color: AppTheme.textTertiary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _cancelTrip() {
    Navigator.pop(context);
  }

  // ───── QR Modal (keep existing) ─────

  Widget _buildQrModal() {
    return Positioned.fill(
      child: Container(
        color: AppTheme.darkSurfaceColor,
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: Colors.grey.shade100),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _qrModalTitle,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => setState(() => _showQrModal = false),
                      child: const Icon(Icons.close_rounded,
                          size: 18, color: AppTheme.textTertiary),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    color: AppTheme.darkSurfaceColor,
                    borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
                    border: Border.all(color: AppTheme.primaryColor, width: 4),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: MobileScanner(
                    onDetect: _onQrDetect,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'يرجى مطابقة الفاتورة وتصوير الكود لتحديث النظام تلقائياً.',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppTheme.textTertiary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => setState(() => _showQrModal = false),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.successColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
                      ),
                    ),
                    child: const Text(
                      'إلغاء المسح',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ───── Success Modal (keep existing) ─────

  Widget _buildSuccessModal() {
    return Positioned.fill(
      child: Container(
        color: AppTheme.darkSurfaceColor,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(40),
                border: Border.all(color: AppTheme.dividerColor),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppTheme.backgroundColor,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Stack(
                      alignment: Alignment.center,
                      children: [
                        Icon(Icons.check_circle_rounded,
                            size: 48, color: AppTheme.successColor),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'تم إتمام وتوصيل الطلب بنجاح!',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'شكراً لك يا كابتن، تم إيداع المستحقات في محفظتك الآن.',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.backgroundColor,
                      borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
                      border: Border.all(color: AppTheme.dividerColor),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'أرباح التوصيل الصافية',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: AppTheme.textTertiary,
                                    ),
                                  ),
                                  Text(
                                    '${_deliveryEarnings.toStringAsFixed(2)} جنيه',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.darkBackgroundColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              height: 32,
                              width: 1,
                              color: AppTheme.dividerColor,
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text(
                                    'حوافز المسافة الإضافية',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: AppTheme.textTertiary,
                                    ),
                                  ),
                                  Text(
                                    '+${_bonusEarnings.toStringAsFixed(2)} جنيه',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.successColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Divider(height: 1, color: AppTheme.dividerColor),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'إجمالي ما تم تحصيله:',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                            Text(
                              '${_totalEarnings.toStringAsFixed(2)} جنيه',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () =>
                          Navigator.of(context).popUntil((r) => r.isFirst),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.darkBackgroundColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
                        ),
                        elevation: 2,
                      ),
                      child: const Text(
                        'الانتقال واستقبال الطلب التالي',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () =>
                          Navigator.of(context).popUntil((r) => r.isFirst),
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.textSecondary,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
                        ),
                      ),
                      child: const Text(
                        'العودة للقائمة الرئيسية',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
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

  // ───── Chat Overlay (keep existing) ─────

  Widget _buildChatOverlay() {
    return Positioned.fill(
      child: GestureDetector(
        onTap: () => setState(() => _showChat = false),
        child: Container(
          color: Colors.black26,
          child: GestureDetector(
            onTap: () {},
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                height: MediaQuery.of(context).size.height * 0.5,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'المحادثة',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          GestureDetector(
                            onTap: () =>
                                setState(() => _showChat = false),
                            child: const Icon(Icons.close_rounded,
                                size: 20, color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    const Divider(),
                    Expanded(
                      child: _chatMessages.isEmpty
                          ? const Center(
                              child: Text(
                                'لا توجد رسائل بعد',
                                style: TextStyle(color: AppTheme.textTertiary),
                              ),
                            )
                          : ListView.builder(
                              controller: _chatScroll,
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: _chatMessages.length,
                              itemBuilder: (ctx, i) {
                                final msg = _chatMessages[i];
                                final isMe = msg['sender_id'] ==
                                    SupabaseService.currentUserId;
                                return Align(
                                  alignment: isMe
                                      ? Alignment.centerLeft
                                      : Alignment.centerRight,
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.all(12),
                                    constraints: BoxConstraints(
                                        maxWidth:
                                            MediaQuery.of(context).size.width *
                                                0.7),
                                    decoration: BoxDecoration(
                                      color: isMe
                                          ? AppTheme.primaryColor
                                          : AppTheme.backgroundColor,
                                      borderRadius: BorderRadius.circular(
                                          DesignTokens.radiusMd),
                                    ),
                                    child: Text(
                                      msg['message']?.toString() ?? '',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isMe
                                            ? Colors.white
                                            : AppTheme.textPrimary,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 4,
                            offset: const Offset(0, -2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _chatCtrl,
                              decoration: InputDecoration(
                                hintText: 'اكتب رسالة...',
                                hintStyle: const TextStyle(fontSize: 12),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                      DesignTokens.radiusLg),
                                  borderSide: BorderSide.none,
                                ),
                                filled: true,
                                fillColor: AppTheme.backgroundColor,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 10),
                              ),
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          SizedBox(width: 8.w),
                          GestureDetector(
                            onTap: _sendMessage,
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor,
                                borderRadius: BorderRadius.circular(
                                    DesignTokens.radiusMd),
                              ),
                              child: const Icon(Icons.send_rounded,
                                  size: 18, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ───── Painters ─────

class _MapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.backgroundColor.withValues(alpha: 0.6)
      ..style = PaintingStyle.fill;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _RouteLinePainter extends CustomPainter {
  final Map<String, Offset> markerPositions;

  _RouteLinePainter({required this.markerPositions});

  @override
  void paint(Canvas canvas, Size size) {
    final shop = markerPositions['shop'];
    final driver = markerPositions['driver'];
    final client = markerPositions['client'];
    if (shop == null || driver == null || client == null) return;

    final paint = Paint()
      ..color = AppTheme.primaryColor
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;

    // Dashed effect
    final path = ui.Path()
      ..moveTo(shop.dx + 18, shop.dy + 18)
      ..lineTo(shop.dx + 18, (shop.dy + driver.dy) / 2)
      ..lineTo(driver.dx, driver.dy);

    // Draw dashes manually
    final metrics = path.computeMetrics();
    for (final metric in metrics) {
      double distance = 0;
      while (distance < metric.length) {
        final end = (distance + 8).clamp(0, metric.length).toDouble();
        final segment = metric.extractPath(distance, end);
        canvas.drawPath(segment, paint);
        distance += 14;
      }
    }

    // Second segment: driver to client
    final path2 = ui.Path()
      ..moveTo(driver.dx, driver.dy)
      ..lineTo(client.dx, driver.dy)
      ..lineTo(client.dx, client.dy + 12);

    final metrics2 = path2.computeMetrics();
    for (final metric in metrics2) {
      double distance = 0;
      while (distance < metric.length) {
        final end = (distance + 8).clamp(0, metric.length).toDouble();
        final segment = metric.extractPath(distance, end);
        canvas.drawPath(segment, paint);
        distance += 14;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RouteLinePainter oldDelegate) => true;
}
