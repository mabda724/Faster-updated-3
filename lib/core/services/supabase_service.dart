import 'package:supabase_flutter/supabase_flutter.dart';
import '../exceptions/app_exceptions.dart';
import '../../config/app_config.dart';
import '../stubs/stub_auth_repository.dart';
import '../stubs/stub_responses.dart';

class SupabaseService {
  static bool _initialized = false;
  static bool _bypassMode = false;
  static MockAuthRepository? _bypassAuth;

  static void enableBypassMode() {
    _bypassMode = true;
    _initialized = true;
    _bypassAuth = MockAuthRepository();
  }

  static bool get isBypassMode => _bypassMode;

  static SupabaseClient get client {
    if (_bypassMode) {
      throw UnsupportedError('Supabase client unavailable');
    }
    if (!_initialized) throw AppException('Supabase not initialized');
    return Supabase.instance.client;
  }

  static Future<void> initialize() async {
    if (_initialized) return;
    if (_bypassMode) return;
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      anonKey: AppConfig.supabaseAnonKey,
    );
    _initialized = true;
  }

  static SupabaseClient get db => client;
  static GoTrueClient get auth => client.auth;
  static SupabaseStorageClient get storage => client.storage;

  static String? get currentUserId =>
      _bypassMode ? 'usr_${DateTime.now().millisecondsSinceEpoch}' : (_initialized ? auth.currentUser?.id : null);

  static bool get isLoggedIn =>
      _bypassMode ? true : (_initialized && auth.currentUser != null);

  static Future<Map<String, dynamic>?> getCurrentSession() async {
    if (_bypassMode) {
      return _bypassAuth?.getCurrentSession();
    }
    final user = auth.currentUser;
    if (user == null) return null;
    return {'user_id': user.id, 'email': user.email, 'role': user.userMetadata?['role']};
  }

  static Future<Map<String, dynamic>> redeemPoints(int amount) async {
    if (_bypassMode) return MockResponses.success();
    final uid = currentUserId;
    if (uid == null) throw Exception('User not logged in');
    final res = await db.rpc('redeem_points', params: {
      'p_user_id': uid,
      'p_amount': amount,
    });
    return Map<String, dynamic>.from(res as Map);
  }

  static Future<Map<String, dynamic>> getUserPoints() async {
    if (_bypassMode) return MockResponses.getWalletBalance('usr_placeholder');
    final uid = currentUserId;
    if (uid == null) throw Exception('User not logged in');
    final res = await db.from('user_points').select().eq('user_id', uid).maybeSingle();
    return Map<String, dynamic>.from(res as Map);
  }

  static Future<void> upsertProviderSchedule({
    int? id,
    required int dayOfWeek,
    required String startTime,
    required String endTime,
  }) async {
    if (_bypassMode) return;
    final uid = currentUserId;
    if (uid == null) throw Exception('User not logged in');
    await db.rpc('upsert_provider_schedule', params: {
      'p_id': id,
      'p_provider_id': uid,
      'p_day_of_week': dayOfWeek,
      'p_start_time': startTime,
      'p_end_time': endTime,
    });
  }
}
