import '../../config/app_config.dart';

/// Application constants - non-sensitive values only
/// For sensitive data (API keys, secrets) use AppConfig
class AppConstants {
  // Use secure config for sensitive data
  static String get supabaseUrl => AppConfig.supabaseUrl;
  static String get supabaseAnonKey => AppConfig.supabaseAnonKey;
  static String get adminEmail => AppConfig.adminEmail;
  static double get defaultCommissionRate => AppConfig.defaultCommissionRate;
  static String get currency => AppConfig.currency;

  // Server URL - use config
  static String get paymentServerUrl => AppConfig.paymentServerUrl;

  // NOTE: Kashier keys removed from code - use AppConfig or backend only
  // NEVER commit API keys or secrets to version control
}
