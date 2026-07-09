import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/location_service.dart';

class DeliveryActiveScreen extends StatefulWidget {
  final Map<String, dynamic> booking;
  const DeliveryActiveScreen({super.key, required this.booking});
  @override
  State<DeliveryActiveScreen> createState() => _DeliveryActiveScreenState();
}

class _DeliveryActiveScreenState extends State<DeliveryActiveScreen> {
  late Map<String, dynamic> _booking;
  bool _isUpdating = false;
  LatLng? _pickupLocation;
  LatLng? _destinationLocation;
  LatLng? _currentLocation;
  final MapController _mapController = MapController();
  StreamSubscription? _bookingSub;

  String get _status => _booking['status'] as String? ?? 'pending';
  double get _deliveryFee => double.tryParse(_booking['total_price']?.toString() ?? '0') ?? 0;

  @override
  void initState() {
    super.initState();
    _booking = Map<String, dynamic>.from(widget.booking);
    _extractLocations();
    _getCurrentLocation();
    _listenForBookingUpdates();
  }

  @override
  void dispose() {
    _bookingSub?.cancel();
    super.dispose();
  }

  void _listenForBookingUpdates() {
    final bookingId = _booking['id'];
    if (bookingId == null) return;
    _bookingSub = SupabaseService.db
        .from('bookings')
        .stream(primaryKey: ['id'])
        .eq('id', bookingId)
        .listen((data) {
      if (data.isNotEmpty && mounted) {
        setState(() => _booking = Map<String, dynamic>.from(data.first));
      }
    });
  }

  void _extractLocations() {
    final pLat = _booking['client_lat'] as double?;
    final pLng = _booking['client_lng'] as double?;
    if (pLat != null && pLng != null) {
      _pickupLocation = LatLng(pLat, pLng);
    }
    final dLat = _booking['destination_lat'] as double?;
    final dLng = _booking['destination_lng'] as double?;
    if (dLat != null && dLng != null) {
      _destinationLocation = LatLng(dLat, dLng);
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      final pos = await LocationService.getCurrentPosition();
      if (pos != null && mounted) {
        setState(() => _currentLocation = LatLng(pos.latitude, pos.longitude));
      }
    } catch (e) {
      debugPrint('Error getting location: $e');
    }
  }

  Future<void> _updateStatus(String newStatus) async {
    setState(() => _isUpdating = true);
    try {
      await SupabaseService.db.from('bookings').update({
        'status': newStatus,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', _booking['id']);

      if (mounted) {
        setState(() {
          _booking['status'] = newStatus;
          _isUpdating = false;
        });
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

  Future<void> _cancelDelivery() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: DesignTokens.brLg),
        title: const Text('إلغاء التوصيل', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('هل أنت متأكد من إلغاء هذا التوصيل؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('لا', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('نعم، إلغاء', style: TextStyle(color: AppTheme.errorColor)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _updateStatus('cancelled');
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _callClient() async {
    final phone = _booking['profiles']?['phone'] as String?;
    if (phone == null || phone.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('رقم الهاتف غير متوفر'), backgroundColor: AppTheme.errorColor),
        );
      }
      return;
    }
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  List<Marker> _buildMarkers() {
    final markers = <Marker>[];
    if (_pickupLocation != null) {
      markers.add(Marker(
        point: _pickupLocation!,
        width: 40.w,
        height: 40.h,
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.tertiaryColor,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.26), blurRadius: 4)],
          ),
          child: const Icon(Icons.pickup, color: Colors.white, size: 18),
        ),
      ));
    }
    if (_destinationLocation != null) {
      markers.add(Marker(
        point: _destinationLocation!,
        width: 40.w,
        height: 40.h,
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.successColor,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.26), blurRadius: 4)],
          ),
          child: const Icon(Icons.location_on, color: Colors.white, size: 18),
        ),
      ));
    }
    if (_currentLocation != null) {
      markers.add(Marker(
        point: _currentLocation!,
        width: 36.w,
        height: 36.h,
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.primaryColor,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.26), blurRadius: 4)],
          ),
          child: const Icon(Icons.navigation, color: Colors.white, size: 16),
        ),
      ));
    }
    return markers;
  }

  LatLng get _mapCenter {
    if (_currentLocation != null) return _currentLocation!;
    if (_pickupLocation != null) return _pickupLocation!;
    return const LatLng(24.7136, 46.6753);
  }

  @override
  Widget build(BuildContext context) {
    final client = _booking['profiles'] as Map<String, dynamic>?;
    final service = _booking['services'] as Map<String, dynamic>?;
    final address = _booking['address'] as String? ?? '';
    final destinationAddress = _booking['destination_address'] as String? ?? '';

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Column(
        children: [
          // Map
          Expanded(
            flex: 3,
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _mapCenter,
                initialZoom: 14.0,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.faster',
                ),
                MarkerLayer(markers: _buildMarkers()),
              ],
            ),
          ),
          // Bottom info sheet
          Expanded(
            flex: 4,
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 24.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40.w,
                        height: 4.h,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: DesignTokens.brFull,
                        ),
                      ),
                    ),
                    SizedBox(height: 16.h),
                    // Status badge
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'تفاصيل التوصيل',
                          style: TextStyle(
                            fontSize: DesignTokens.textTitleLarge,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                          decoration: BoxDecoration(
                            color: _getStatusColor(_status).withValues(alpha: 0.1),
                            borderRadius: DesignTokens.brFull,
                          ),
                          child: Text(
                            _getStatusText(_status),
                            style: TextStyle(
                              fontSize: DesignTokens.textLabelMedium,
                              fontWeight: FontWeight.w600,
                              color: _getStatusColor(_status),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16.h),
                    // Client info
                    _buildInfoCard(
                      child: Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(DesignTokens.space8),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withValues(alpha: 0.1),
                              borderRadius: DesignTokens.brSm,
                            ),
                            child: Icon(Icons.person_rounded, color: AppTheme.primaryColor, size: 20),
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  client?['full_name'] ?? 'عميل',
                                  style: TextStyle(
                                    fontSize: DesignTokens.textBodyLarge,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                                Text(
                                  'العميل',
                                  style: TextStyle(
                                    fontSize: DesignTokens.textLabelSmall,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: _callClient,
                            icon: Container(
                              padding: EdgeInsets.all(DesignTokens.space6),
                              decoration: BoxDecoration(
                                color: AppTheme.successColor.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.phone_rounded, color: AppTheme.successColor, size: 18),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 12.h),
                    // Items count
                    _buildInfoCard(
                      child: Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(DesignTokens.space8),
                            decoration: BoxDecoration(
                              color: AppTheme.infoColor.withValues(alpha: 0.1),
                              borderRadius: DesignTokens.brSm,
                            ),
                            child: Icon(Icons.inventory_2_rounded, color: AppTheme.infoColor, size: 20),
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  service?['name_ar'] ?? 'طلب توصيل',
                                  style: TextStyle(
                                    fontSize: DesignTokens.textBodyLarge,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                                Text(
                                  'نوع الطلب',
                                  style: TextStyle(
                                    fontSize: DesignTokens.textLabelSmall,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 12.h),
                    // Pickup & Destination
                    _buildLocationRow(
                      icon: Icons.circle,
                      iconColor: AppTheme.tertiaryColor,
                      label: 'نقطة الاستلام',
                      address: address.isNotEmpty ? address : 'غير محدد',
                      isFirst: true,
                    ),
                    _buildLocationRow(
                      icon: Icons.location_on,
                      iconColor: AppTheme.successColor,
                      label: 'الوجهة',
                      address: destinationAddress.isNotEmpty ? destinationAddress : 'غير محدد',
                      isLast: true,
                    ),
                    SizedBox(height: 16.h),
                    // Delivery fee
                    _buildInfoCard(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'أجرة التوصيل',
                            style: TextStyle(
                              fontSize: DesignTokens.textBodyLarge,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          Text(
                            '${_deliveryFee.toStringAsFixed(0)} ج.م',
                            style: TextStyle(
                              fontSize: DesignTokens.textTitleLarge,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.successColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 20.h),
                    // Action buttons
                    _buildActionButtons(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    if (_status == 'cancelled' || _status == 'completed') {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () => Navigator.pop(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryColor,
            padding: EdgeInsets.symmetric(vertical: DesignTokens.space12),
            shape: RoundedRectangleBorder(borderRadius: DesignTokens.brMd),
          ),
          child: const Text(
            'العودة',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      );
    }

    String nextStatus;
    String nextLabel;
    switch (_status) {
      case 'accepted':
        nextStatus = 'on_the_way';
        nextLabel = 'في الطريق للاستلام';
        break;
      case 'on_the_way':
        nextStatus = 'arrived';
        nextLabel = 'تم استلام الطلب';
        break;
      case 'arrived':
        nextStatus = 'in_progress';
        nextLabel = 'في الطريق للتوصيل';
        break;
      case 'in_progress':
        nextStatus = 'completed';
        nextLabel = 'تم التوصيل';
        break;
      default:
        nextStatus = '';
        nextLabel = '';
    }

    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isUpdating ? null : () => _updateStatus(nextStatus),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              padding: EdgeInsets.symmetric(vertical: DesignTokens.space12),
              shape: RoundedRectangleBorder(borderRadius: DesignTokens.brMd),
              elevation: 0,
            ),
            child: _isUpdating
                ? SizedBox(
                    width: 20.w,
                    height: 20.h,
                    child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : Text(
                    nextLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: DesignTokens.textBodyLarge,
                    ),
                  ),
          ),
        ),
        SizedBox(height: 10.h),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: _cancelDelivery,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppTheme.errorColor),
              padding: EdgeInsets.symmetric(vertical: DesignTokens.space12),
              shape: RoundedRectangleBorder(borderRadius: DesignTokens.brMd),
            ),
            child: const Text(
              'إلغاء التوصيل',
              style: TextStyle(
                color: AppTheme.errorColor,
                fontWeight: FontWeight.bold,
                fontSize: DesignTokens.textBodyLarge,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard({required Widget child}) {
    return Container(
      padding: EdgeInsets.all(DesignTokens.space12),
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: DesignTokens.brMd,
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: child,
    );
  }

  Widget _buildLocationRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String address,
    bool isFirst = false,
    bool isLast = false,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              Container(
                width: 24.w,
                height: 24.h,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 12),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: Colors.grey.shade300,
                  ),
                ),
            ],
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 12.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: DesignTokens.textLabelSmall,
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    address,
                    style: TextStyle(
                      fontSize: DesignTokens.textBodySmall,
                      color: AppTheme.textPrimary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'accepted':
        return AppTheme.tertiaryColor;
      case 'on_the_way':
        return AppTheme.infoColor;
      case 'arrived':
        return AppTheme.primaryColor;
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

  String _getStatusText(String status) {
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
}
