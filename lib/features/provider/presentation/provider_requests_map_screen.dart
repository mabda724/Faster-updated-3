import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/location_service.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:geolocator/geolocator.dart';
import 'provider_order_detail_screen.dart';

class ProviderRequestsMapScreen extends StatefulWidget {
  const ProviderRequestsMapScreen({super.key});

  @override
  State<ProviderRequestsMapScreen> createState() =>
      _ProviderRequestsMapScreenState();
}

class _ProviderRequestsMapScreenState extends State<ProviderRequestsMapScreen>
    with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();
  List<Marker> _markers = [];
  List<CircleMarker> _radiusCircle = [];
  List<Polyline> _routeLines = [];
  Position? _currentPos;
  bool _isLoading = true;
  late AnimationController _pulseController;
  StreamSubscription? _requestsSubscription;
  Timer? _locationTimer;
  int? _providerCategoryId;
  List<Map<String, dynamic>> _sortedRequests = [];
  double _searchRadiusKm = 20;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _initMap();
    _listenToRequests();
    _startLocationUpdates();
  }

  void _startLocationUpdates() {
    _locationTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      final pos = await LocationService.getCurrentPosition();
      if (pos != null && mounted) {
        setState(() => _currentPos = pos);
        // Location tracking handled by CompassService via provider_locations table
        debugPrint('Location updated: ${pos.latitude}, ${pos.longitude}');
      }
    });
  }

  void _listenToRequests() {
    _requestsSubscription = SupabaseService.db
        .from('service_requests')
        .stream(primaryKey: ['id'])
        .eq('status', 'pending')
        .listen((data) {
          if (mounted) {
            _loadNearbyRequests();
          }
        });
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    _requestsSubscription?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  /// Haversine distance in km
  double _haversineDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const R = 6371.0; // Earth radius in km
    final dLat = _degToRad(lat2 - lat1);
    final dLon = _degToRad(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degToRad(lat1)) *
            cos(_degToRad(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  double _degToRad(double deg) => deg * (pi / 180);

  String _formatDistance(double km) {
    if (km < 1) return '${(km * 1000).toStringAsFixed(0)} م';
    return '${km.toStringAsFixed(1)} كم';
  }

  Future<void> _initMap() async {
    final pos = await LocationService.getCurrentPosition();
    if (pos != null) {
      if (mounted) {
        setState(() => _currentPos = pos);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            try {
              _mapController.move(LatLng(pos.latitude, pos.longitude), 13);
            } catch (_) {}
          }
        });
      }
    }
    await _loadNearbyRequests();
  }

  Future<void> _loadNearbyRequests() async {
    try {
      // Get provider's category and search radius
      final profile = await SupabaseService.db
          .from('provider_profiles')
          .select('category_id, search_radius_km')
          .eq('id', SupabaseService.currentUserId!)
          .maybeSingle();

      if (profile != null) {
        final categoryId = profile['category_id'];
        _providerCategoryId = categoryId is int
            ? categoryId
            : int.tryParse(categoryId?.toString() ?? '');
        _searchRadiusKm =
            (profile['search_radius_km'] as num?)?.toDouble() ?? 20;
      }

      // Try using the RPC function first
      List<Map<String, dynamic>> requests;
      try {
        final rpcResult = await SupabaseService.db.rpc(
          'find_matching_service_requests_for_provider',
          params: {'p_provider_id': SupabaseService.currentUserId!},
        );
        requests = List<Map<String, dynamic>>.from(rpcResult);
      } catch (e) {
        // Fallback: manual filtering
        debugPrint('RPC not available, falling back to manual filter: $e');
        requests = await _loadRequestsManual();
      }

      _sortedRequests = requests;

      List<Marker> markers = [];

      // User Marker
      if (_currentPos != null) {
        markers.add(
          Marker(
            point: LatLng(_currentPos!.latitude, _currentPos!.longitude),
            width: 50,
            height: 50,
            child: _buildUserMarker(),
          ),
        );
      }

      for (int i = 0; i < requests.length; i++) {
        final req = requests[i];
        final lat = _toDouble(req['lat']);
        final lng = _toDouble(req['lng']);

        if (lat != null && lng != null) {
          final distance = _currentPos != null
              ? _haversineDistance(
                  _currentPos!.latitude,
                  _currentPos!.longitude,
                  lat,
                  lng,
                )
              : _toDouble(req['distance_km']) ?? 0.0;
          markers.add(
            Marker(
              point: LatLng(lat, lng),
              width: 80,
              height: 80,
              child: Semantics(
                label: 'تفاصيل الطلب',
                child: GestureDetector(
                  onTap: () => _showRequestDetails(req, distance),
                  child: _buildRequestMarker(isNearest: i == 0),
                ),
              ),
            ),
          );
        }
      }

      // Build radius circle
      List<CircleMarker> circles = [];
      if (_currentPos != null) {
        circles.add(
          CircleMarker(
            point: LatLng(_currentPos!.latitude, _currentPos!.longitude),
            radius: _searchRadiusKm * 1000, // meters
            color: AppTheme.primaryColor.withValues(alpha: 0.08),
            borderColor: AppTheme.primaryColor.withValues(alpha: 0.3),
            borderStrokeWidth: 2,
          ),
        );
      }

      if (mounted) {
        setState(() {
          _markers = markers;
          _radiusCircle = circles;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading requests: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Manual fallback for loading service_requests with category + distance filter
  Future<List<Map<String, dynamic>>> _loadRequestsManual() async {
    var query = SupabaseService.db
        .from('service_requests')
        .select(
          '*, profiles(full_name), services!inner(title, price, category_id)',
        )
        .eq('status', 'pending');

    // Filter by specialty if provider has one
    if (_providerCategoryId != null) {
      query = query.eq('services.category_id', _providerCategoryId!);
    }

    final rawRequests = await query;
    List<Map<String, dynamic>> results =
        List<Map<String, dynamic>>.from(rawRequests);

    // Filter by distance and sort
    if (_currentPos != null) {
      final withDistance = <Map<String, dynamic>>[];
      for (final r in results) {
        final lat = _toDouble(r['lat']);
        final lng = _toDouble(r['lng']);
        if (lat != null && lng != null) {
          final dist = _haversineDistance(
            _currentPos!.latitude,
            _currentPos!.longitude,
            lat,
            lng,
          );
          if (dist <= _searchRadiusKm) {
            r['distance_km'] = dist;
            withDistance.add(r);
          }
        } else {
          r['distance_km'] = null;
          withDistance.add(r);
        }
      }
      // Sort: nearest first
      withDistance.sort((a, b) {
        final dA = a['distance_km'];
        final dB = b['distance_km'];
        if (dA == null && dB == null) return 0;
        if (dA == null) return 1;
        if (dB == null) return -1;
        return (dA as double).compareTo(dB as double);
      });
      return withDistance;
    }

    return results;
  }

  double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString());
  }

  void _showRequestDetails(Map<String, dynamic> req, double distance) {
    final distanceText = _formatDistance(distance);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: DesignTokens.brXl),
        title: Row(
          children: [
            Icon(Icons.article_outlined, color: AppTheme.primaryColor, size: 24),
            SizedBox(width: DesignTokens.space5.w),
            Expanded(
              child: Text(
                req['services']?['title'] ??
                    req['service_title'] ??
                    'طلب خدمة جديد',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: DesignTokens.textTitleMedium,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: DesignTokens.space6.w,
                vertical: DesignTokens.space3.h,
              ),
              decoration: BoxDecoration(
                color: AppTheme.tertiaryColor.withValues(alpha: 0.1),
                borderRadius: DesignTokens.brMd,
              ),
              child: Text(
                'طلب فوري مباشر',
                style: TextStyle(
                  color: AppTheme.tertiaryColor,
                  fontSize: DesignTokens.textLabelMedium,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            SizedBox(height: DesignTokens.space8.h),
            _infoItem(
              Icons.person_rounded,
              req['profiles']?['full_name'] ??
                  req['client_name'] ??
                  'عميل',
            ),
            SizedBox(height: DesignTokens.space4.h),
            _infoItem(
              Icons.location_on_rounded,
              'على بعد $distanceText منك',
            ),
            SizedBox(height: DesignTokens.space4.h),
            _infoItem(
              Icons.attach_money_rounded,
              '${req['services']?['price'] ?? req['service_price'] ?? 0} جنيه',
            ),
            SizedBox(height: DesignTokens.space6.h),
            // Show route button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _showRouteToClient(req);
                },
                icon: Icon(
                  Icons.location_on_rounded,
                  color: AppTheme.primaryColor,
                  size: 18,
                ),
                label: Text(
                  'عرض المسار على الخريطة',
                  style: TextStyle(
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AppTheme.primaryColor),
                  shape: RoundedRectangleBorder(
                    borderRadius: DesignTokens.brMd,
                  ),
                  padding: EdgeInsets.symmetric(
                    vertical: DesignTokens.space5.h,
                  ),
                ),
              ),
            ),
            SizedBox(height: DesignTokens.space4.h),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await _acceptRequest(req);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: DesignTokens.brLg,
                  ),
                ),
                child: Text(
                  'قبول الطلب والتوجه للعميل',
                  style: TextStyle(
                    color: AppTheme.surfaceColor,
                    fontWeight: FontWeight.bold,
                    fontSize: DesignTokens.textBodyLarge,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showRouteToClient(Map<String, dynamic> req) {
    final lat = _toDouble(req['lat']);
    final lng = _toDouble(req['lng']);
    if (lat == null || lng == null || _currentPos == null) return;

    setState(() {
      _routeLines = [
        Polyline(
          points: [
            LatLng(_currentPos!.latitude, _currentPos!.longitude),
            LatLng(lat, lng),
          ],
          color: AppTheme.primaryColor,
          strokeWidth: 4,
        ),
      ];
    });

    // Fit bounds to show both points
    try {
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds(
            LatLng(
              min(_currentPos!.latitude, lat),
              min(_currentPos!.longitude, lng),
            ),
            LatLng(
              max(_currentPos!.latitude, lat),
              max(_currentPos!.longitude, lng),
            ),
          ),
          padding: const EdgeInsets.all(80),
        ),
      );
    } catch (e) {
      debugPrint('Error fitting bounds: $e');
    }
  }

  Future<void> _acceptRequest(Map<String, dynamic> req) async {
    try {
      final providerId = SupabaseService.currentUserId;
      if (providerId == null) return;
      final hasProviderProfile = await _ensureProviderProfile(providerId);
      if (!hasProviderProfile) {
        throw Exception(
          'حسابك مقدم خدمة لكن ملف مقدم الخدمة ناقص. افتح لوحة مقدم الخدمة مرة وحاول تاني.',
        );
      }

      final price = req['services']?['price'] ?? req['service_price'] ?? 0;
      final commissionRate = 0.10;
      final address = req['address'] ?? 'طلب فوري (موقع الخريطة)';
      final lat = req['lat'] ?? 30.0444;
      final lng = req['lng'] ?? 31.2357;

      // Atomic acceptance via RPC to prevent race conditions
      final response = await SupabaseService.db.rpc(
        'accept_service_request',
        params: {
          'p_request_id': req['id'],
          'p_provider_id': providerId,
          'p_client_id': req['client_id'],
          'p_service_id': req['service_id'],
          'p_price': price,
          'p_commission_rate': commissionRate,
          'p_address': address,
          'p_lat': lat,
          'p_lng': lng,
        },
      );

      if (response == null || response['success'] != true) {
        final error = response?['error'] ?? 'Unknown error';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                error.toString().contains('already taken')
                    ? 'تم قبول الطلب بواسطة مزود آخر'
                    : 'فشل قبول الطلب: $error',
              ),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
        return;
      }

      final bookingRes = Map<String, dynamic>.from(response['booking']);

      // Show route to client
      _showRouteToClient(req);

      // Show success and navigate
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'تم قبول الطلب بنجاح! يتم عرض المسار إلى العميل',
            ),
            backgroundColor: AppTheme.successColor,
          ),
        );

        await Future.delayed(const Duration(seconds: 2));

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => ProviderOrderDetailScreen(booking: bookingRes),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error accepting request: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في قبول الطلب: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<bool> _ensureProviderProfile(String providerId) async {
    final existing = await SupabaseService.db
        .from('provider_profiles')
        .select('id')
        .eq('id', providerId)
        .maybeSingle();
    if (existing != null) return true;

    final profile = await SupabaseService.db
        .from('profiles')
        .select('role')
        .eq('id', providerId)
        .maybeSingle();
    if (profile?['role'] != 'provider') return false;

    await SupabaseService.db.from('provider_profiles').insert({
      'id': providerId,
      'profession': '',
      'rating': 0,
      'is_online': true,
      'wallet_balance': 0,
      'document_verification_status': 'pending',
    });
    return true;
  }

  void _showRadiusDialog() {
    final controller =
        TextEditingController(text: _searchRadiusKm.toStringAsFixed(0));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: DesignTokens.brXl),
        title: Row(
          children: [
            Icon(
              Icons.tune,
              color: AppTheme.primaryColor,
              size: 24,
            ),
            SizedBox(width: DesignTokens.space5.w),
            Text(
              'نطاق البحث',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
                fontSize: DesignTokens.textTitleMedium,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'عرض الطلبات ضمن نطاق ${_searchRadiusKm.toStringAsFixed(0)} كم من موقعك الحالي على الخريطة',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: DesignTokens.textBodyMedium,
              ),
            ),
            SizedBox(height: DesignTokens.space6.h),
            TextField(
              controller: controller,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'المسافة بالكيلومتر',
                suffixText: 'كم',
                border: OutlineInputBorder(
                  borderRadius: DesignTokens.brMd,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'إلغاء',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final val = double.tryParse(controller.text);
              if (val != null && val >= 1 && val <= 10000) {
                Navigator.pop(ctx);
                setState(() => _searchRadiusKm = val);
                // Save to provider profile
                try {
                  await SupabaseService.db
                      .from('provider_profiles')
                      .update({'search_radius_km': val})
                      .eq('id', SupabaseService.currentUserId!);
                } catch (_) {}
                _loadNearbyRequests();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: DesignTokens.brMd,
              ),
            ),
            child: Text(
              'حفظ',
              style: TextStyle(color: AppTheme.surfaceColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoItem(IconData ic, String text) => Row(
    children: [
      Icon(ic, size: 18, color: AppTheme.textSecondary),
      SizedBox(width: DesignTokens.space5.w),
      Expanded(
        child: Text(
          text,
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: DesignTokens.textBodyMedium,
          ),
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _currentPos != null
                        ? LatLng(
                            _currentPos!.latitude,
                            _currentPos!.longitude,
                          )
                        : const LatLng(30.0444, 31.2357),
                    initialZoom: 13,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                      subdomains: const ['a', 'b', 'c', 'd'],
                    ),
                    // Search radius circle
                    CircleLayer(circles: _radiusCircle),
                    if (_routeLines.isNotEmpty)
                      PolylineLayer(polylines: _routeLines),
                    MarkerLayer(markers: _markers),
                  ],
                ),
                // Nearby requests count badge
                Positioned(
                  top: DesignTokens.space16,
                  left: DesignTokens.space16,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: DesignTokens.space16.w,
                      vertical: DesignTokens.space5.h,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceColor,
                      borderRadius: DesignTokens.brXl,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.textPrimary.withValues(alpha: 0.1),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.notifications_rounded,
                          color: AppTheme.primaryColor,
                          size: 20,
                        ),
                        SizedBox(width: DesignTokens.space4.w),
                        Text(
                          '${_sortedRequests.length} طلب ضمن ${_searchRadiusKm.toStringAsFixed(0)} كم',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: DesignTokens.textBodySmall,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Category filter indicator
                if (_providerCategoryId != null)
                  Positioned(
                    top: DesignTokens.space16,
                    right: DesignTokens.space16,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: DesignTokens.space6.w,
                        vertical: DesignTokens.space4.h,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceColor,
                        borderRadius: DesignTokens.brXl,
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.textPrimary.withValues(alpha: 0.1),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.filter_list_rounded,
                            color: AppTheme.primaryColor,
                            size: DesignTokens.iconSm,
                          ),
                          SizedBox(width: DesignTokens.space3.w),
                          Text(
                            'تخصصك فقط',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: DesignTokens.textLabelMedium,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                // Nearest request quick access
                if (_sortedRequests.isNotEmpty && _currentPos != null)
                  Positioned(
                    bottom: DesignTokens.space24,
                    left: DesignTokens.space16,
                    right: DesignTokens.space16,
                    child: _buildNearestRequestCard(),
                  ),
                // Location FAB
                Positioned(
                  bottom: DesignTokens.space16,
                  right: DesignTokens.space16,
                  child: ElevatedButton(
                    onPressed: () {
                      if (_currentPos != null) {
                        _mapController.move(
                          LatLng(
                            _currentPos!.latitude,
                            _currentPos!.longitude,
                          ),
                          15,
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.surfaceColor,
                      shape: const CircleBorder(),
                      padding: EdgeInsets.zero,
                      fixedSize: const Size(56, 56),
                    ),
                    child: Icon(
                      Icons.location_on_rounded,
                      color: AppTheme.primaryColor,
                      size: DesignTokens.iconLg,
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildNearestRequestCard() {
    final nearest = _sortedRequests.first;
    final lat = _toDouble(nearest['lat']) ?? 0;
    final lng = _toDouble(nearest['lng']) ?? 0;
    final distance = _currentPos != null
        ? _haversineDistance(
            _currentPos!.latitude,
            _currentPos!.longitude,
            lat,
            lng,
          )
        : _toDouble(nearest['distance_km']) ?? 0.0;
    final distanceText = _formatDistance(distance);

    return Semantics(
      label: 'تفاصيل الطلب',
      child: GestureDetector(
        onTap: () => _showRequestDetails(nearest, distance),
        child: Container(
          padding: EdgeInsets.all(DesignTokens.space16.w),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: DesignTokens.brLg,
            boxShadow: [
              BoxShadow(
                color: AppTheme.textPrimary.withValues(alpha: 0.1),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: DesignTokens.brMd,
                ),
                child: Icon(
                  Icons.bolt_rounded,
                  color: AppTheme.primaryColor,
                  size: DesignTokens.iconMd,
                ),
              ),
              SizedBox(width: DesignTokens.space12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      nearest['services']?['title'] ??
                          nearest['service_title'] ??
                          'طلب جديد',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: DesignTokens.textBodyMedium,
                        color: AppTheme.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: DesignTokens.space2.h),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_rounded,
                          size: 14,
                          color: AppTheme.primaryColor,
                        ),
                        SizedBox(width: DesignTokens.space3.w),
                        Text(
                          distanceText,
                          style: TextStyle(
                            color: AppTheme.primaryColor,
                            fontSize: DesignTokens.textLabelMedium,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(width: DesignTokens.space8.w),
                        Icon(
                          Icons.person_rounded,
                          size: DesignTokens.iconSm,
                          color: AppTheme.textSecondary,
                        ),
                        SizedBox(width: DesignTokens.space3.w),
                        Expanded(
                          child: Text(
                            nearest['profiles']?['full_name'] ??
                                nearest['client_name'] ??
                                'عميل',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: DesignTokens.textLabelMedium,
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
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: DesignTokens.space12.w,
                  vertical: DesignTokens.space4.h,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  borderRadius: DesignTokens.brMd,
                ),
                child: Text(
                  'قبول',
                  style: TextStyle(
                    color: AppTheme.surfaceColor,
                    fontWeight: FontWeight.bold,
                    fontSize: DesignTokens.textLabelMedium,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserMarker() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.2),
        shape: BoxShape.circle,
        border: Border.all(color: AppTheme.primaryColor, width: 2),
      ),
      child: Center(
        child: Icon(
          Icons.person_rounded,
          color: AppTheme.primaryColor,
          size: DesignTokens.iconMd,
        ),
      ),
    );
  }

  Widget _buildRequestMarker({bool isNearest = false}) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 60 * _pulseController.value,
              height: 60 * _pulseController.value,
              decoration: BoxDecoration(
                color: (isNearest ? AppTheme.successColor : AppTheme.primaryColor)
                    .withValues(alpha: 0.4 * (1 - _pulseController.value)),
                shape: BoxShape.circle,
              ),
            ),
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: isNearest
                    ? AppTheme.successColor
                    : AppTheme.primaryColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.textPrimary.withValues(alpha: 0.26),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                isNearest
                    ? Icons.star_rounded
                    : Icons.build_rounded,
                color: AppTheme.surfaceColor,
                size: DesignTokens.iconSm,
              ),
            ),
          ],
        );
      },
    );
  }
}
