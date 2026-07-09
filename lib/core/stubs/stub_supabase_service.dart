import 'stub_responses.dart';

class StubSupabaseService {
  StubSupabaseService._();
  static final StubSupabaseService _instance = StubSupabaseService._();
  factory StubSupabaseService() => _instance;

  static bool _isLoggedIn = false;
  static String? _currentUserId;
  static String? _currentRole;

  static bool get isLoggedIn => _isLoggedIn;
  static String? get currentUserId => _currentUserId;
  static String? get currentRole => _currentRole;

  static Future<void> initialize() async {
    await Future.delayed(const Duration(milliseconds: 300));
    _isLoggedIn = false;
    _currentUserId = null;
    _currentRole = null;
  }

  static Future<void> signIn(String phone, String password) async {
    final resp = await StubResponses.login(phone, password);
    if (resp['success'] == true) {
      _isLoggedIn = true;
      _currentUserId = 'usr_${DateTime.now().millisecondsSinceEpoch}';
      _currentRole = 'client';
    }
  }

  static Future<void> signOut() async {
    await Future.delayed(const Duration(milliseconds: 200));
    _isLoggedIn = false;
    _currentUserId = null;
    _currentRole = null;
  }

  static Future<List<Map<String, dynamic>>> from(String table) async {
    await Future.delayed(const Duration(milliseconds: 100));
    return _getTableData(table);
  }

  static Future<Map<String, dynamic>> fromSingle(String table, String id) async {
    await Future.delayed(const Duration(milliseconds: 100));
    final data = _getTableData(table);
    return data.isNotEmpty ? data.first : {};
  }

  static Future<Map<String, dynamic>> rpc(String name, {Map<String, dynamic>? params}) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return {'success': true, 'rpc': name, 'params': params, 'result': 'ok'};
  }

  static Future<void> upsert(String table, Map<String, dynamic> data) async {
    await Future.delayed(const Duration(milliseconds: 200));
  }

  static Future<void> delete(String table, String id) async {
    await Future.delayed(const Duration(milliseconds: 200));
  }

  static List<Map<String, dynamic>> _getTableData(String table) {
    switch (table) {
      case 'categories':
      case 'stub_categories':
        return StubData.stubServices;
      case 'bookings':
      case 'stub_bookings':
        return StubData.stubBookings;
      case 'notifications':
      case 'stub_notifications':
        return StubData.stubNotifications;
      case 'users':
      case 'stub_users':
      case 'profiles':
      case 'stub_profiles':
        return StubData.stubUsers;
      case 'wallet_transactions':
      case 'stub_transactions':
        return StubData.stubWalletTransactions;
      default:
        return [];
    }
  }
}
