import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';
import '../services/supabase_service.dart';

class CompassService {
  static StreamSubscription<CompassEvent>? _compassSubscription;
  static StreamSubscription<Position>? _locationSubscription;
  static double? _currentHeading;
  static Position? _currentPosition;
  static bool _isTracking = false;
  static Timer? _updateTimer;

  static double? get currentHeading => _currentHeading;
  static Position? get currentPosition => _currentPosition;

  /// Start tracking compass heading and location
  /// Updates provider_profiles.heading and location every 5 seconds
  static Future<void> startTracking() async {
    if (_isTracking) return;
    _isTracking = true;

    debugPrint('CompassService: Starting tracking');

    // Listen to compass heading
    _compassSubscription = FlutterCompass.events?.listen((CompassEvent event) {
      _currentHeading = event.heading;
      debugPrint('Compass heading: ${event.heading}°');
    });

    // Listen to location updates
    _locationSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 5,
      ),
    ).listen((Position position) {
      _currentPosition = position;
      debugPrint('Location updated: ${position.latitude}, ${position.longitude}');
      // Update heading and location to database every 5 seconds
      final heading = _currentHeading;
      if (heading != null) {
        _updateProviderData(position, heading);
      }
    });

    // Fallback timer to update data every 5 seconds
    _updateTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      final heading = _currentHeading;
      final pos = _currentPosition;
      if (heading != null && pos != null) {
        _updateProviderData(pos, heading);
      }
    });
  }

  /// Stop tracking compass and location
  static Future<void> stopTracking() async {
    if (!_isTracking) return;
    _isTracking = false;

    debugPrint('CompassService: Stopping tracking');

    await _compassSubscription?.cancel();
    await _locationSubscription?.cancel();
    _updateTimer?.cancel();

    _compassSubscription = null;
    _locationSubscription = null;
    _updateTimer = null;
    _currentHeading = null;
    _currentPosition = null;
  }

  /// Update provider's heading and location in database
  static Future<void> _updateProviderData(Position position, double heading) async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return;

    try {
      // Update provider_profiles with current location and heading
      await SupabaseService.db.from('provider_profiles').update({
        'heading': heading,
        'current_lat': position.latitude,
        'current_lng': position.longitude,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'last_location': 'POINT(${position.longitude} ${position.latitude})',
      }).eq('id', userId);

      // Update provider_locations for real-time tracking (this is what tracking_screen reads)
      await SupabaseService.db.from('provider_locations').upsert({
        'provider_id': userId,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'heading': heading,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'provider_id');

      debugPrint('Updated location and heading: ${position.latitude}, ${position.longitude}, $heading° for provider $userId');
    } catch (e) {
      debugPrint('Error updating provider data: $e');
    }
  }

  /// Get compass heading (0-360 degrees)
  /// 0 = North, 90 = East, 180 = South, 270 = West
  static Future<double?> getHeading() async {
    return _currentHeading;
  }

  /// Get direction text from heading
  static String getDirectionText(double heading) {
    final directions = ['شمال', 'شمال شرق', 'شرق', 'جنوب شرق', 'جنوب', 'جنوب غرب', 'غرب', 'شمال غرب'];
    final index = ((heading + 22.5) / 45).floor() % 8;
    return directions[index];
  }
}
