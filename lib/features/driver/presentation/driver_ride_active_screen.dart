import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/services/supabase_service.dart';

class DriverRideActiveScreen extends StatefulWidget {
  final Map<String, dynamic> booking;
  final String vehicleType;

  const DriverRideActiveScreen({
    super.key,
    required this.booking,
    required this.vehicleType,
  });

  @override
  State<DriverRideActiveScreen> createState() => _DriverRideActiveScreenState();
}

class _DriverRideActiveScreenState extends State<DriverRideActiveScreen> {
  late Map<String, dynamic> _booking;
  MapController? _mapController;
  LatLng? _driverLocation;
  LatLng? _pickupLocation;
  LatLng? _destinationLocation;
  StreamSubscription? _driverLocSub;
  StreamSubscription? _bookingSub;
  bool _isLoading = true;
  bool _isUpdating = false;
  String? _clientName;
  String? _clientPhone;

  String get _vehicleEmoji {
    return widget.vehicleType == 'scooter' ? '🛵' : '🚗';
  }

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
          if (newStatus == 'completed' || newStatus == 'cancelled') {
            Future.delayed(const Duration(seconds: 2), () {
              if (mounted) Navigator.of(context).pop();
            });
          }
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
        message = 'جاري التوجه للعميل 🛣️';
        break;
      case 'arrived':
        message = 'وصلت للعميل! 📍';
        break;
      case 'in_progress':
        message = 'بدأت الرحلة 🚕';
        break;
      case 'completed':
        message = 'تم انتهاء الرحلة بنجاح ✅';
        break;
      case 'cancelled':
        message = 'تم إلغاء الرحلة';
        break;
      default:
        message = 'تم تحديث الحالة';
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, textAlign: TextAlign.right),
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
      // Parse locations
      final pickupLat = double.tryParse(_booking['pickup_lat']?.toString() ?? '');
      final pickupLng = double.tryParse(_booking['pickup_lng']?.toString() ?? '');
      if (pickupLat != null && pickupLng != null) {
        _pickupLocation = LatLng(pickupLat, pickupLng);
      }

      final destLat = double.tryParse(_booking['destination_lat']?.toString() ?? '');
      final destLng = double.tryParse(_booking['destination_lng']?.toString() ?? '');
      if (destLat != null && destLng != null) {
        _destinationLocation = LatLng(destLat, destLng);
      }

      // Get client info from profiles relation
      final clientProfile = _booking['profiles'];
      if (clientProfile is Map) {
        _clientName = clientProfile['full_name'] ?? 'العميل';
        _clientPhone = clientProfile['phone']?.toString();
      }

      // Load driver initial location
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
        final cp = fresh['profiles'];
        if (cp is Map) {
          _clientName = cp['full_name'] ?? 'العميل';
          _clientPhone = cp['phone']?.toString();
        }
        setState(() {
          _booking = fresh;
          _isLoading = false;
        });
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
    if (_pickupLocation != null) points.add(_pickupLocation!);
    if (_destinationLocation != null) points.add(_destinationLocation!);
    if (points.isEmpty) return;

    if (points.length == 1) {
      try { _mapController!.move(points.first, 15); } catch (_) {}
    } else {
      try {
        final bounds = LatLngBounds.fromPoints(points);
        _mapController!.fitCamera(CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(60)));
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
      }
    } catch (e) {
      debugPrint('Error updating status: $e');
      if (mounted) {
        setState(() => _isUpdating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ: $e', textAlign: TextAlign.right),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<bool> _showConfirmDialog(String status) async {
    String title, content;
    switch (status) {
      case 'on_the_way':
        title = 'تأكيد الذهاب';
        content = 'هل تريد التوجه لنقطة الاستلام الآن؟';
        break;
      case 'arrived':
        title = 'تأكيد الوصول';
        content = 'هل وصلت بالفعل للعميل؟';
        break;
      case 'in_progress':
        title = 'بدء الرحلة';
        content = 'هل بدأت الرحلة بالفعل؟';
        break;
      case 'completed':
        title = 'إنهاء الرحلة';
        content = 'هل تريد إنهاء الرحلة؟ تأكد من وصول العميل.';
        break;
      case 'cancelled':
        title = 'إلغاء الرحلة';
        content = 'هل أنت متأكد من إلغاء الرحلة؟';
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
      case 'accepted': return 'on_the_way';
      case 'on_the_way': return 'arrived';
      case 'arrived': return 'in_progress';
      case 'in_progress': return 'completed';
      default: return current;
    }
  }

  String _nextStatusLabel(String current) {
    switch (current) {
      case 'accepted': return 'في الطريق للاستلام';
      case 'on_the_way': return 'وصلت للعميل';
      case 'arrived': return 'بدء الرحلة';
      case 'in_progress': return 'إنهاء الرحلة';
      default: return '';
    }
  }

  IconData _nextStatusIcon(String current) {
    switch (current) {
      case 'accepted': return Icons.directions_car_rounded;
      case 'on_the_way': return Icons.person_pin_circle_rounded;
      case 'arrived': return Icons.play_circle_filled_rounded;
      case 'in_progress': return Icons.check_circle_rounded;
      default: return Icons.arrow_forward;
    }
  }

  Color _nextStatusColor(String current) {
    switch (current) {
      case 'accepted': return AppTheme.infoColor;
      case 'on_the_way': return AppTheme.tertiaryColor;
      case 'arrived': return AppTheme.primaryColor;
      case 'in_progress': return AppTheme.successColor;
      default: return AppTheme.textSecondary;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'accepted': return AppTheme.primaryColor;
      case 'on_the_way': return AppTheme.infoColor;
      case 'arrived': return AppTheme.tertiaryColor;
      case 'in_progress': return AppTheme.successColor;
      case 'completed': return AppTheme.successColor;
      case 'cancelled': return AppTheme.errorColor;
      default: return AppTheme.textSecondary;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'accepted': return 'مقبول';
      case 'on_the_way': return 'في الطريق';
      case 'arrived': return 'وصلت';
      case 'in_progress': return 'الرحلة جارية';
      case 'completed': return 'مكتمل';
      case 'cancelled': return 'ملغى';
      default: return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = _booking['status'] ?? '';
    final isActive = status != 'completed' && status != 'cancelled';

    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
          : Stack(
              children: [
                Positioned.fill(child: _buildMap()),
                Positioned(top: 0, left: 0, right: 0, child: _buildTopBar()),
                Positioned(left: 0, right: 0, bottom: 0, child: _buildBottomSheet(isActive)),
              ],
            ),
    );
  }

  Widget _buildMap() {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _driverLocation ?? _pickupLocation ?? const LatLng(30.0444, 31.2357),
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
        width: 48,
        height: 48,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: [BoxShadow(color: AppTheme.primaryColor.withValues(alpha: 0.4), blurRadius: 8)],
              ),
              child: Text(_vehicleEmoji, style: const TextStyle(fontSize: 22)),
            ),
            Container(width: 2, height: 12, color: AppTheme.primaryColor),
          ],
        ),
      ));
    }
    if (_pickupLocation != null) {
      markers.add(Marker(
        point: _pickupLocation!,
        width: 36,
        height: 36,
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.successColor,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: const Icon(Icons.flag, color: Colors.white, size: 18),
        ),
      ));
    }
    if (_destinationLocation != null) {
      markers.add(Marker(
        point: _destinationLocation!,
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
      margin: EdgeInsets.fromLTRB(
        DesignTokens.space6.w,
        MediaQuery.of(context).padding.top + DesignTokens.space4.h,
        DesignTokens.space6.w,
        0,
      ),
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
            icon: const Icon(Icons.arrow_forward_ios_rounded, size: 20),
          ),
          Expanded(
            child: Text(
              '$_vehicleEmoji رحلة #${_booking['id'].toString().substring(0, 8)}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: DesignTokens.textTitleSmall),
              textAlign: TextAlign.center,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: DesignTokens.space4, vertical: DesignTokens.space2),
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

  Widget _buildBottomSheet(bool isActive) {
    final pickupAddress = _booking['pickup_address'] ?? 'نقطة الاستلام';
    final destinationAddress = _booking['destination_address'] ?? 'الوجهة';
    final price = double.tryParse((_booking['total_price'])?.toString() ?? '0') ?? 0;
    final status = _booking['status'] ?? '';

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.55),
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
            Center(
              child: Container(
                width: 40,
                height: 4,
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
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                  child: Text(_clientName?.substring(0, 1) ?? '؟',
                      style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
                ),
                SizedBox(width: DesignTokens.space3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_clientName ?? 'العميل',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: DesignTokens.textBodyLarge)),
                      Text('عميل FASTER',
                          style: TextStyle(fontSize: DesignTokens.textBodySmall, color: AppTheme.textSecondary)),
                    ],
                  ),
                ),
                if (_clientPhone != null && _clientPhone!.isNotEmpty) ...[
                  _buildCircleButton(Icons.phone_rounded, AppTheme.successColor,
                      () => launchUrl(Uri.parse('tel:$_clientPhone'))),
                  SizedBox(width: DesignTokens.space2),
                  _buildCircleButton(Icons.chat_rounded, AppTheme.primaryColor, () {
                    // Navigate to chat screen
                  }),
                ],
              ],
            ),
            SizedBox(height: DesignTokens.space6.h),

            // Route card
            Container(
              padding: EdgeInsets.all(DesignTokens.space4),
              decoration: BoxDecoration(
                color: AppTheme.backgroundColor,
                borderRadius: DesignTokens.brMd,
                border: Border.all(color: AppTheme.borderColor.withValues(alpha: 0.5)),
              ),
              child: Column(
                children: [
                  _buildRouteRow(Icons.trip_origin, pickupAddress, AppTheme.successColor, 'نقطة الاستلام'),
                  Container(margin: EdgeInsets.only(right: 10), width: 1, height: 16, color: AppTheme.borderColor),
                  _buildRouteRow(Icons.location_on, destinationAddress, AppTheme.errorColor, 'الوجهة'),
                ],
              ),
            ),
            SizedBox(height: DesignTokens.space4.h),

            // Price card
            Container(
              padding: EdgeInsets.all(DesignTokens.space4),
              decoration: BoxDecoration(
                color: AppTheme.successColor.withValues(alpha: 0.06),
                borderRadius: DesignTokens.brMd,
                border: Border.all(color: AppTheme.successColor.withValues(alpha: 0.15)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.local_taxi, color: AppTheme.successColor, size: 20),
                      SizedBox(width: DesignTokens.space2),
                      Text('سعر الرحلة',
                          style: TextStyle(fontSize: DesignTokens.textBodyMedium, color: AppTheme.textSecondary)),
                    ],
                  ),
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
            SizedBox(height: DesignTokens.space6.h),

            // Status progress indicator
            if (isActive) ...[
              _buildProgressIndicator(status),
              SizedBox(height: DesignTokens.space6.h),
              SizedBox(
                width: double.infinity,
                height: DesignTokens.buttonHeight,
                child: ElevatedButton.icon(
                  onPressed: _isUpdating ? null : () => _updateStatus(_nextStatus(status)),
                  icon: _isUpdating
                      ? const SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Icon(_nextStatusIcon(status)),
                  label: Text(
                    _isUpdating ? 'جاري التحديث...' : _nextStatusLabel(status),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _nextStatusColor(status),
                    shape: RoundedRectangleBorder(borderRadius: DesignTokens.brMd),
                  ),
                ),
              ),
              SizedBox(height: DesignTokens.space3),
              SizedBox(
                width: double.infinity,
                height: DesignTokens.buttonHeight,
                child: OutlinedButton.icon(
                  onPressed: _isUpdating ? null : () => _updateStatus('cancelled'),
                  icon: const Icon(Icons.cancel_outlined),
                  label: const Text('إلغاء الرحلة', style: TextStyle(color: AppTheme.errorColor, fontWeight: FontWeight.bold)),
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

  Widget _buildProgressIndicator(String status) {
    final steps = ['accepted', 'on_the_way', 'arrived', 'in_progress', 'completed'];
    final currentIndex = steps.indexOf(status);

    return Row(
      children: List.generate(steps.length * 2 - 1, (i) {
        if (i.isOdd) {
          return Expanded(
            child: Container(
              height: 2,
              color: (i ~/ 2) < currentIndex
                  ? AppTheme.primaryColor
                  : AppTheme.borderColor,
            ),
          );
        }
        final idx = i ~/ 2;
        final isDone = idx < currentIndex;
        final isCurrent = idx == currentIndex;
        final color = isDone || isCurrent ? AppTheme.primaryColor : AppTheme.borderColor;
        return Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: isDone || isCurrent ? AppTheme.primaryColor : Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2),
          ),
          child: isDone
              ? const Icon(Icons.check, color: Colors.white, size: 14)
              : null,
        );
      }),
    );
  }

  Widget _buildCircleButton(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }

  Widget _buildRouteRow(IconData icon, String text, Color color, String label) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        SizedBox(width: DesignTokens.space2),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: DesignTokens.textLabelSmall, color: AppTheme.textSecondary)),
              Text(text, style: const TextStyle(fontSize: DesignTokens.textBodyMedium, color: AppTheme.textPrimary),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ],
    );
  }
}