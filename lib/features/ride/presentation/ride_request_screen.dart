import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/widgets/map_picker_screen.dart';
import 'ride_waiting_screen.dart';

class RideRequestScreen extends StatefulWidget {
  const RideRequestScreen({super.key});

  @override
  State<RideRequestScreen> createState() => _RideRequestScreenState();
}

class _RideRequestScreenState extends State<RideRequestScreen> {
  // Step 0: Vehicle type, Step 1: Pickup, Step 2: Destination + Confirm
  int _step = 0;

  String? _vehicleType; // 'car' | 'scooter'
  LatLng? _pickupLatLng;
  String _pickupAddress = 'جاري تحديد موقعك...';

  LatLng? _destLatLng;
  String _destAddress = '';

  // Price data
  double? _distanceKm;
  int? _durationMin;
  double? _pricePerKm;
  double? _totalPrice;

  bool _isLoadingPickup = true;
  bool _isCalculatingPrice = false;
  bool _isCreatingBooking = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _capturePickupLocation();
  }

  Future<void> _capturePickupLocation() async {
    setState(() => _isLoadingPickup = true);
    try {
      final pos = await LocationService.getPreciseLatLng();
      if (!mounted) return;
      if (pos != null) {
        final latLng = LatLng(pos.latitude, pos.longitude);
        final address = await LocationService.getAddressFromLatLng(latLng) ??
            'عنوان غير معروف';
        if (mounted) {
          setState(() {
            _pickupLatLng = latLng;
            _pickupAddress = address;
            _isLoadingPickup = false;
          });
        }
      } else {
        setState(() {
          _pickupAddress = 'تعذر تحديد الموقع تلقائياً';
          _isLoadingPickup = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _pickupAddress = 'تعذر تحديد الموقع';
        _isLoadingPickup = false;
      });
    }
  }

  Future<void> _openMapPicker({required bool isDestination}) async {
    final initialLoc = _pickupLatLng ??
        const LatLng(30.0444, 31.2357); // Cairo default
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => MapPickerScreen(initialLocation: initialLoc),
      ),
    );
    if (result == null || !mounted) return;
    final location = result['location'] as LatLng?;
    final address = result['address'] as String?;
    if (location == null) return;

    if (isDestination) {
      setState(() {
        _destLatLng = location;
        _destAddress = address ?? 'عنوان الوجهة';
      });
      _calculatePrice();
    } else {
      setState(() {
        _pickupLatLng = location;
        _pickupAddress = address ?? 'عنوان الانطلاق';
      });
    }
  }

  Future<void> _calculatePrice() async {
    if (_pickupLatLng == null ||
        _destLatLng == null ||
        _vehicleType == null) return;
    setState(() {
      _isCalculatingPrice = true;
      _error = null;
      _pricePerKm = null;
      _totalPrice = null;
      _distanceKm = null;
      _durationMin = null;
    });
    try {
      final result = await SupabaseService.db.rpc(
        'calculate_ride_price',
        params: {
          'p_pickup_lat': _pickupLatLng!.latitude,
          'p_pickup_lng': _pickupLatLng!.longitude,
          'p_dest_lat': _destLatLng!.latitude,
          'p_dest_lng': _destLatLng!.longitude,
          'p_vehicle_type': _vehicleType,
        },
      );
      if (!mounted) return;
      setState(() {
        _distanceKm = _toDouble(result['distance_km']);
        _durationMin = _toInt(result['duration_min']);
        _pricePerKm = _toDouble(result['price_per_km']);
        _totalPrice = _toDouble(result['total_price']);
        _isCalculatingPrice = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'فشل حساب السعر: $e';
        _isCalculatingPrice = false;
      });
    }
  }

  Future<void> _createRideBooking() async {
    if (_pickupLatLng == null ||
        _destLatLng == null ||
        _vehicleType == null ||
        _totalPrice == null) return;
    if (_isCreatingBooking) return;
    setState(() => _isCreatingBooking = true);
    try {
      final uid = SupabaseService.currentUserId;
      if (uid == null) throw Exception('المستخدم غير مسجل دخول');

      final result = await SupabaseService.db.rpc(
        'create_ride_request',
        params: {
          'p_client_id': uid,
          'p_pickup_lat': _pickupLatLng!.latitude,
          'p_pickup_lng': _pickupLatLng!.longitude,
          'p_pickup_address': _pickupAddress,
          'p_dest_lat': _destLatLng!.latitude,
          'p_dest_lng': _destLatLng!.longitude,
          'p_dest_address': _destAddress,
          'p_vehicle_type': _vehicleType,
        },
      );
      if (!mounted) return;
      final bookingId = result['booking_id'] as String?;
      if (bookingId == null) throw Exception('لم يتم إنشاء الحجز');

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => RideWaitingScreen(
            bookingId: bookingId,
            totalPrice: _totalPrice!,
            distanceKm: _distanceKm ?? 0,
            vehicleType: _vehicleType!,
            pickupAddress: _pickupAddress,
            destinationAddress: _destAddress,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'فشل إنشاء الطلب: $e';
        _isCreatingBooking = false;
      });
    }
  }

  void _goToStep(int step) {
    if (step == 1 && _vehicleType == null) return;
    if (step == 2 &&
        (_pickupLatLng == null || _destLatLng == null || _vehicleType == null)) {
      return;
    }
    setState(() => _step = step);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceColor,
        elevation: 0,
        centerTitle: true,
        title: Text(
          _step == 0 ? 'طلب رحلة' : _step == 1 ? 'مكان الانطلاق' : 'تأكيد الرحلة',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: DesignTokens.textTitleMedium,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded, color: AppTheme.textPrimary),
          tooltip: 'العودة',
          onPressed: () => _step == 0
              ? Navigator.pop(context)
              : setState(() => _step--),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildStepIndicator(),
            Expanded(child: _buildCurrentStep()),
          ],
        ),
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: DesignTokens.space24,
        vertical: DesignTokens.space16,
      ),
      padding: EdgeInsets.all(DesignTokens.space4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: DesignTokens.brFull,
        border: Border.all(color: AppTheme.textPrimary.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: List.generate(3, (index) {
          final isActive = _step == index;
          final isDone = _step > index;
          return Expanded(
            child: AnimatedContainer(
              duration: DesignTokens.durationNormal,
              curve: DesignTokens.curveEaseInOut,
              height: 34.h,
              decoration: BoxDecoration(
                gradient: isActive
                    ? AppTheme.primaryGradient
                    : isDone
                        ? LinearGradient(
                            colors: [
                              AppTheme.primaryColor.withValues(alpha: 0.75),
                              AppTheme.primaryColor.withValues(alpha: 0.55),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          )
                        : null,
                color: isActive || isDone ? null : Colors.transparent,
                borderRadius: DesignTokens.brFull,
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: AppTheme.primaryColor.withValues(alpha: 0.25),
                          blurRadius: 8,
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedContainer(
                    duration: DesignTokens.durationFast,
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isActive || isDone
                          ? AppTheme.surfaceColor
                          : AppTheme.textSecondary.withValues(alpha: 0.3),
                    ),
                    child: Center(
                      child: isDone
                          ? Icon(Icons.check_rounded,
                              size: DesignTokens.iconSm,
                              color: AppTheme.surfaceColor)
                          : Text(
                              '${index + 1}',
                              style: TextStyle(
                                color: isActive
                                    ? AppTheme.primaryColor
                                    : AppTheme.textSecondary,
                                fontWeight: FontWeight.bold,
                                fontSize: DesignTokens.textLabelSmall,
                              ),
                            ),
                    ),
                  ),
                  SizedBox(width: DesignTokens.space2),
                  Text(
                    ['نوع المركبة', 'الانطلاق', 'الوجهة'][index],
                    style: TextStyle(
                      color: isActive || isDone
                          ? AppTheme.surfaceColor
                          : AppTheme.textSecondary,
                      fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                      fontSize: DesignTokens.textLabelSmall,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_step) {
      case 0:
        return _buildVehicleStep();
      case 1:
        return _buildPickupStep();
      default:
        return _buildConfirmStep();
    }
  }

  Widget _buildVehicleStep() {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: DesignTokens.space24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: DesignTokens.space8),
          Text(
            'اختر نوع المركبة',
            style: TextStyle(
              fontSize: DesignTokens.textTitleSmall,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          SizedBox(height: DesignTokens.space4),
          Text(
            'يُستخدم لاختيار السائق المناسب و حساب سعر الرحلة.',
            style: TextStyle(
              fontSize: DesignTokens.textBodySmall,
              color: AppTheme.textSecondary,
            ),
          ),
          SizedBox(height: DesignTokens.space24),
          Row(
            children: [
              Expanded(
                child: _VehicleCard(
                  icon: Icons.directions_car_rounded,
                  label: 'سيارة',
                  isSelected: _vehicleType == 'car',
                  priceLabel: '3.5 جنيه/كم',
                  onTap: () {
                    setState(() => _vehicleType = 'car');
                    _goToStep(1);
                  },
                ),
              ),
              SizedBox(width: DesignTokens.space16),
              Expanded(
                child: _VehicleCard(
                  icon: Icons.two_wheeler_rounded,
                  label: 'سكوتر',
                  isSelected: _vehicleType == 'scooter',
                  priceLabel: '2.0 جنيه/كم',
                  onTap: () {
                    setState(() => _vehicleType = 'scooter');
                    _goToStep(1);
                  },
                ),
              ),
            ],
          ),
          SizedBox(height: DesignTokens.space32),
        ],
      ),
    );
  }

  Widget _buildPickupStep() {
    final isCar = _vehicleType == 'car';
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: DesignTokens.space24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isCar ? Icons.directions_car_rounded : Icons.two_wheeler_rounded,
                color: AppTheme.primaryColor,
                size: DesignTokens.iconMd,
              ),
              SizedBox(width: DesignTokens.space4),
              Text(
                isCar ? 'رحلة بسيارة' : 'رحلة بسكوتر',
                style: TextStyle(
                  fontSize: DesignTokens.textBodySmall,
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => setState(() => _step = 0),
                icon: Icon(Icons.edit_rounded, size: DesignTokens.iconSm),
                label: Text('تغيير'),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.primaryColor,
                ),
              ),
            ],
          ),
          SizedBox(height: DesignTokens.space16),
          _LocationField(
            label: 'مكان الانطلاق',
            address: _pickupAddress,
            icon: Icons.trip_origin_rounded,
            isLoading: _isLoadingPickup,
            onTap: () => _openMapPicker(isDestination: false),
          ),
          SizedBox(height: DesignTokens.space24),
          _DividerWithLabel(label: 'إلى'),
          SizedBox(height: DesignTokens.space24),
          _LocationField(
            label: 'مكان الوصول',
            address: _destAddress.isEmpty ? 'اضغط لاختيار الوجهة' : _destAddress,
            icon: Icons.location_on_rounded,
            isLoading: false,
            onTap: () => _openMapPicker(isDestination: true),
          ),
          SizedBox(height: DesignTokens.space32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _pickupLatLng == null || _destLatLng == null
                  ? null
                  : () => _goToStep(2),
              style: ElevatedButton.styleFrom(
                backgroundColor: null,
                shadowColor:
                    AppTheme.primaryColor.withValues(alpha: 0.25),
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: DesignTokens.brLg,
                ),
              ),
              child: Text(
                'متابعة',
                style: TextStyle(
                  color: AppTheme.surfaceColor,
                  fontWeight: FontWeight.bold,
                  fontSize: DesignTokens.textBodyMedium,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
          SizedBox(height: DesignTokens.space16),
        ],
      ),
    );
  }

  Widget _buildConfirmStep() {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: DesignTokens.space24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Route info card
          Container(
            padding: EdgeInsets.all(DesignTokens.space16),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor.withValues(alpha: 0.92),
              borderRadius: DesignTokens.brLg,
              border: Border.all(
                color: AppTheme.textPrimary.withValues(alpha: 0.06),
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.trip_origin_rounded,
                        color: AppTheme.primaryColor, size: DesignTokens.iconMd),
                    SizedBox(width: DesignTokens.space4),
                    Expanded(
                      child: Text(
                        _pickupAddress,
                        style: TextStyle(
                          fontSize: DesignTokens.textBodySmall,
                          color: AppTheme.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: EdgeInsets.only(
                    left: 11.w,
                    top: DesignTokens.space2,
                    bottom: DesignTokens.space2,
                  ),
                  child: VerticalDivider(
                    width: 2,
                    thickness: 2,
                    color: AppTheme.textSecondary.withValues(alpha: 0.3),
                    indent: 4,
                    endIndent: 4,
                  ),
                ),
                Row(
                  children: [
                    Icon(Icons.location_on_rounded,
                        color: AppTheme.errorColor, size: DesignTokens.iconMd),
                    SizedBox(width: DesignTokens.space4),
                    Expanded(
                      child: Text(
                        _destAddress,
                        style: TextStyle(
                          fontSize: DesignTokens.textBodySmall,
                          color: AppTheme.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: DesignTokens.space16),
          // Price card
          _isCalculatingPrice
              ? Center(
                  child: Padding(
                    padding: EdgeInsets.all(DesignTokens.space20),
                    child: CircularProgressIndicator(
                        color: AppTheme.primaryColor),
                  ),
                )
              : _totalPrice != null
                  ? Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(DesignTokens.space20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.primaryColor.withValues(alpha: 0.08),
                            AppTheme.primaryColor.withValues(alpha: 0.02),
                          ],
                          begin: Alignment.topRight,
                          end: Alignment.bottomLeft,
                        ),
                        borderRadius: DesignTokens.brLg,
                        border: Border.all(
                          color:
                              AppTheme.primaryColor.withValues(alpha: 0.12),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'تفاصيل الرحلة',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: DesignTokens.textBodyMedium,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: DesignTokens.space4,
                                  vertical: DesignTokens.space1,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor
                                      .withValues(alpha: 0.1),
                                  borderRadius: DesignTokens.brSm,
                                ),
                                child: Text(
                                  _vehicleType == 'car'
                                      ? 'سيارة'
                                      : 'سكوتر',
                                  style: TextStyle(
                                    fontSize: DesignTokens.textLabelSmall,
                                    color: AppTheme.primaryColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: DesignTokens.space12),
                          _PriceRow(
                            icon: Icons.straighten_rounded,
                            label: 'المسافة',
                            value:
                                '${_distanceKm?.toStringAsFixed(1) ?? '?'} كم',
                          ),
                          SizedBox(height: DesignTokens.space6),
                          _PriceRow(
                            icon: Icons.speed_rounded,
                            label: 'سعر الكيلومتر',
                            value:
                                '${_pricePerKm?.toStringAsFixed(1) ?? '?'} جنيه',
                          ),
                          SizedBox(height: DesignTokens.space6),
                          _PriceRow(
                            icon: Icons.access_time_rounded,
                            label: 'الوقت المتوقع',
                            value:
                                '${_durationMin ?? '?'} دقيقة',
                          ),
                          SizedBox(height: DesignTokens.space12),
                          Divider(
                            height: 1,
                            color: AppTheme.textPrimary
                                .withValues(alpha: 0.08),
                          ),
                          SizedBox(height: DesignTokens.space8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'السعر الإجمالي',
                                style: TextStyle(
                                  fontSize: DesignTokens.textBodyMedium,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              Text(
                                '${_totalPrice?.toStringAsFixed(0) ?? '?'} جنيه',
                                style: TextStyle(
                                  fontSize: DesignTokens.textTitleSmall,
                                  fontWeight: FontWeight.w900,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    )
                  : const SizedBox.shrink(),
          if (_error != null) ...[
            SizedBox(height: DesignTokens.space12),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(DesignTokens.space12),
              decoration: BoxDecoration(
                color: AppTheme.errorColor.withValues(alpha: 0.06),
                borderRadius: DesignTokens.brMd,
                border: Border.all(
                  color: AppTheme.errorColor.withValues(alpha: 0.15),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline_rounded,
                      color: AppTheme.errorColor,
                      size: DesignTokens.iconMd),
                  SizedBox(width: DesignTokens.space4),
                  Expanded(
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: AppTheme.errorColor,
                        fontSize: DesignTokens.textBodySmall,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          SizedBox(height: DesignTokens.space24),
          SizedBox(
            width: double.infinity,
            height: DesignTokens.buttonHeight,
            child: ElevatedButton(
              onPressed: _isCreatingBooking ||
                      _totalPrice == null ||
                      _destLatLng == null
                  ? null
                  : _createRideBooking,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isCreatingBooking
                    ? AppTheme.textTertiary
                    : null,
                shadowColor:
                    AppTheme.primaryColor.withValues(alpha: 0.25),
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: DesignTokens.brLg,
                ),
              ),
              child: _isCreatingBooking
                  ? SizedBox(
                      height: DesignTokens.space20,
                      width: DesignTokens.space20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.surfaceColor,
                      ),
                    )
                  : Text(
                      'تأكيد الطلب',
                      style: TextStyle(
                        color: AppTheme.surfaceColor,
                        fontWeight: FontWeight.bold,
                        fontSize: DesignTokens.textBodyMedium,
                        letterSpacing: 0.3,
                      ),
                    ),
            ),
          ),
          SizedBox(height: DesignTokens.space32),
        ],
      ),
    );
  }

  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  static int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }
}

// -------------------------------------------------------------------
// Local widgets
// -------------------------------------------------------------------

class _VehicleCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final String priceLabel;
  final VoidCallback onTap;

  const _VehicleCard({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.priceLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: DesignTokens.durationNormal,
        curve: DesignTokens.curveEaseInOut,
        padding: EdgeInsets.all(DesignTokens.space20),
        decoration: BoxDecoration(
          gradient: isSelected
              ? AppTheme.primaryGradient
              : null,
          color: isSelected ? null : AppTheme.surfaceColor,
          borderRadius: DesignTokens.brLg,
          border: Border.all(
            color: isSelected
                ? AppTheme.primaryColor.withValues(alpha: 0.3)
                : AppTheme.textPrimary.withValues(alpha: 0.06),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.primaryColor.withValues(alpha: 0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: DesignTokens.iconLg,
              color: isSelected ? AppTheme.surfaceColor : AppTheme.primaryColor,
            ),
            SizedBox(height: DesignTokens.space4),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: DesignTokens.textBodyMedium,
                color: isSelected ? AppTheme.surfaceColor : AppTheme.textPrimary,
              ),
            ),
            SizedBox(height: DesignTokens.space2),
            Text(
              priceLabel,
              style: TextStyle(
                fontSize: DesignTokens.textBodySmall,
                color: isSelected
                    ? AppTheme.surfaceColor.withValues(alpha: 0.8)
                    : AppTheme.textSecondary,
              ),
            ),
            if (isSelected) ...[
              SizedBox(height: DesignTokens.space8),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: DesignTokens.space6,
                  vertical: DesignTokens.space2,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceColor.withValues(alpha: 0.2),
                  borderRadius: DesignTokens.brSm,
                ),
                child: Icon(
                  Icons.check_rounded,
                  color: AppTheme.surfaceColor,
                  size: DesignTokens.iconMd,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LocationField extends StatelessWidget {
  final String label;
  final String address;
  final IconData icon;
  final bool isLoading;
  final VoidCallback onTap;

  const _LocationField({
    required this.label,
    required this.address,
    required this.icon,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: DesignTokens.brLg,
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.all(DesignTokens.space16),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor.withValues(alpha: 0.92),
            borderRadius: DesignTokens.brLg,
            border: Border.all(
              color: AppTheme.textPrimary.withValues(alpha: 0.06),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(DesignTokens.space3),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.08),
                  borderRadius: DesignTokens.brSm,
                ),
                child: isLoading
                    ? SizedBox(
                        width: DesignTokens.iconMd,
                        height: DesignTokens.iconMd,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.primaryColor,
                        ),
                      )
                    : Icon(
                        icon,
                        color: AppTheme.primaryColor,
                        size: DesignTokens.iconMd,
                      ),
              ),
              SizedBox(width: DesignTokens.space6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: DesignTokens.textLabelSmall,
                        color: AppTheme.textTertiary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: DesignTokens.space1),
                    Text(
                      address,
                      style: TextStyle(
                        fontSize: DesignTokens.textBodySmall,
                        color:
                            address.contains('تعذر') || address.contains('غير')
                                ? AppTheme.errorColor
                                : AppTheme.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: DesignTokens.iconXs,
                color: AppTheme.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DividerWithLabel extends StatelessWidget {
  final String label;
  const _DividerWithLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Divider(
            height: 1,
            color: AppTheme.textPrimary.withValues(alpha: 0.08),
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: DesignTokens.space4),
          child: Icon(
            Icons.arrow_downward_rounded,
            size: DesignTokens.iconSm,
            color: AppTheme.textTertiary,
          ),
        ),
        Expanded(
          child: Divider(
            height: 1,
            color: AppTheme.textPrimary.withValues(alpha: 0.08),
          ),
        ),
      ],
    );
  }
}

class _PriceRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _PriceRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon,
            size: DesignTokens.iconSm,
            color: AppTheme.textTertiary),
        SizedBox(width: DesignTokens.space2),
        Text(
          label,
          style: TextStyle(
            fontSize: DesignTokens.textBodySmall,
            color: AppTheme.textSecondary,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: DesignTokens.textBodyMedium,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }
}
