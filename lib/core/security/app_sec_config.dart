import 'package:flutter/foundation.dart';

class AppSecConfig {
  AppSecConfig._();

  static String? get supabaseUrl => _fromDefine('SUPABASE_URL');
  static String? get supabaseAnonKey => _fromDefine('SUPABASE_ANON_KEY');
  static String? get paymobPublicKey => _fromDefine('PAYMOB_PUBLIC_KEY');

  static String? get appEnvironment =>
      _fromDefine('FLUTTER_ENV') ?? 'production';

  static Map<String, List<String>> get sslPinnedHosts {
    final raw = _fromDefine('SSL_PINNED_HOSTS');
    if (raw == null || raw.isEmpty) {
      return _defaultPinnedHosts;
    }
    final map = <String, List<String>>{};
    for (final entry in raw.split(';')) {
      final parts = entry.split('=');
      if (parts.length == 2) {
        map[parts[0].trim()] = parts[1].trim().split(',').map((s) => s.trim()).toList();
      }
    }
    return map;
  }

  static Map<String, List<String>> get _defaultPinnedHosts {
    return {
      'xoxnjnhqpqkkctkvxzzy.supabase.co': [
        'D8:8F:4A:7E:5C:2B:9F:1E:3A:6D:0C:4E:7B:2A:9D:1F:3C:6E:0B:4A:7D:2C:9E:1B:3F:6A:0D:4C:7E:2B:9F:1A',
      ],
    };
  }

  static String? _fromDefine(String key) {
    try {
      return String.fromEnvironment(key);
    } catch (_) {
      return null;
    }
  }

  static List<String> get integrityExemptRoles =>
      const ['developer', 'admin'];
}
