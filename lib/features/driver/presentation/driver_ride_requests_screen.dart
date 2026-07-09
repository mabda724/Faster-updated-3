import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/location_service.dart';
import 'driver_ride_active_screen.dart';

class DriverRideRequestsScreen extends StatefulWidget {
  const DriverRideRequestsScreen({super.key});

  @override
  State<DriverRideRequestsScreen> createState() => _DriverRideRequestsScreenState();
}

class _DriverRideRequestsScreenState extends State<DriverRideRequestsScreen> {
  List<Map<String, dynamic>> _requests = [];
  bool _isLoading = true;
  String? _error;
  double _searchRadius = 10.0; // km
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _loadRequests();
    _subscribeToRequests();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _subscribeToRequests() {
    // We use RPC to fetch matching requests, so no need to stream bookings directly
    // If streaming is needed later, we can implement it
  }

  Future<void> _loadRequests() async {
    try {
      final uid = SupabaseService.currentUserId;
      if (uid == null) return;

      // Get driver's current location
      final loc = await LocationService.getCurrentPosition();
      if (loc == null) {
        if (mounted) setState(() {
          _error = 'لا يمكن تحديد موقعك. تأكد من تفعيل GPS.';
          _isLoading = false;
        });
        return;
      }

      // Find nearby ride requests
      final rides = await SupabaseService.db.rpc('find_nearby_ride_requests', params: {
        'p_driver_id': uid,
        'p_radius_km': _searchRadius,
      }) as List? ?? [];

      // Filter to only pending rides without a provider
      final pendingRides = (rides as List).where((r) =>
        r['status'] == 'pending' && r['provider_id'] == null
      ).toList();

      if (mounted) setState(() {
        _requests = pendingRides.cast<Map<String, dynamic>>();
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      debugPrint('Error loading ride requests: $e');
      // Fallback: manual query
      try {
        final uid = SupabaseService.currentUserId;
        if (uid == null) return;

        final loc = await LocationService.getCurrentPosition();
        if (loc == null) {
          if (mounted) setState(() => _isLoading = false);
          return;
        }

        final allRides = await SupabaseService.db
            .from('bookings')
            .select()
            .eq('booking_type', 'ride')
            .eq('status', 'pending')
            .isFilter('provider_id', null);

        // Calculate distance and filter
        final driverLoc = LatLng(loc.latitude, loc.longitude);
        final filtered = <Map<String, dynamic>>[];
        for (final ride in allRides) {
          final pickupLat = double.tryParse(ride['pickup_lat']?.toString() ?? '');
          final pickupLng = double.tryParse(ride['pickup_lng']?.toString() ?? '');
          if (pickupLat != null && pickupLng != null) {
            final pickup = LatLng(pickupLat, pickupLng);
            final distance = const Distance().as(LengthUnit.Kilometer, driverLoc, pickup);
            if (distance <= _searchRadius) {
              filtered.add({...ride, 'distance_km': distance});
            }
          }
        }

        filtered.sort((a, b) => (a['distance_km'] as double).compareTo(b['distance_km'] as double));

        if (mounted) setState(() {
          _requests = filtered;
          _isLoading = false;
          _error = null;
        });
      } catch (_) {
        if (mounted) setState(() {
          _error = 'حدث خطأ في تحميل الطلبات';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _acceptRide(String bookingId) async {
    try {
      final uid = SupabaseService.currentUserId;
      if (uid == null) return;

      // Check if driver has the right vehicle type
      final provider = await SupabaseService.db
          .from('provider_profiles')
          .select('vehicle_type')
          .eq('id', uid)
          .single();

      final vehicleType = provider['vehicle_type'] ?? 'car';

      // Accept the ride
      await SupabaseService.db.from('bookings').update({
        'provider_id': uid,
        'status': 'accepted',
        'accepted_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', bookingId);

      // Load the booking and navigate to active screen
      final booking = await SupabaseService.db
          .from('bookings')
          .select('''
            *,
            profiles(full_name, phone, avatar_url)
          ''')
          .eq('id', bookingId)
          .single();

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => DriverRideActiveScreen(
              booking: booking,
              vehicleType: vehicleType,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error accepting ride: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  void _showRadiusDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: DesignTokens.brLg),
        title: const Text('نطاق البحث', textAlign: TextAlign.right),
        content: StatefulBuilder(
          builder: (ctx, setDialogState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${_searchRadius.toInt()} كم',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),
              Slider(
                value: _searchRadius,
                min: 1,
                max: 50,
                divisions: 49,
                label: '${_searchRadius.toInt()} كم',
                onChanged: (val) {
                  setDialogState(() => _searchRadius = val);
                  setState(() {});
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _loadRequests();
            },
            child: const Text('تطبيق'),
          ),
        ],
      ),
    );
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
          'طلبات المشاوير',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: DesignTokens.textTitleSmall,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _showRadiusDialog,
            icon: Icon(Icons.tune, color: AppTheme.primaryColor),
            tooltip: 'نطاق البحث',
          ),
          IconButton(
            onPressed: _loadRequests,
            icon: Icon(Icons.refresh, color: AppTheme.primaryColor),
          ),
        ],
      ),
      body: Column(
        children: [
          // Radius banner
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              horizontal: DesignTokens.space16,
              vertical: DesignTokens.space2,
            ),
            color: AppTheme.primaryColor.withValues(alpha: 0.05),
            child: Row(
              children: [
                Icon(Icons.radar, color: AppTheme.primaryColor, size: 16),
                SizedBox(width: DesignTokens.space2),
                Text(
                  'البحث في نطاق ${_searchRadius.toInt()} كم',
                  style: TextStyle(
                    color: AppTheme.primaryColor,
                    fontSize: DesignTokens.textBodySmall,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: _showRadiusDialog,
                  child: Text(
                    'تغيير',
                    style: TextStyle(
                      color: AppTheme.primaryColor,
                      fontSize: DesignTokens.textBodySmall,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? _buildError()
                    : _requests.isEmpty
                        ? _buildEmpty()
                        : _buildRequestList(),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(DesignTokens.space24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.location_off, size: 64, color: AppTheme.errorColor),
            SizedBox(height: DesignTokens.space4),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary),
            ),
            SizedBox(height: DesignTokens.space4),
            ElevatedButton(
              onPressed: _loadRequests,
              child: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(DesignTokens.space24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.local_taxi_outlined,
                  size: 40, color: AppTheme.primaryColor),
            ),
            SizedBox(height: DesignTokens.space4),
            Text(
              'لا توجد طلبات مشاوير قريبة',
              style: TextStyle(
                fontSize: DesignTokens.textTitleSmall,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            SizedBox(height: DesignTokens.space2),
            Text(
              'محاولة البحث في نطاق أكبر...',
              style: TextStyle(
                fontSize: DesignTokens.textBodySmall,
                color: AppTheme.textSecondary,
              ),
            ),
            SizedBox(height: DesignTokens.space4),
            TextButton.icon(
              onPressed: _showRadiusDialog,
              icon: Icon(Icons.radar, size: 16),
              label: const Text('تغيير نطاق البحث'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestList() {
    return RefreshIndicator(
      onRefresh: _loadRequests,
      child: ListView.builder(
        padding: EdgeInsets.all(DesignTokens.space16),
        itemCount: _requests.length,
        itemBuilder: (context, index) {
          final req = _requests[index];
          return _buildRideRequestCard(req);
        },
      ),
    );
  }

  Widget _buildRideRequestCard(Map<String, dynamic> req) {
    final distance = req['distance_km'] as double? ?? 0.0;
    final price = double.tryParse(req['total_price']?.toString() ?? '0') ?? 0;
    final vehicleType = req['ride_vehicle_type'] ?? 'car';
    final pickupAddress = req['pickup_address'] ?? 'غير محدد';
    final destAddress = req['destination_address'] ?? 'غير محدد';

    final vehicleIcon = vehicleType == 'scooter' ? '🛵' : '🚗';
    final vehicleLabel = vehicleType == 'scooter' ? 'سكوتر' : 'سيارة';

    return Container(
      margin: EdgeInsets.only(bottom: DesignTokens.space3),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: DesignTokens.brLg,
        border: Border.all(color: AppTheme.borderColor.withValues(alpha: 0.5)),
        boxShadow: DesignTokens.shadow1(Colors.black.withValues(alpha: 0.06)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.all(DesignTokens.space3),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.06),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Text(vehicleIcon, style: const TextStyle(fontSize: 20)),
                SizedBox(width: DesignTokens.space2),
                Text(
                  vehicleLabel,
                  style: TextStyle(
                    fontSize: DesignTokens.textBodySmall,
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: DesignTokens.space2,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.tertiaryColor.withValues(alpha: 0.1),
                    borderRadius: DesignTokens.brSm,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.straighten, size: 12, color: AppTheme.tertiaryColor),
                      SizedBox(width: 4),
                      Text(
                        '${distance.toStringAsFixed(1)} كم',
                        style: TextStyle(
                          fontSize: DesignTokens.textLabelSmall,
                          color: AppTheme.tertiaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Addresses
          Padding(
            padding: EdgeInsets.all(DesignTokens.space3),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      margin: EdgeInsets.only(top: 5),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    SizedBox(width: DesignTokens.space2),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'من',
                            style: TextStyle(
                              fontSize: DesignTokens.textLabelSmall,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          Text(
                            pickupAddress,
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
                  ],
                ),
                Container(
                  margin: EdgeInsets.only(right: 3, left: 20),
                  width: 1,
                  height: 16,
                  color: AppTheme.borderColor,
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      margin: EdgeInsets.only(top: 5),
                      decoration: BoxDecoration(
                        color: AppTheme.errorColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    SizedBox(width: DesignTokens.space2),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'إلى',
                            style: TextStyle(
                              fontSize: DesignTokens.textLabelSmall,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          Text(
                            destAddress,
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
                  ],
                ),
              ],
            ),
          ),

          // Price and Accept button
          Container(
            padding: EdgeInsets.fromLTRB(
              DesignTokens.space3,
              DesignTokens.space2,
              DesignTokens.space3,
              DesignTokens.space3,
            ),
            decoration: BoxDecoration(
              color: AppTheme.backgroundColor,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'سعر الرحلة',
                      style: TextStyle(
                        fontSize: DesignTokens.textLabelSmall,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    Text(
                      '${price.toStringAsFixed(1)} جنيه',
                      style: TextStyle(
                        fontSize: DesignTokens.textTitleMedium,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.successColor,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: () => _acceptRide(req['id'].toString()),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(
                      horizontal: DesignTokens.space4,
                      vertical: DesignTokens.space3,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: DesignTokens.brMd,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle, size: 18),
                      SizedBox(width: 4),
                      const Text(
                        'قبول',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}