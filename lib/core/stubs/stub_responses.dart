import 'stub_data.dart';

class StubResponses {
  StubResponses._();

  static Future<void> _delay() =>
      Future.delayed(Duration(milliseconds: 200 + (DateTime.now().millisecond % 600)));

  static Future<Map<String, dynamic>> login(String phone, String password) async {
    await _delay();
    if (phone.isEmpty || password.isEmpty) {
      return {'success': false, 'error': 'يرجى إدخال رقم الهاتف وكلمة المرور'};
    }
    return {
      'success': true,
      'user': StubData.stubUsers[0],
      'session': {
        'access_token': 'tk_' + DateTime.now().millisecondsSinceEpoch.toString(),
        'refresh_token': 'rt_' + DateTime.now().millisecondsSinceEpoch.toString(),
      },
      'message': 'تم تسجيل الدخول بنجاح',
    };
  }

  static Future<Map<String, dynamic>> signUp(Map<String, dynamic> userData) async {
    await _delay();
    return {
      'success': true,
      'user': {...StubData.stubUsers[0], ...userData},
      'message': 'تم إنشاء الحساب بنجاح',
    };
  }

  static Future<Map<String, dynamic>> verifyOtp(String code) async {
    await _delay();
    return {'success': true, 'message': 'تم التحقق بنجاح'};
  }

  static Future<List<Map<String, dynamic>>> getCategories() async {
    await _delay();
    return StubData.stubServices;
  }

  static Future<List<Map<String, dynamic>>> getProviders(String serviceId) async {
    await _delay();
    return [
      {
        'id': 'prov-001',
        'full_name': 'سارة خالد',
        'rating': 4.5,
        'total_orders': 128,
        'price': 150.0,
        'distance_km': 2.3,
        'avatar_url': 'https://i.pravatar.cc/150?u=prov1',
      },
      {
        'id': 'prov-002',
        'full_name': 'محمد علي',
        'rating': 4.8,
        'total_orders': 256,
        'price': 180.0,
        'distance_km': 3.7,
        'avatar_url': 'https://i.pravatar.cc/150?u=prov2',
      },
      {
        'id': 'prov-003',
        'full_name': 'فاطمة حسن',
        'rating': 4.2,
        'total_orders': 89,
        'price': 130.0,
        'distance_km': 5.1,
        'avatar_url': 'https://i.pravatar.cc/150?u=prov3',
      },
    ];
  }

  static Future<List<Map<String, dynamic>>> getBookings(String userId) async {
    await _delay();
    return StubData.stubBookings;
  }

  static Future<Map<String, dynamic>> createBooking(Map<String, dynamic> data) async {
    await _delay();
    return {
      'success': true,
      'booking_id': 'bkg_${DateTime.now().millisecondsSinceEpoch}',
      'status': 'pending',
      'message': 'تم إنشاء الحجز بنجاح',
    };
  }

  static Future<Map<String, dynamic>> cancelBooking(String bookingId) async {
    await _delay();
    return {'success': true, 'status': 'cancelled', 'message': 'تم إلغاء الحجز'};
  }

  static Future<Map<String, dynamic>> processPayment(Map<String, dynamic> data) async {
    await _delay();
    return {
      'success': true,
      'transaction_id': 'txn_${DateTime.now().millisecondsSinceEpoch}',
      'amount': data['amount'],
      'status': 'completed',
      'message': 'تمت المعاملة بنجاح',
    };
  }

  static Future<Map<String, dynamic>> getDashboardStats(String role) async {
    await _delay();
    return StubData.stubStats;
  }

  static Future<List<Map<String, dynamic>>> getChatMessages(String conversationId) async {
    await _delay();
    return StubData.stubChatMessages;
  }

  static Future<Map<String, dynamic>> sendMessage(Map<String, dynamic> data) async {
    await _delay();
    return {
      'success': true,
      'message_id': 'msg_${DateTime.now().millisecondsSinceEpoch}',
      'text': data['text'],
      'time': DateTime.now().toIso8601String(),
    };
  }

  static Future<List<Map<String, dynamic>>> getNotifications(String userId) async {
    await _delay();
    return StubData.stubNotifications;
  }

  static Future<List<Map<String, dynamic>>> getWalletTransactions(String userId) async {
    await _delay();
    return StubData.stubWalletTransactions;
  }

  static Future<Map<String, dynamic>> getWalletBalance(String userId) async {
    await _delay();
    return {'balance': 1250.0, 'currency': 'جنيه', 'points': 350};
  }

  static Future<Map<String, dynamic>> success() async {
    await _delay();
    return {'success': true, 'message': 'تمت العملية بنجاح'};
  }

  static Future<Map<String, dynamic>> error(String code) async {
    await _delay();
    return {'success': false, 'error': 'حدث خطأ أثناء المعالجة', 'code': code};
  }

  static Future<Map<String, dynamic>> restricted(String action) async {
    await _delay();
    return {
      'success': false,
      'restricted': true,
      'message': 'الإجراء غير متاح حالياً',
      'action': action,
    };
  }
}
