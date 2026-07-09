class PaymentResult {
  final bool isSuccessful;
  final bool isPending;
  final bool isRejected;
  final String orderId;
  final Map<String, dynamic>? transactionDetails;
  final String? errorMessage;

  PaymentResult({
    this.isSuccessful = false,
    this.isPending = false,
    this.isRejected = false,
    this.orderId = 'pending',
    this.transactionDetails,
    this.errorMessage,
  });
}

class PaymobServiceWrapper {
  PaymobServiceWrapper._();

  static Future<PaymentResult> pay({
    int? amount,
    String? userId,
    String? fullName,
    String? email,
    String? phone,
    String paymentMethod = 'card',
    String appName = 'Faster',
  }) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return PaymentResult(
      isSuccessful: false,
      orderId: 'pay_${DateTime.now().millisecondsSinceEpoch}',
      errorMessage: 'نظام الدفع غير متاح حالياً',
    );
  }
}

class SecurityService {
  SecurityService._();

  static bool get isCompromised => false;
  static bool get isRooted => false;
  static bool get isEmulator => false;
  static bool get isJailbroken => false;
  static String get status => 'ok';

  static Future<void> checkIntegrity() async {
    await Future.delayed(const Duration(milliseconds: 100));
  }
}

class SecurityIncidentService {
  SecurityIncidentService._();

  static Future<void> arm() async {
    await Future.delayed(const Duration(milliseconds: 100));
  }
}

class HoneypotDatabaseService {
  HoneypotDatabaseService._();

  static Future<void> initialize() async {
    await Future.delayed(const Duration(milliseconds: 100));
  }
}

class EncryptedCacheService {
  EncryptedCacheService._();

  static Future<void> initialize() async {
    await Future.delayed(const Duration(milliseconds: 100));
  }
}

class PinningHttpOverrides {
  PinningHttpOverrides._();
}

class AppSecConfig {
  AppSecConfig._();
  static List<String> get sslPinnedHosts => [];
}

class RemoteMessage {
  final Map<String, String> data;
  final RemoteMessageNotification? notification;
  RemoteMessage({this.data = const {}, this.notification});
}

class RemoteMessageNotification {
  final String? title;
  final String? body;
  RemoteMessageNotification({this.title, this.body});
}

class NotificationService {
  NotificationService._();

  static void initialize() {}

  static Stream<RemoteMessage> get onForegroundMessage {
    return const Stream.empty();
  }
}

class NotificationBadgeService {
  NotificationBadgeService._();

  Future<void> initialize() async {
    await Future.delayed(const Duration(milliseconds: 100));
  }
}

class LicenseManager {
  LicenseManager._();

  static bool get isLicensed => false;
  static String get licenseStatus => 'inactive';

  static Future<bool> validateLicense() async {
    await Future.delayed(const Duration(milliseconds: 100));
    return false;
  }
}

class PolicyEnforcement {
  PolicyEnforcement._();

  static Future<void> enforce() async {
    await Future.delayed(const Duration(milliseconds: 100));
  }
}

class ChatCleanupService {
  ChatCleanupService._();

  static Future<void> runIfNeeded() async {
    await Future.delayed(const Duration(milliseconds: 100));
  }
}

class MaintenanceService {
  MaintenanceService._();

  static bool isDownForRole(String role) => false;
}

class LocationService {
  LocationService._();

  static Future<bool> handleLocationPermission() async {
    await Future.delayed(const Duration(milliseconds: 200));
    return true;
  }
}

class FirebaseApp {
  static Future<FirebaseApp> initializeApp() async {
    await Future.delayed(const Duration(milliseconds: 100));
    return FirebaseApp._();
  }
  FirebaseApp._();
}

class FirebaseMessaging {
  static FirebaseMessaging get instance => FirebaseMessaging._();
  FirebaseMessaging._();

  Future<void> requestPermission() async {}
  Future<String?> getToken() async => 'fcm_${DateTime.now().millisecondsSinceEpoch}';
  Stream<RemoteMessage> get onMessage => const Stream.empty();
}

class FlutterLocalNotificationsPlugin {
  FlutterLocalNotificationsPlugin();

  Future<void> initialize(initializationSettings, {onDidReceiveNotificationResponse}) async {}
}
