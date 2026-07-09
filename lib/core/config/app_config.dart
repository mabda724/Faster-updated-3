import 'package:flutter/foundation.dart';

class AppConfig {
  // Use your local IP or 'localhost' for web/desktop
  // For Android Emulator use '10.0.2.2'
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:3001';
    }
    // Default for mobile/desktop
    return 'http://localhost:3001'; 
    // Note: If testing on Android physical device, use your computer's local IP (e.g., 192.168.1.5)
  }
}

/// App-wide constants to avoid hardcoded values throughout the codebase
class AppConstants {
  // ──────────────── WhatsApp ────────────────
  static const String fallbackWhatsAppNumber = '201000000000';
  static const String defaultWhatsAppMessage = 'مرحباً، أحتاج مساعدة';

  // ──────────────── Financial ────────────────
  static const double minWithdrawalAmount = 500.0;
  static const double defaultCommissionRate = 0.10; // 10%

  // ──────────────── Timeouts ────────────────
  static const Duration locationTimeout = Duration(seconds: 15);
  static const Duration initializationTimeout = Duration(seconds: 4);
  static const Duration splashDuration = Duration(seconds: 3);

  // ──────────────── Limits ────────────────
  static const int maxTrailLength = 200;
  static const int maxServicesLimit = 6;
  static const int chatCleanupDays = 30;
  static const int providerCancelLimit = 3;

  // ──────────────── Layout ────────────────
  static const double carouselHeightLarge = 180;
  static const double carouselHeightSmall = 140;
  static const double serviceCardWidth = 160;
  static const double offerCardWidth = 260;

  // ──────────────── Map ────────────────
  static const String nominatimUrl = 'https://nominatim.openstreetmap.org/reverse';

  // ──────────────── Default Images ────────────────
  static const String defaultServiceImage = 'https://images.unsplash.com/photo-1581578731548-c64695cc6952?w=400&q=80';
  static const String defaultCarouselImage1 = 'https://images.unsplash.com/photo-1581578731548-c64695cc6952?w=800&q=80';
  static const String defaultCarouselImage2 = 'https://images.unsplash.com/photo-1621905252507-b35492cc74b4?w=800&q=80';
}
