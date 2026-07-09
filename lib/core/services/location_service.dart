import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'supabase_service.dart';

class LocationService {
  static StreamSubscription<Position>? _positionSubscription;
  static String? _currentOrderId;
  static Position? _lastKnownPosition;

  static Future<bool> handleLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('Location services are disabled.');
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        debugPrint('Location permissions are denied');
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      debugPrint('Location permissions are permanently denied');
      return false;
    }

    return true;
  }

  /// Get current position with high accuracy and retry logic.
  /// Automatically captures precise location without user interaction.
  static Future<Position?> getCurrentPosition() async {
    final hasPermission = await handleLocationPermission();
    if (!hasPermission) return null;

    try {
      // First try: high accuracy with reasonable timeout
      final position = await Geolocator.getCurrentPosition(
        locationSettings: kIsWeb
            ? const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 25))
            : const LocationSettings(
                accuracy: LocationAccuracy.bestForNavigation,
                timeLimit: Duration(seconds: 15),
                distanceFilter: 0,
              ),
      );
      _lastKnownPosition = position;

      // If accuracy is poor (> 50m), try once more for better accuracy
      if (!kIsWeb && position.accuracy > 50) {
        try {
          final betterPosition = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.bestForNavigation,
              timeLimit: Duration(seconds: 10),
              distanceFilter: 0,
            ),
          );
          if (betterPosition.accuracy < position.accuracy) {
            _lastKnownPosition = betterPosition;
            return betterPosition;
          }
        } catch (_) {
          // Use the first position if retry fails
        }
      }

      return position;
    } catch (e) {
      debugPrint('Error getting current position: $e');
      // Fallback: try last known position
      try {
        final lastKnown = await Geolocator.getLastKnownPosition();
        if (lastKnown != null) {
          _lastKnownPosition = lastKnown;
          return lastKnown;
        }
      } catch (_) {}
      // Final fallback: use cached position
      return _lastKnownPosition;
    }
  }

  /// Get precise LatLng automatically - used for booking location capture.
  /// Returns null only if location is completely unavailable.
  static Future<LatLng?> getPreciseLatLng() async {
    final pos = await getCurrentPosition();
    if (pos == null) return null;
    return LatLng(pos.latitude, pos.longitude);
  }

  /// Get current position accuracy in meters.
  static Future<double?> getCurrentAccuracy() async {
    final pos = await getCurrentPosition();
    return pos?.accuracy;
  }

  static Future<void> startOnlineTracking() async {
    await startTracking();
  }

  static Future<void> startOrderTracking(String orderId) async {
    await startTracking(orderId);
  }

  static Future<void> startTracking([String? orderId]) async {
    final hasPermission = await handleLocationPermission();
    if (!hasPermission) return;

    final uid = SupabaseService.currentUserId;
    if (uid == null) return;

    if (orderId != null) {
      _currentOrderId = orderId;
    } else {
      await SupabaseService.db.from('provider_profiles').update({
        'is_online': true,
      }).eq('id', uid);
    }

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 5, // Update every 5 meters for precise tracking
      ),
    ).listen(
      (Position position) async {
        _lastKnownPosition = position;
        await _updateLocationInSupabase(position, orderId);
      },
      onError: (error) {
        debugPrint('Location stream error: $error');
      },
      cancelOnError: false,
    );

    // Also capture initial position immediately
    final initialPos = await getCurrentPosition();
    if (initialPos != null) {
      await _updateLocationInSupabase(initialPos, orderId);
    }

    debugPrint('Started location tracking${orderId != null ? ' for order: $orderId' : ''}');
  }

  static Future<void> stopTracking() async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;

    final uid = SupabaseService.currentUserId;
    if (uid == null) return;

    final wasOnOrder = _currentOrderId != null;

    if (!wasOnOrder) {
      await SupabaseService.db.from('provider_profiles').update({
        'is_online': false,
      }).eq('id', uid);
    }

    _currentOrderId = null;
    debugPrint('Stopped location tracking');
  }

  static Future<void> _updateLocationInSupabase(Position position, String? orderId) async {
    final uid = SupabaseService.currentUserId;
    if (uid == null) return;

    try {
      await SupabaseService.db.from('provider_profiles').update({
        'latitude': position.latitude,
        'longitude': position.longitude,
        'current_lat': position.latitude,
        'current_lng': position.longitude,
        'last_location_update': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', uid);

      if (orderId != null) {
        await SupabaseService.db.from('provider_locations').upsert({
          'provider_id': uid,
          'order_id': orderId,
          'latitude': position.latitude,
          'longitude': position.longitude,
          'accuracy': position.accuracy,
          'speed': position.speed,
          'heading': position.heading,
          'updated_at': DateTime.now().toIso8601String(),
        }, onConflict: 'provider_id');
      }

      debugPrint('Location updated: ${position.latitude}, ${position.longitude} (accuracy: ${position.accuracy.toStringAsFixed(1)}m)');
    } catch (e) {
      debugPrint('Error updating location: $e');
    }
  }

  static Future<LatLng?> getLastKnownLocation() async {
    final uid = SupabaseService.currentUserId;
    if (uid == null) return null;

    try {
      final data = await SupabaseService.db
          .from('provider_profiles')
          .select('latitude, longitude')
          .eq('id', uid)
          .maybeSingle();

      if (data != null && data['latitude'] != null && data['longitude'] != null) {
        return LatLng(data['latitude'], data['longitude']);
      }
    } catch (e) {
      debugPrint('Error getting last known location: $e');
    }
    return null;
  }

  /// Get readable address from coordinates using Nominatim API.
  static Future<String> getAddressFromLatLng(LatLng location) async {
    try {
      final res = await http.get(
        Uri.parse(
          'https://nominatim.openstreetmap.org/reverse?format=json&lat=${location.latitude}&lon=${location.longitude}&accept-language=ar',
        ),
        headers: {'User-Agent': 'Faster-App/1.0'},
      ).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        return data['display_name'] ?? 'عنوان غير معروف';
      }
    } catch (e) {
      debugPrint('Reverse geocode error: $e');
    }
    return 'موقع العميل';
  }

  static double calculateDistance(LatLng from, LatLng to) {
    const Distance distance = Distance();
    return distance.as(LengthUnit.Kilometer, from, to);
  }
}
