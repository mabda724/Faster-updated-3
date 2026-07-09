import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/location_service.dart';
import 'driver_arrival_qr_scan_screen.dart';

class DriverActiveRideScreen extends StatefulWidget {
  final Map<String, dynamic> booking;
  const DriverActiveRideScreen({super.key, required this.booking});
  @override
  State<DriverActiveRideScreen> createState() => _DriverActiveRideScreenState();
}

class _DriverActiveRideScreenState extends State<DriverActiveRideScreen> {
  late Map<String, dynamic> _booking;
  MapController? _mapController;
  LatLng? _driverLocation;
  LatLng? _clientLocation;
  StreamSubscription? _driverLocSub;
  StreamSubscription? _bookingSub;
  bool _isLoading = true;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _booking = widget.booking;
    _mapController = MapController();
    _load();
    _listenBookingUpdates();
    _trackDriverLocation();
  }

  @override
  void dispose() {
    _driverLocSub?.cancel();
    _bookingSub?.cancel();
    super.dispose();
  }

  void _listenBookingUpdates() {
    _bookingSub = SupabaseService.db
        .from('bookings')
        .stream(primaryKey: ['id'])
        .eq('id', _booking['id'])
        .listen((data) {
          if (data.isNotEmpty && mounted) {
            final newStatus = data.first['status'];
            final oldStatus = _booking['status'];
            setState(() => _booking = data.first);
            if (newStatus != oldStatus) {
              _showStatusSnackBar(newStatus);
            }
          }
        });
  }

  void _trackDriverLocation() {
    final uid = SupabaseService.currentUserId;
    if (uid == null) return;
    _driverLocSub = SupabaseService.db
        .from('provider_locations')
        .stream(primaryKey: ['provider_id'])
        .eq('provider_id', uid)
        .listen((data) {
          if (data.isNotEmpty && mounted) {
            final lat = double.tryParse(data.first['latitude']?.toString() ?? '');
            final lng = double.tryParse(data.first['longitude']?.toString() ?? '');
            if (lat != null && lng != null) {
              setState(() => _driverLocation = LatLng(lat, lng));
            }
          }
        });
  }

  void _showStatusSnackBar(String status) {
    String message;
    switch (status) {
      case 'on_the_way':
        message = 'جاري التوجه للعميل';
        break;
      case 'arrived':
        message = 'تم الوصول للعميل';
        break;
      case 'in_progress':
        message = 'بدأت الرحلة';
        break;
      case 'completed':
        message = 'تم إنهاء الرحلة بنجاح';
        break;
      case 'cancelled':
        message = 'تم إلغاء الرحلة';
        break;
      default:
        message = 'تم تحديث الحالة';
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: status == 'completed'
            ? AppTheme.successColor
            : status == 'cancelled'
                ? AppTheme.errorColor
                : AppTheme.primaryColor,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _load() async {
    try {
      // Load client location from booking
      final clientLat = double.tryParse(_booking['client_lat']?.toString() ?? '');
      final clientLng = double.tryParse(_booking['client_lng']?.toString() ?? '');
      if (clientLat != null && clientLng != null) {
        _clientLocation = LatLng(clientLat, clientLng);
      }

      // Load pickup location
      final pickupLat = double.tryParse(_booking['pickup_lat']?.toString() ?? '');
      final pickupLng = double.tryParse(_booking['pickup_lng']?.toString() ?? '');

      // Load driver location
      final uid = SupabaseService.currentUserId;
      if (uid != null) {
        final loc = await SupabaseService.db
            .from('provider_locations')
            .select('latitude, longitude')
            .eq('provider_id', uid)
            .maybeSingle();
        if (loc != null) {
          final lat = double.tryParse(loc['latitude']?.toString() ?? '');
          final lng = double.tryParse(loc['longitude']?.toString() ?? '');
          if (lat != null && lng != null) {
            _driverLocation = LatLng(lat, lng);
          }
        }
      }

      // Refresh booking data
      final fresh = await SupabaseService.db
          .from('bookings')
          .select('*, profiles(full_name, phone)')
          .eq('id', _booking['id'])
          .single();
      if (mounted) {
        setState(() {
          _booking = fresh;
          _isLoading = false;
        });
        // Fit map to show all points
        _fitMapBounds();
      }
    } catch (e) {
      debugPrint('Error loading ride: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _fitMapBounds() {
    if (_mapController == null) return;
    final points = <LatLng>[];
    if (_driverLocation != null) points.add(_driverLocation!);
    if (_clientLocation != null) points.add(_clientLocation!);
    final pickupLat = double.tryParse(_booking['pickup_lat']?.toString() ?? '');
    final pickupLng = double.tryParse(_booking['pickup_lng']?.toString() ?? '');
    if (pickupLat != null && pickupLng != null) points.add(LatLng(pickupLat, pickupLng));
    final destLat = double.tryParse(_booking['destination_lat']?.toString() ?? '');
    final destLng = double.tryParse(_booking['destination_lng']?.toString() ?? '');
    if (destLat != null && destLng != null) points.add(LatLng(destLat, destLng));

    if (points.length >= 2) {
      try {
        final bounds = LatLngBounds.fromPoints(points);
        _mapController!.fitCamera(
          CameraFit.bounds(
            bounds: bounds,
            padding: const EdgeInsets.all(50),
          ),
        );
      } catch (_) {}
    }
  }

  Future<void> _updateStatus(String newStatus) async {
    if (_isUpdating) return;
    final confirmed = await _showConfirmDialog(newStatus);
    if (!confirmed) return;

    setState(() => _isUpdating = true);
    try {
      await SupabaseService.db.from('bookings').update({
        'status': newStatus,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', _booking['id']);

      if (newStatus == 'completed') {
        // Mark ride as completed
        await SupabaseService.db.from('bookings').update({
          'completed_at': DateTime.now().toUtc().toIso8601String(),
        }).eq('id', _booking['id']);
      }

      if (mounted) {
        setState(() {
          _booking['status'] = newStatus;
          _isUpdating = false;
        });
        _showStatusSnackBar(newStatus);
        if (newStatus == 'completed' || newStatus == 'cancelled') {
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      debugPrint('Error updating status: $e');
      if (mounted) {
        setState(() => _isUpdating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحديث الحالة: $e'), backgroundColor: AppTheme.errorColor),
        );
      }
    }
  }

  Future<bool> _showConfirmDialog(String status) async {
    String title, content;
    switch (status) {
      case 'on_the_way':
        title = 'تأكيد الذهاب';
        content = 'هل تريد التوجه للعميل الآن؟';
        break;
      case 'arrived':
        title = 'تأكيد الوصول';
        content = 'هل وصلت بالفعل للعميل؟';
        break;
      case 'in_progress':
        title = 'بدء الرحلة';
        content = 'هل تريد بدء تنفيذ الخدمة؟';
        break;
      case 'completed':
        title = 'إنهاء الرحلة';
        content = 'هل تريد إنهاء الرحلة؟';
        break;
      case 'cancelled':
        title = 'إلغاء الرحلة';
        content = 'هل أنت متأكد من إلغاء هذه الرحلة؟ سيتم خصم عمولة الإلغاء.';
        break;
      default:
        return true;
    }
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: DesignTokens.brLg),
        title: Text(title, textAlign: TextAlign.center),
        content: Text(content, textAlign: TextAlign.center),
        actionsAlignment: MainAxisAlignment.spaceEvenly,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: status == 'cancelled' ? AppTheme.errorColor : AppTheme.primaryColor,
              shape: RoundedRectangleBorder(borderRadius: DesignTokens.brMd),
            ),
            child: const Text('تأكيد', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  String _nextStatus(String current) {
    switch (current) {
      case 'accepted':
        return 'on_the_way';
      case 'on_the_way':
        return 'arrived';
      case 'arrived':
        return 'in_progress';
      case 'in_progress':
        return 'completed';
      default:
        return current;
    }
  }

  String _nextStatusLabel(String current) {
    switch (current) {
      case 'accepted':
        return 'في الطريق للاستلام';
      case 'on_the_way':
        return 'وصلت للعميل';
      case 'arrived':
        return ' بدأت الرحلة';
      case 'in_progress':
        return 'أنهيت الرحلة';
      default:
        return '';
    }
  }

  Future<void> _handleNextAction(String status) async {
    if (status == 'arrived') {
      // Scan QR to start ride
      final result = await Navigator.push<String>(
        context,
        MaterialPageRoute(
          builder: (_) => DriverArrivalQrScanScreen(bookingId: _booking['id'].toString()),
        ),
      );
      if (result == null) return; // User cancelled
      // Verify QR code matches locked code in booking
      final qrCode = _booking['client_qr_code']?.toString();
      if (qrCode != null && result.trim() != qrCode.trim()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('الكود غير صحيح!'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
        return;
      }
      await _updateStatus('in_progress');
    } else {
      await _updateStatus(_nextStatus(status));
    }
  }

  IconData _nextStatusIcon(String current) {
    switch (current) {
      case 'accepted':
        return Icons.directions_car_rounded;
      case 'on_the_way':
        return Icons.person_pin_circle_rounded;
      case 'arrived':
        return Icons.qr_code_scanner_rounded;
      case 'in_progress':
        return Icons.check_circle_rounded;
      default:
        return Icons.arrow_forward;
    }
  }

  Color _nextStatusColor(String current) {
    switch (current) {
      case 'accepted':
        return AppTheme.infoColor;
      case 'on_the_way':
        return AppTheme.tertiaryColor;
      case 'arrived':
        return AppTheme.primaryColor;
      case 'in_progress':
        return AppTheme.successColor;
      default:
        return AppTheme.textSecondary;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'accepted':
        return AppTheme.primaryColor;
      case 'on_the_way':
        return AppTheme.infoColor;
      case 'arrived':
        return AppTheme.tertiaryColor;
      case 'in_progress':
        return AppTheme.successColor;
      case 'completed':
        return AppTheme.successColor;
      case 'cancelled':
        return AppTheme.errorColor;
      default:
        return AppTheme.textSecondary;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'accepted':
        return 'مقبول';
      case 'on_the_way':
        return 'في الطريق';
      case 'arrived':
        return 'وصل';
      case 'in_progress':
        return 'جاري التنفيذ';
      case 'completed':
        return 'مكتمل';
      case 'cancelled':
        return 'ملغى';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
          : Stack(
              children: [
                // Map
                Positioned.fill(
                  child: _buildMap(),
                ),
                // Top bar
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: _buildTopBar(),
                ),
                // Bottom sheet
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _buildBottomSheet(),
                ),
              ],
            ),
    );
  }

  Widget _buildMap() {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _driverLocation ?? const LatLng(30.0444, 31.2357),
        initialZoom: 14,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.faster.app',
        ),
        MarkerLayer(markers: _buildMarkers()),
      ],
    );
  }

  List<Marker> _buildMarkers() {
    final markers = <Marker>[];
    if (_driverLocation != null) {
      markers.add(Marker(
        point: _driverLocation!,
        width: 44,
        height: 44,
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.primaryColor,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [BoxShadow(color: AppTheme.primaryColor.withValues(alpha: 0.3), blurRadius: 8)],
          ),
          child: const Icon(Icons.directions_car_rounded, color: Colors.white, size: 22),
        ),
      ));
    }
    if (_clientLocation != null) {
      markers.add(Marker(
        point: _clientLocation!,
        width: 44,
        height: 44,
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.successColor,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [BoxShadow(color: AppTheme.successColor.withValues(alpha: 0.3), blurRadius: 8)],
          ),
          child: const Icon(Icons.person, color: Colors.white, size: 22),
        ),
      ));
    }
    final pickupLat = double.tryParse(_booking['pickup_lat']?.toString() ?? '');
    final pickupLng = double.tryParse(_booking['pickup_lng']?.toString() ?? '');
    if (pickupLat != null && pickupLng != null) {
      markers.add(Marker(
        point: LatLng(pickupLat, pickupLng),
        width: 36,
        height: 36,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.blue,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: const Icon(Icons.flag, color: Colors.white, size: 18),
        ),
      ));
    }
    final destLat = double.tryParse(_booking['destination_lat']?.toString() ?? '');
    final destLng = double.tryParse(_booking['destination_lng']?.toString() ?? '');
    if (destLat != null && destLng != null) {
      markers.add(Marker(
        point: LatLng(destLat, destLng),
        width: 36,
        height: 36,
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.errorColor,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: const Icon(Icons.location_on, color: Colors.white, size: 18),
        ),
      ));
    }
    return markers;
  }

  Widget _buildTopBar() {
    return Container(
      margin: EdgeInsets.fromLTRB(DesignTokens.space6.w, MediaQuery.of(context).padding.top + DesignTokens.space4.h, DesignTokens.space6.w, 0),
      padding: const EdgeInsets.symmetric(
        horizontal: DesignTokens.space6,
        vertical: DesignTokens.space4,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: DesignTokens.brLg,
        boxShadow: DesignTokens.shadow3(Colors.black),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
          ),
          Expanded(
            child: Text(
              _booking['status'] == 'completed' || _booking['status'] == 'cancelled'
                  ? 'الرحلة منتهية'
                  : 'تفاصيل الرحلة',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: DesignTokens.textTitleMedium,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: DesignTokens.space4,
              vertical: DesignTokens.space2,
            ),
            decoration: BoxDecoration(
              color: _statusColor(_booking['status'] ?? '').withValues(alpha: 0.1),
              borderRadius: DesignTokens.brXl,
            ),
            child: Text(
              _statusLabel(_booking['status'] ?? ''),
              style: TextStyle(
                fontSize: DesignTokens.textBodySmall,
                fontWeight: FontWeight.bold,
                color: _statusColor(_booking['status'] ?? ''),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomSheet() {
    final clientProfile = _booking['profiles'];
    final clientName = clientProfile is Map ? (clientProfile['full_name'] ?? 'عميل') : 'عميل';
    final clientPhone = clientProfile is Map ? (clientProfile['phone'] ?? '') : '';
    final clientRating = _booking['client_rating'];
    final pickup = _booking['pickup_address'] ?? 'نقطة الانطلاق';
    final destination = _booking['destination_address'] ?? 'الوجهة';
    final price = double.tryParse(
            (_booking['offered_price'] ?? _booking['total_price'])?.toString() ?? '0') ??
        0;
    final status = _booking['status'] ?? '';
    final isActive = status != 'completed' && status != 'cancelled';

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.55,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(DesignTokens.radius2xl)),
        boxShadow: DesignTokens.shadow5(Colors.black),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          DesignTokens.space8.w,
          DesignTokens.space6.h,
          DesignTokens.space8.w,
          MediaQuery.of(context).padding.bottom + DesignTokens.space8.h,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: DesignTokens.space12,
                height: DesignTokens.space1,
                decoration: BoxDecoration(
                  color: AppTheme.textTertiary,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            SizedBox(height: DesignTokens.space8.h),

            // Client info
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.person, color: AppTheme.primaryColor, size: 24),
                ),
                SizedBox(width: DesignTokens.space6.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(clientName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: DesignTokens.textBodyLarge,
                          )),
                      if (clientRating != null)
                        Row(
                          children: [
                            const Icon(Icons.star_rounded, color: AppTheme.tertiaryColor, size: 16),
                            SizedBox(width: DesignTokens.space1.w),
                            Text(
                              '${double.tryParse(clientRating.toString())?.toStringAsFixed(1) ?? clientRating}',
                              style: TextStyle(
                                fontSize: DesignTokens.textBodySmall,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                if (clientPhone.toString().isNotEmpty)
                  Row(
                    children: [
                      _buildCircleButton(
                        Icons.phone_rounded,
                        AppTheme.successColor,
                        () => launchUrl(Uri.parse('tel:$clientPhone')),
                      ),
                      SizedBox(width: DesignTokens.space3.w),
                      _buildCircleButton(
                        Icons.chat_rounded,
                        AppTheme.primaryColor,
                        () {
                          // Navigate to chat
                        },
                      ),
                    ],
                  ),
              ],
            ),
            SizedBox(height: DesignTokens.space8.h),

            // Route info
            Container(
              padding: const EdgeInsets.all(DesignTokens.space6),
              decoration: BoxDecoration(
                color: AppTheme.backgroundColor,
                borderRadius: DesignTokens.brMd,
              ),
              child: Column(
                children: [
                  _buildRouteRow(Icons.circle, pickup, AppTheme.successColor, 'نقطة الانطلاق'),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: DesignTokens.space2),
                    child: Row(
                      children: [
                        SizedBox(width: DesignTokens.space3.w + 5),
                        Container(width: 1, height: 20, color: AppTheme.textSecondary.withValues(alpha: 0.3)),
                      ],
                    ),
                  ),
                  _buildRouteRow(Icons.location_on, destination, AppTheme.errorColor, 'الوجهة'),
                ],
              ),
            ),
            SizedBox(height: DesignTokens.space6.h),

            // Price
            Container(
              padding: const EdgeInsets.all(DesignTokens.space6),
              decoration: BoxDecoration(
                color: AppTheme.successColor.withValues(alpha: 0.05),
                borderRadius: DesignTokens.brMd,
                border: Border.all(color: AppTheme.successColor.withValues(alpha: 0.15)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('سعر الرحلة',
                      style: TextStyle(
                        fontSize: DesignTokens.textBodyLarge,
                        color: AppTheme.textSecondary,
                      )),
                  Text(
                    '${price.toStringAsFixed(0)} ج.م',
                    style: const TextStyle(
                      fontSize: DesignTokens.textTitleLarge,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.successColor,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: DesignTokens.space8.h),

            // Action buttons
            if (isActive) ...[
              // Next status button
              SizedBox(
                width: double.infinity,
                height: DesignTokens.buttonHeight + 4,
                child: ElevatedButton.icon(
                  onPressed: _isUpdating ? null : () => _handleNextAction(status),
                  icon: _isUpdating
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Icon(_nextStatusIcon(status), color: Colors.white),
                  label: Text(
                    _isUpdating ? 'جاري التحديث...' : _nextStatusLabel(status),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: DesignTokens.textBodyLarge,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _nextStatusColor(status),
                    shape: RoundedRectangleBorder(borderRadius: DesignTokens.brMd),
                  ),
                ),
              ),
              SizedBox(height: DesignTokens.space4.h),
              // Cancel button
              SizedBox(
                width: double.infinity,
                height: DesignTokens.buttonHeight,
                child: OutlinedButton.icon(
                  onPressed: _isUpdating ? null : () => _updateStatus('cancelled'),
                  icon: const Icon(Icons.cancel_outlined, color: AppTheme.errorColor),
                  label: const Text('إلغاء الرحلة',
                      style: TextStyle(color: AppTheme.errorColor, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppTheme.errorColor),
                    shape: RoundedRectangleBorder(borderRadius: DesignTokens.brMd),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCircleButton(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }

  Widget _buildRouteRow(IconData icon, String text, Color color, String label) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        SizedBox(width: DesignTokens.space4.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(
                fontSize: DesignTokens.textLabelSmall,
                color: AppTheme.textSecondary,
              )),
              Text(text,
                  style: const TextStyle(
                    fontSize: DesignTokens.textBodyMedium,
                    color: AppTheme.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ],
    );
  }
}
