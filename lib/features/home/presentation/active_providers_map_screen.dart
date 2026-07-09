import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../../provider/presentation/provider_details_screen.dart';

class ActiveProvidersMapScreen extends StatefulWidget {
  const ActiveProvidersMapScreen({super.key});

  @override
  State<ActiveProvidersMapScreen> createState() =>
      _ActiveProvidersMapScreenState();
}

class _ActiveProvidersMapScreenState extends State<ActiveProvidersMapScreen> {
  final MapController _mapController = MapController();
  LatLng? _userLocation;
  List<dynamic> _activeProviders = [];
  bool _isLoading = true;
  double _currentRadiusKm = 3.0; // 3 km as requested

  @override
  void initState() {
    super.initState();
    _getUserLocation();
  }

  Future<void> _getUserLocation() async {
    try {
      // Check permission first
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        // Fallback to default location (Cairo) if denied
        debugPrint('Location permissions denied. Using default location.');
        setState(() {
          _userLocation = const LatLng(30.0444, 31.2357);
        });
        _loadActiveProviders();
        return;
      }

      final position = await Geolocator.getCurrentPosition();
      setState(() {
        _userLocation = LatLng(position.latitude, position.longitude);
      });
      _loadActiveProviders();
    } catch (e) {
      debugPrint('Error getting location: $e');
      setState(() {
        _userLocation = const LatLng(30.0444, 31.2357); // Fallback
        _isLoading = false;
      });
    }
  }

  Future<void> _loadActiveProviders() async {
    if (_userLocation == null) return;

    try {
      // Try calling the RPC function first
      try {
        final res = await SupabaseService.db.rpc(
          'find_providers_within_radius',
          params: {
            'client_lat': _userLocation!.latitude,
            'client_lng': _userLocation!.longitude,
            'radius_km': _currentRadiusKm,
          },
        );

        if (res is List) {
          if (res.isEmpty) {
            if (_currentRadiusKm == 3.0) {
              _currentRadiusKm = 10.0;
              _loadActiveProviders();
              return;
            } else if (_currentRadiusKm == 10.0) {
              _currentRadiusKm = 20.0;
              _loadActiveProviders();
              return;
            }
          } else {
            setState(() {
              _activeProviders = res;
              _isLoading = false;
            });
            return;
          }
        }
      } catch (rpcError) {
        debugPrint('RPC not found, falling back to manual fetch: $rpcError');
      }

      // Fallback: Fetch all online providers and filter in Dart
      final res = await SupabaseService.db
          .from('provider_profiles')
          .select('*, profiles(*)')
          .eq('is_online', true);

      final List filtered = [];
      for (var p in res) {
        // Skip banned or unapproved docs
        final prof = p['profiles'] ?? {};
        if (prof['banned_at'] != null) continue;
        if (p['document_verification_status'] != 'approved') continue;
        if (p['last_location'] != null) {
          // Parse Point(lon lat) string or geojson
          final loc = p['last_location'];
          final coords = _parsePoint(loc);
          if (coords != null) {
            final distance = Geolocator.distanceBetween(
              _userLocation!.latitude,
              _userLocation!.longitude,
              coords.latitude,
              coords.longitude,
            );
            if (distance <= _currentRadiusKm * 1000) {
              p['lat'] = coords.latitude;
              p['lon'] = coords.longitude;
              filtered.add(p);
            }
          }
        }
      }

      if (filtered.isEmpty) {
        if (_currentRadiusKm == 3.0) {
          _currentRadiusKm = 10.0;
          _loadActiveProviders();
          return;
        } else if (_currentRadiusKm == 10.0) {
          _currentRadiusKm = 20.0;
          _loadActiveProviders();
          return;
        }
      }

      setState(() {
        _activeProviders = filtered;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading providers: $e');
      setState(() => _isLoading = false);
    }
  }

  LatLng? _parsePoint(dynamic point) {
    try {
      if (point is String) {
        final parts = point
            .replaceAll('POINT(', '')
            .replaceAll(')', '')
            .split(' ');
        return LatLng(double.parse(parts[1]), double.parse(parts[0]));
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  List<LatLng> _createCircle(LatLng center, double radiusMeters) {
    const int points = 64; // circle smoothness
    final List<LatLng> circlePoints = [];
    final double earthRadius = 6371000; // meters
    double latRad = center.latitude * (pi / 180);
    double lngRad = center.longitude * (pi / 180);
    double angularRadius = radiusMeters / earthRadius;

    for (int i = 0; i <= points; i++) {
      double bearing = (2 * pi * i) / points;
      double lat = asin(
        sin(latRad) * cos(angularRadius) +
            cos(latRad) * sin(angularRadius) * cos(bearing),
      );
      double lng =
          lngRad +
          atan2(
            sin(bearing) * sin(angularRadius) * cos(latRad),
            cos(angularRadius) - sin(latRad) * sin(lat),
          );
      circlePoints.add(LatLng(lat * (180 / pi), lng * (180 / pi)));
    }
    return circlePoints;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'مزودي الخدمة النشطين',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppTheme.textPrimary,
          ),
          tooltip: 'العودة',
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor),
            )
          : Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter:
                        _userLocation ?? const LatLng(30.0444, 31.2357),
                    initialZoom: 13,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.faster.app',
                    ),
                    PolygonLayer(
                      polygons: [
                        if (_userLocation != null)
                          Polygon(
                            points: _createCircle(
                              _userLocation!,
                              _currentRadiusKm * 1000,
                            ),
                            color: AppTheme.primaryColor.withValues(alpha: 0.1),
                            borderStrokeWidth: 2,
                            borderColor: AppTheme.primaryColor,
                          ),
                      ],
                    ),
                    MarkerLayer(
                      markers: [
                        if (_userLocation != null)
                          Marker(
                            point: _userLocation!,
                            width: 80,
                            height: 80,
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.12),
                                        blurRadius: 4,
                                      ),
                                    ],
                                  ),
                                  child: const Text(
                                    'أنت هنا',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const Icon(
                                  Icons.person_pin_circle,
                                  color: Colors.blue,
                                  size: 40,
                                ),
                              ],
                            ),
                          ),
                        ..._activeProviders.map((p) {
                          final lat = (p['lat'] as num?)?.toDouble();
                          final lng = (p['lon'] as num?)?.toDouble();
                          if (lat == null || lng == null) {
                            return const Marker(
                              point: LatLng(0, 0),
                              child: SizedBox(),
                            );
                          }
                          return Marker(
                            point: LatLng(lat, lng),
                            width: 60,
                            height: 60,
                            child: GestureDetector(
                              onTap: () {
                                _showProviderPreview(p);
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppTheme.primaryColor,
                                    width: 3,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.26),
                                      blurRadius: 6,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                  color: Colors.white,
                                ),
                                  child: ClipOval(
                                  child: p['profiles']?['avatar_url'] != null
                                      ? Image.network(
                                          p['profiles']['avatar_url'],
                                          fit: BoxFit.cover,
                                          semanticLabel: 'صورة مقدم الخدمة',
                                        )
                                      : const Icon(
                                          Icons.person,
                                          color: AppTheme.textSecondary,
                                          size: 30,
                                        ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ],
                ),
                if (_activeProviders.isEmpty)
                  Positioned(
                    top: 16.h,
                    left: 24.w,
                    right: 24.w,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: Text(
                        'لا يوجد مزودين نشطين في نطاق ${_currentRadiusKm.toStringAsFixed(0)} كم',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  void _showProviderPreview(dynamic provider) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundImage: provider['profiles']?['avatar_url'] != null
                      ? NetworkImage(provider['profiles']['avatar_url'])
                      : null,
                ),
                SizedBox(width: 16.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              provider['profiles']?['full_name'] ?? 'مقدم خدمة',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ),
                          if (provider['profiles']?['is_verified'] == true) ...[
                            SizedBox(width: 4),
                            Icon(Icons.verified_rounded, size: 16, color: AppTheme.primaryColor),
                          ],
                        ],
                      ),
                      Row(
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            color: AppTheme.tertiaryColor,
                            size: 16,
                          ),
                          Text('${provider['rating'] ?? 0.0}'),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 20.h),
            ElevatedButton(
              onPressed: () {
                if (mounted) {
                  Navigator.pop(context);
                }
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        ProviderDetailsScreen(providerId: provider['id']),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'عرض الملف الشخصي',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
