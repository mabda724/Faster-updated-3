import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/location_service.dart';

class RideTrackingScreen extends StatefulWidget {
  final String bookingId;
  final String pickupAddress;
  final String destinationAddress;
  final double totalPrice;
  final double distanceKm;
  final String vehicleType;

  const RideTrackingScreen({
    super.key,
    required this.bookingId,
    required this.pickupAddress,
    required this.destinationAddress,
    required this.totalPrice,
    required this.distanceKm,
    required this.vehicleType,
  });

  @override
  State<RideTrackingScreen> createState() => _RideTrackingScreenState();
}

class _RideTrackingScreenState extends State<RideTrackingScreen> {
  Map<String, dynamic>? _booking;
  bool _isLoading = true;
  LatLng? _driverLocation;
  LatLng? _pickupLocation;
  LatLng? _destinationLocation;
  StreamSubscription? _driverLocSub;
  StreamSubscription? _bookingSub;
  final MapController _mapController = MapController();
  String _status = 'pending';
  String? _driverName;
  String? _driverPhone;
  String? _driverAvatar;
  double? _driverRating;
  String? _carPlate;
  String? _carColor;
  bool _showRoute = false;

  String get _vehicleEmoji {
    switch (widget.vehicleType) {
      case 'scooter':
        return '🛵';
      case 'car':
      default:
        return '🚗';
    }
  }

  String get _vehicleLabel {
    switch (widget.vehicleType) {
      case 'scooter':
        return 'سكوتر';
      case 'car':
      default:
        return 'سيارة';
    }
  }

  String get _statusText {
    switch (_status) {
      case 'pending':
        return 'جاري البحث عن سائق...';
      case 'accepted':
        return 'تم العثور على سائق';
      case 'on_the_way':
        return 'السائق في الطريق إليك';
      case 'arrived':
        return 'السائق وصل';
      case 'in_progress':
        return 'الرحلة جارية';
      case 'completed':
        return 'تم انتهاء الرحلة';
      case 'cancelled':
        return 'تم إلغاء الرحلة';
      default:
        return _status;
    }
  }

  IconData get _statusIcon {
    switch (_status) {
      case 'pending':
        return Icons.search;
      case 'accepted':
        return Icons.check_circle;
      case 'on_the_way':
        return Icons.directions_car;
      case 'arrived':
        return Icons.location_on;
      case 'in_progress':
        return Icons.route;
      case 'completed':
        return Icons.check_circle;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.info;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadBooking();
  }

  @override
  void dispose() {
    _driverLocSub?.cancel();
    _bookingSub?.cancel();
    super.dispose();
  }

  void _listenForBookingUpdates() {
    _bookingSub = SupabaseService.db
        .from('bookings')
        .stream(primaryKey: ['id'])
        .eq('id', widget.bookingId)
        .listen((data) {
      if (data.isNotEmpty && mounted) {
        final oldStatus = _status;
        setState(() {
          _booking = data.first;
          _status = data.first['status'] ?? 'pending';
        });

        // Subscribe to driver location once we have a driver
        final driverId = data.first['provider_id']?.toString();
        if (driverId != null && _driverLocSub == null) {
          _subscribeToDriverLocation(driverId);
        }

        // Show status change snackbar
        if (oldStatus != _status) {
          _showStatusSnackBar(_status);
        }

        // Show completed dialog
        if (oldStatus != 'completed' && _status == 'completed') {
          _showCompletedDialog();
        }
      }
    });
  }

  void _subscribeToDriverLocation(String driverId) {
    _driverLocSub = SupabaseService.db
        .from('provider_locations')
        .stream(primaryKey: ['provider_id'])
        .eq('provider_id', driverId)
        .listen((data) {
      if (data.isNotEmpty && mounted) {
        final lat = double.tryParse(data.first['latitude']?.toString() ?? '');
        final lng = double.tryParse(data.first['longitude']?.toString() ?? '');
        if (lat != null && lng != null) {
          setState(() {
            _driverLocation = LatLng(lat, lng);
            _showRoute = true;
          });
          // Auto-center map on driver
          _centerOnDriver();
        }
      }
    });
  }

  void _centerOnDriver() {
    if (_driverLocation == null || _mapController.camera.zoom < 14) {
      _fitBounds();
    } else {
      try {
        _mapController.move(_driverLocation!, 15);
      } catch (_) {}
    }
  }

  void _fitBounds() {
    final points = <LatLng>[];
    if (_driverLocation != null) points.add(_driverLocation!);
    if (_pickupLocation != null) points.add(_pickupLocation!);
    if (_destinationLocation != null) points.add(_destinationLocation!);
    if (points.isEmpty) return;

    if (points.length == 1) {
      try {
        _mapController.move(points.first, 15);
      } catch (_) {}
    } else {
      try {
        final bounds = LatLngBounds.fromPoints(points);
        _mapController.fitCamera(
          CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(80)),
        );
      } catch (_) {}
    }
  }

  void _showStatusSnackBar(String status) {
    String message;
    switch (status) {
      case 'on_the_way':
        message = 'السائق في الطريق إليك 🚗';
        break;
      case 'arrived':
        message = 'السائق وصل إليك! 📍';
        break;
      case 'in_progress':
        message = 'بدأت الرحلة 🛣️';
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

  void _showCompletedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: DesignTokens.brLg),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: AppTheme.successColor, size: 28),
            SizedBox(width: DesignTokens.space8),
            Expanded(child: Text('تم انتهاء الرحلة', textAlign: TextAlign.right)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildInfoRow('المسافة', '${widget.distanceKm.toStringAsFixed(1)} كم'),
            const SizedBox(height: DesignTokens.space8),
            _buildInfoRow('التكلفة', '${widget.totalPrice.toStringAsFixed(1)} جنيه'),
            const SizedBox(height: DesignTokens.space16),
            const Text(
              'كيف كانت رحلتك؟',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppTheme.textSecondary)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }

  Future<void> _callDriver() async {
    if (_driverPhone == null) return;
    final uri = Uri.parse('tel:$_driverPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _loadBooking() async {
    try {
      final data = await SupabaseService.db
          .from('bookings')
          .select('''
            *,
            provider_profiles(
              id,
              profiles(full_name, phone, avatar_url),
              vehicle_type,
              car_plate,
              car_color,
              rating
            )
          ''')
          .eq('id', widget.bookingId)
          .single();

      // Parse pickup location
      final pickupLat = double.tryParse(data['pickup_lat']?.toString() ?? '');
      final pickupLng = double.tryParse(data['pickup_lng']?.toString() ?? '');
      if (pickupLat != null && pickupLng != null) {
        _pickupLocation = LatLng(pickupLat, pickupLng);
      }

      // Parse destination location
      final destLat = double.tryParse(data['destination_lat']?.toString() ?? '');
      final destLng = double.tryParse(data['destination_lng']?.toString() ?? '');
      if (destLat != null && destLng != null) {
        _destinationLocation = LatLng(destLat, destLng);
      }

      // Extract driver data
      final providerData = data['provider_profiles'];
      if (providerData != null) {
        final profile = providerData['profiles'];
        _driverName = profile?['full_name'] ?? 'السائق';
        _driverPhone = profile?['phone']?.toString();
        _driverAvatar = profile?['avatar_url']?.toString();
        _driverRating = providerData['rating']?.toDouble();
        _carPlate = providerData['car_plate'];
        _carColor = providerData['car_color'];

        // Subscribe to driver location
        final driverId = providerData['id']?.toString();
        if (driverId != null) {
          _subscribeToDriverLocation(driverId);
          // Load initial location
          _loadDriverInitialLocation(driverId);
        }
      }

      if (mounted) {
        setState(() {
          _booking = data;
          _status = data['status'] ?? 'pending';
          _isLoading = false;
        });
        _fitBounds();
        _listenForBookingUpdates();
      }
    } catch (e) {
      debugPrint('Error loading ride tracking: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadDriverInitialLocation(String driverId) async {
    try {
      final loc = await SupabaseService.db
          .from('provider_locations')
          .select('latitude, longitude')
          .eq('provider_id', driverId)
          .maybeSingle();
      if (loc != null && mounted) {
        final lat = double.tryParse(loc['latitude']?.toString() ?? '');
        final lng = double.tryParse(loc['longitude']?.toString() ?? '');
        if (lat != null && lng != null) {
          setState(() {
            _driverLocation = LatLng(lat, lng);
            _showRoute = true;
          });
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Map
          Positioned.fill(
            child: _buildMap(),
          ),

          // Top bar with back button
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            child: _buildBackButton(),
          ),

          // Status chip
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 16,
            child: _buildStatusChip(),
          ),

          // Bottom sheet with driver info and trip details
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

  Widget _buildBackButton() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: DesignTokens.brMd,
        boxShadow: DesignTokens.shadow2(Colors.black.withValues(alpha: 0.12)),
      ),
      child: IconButton(
        onPressed: () => Navigator.of(context).pop(),
        icon: const Icon(Icons.arrow_forward, color: AppTheme.textPrimary),
        iconSize: DesignTokens.iconMd,
      ),
    );
  }

  Widget _buildStatusChip() {
    Color chipColor;
    switch (_status) {
      case 'completed':
        chipColor = AppTheme.successColor;
        break;
      case 'cancelled':
        chipColor = AppTheme.errorColor;
        break;
      case 'on_the_way':
      case 'in_progress':
        chipColor = AppTheme.tertiaryColor;
        break;
      case 'arrived':
        chipColor = AppTheme.primaryColor;
        break;
      default:
        chipColor = AppTheme.textSecondary;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: DesignTokens.space12, vertical: 6),
      decoration: BoxDecoration(
        color: chipColor,
        borderRadius: DesignTokens.brFull,
        boxShadow: DesignTokens.shadow2(Colors.black.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_statusIcon, color: Colors.white, size: 16),
          const SizedBox(width: 6),
          Text(
            _statusText,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMap() {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _driverLocation ??
            _pickupLocation ??
            _destinationLocation ??
            const LatLng(30.0444, 31.2357),
        initialZoom: 14,
        minZoom: 5,
        maxZoom: 18,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.faster.app',
        ),
        if (_pickupLocation != null)
          MarkerLayer(
            markers: [
              Marker(
                point: _pickupLocation!,
                width: 40,
                height: 40,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: DesignTokens.shadow2(Colors.black.withValues(alpha: 0.26)),
                  ),
                  child: const Icon(Icons.my_location, color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
        if (_destinationLocation != null)
          MarkerLayer(
            markers: [
              Marker(
                point: _destinationLocation!,
                width: 40,
                height: 40,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.errorColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: DesignTokens.shadow2(Colors.black.withValues(alpha: 0.26)),
                  ),
                  child: const Icon(Icons.location_on, color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
        if (_driverLocation != null)
          MarkerLayer(
            markers: [
              Marker(
                point: _driverLocation!,
                width: 50,
                height: 50,
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(DesignTokens.space4),
                      decoration: BoxDecoration(
                        color: AppTheme.tertiaryColor,
                        shape: BoxShape.circle,
                        boxShadow: DesignTokens.shadow3(Colors.black.withValues(alpha: 0.38)),
                      ),
                      child: Text(
                        _vehicleEmoji,
                        style: const TextStyle(fontSize: 24),
                      ),
                    ),
                    Container(
                      width: 2,
                      height: 15,
                      color: AppTheme.tertiaryColor,
                    ),
                  ],
                ),
              ),
            ],
          ),
        if (_showRoute && _driverLocation != null && _pickupLocation != null)
          PolylineLayer(
            polylines: [
              Polyline(
                points: [_driverLocation!, _pickupLocation!],
                color: AppTheme.primaryColor,
                strokeWidth: 4,
                borderColor: Colors.white,
                borderStrokeWidth: 2,
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildBottomSheet() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: DesignTokens.shadow4(Colors.black),
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(DesignTokens.space4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.textSecondary.withValues(alpha: 0.3),
                  borderRadius: DesignTokens.brFull,
                ),
              ),
              SizedBox(height: DesignTokens.space3),

              // Driver info (when found)
              if (_driverName != null) ...[
                _buildDriverCard(),
                SizedBox(height: DesignTokens.space3),
              ],

              // Trip details
              _buildTripDetailsCard(),
              SizedBox(height: DesignTokens.space3),

              // Call driver button
              if (_driverPhone != null && _status != 'completed' && _status != 'cancelled')
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _callDriver,
                    icon: const Icon(Icons.phone),
                    label: const Text('اتصل بالسائق'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.successColor,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: DesignTokens.space3),
                      shape: RoundedRectangleBorder(
                        borderRadius: DesignTokens.brMd,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDriverCard() {
    return Container(
      padding: EdgeInsets.all(DesignTokens.space3),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.08),
        borderRadius: DesignTokens.brMd,
        border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 28,
            backgroundColor: AppTheme.primaryColor,
            backgroundImage: _driverAvatar != null ? NetworkImage(_driverAvatar!) : null,
            child: _driverAvatar == null
                ? Text(
                    _driverName!.substring(0, 1),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          ),
          SizedBox(width: DesignTokens.space3),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _driverName!,
                  style: TextStyle(
                    fontSize: DesignTokens.textTitleSmall,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                if (_carPlate != null && _carColor != null)
                  Text(
                    '$_carColor $_carPlate',
                    style: TextStyle(
                      fontSize: DesignTokens.textBodySmall,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                if (_driverRating != null)
                  Row(
                    children: [
                      const Icon(Icons.star, color: AppTheme.tertiaryColor, size: 14),
                      const SizedBox(width: DesignTokens.space4),
                      Text(
                        _driverRating!.toStringAsFixed(1),
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
          // Call button
          Container(
            decoration: BoxDecoration(
              color: AppTheme.successColor,
              shape: BoxShape.circle,
              boxShadow: DesignTokens.shadow1(AppTheme.successColor.withValues(alpha: 0.3)),
            ),
            child: IconButton(
              onPressed: _callDriver,
              icon: const Icon(Icons.phone, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTripDetailsCard() {
    return Container(
      padding: EdgeInsets.all(DesignTokens.space3),
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: DesignTokens.brMd,
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          // Addresses
          _buildAddressRow(Icons.trip_origin, widget.pickupAddress, AppTheme.primaryColor),
          Container(
            margin: EdgeInsets.only(right: 10, left: 30),
            width: 2,
            height: 20,
            color: Colors.grey.shade300,
          ),
          _buildAddressRow(Icons.location_on, widget.destinationAddress, AppTheme.errorColor),
          const Divider(height: 20),
          // Price and distance
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildDetailItem('$_vehicleEmoji $_vehicleLabel', '${widget.distanceKm.toStringAsFixed(1)} كم'),
              Container(width: 1, height: 30, color: Colors.grey.shade300),
              _buildDetailItem('💰 التكلفة', '${widget.totalPrice.toStringAsFixed(1)} جنيه'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAddressRow(IconData icon, String address, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 16),
        SizedBox(width: DesignTokens.space2),
        Expanded(
          child: Text(
            address,
            style: TextStyle(
              fontSize: DesignTokens.textBodySmall,
              color: AppTheme.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: DesignTokens.textBodySmall,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: DesignTokens.space4),
        Text(
          value,
          style: TextStyle(
            fontSize: DesignTokens.textTitleSmall,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }
}