// ============================================================
// Faster App - جميع الحقوق محفوظة
// All Rights Reserved © 2024-2026
// المالك: محمد ابراهيم عبدالله | 01128966996
// ============================================================
// ============================================================
// Faster App - ???? ?????? ??????
// ??????: ???? ??????? ??????? | 01128966996
import 'package:flutter/material.dart';
import 'supabase_service.dart';

/// Reads maintenance flags from app_settings and decides if the app
/// should show the maintenance screen for the current user role.
class MaintenanceService {
  static String? _cachedMessage;
  static bool _clientDown = false;
  static bool _providerDown = false;
  /// Call this early (e.g. in main() after Supabase init).
  static Future<void> check() async {
    try {
      final rows = await SupabaseService.db
          .from('app_settings')
          .select('key, value')
          .inFilter('key', ['maintenance_client', 'maintenance_provider', 'maintenance_message']);
      for (final r in rows) {
        final k = r['key']?.toString();
        final v = r['value']?.toString();
        if (k == 'maintenance_client') {
          _clientDown = v == 'true' || v == '1';
        } else if (k == 'maintenance_provider') {
          _providerDown = v == 'true' || v == '1';
        } else if (k == 'maintenance_message') {
          _cachedMessage = v;
        }
      }
    } catch (e) {
      debugPrint('Maintenance check error: $e');
    }
  }

  static bool isDownForRole(String? role) {
    if (role == 'admin') return false; // admins never blocked
    if (role == 'provider') return _providerDown;
    return _clientDown; // client or guest
  }

  static String get message =>
      _cachedMessage?.isNotEmpty == true
          ? _cachedMessage!
          : 'سنعود قريباً... نحن نقوم بتحديث التطبيق لتقديم تجربة أفضل لك.';
}
