import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Secure configuration loaded from Supabase
/// Keys and IDs are stored securely in Supabase database
class AppConfig {
  // Lazy initialization
  static bool _initialized = false;
  static Map<String, dynamic> _remoteConfig = {};

  // Default values — override via --dart-define in production
  static const String _fallbackSupabaseUrl = 'https://placeholder.supabase.local';
  static const String _fallbackSupabaseAnonKey = 'placeholder_anon_key';

  /// Initialize configuration from Supabase
  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Load minimal config from .env for development (optional)
      try {
        await dotenv.load(fileName: 'assets/.env');
      } catch (e) {
        // .env is optional now
      }

      // Fetch configuration from Supabase
      await _loadRemoteConfig();

      _initialized = true;

      if (kDebugMode) {
        print('✅ Configuration loaded from Supabase');
      }
    } catch (e) {
      debugPrint('⚠️ Failed to load remote config, using fallbacks: $e');
      _initialized = true;
    }
  }

  /// Load configuration from Supabase
  static Future<void> _loadRemoteConfig() async {
    try {
      // Use minimal fallbacks to connect to Supabase initially
      final tempUrl = dotenv.env['SUPABASE_URL'] ?? _fallbackSupabaseUrl;
      final tempKey = dotenv.env['SUPABASE_ANON_KEY'] ?? _fallbackSupabaseAnonKey;

      final tempClient = SupabaseClient(tempUrl, tempKey);

      final response = await tempClient.functions.invoke('get-app-config');

      if (response.status != 200 || response.data == null) {
        throw Exception('Failed to fetch config: ${response.status}');
      }

      final data = response.data is String
          ? Map<String, dynamic>.from(jsonDecode(response.data as String))
          : Map<String, dynamic>.from(response.data as Map);

      _remoteConfig = data;

      if (kDebugMode) {
        print('📥 Loaded ${data.length} config keys from Supabase');
      }
    } catch (e) {
      throw Exception('Remote config loading failed: $e');
    }
  }

  // Supabase
  static String get supabaseUrl => _remoteConfig['supabase_url'] ?? _fallbackSupabaseUrl;
  static String get supabaseAnonKey => _remoteConfig['supabase_anon_key'] ?? _fallbackSupabaseAnonKey;

  // Kashier Configuration
  static String get kashierMerchantId => _remoteConfig['kashier_merchant_id'] ?? 'MID-2-670';
  static String get kashierMode => _remoteConfig['kashier_mode'] ?? 'test';

  // Admin
  static String get adminEmail => _remoteConfig['admin_email'] ?? 'admin@faster.com';

  // Server
  static String get paymentServerUrl =>
      _remoteConfig['payment_server_url'] ??
      (kIsWeb ? 'http://localhost:3001' : 'http://10.0.2.2:3001');

  // App
  static String get currency => _remoteConfig['currency'] ?? 'جنيه';
  static double get defaultCommissionRate => double.tryParse(_remoteConfig['default_commission_rate'] ?? '') ?? 10.0;

  // Search radius tiers (comma-separated)
  static List<int> get searchRadiusTiers {
    final raw = _remoteConfig['search_radius_tiers'] as String? ?? '3,5,10,20';
    return raw.split(',').map((e) => int.tryParse(e.trim()) ?? 3).toList();
  }

  static int get defaultSearchRadius => int.tryParse(_remoteConfig['search_radius_default'] ?? '') ?? 3;
}