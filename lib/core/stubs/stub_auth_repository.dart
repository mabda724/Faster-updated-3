import 'stub_responses.dart';

class StubAuthRepository {
  static String? _currentUserId;

  Future<Map<String, dynamic>> login({
    required String phone,
    required String password,
  }) async {
    _currentUserId = 'usr_${DateTime.now().millisecondsSinceEpoch}';
    return StubResponses.login(phone, password);
  }

  Future<Map<String, dynamic>> signUp({
    required String phone,
    required String password,
    String? email,
    required String fullName,
    required String role,
    String? profession,
    int? categoryId,
    String? nationalIdNumber,
    String? bio,
    String? referredBy,
    String? providerType,
    String? storeAddress,
    String? taxId,
    String? vehicleModel,
    String? vehiclePlate,
    String? deliveryArea,
  }) async {
    _currentUserId = 'usr_${DateTime.now().millisecondsSinceEpoch}';
    return StubResponses.signUp({
      'phone': phone,
      'email': email,
      'full_name': fullName,
      'role': role,
    });
  }

  Future<Map<String, dynamic>> verifyOtp(String code) async {
    return StubResponses.verifyOtp(code);
  }

  Future<void> logout() async {
    await Future.delayed(const Duration(milliseconds: 200));
    _currentUserId = null;
  }

  Future<String?> getCurrentRole() async {
    await Future.delayed(const Duration(milliseconds: 100));
    return 'client';
  }

  Future<Map<String, dynamic>?> getCurrentSession() async {
    await Future.delayed(const Duration(milliseconds: 100));
    if (_currentUserId == null) return null;
    return {
      'user_id': _currentUserId,
      'role': 'client',
      'full_name': 'أحمد محمد',
      'email': 'ahmed@mail.local',
    };
  }
}
