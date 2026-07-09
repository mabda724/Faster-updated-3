import 'package:flutter/foundation.dart';

import 'stub_supabase_service.dart';
import 'stub_auth_repository.dart';

class StubServiceRegistry {
  StubServiceRegistry._();

  static bool _initialized = false;

  static StubSupabaseService? stubSupabase;
  static StubAuthRepository? stubAuth;

  static bool get isInitialized => _initialized;

  static Future<void> initialize() async {
    if (_initialized) return;

    stubSupabase = StubSupabaseService();
    await StubSupabaseService.initialize();
    stubAuth = StubAuthRepository();
    _initialized = true;
  }

  static Future<void> stubRestrictedService(String name) async {
    await Future.delayed(const Duration(milliseconds: 50));
  }
}
