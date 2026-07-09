import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import '../../firebase_options.dart';
import '../services/supabase_service.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (kIsWeb) return;
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    }
  } catch (_) {}
  
  // Show local notification from background message
  try {
    const androidSettings = AndroidInitializationSettings('@mipmap/launcher_icon');
    const iosSettings = DarwinInitializationSettings();
    const initSettings = InitializationSettings(android: androidSettings, iOS: iosSettings);
    await FlutterLocalNotificationsPlugin().initialize(initSettings);

    final notification = message.notification;
    if (notification != null) {
      const androidDetails = AndroidNotificationDetails(
        'high_importance_channel',
        'إشعارات مهمة',
        channelDescription: 'إشعارات Faster',
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        icon: '@mipmap/launcher_icon',
      );
      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );
      const details = NotificationDetails(android: androidDetails, iOS: iosDetails);
      await FlutterLocalNotificationsPlugin().show(
        message.hashCode,
        notification.title,
        notification.body,
        details,
        payload: message.data.toString(),
      );
    }
  } catch (e) {
    debugPrint('Background notification display error: $e');
  }
  
  debugPrint('Background message: ${message.messageId}');
}

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static final StreamController<RemoteMessage> _foregroundController =
      StreamController<RemoteMessage>.broadcast();
  static final StreamController<RemoteMessage> _tapController =
      StreamController<RemoteMessage>.broadcast();
  static final StreamController<Map<String, dynamic>> _inAppNotificationController =
      StreamController<Map<String, dynamic>>.broadcast();
  
  static bool _initialized = false;
  static bool _enabled = false;

  static Stream<RemoteMessage> get onForegroundMessage => _foregroundController.stream;
  static Stream<RemoteMessage> get onNotificationTap => _tapController.stream;
  static Stream<Map<String, dynamic>> get onInAppNotification => _inAppNotificationController.stream;

  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      }
      _enabled = true;
    } catch (e) {
      _enabled = false;
      debugPrint('FCM disabled: $e');
      return;
    }

    try {
      if (!kIsWeb) {
        const androidSettings = AndroidInitializationSettings('@mipmap/launcher_icon');
        const iosSettings = DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );

        const initSettings = InitializationSettings(
          android: androidSettings,
          iOS: iosSettings,
        );

        await _localNotifications.initialize(
          initSettings,
          onDidReceiveNotificationResponse: _onNotificationTapped,
        );
      }

      await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      await _saveFcmToken();

      FirebaseMessaging.onMessage.listen((message) async {
        debugPrint('FCM: ${message.notification?.title}');
        if (!kIsWeb) await _showLocalNotification(message);
        _foregroundController.add(message);
      });

      FirebaseMessaging.onMessageOpenedApp.listen((message) {
        debugPrint('Notification opened: ${message.messageId}');
        _tapController.add(message);
      });

      // Handle notification tap when app was terminated (cold start)
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        debugPrint('Initial message: ${initialMessage.messageId}');
        _tapController.add(initialMessage);
      }

      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      _messaging.onTokenRefresh.listen((_) => _saveFcmToken());

      debugPrint('NotificationService initialized');
    } catch (e) {
      debugPrint('FCM setup failed on this platform: $e');
    }
  }

  static void dispose() {
    _foregroundController.close();
    _tapController.close();
    _inAppNotificationController.close();
  }

  /// Show in-app notification with sound
  static Future<void> showInAppNotification({
    required String title,
    required String message,
    String? type,
    Map<String, dynamic>? data,
  }) async {
    if (!_enabled) return;

    try {
      // Play notification sound
      if (!kIsWeb) {
        await _localNotifications.show(
          DateTime.now().millisecondsSinceEpoch ~/ 1000,
          title,
          message,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'high_importance_channel',
              'إشعارات مهمة',
              channelDescription: 'إشعارات Faster',
              importance: Importance.high,
              priority: Priority.high,
              playSound: true,
              sound: RawResourceAndroidNotificationSound('notification_sound'),
              icon: '@mipmap/launcher_icon',
            ),
            iOS: DarwinNotificationDetails(
              presentAlert: true,
              presentBadge: true,
              presentSound: true,
              sound: 'notification_sound.mp3',
            ),
          ),
        );
      }

      // Also add to in-app notification stream
      _inAppNotificationController.add({
        'type': type,
        'title': title,
        'message': message,
        'data': data,
      });
    } catch (e) {
      debugPrint('Error showing in-app notification: $e');
    }
  }

  static Future<void> _saveFcmToken() async {
    if (!_enabled) return;
    final token = await _messaging.getToken();
    if (token == null || !SupabaseService.isLoggedIn) return;

    final userId = SupabaseService.currentUserId;
    if (userId == null) return;

    try {
      await SupabaseService.db.from('profiles').update({
        'fcm_token': token,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', userId);
      debugPrint('FCM token saved');
    } catch (e) {
      debugPrint('Failed to save FCM token: $e');
    }
  }

  static void _onNotificationTapped(NotificationResponse response) {
    debugPrint('Tapped: ${response.payload}');
  }

  static Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    final imageUrl = message.data['image'] ?? message.data['image_url'];
    
    AndroidNotificationDetails androidDetails;
    if (imageUrl != null) {
      final http.Response response = await http.get(Uri.parse(imageUrl));
      final BigPictureStyleInformation bigPictureStyleInformation =
          BigPictureStyleInformation(
        ByteArrayAndroidBitmap(response.bodyBytes),
        largeIcon: ByteArrayAndroidBitmap(response.bodyBytes),
        contentTitle: notification.title,
        summaryText: notification.body,
      );
      androidDetails = AndroidNotificationDetails(
        'high_importance_channel',
        'إشعارات مهمة',
        channelDescription: 'إشعارات Faster',
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        sound: const RawResourceAndroidNotificationSound('notification_sound'),
        icon: '@mipmap/launcher_icon',
        styleInformation: bigPictureStyleInformation,
      );
    } else {
      androidDetails = const AndroidNotificationDetails(
        'high_importance_channel',
        'إشعارات مهمة',
        channelDescription: 'إشعارات Faster',
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('notification_sound'),
        icon: '@mipmap/launcher_icon',
      );
    }

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'notification_sound.mp3',
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      message.hashCode,
      notification.title,
      notification.body,
      notificationDetails,
      payload: message.data.toString(),
    );
  }

  static Future<void> sendPushNotification({
    required String userId,
    required String title,
    required String body,
    String? type,
    Map<String, String>? data,
  }) async {
    if (!_enabled) return;

    try {
      // Convert data values to strings to match edge function expectations
      final stringData = data?.map((key, value) => MapEntry(key, value.toString()));
      
      final response = await SupabaseService.client.functions.invoke(
        'send-notification',
        body: {
          'userId': userId,
          'title': title,
          'messageBody': body, // Changed from 'body' to 'messageBody' to match edge function
          'type': type,
          'data': stringData ?? {},
        },
      );

      final responseData = response.data;
      if (responseData is Map && responseData['success'] == true) {
        debugPrint('Push notification sent to $userId');
      } else {
        final err = responseData is Map ? responseData['error'] : 'unknown';
        debugPrint('Push failed: $err');
      }
    } catch (e) {
      debugPrint('Send notification error: $e');
    }
  }

  static Future<void> subscribeToTopic(String topic) async {
    if (!_enabled) return;
    await _messaging.subscribeToTopic(topic);
  }

  static Future<void> unsubscribeFromTopic(String topic) async {
    if (!_enabled) return;
    await _messaging.unsubscribeFromTopic(topic);
  }

  static Future<String?> getToken() async {
    if (!_enabled) return null;
    return await _messaging.getToken();
  }

  static Future<void> clearToken() async {
    if (!_enabled) return;
    final userId = SupabaseService.currentUserId;
    if (userId == null) return;

    try {
      await SupabaseService.db.from('profiles').update({
        'fcm_token': null,
      }).eq('id', userId);
      await _messaging.deleteToken();
    } catch (e) {
      debugPrint('Clear token error: $e');
    }
  }
}

enum BookingStatus {
  pending('pending', 'في انتظار الموافقة', Icons.schedule),
  accepted('accepted', 'تم القبول', Icons.check_circle),
  onTheWay('on_the_way', 'في الطريق', Icons.directions_car),
  arrived('arrived', 'وصل', Icons.location_on),
  inProgress('in_progress', 'جاري التنفيذ', Icons.build),
  completed('completed', 'تمت الخدمة', Icons.done_all),
  cancelled('cancelled', 'ملغي', Icons.cancel);

  final String value;
  final String label;
  final IconData icon;
  const BookingStatus(this.value, this.label, this.icon);

  static BookingStatus fromString(String status) {
    return BookingStatus.values.firstWhere(
      (s) => s.value == status,
      orElse: () => BookingStatus.pending,
    );
  }

  int get stepIndex {
    switch (this) {
      case BookingStatus.pending:
        return 0;
      case BookingStatus.accepted:
        return 1;
      case BookingStatus.onTheWay:
        return 2;
      case BookingStatus.arrived:
        return 3;
      case BookingStatus.inProgress:
        return 4;
      case BookingStatus.completed:
        return 5;
      case BookingStatus.cancelled:
        return -1;
    }
  }
}

class NotificationTypes {
  static const String orderStatus = 'order_status';
  static const String newBooking = 'new_booking';
  static const String withdrawalRequest = 'withdrawal_request';
  static const String withdrawalUpdate = 'withdrawal_update';
  static const String chatMessage = 'chat_message';
  static const String settlement = 'settlement';
}
