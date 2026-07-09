import 'package:flutter/foundation.dart';
import '../services/supabase_service.dart';
import '../services/notification_service.dart';

class InAppNotifier {
  /// Create in-app notification record + send push notification
  static Future<void> notify({
    required String userId,
    required String title,
    required String message,
    required String type,
    Map<String, dynamic>? data,
  }) async {
    try {
      await SupabaseService.db.from('notifications').insert({
        'user_id': userId,
        'type': type,
        'title': title,
        'message': message,
        'data': data,
        'is_read': false,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
      // Send push notification to phone notification bar
      await NotificationService.sendPushNotification(
        userId: userId,
        title: title,
        body: message,
        type: type,
        data: data?.map((k, v) => MapEntry(k, v.toString())),
      );
      // Also show in-app notification with sound
      await NotificationService.showInAppNotification(
        title: title,
        message: message,
        type: type,
        data: data,
      );
    } catch (e) {
      debugPrint('InAppNotifier error: $e');
    }
  }

  /// Notify both parties about status change
  static Future<void> statusChanged({
    required String bookingId,
    required String newStatus,
    required String? clientId,
    required String? providerId,
  }) async {
    final statusLabels = {
      'accepted': 'تم قبول طلبك ✅',
      'on_the_way': 'مقدم الخدمة في الطريق 🚗',
      'arrived': 'مقدم الخدمة وصل 📍',
      'in_progress': 'بدأ العمل 🔧',
      'completed': 'تم إتمام الخدمة 🎉',
      'cancelled': 'تم إلغاء الطلب',
    };
    final label = statusLabels[newStatus] ?? 'تحديث حالة الطلب';
    final messages = {
      'accepted': 'تم قبول طلب الخدمة، مقدم الخدمة في الطريق إليك',
      'on_the_way': 'مقدم الخدمة في الطريق، توقع وصوله قريباً',
      'arrived': 'مقدم الخدمة في موقعك، قم بتأكيد الوصول',
      'in_progress': 'مقدم الخدمة بدأ في تنفيذ الخدمة',
      'completed': 'تم إتمام الخدمة بنجاح، قيم تجربتك',
      'cancelled': 'تم إلغاء الطلب',
    };
    final body = messages[newStatus] ?? label;

    if (clientId != null) {
      await notify(userId: clientId, title: label, message: body, type: 'order_status', data: {'booking_id': bookingId});
    }
    if (providerId != null) {
      await notify(userId: providerId, title: label, message: body, type: 'order_status', data: {'booking_id': bookingId});
    }
  }

  /// Notify about new chat message
  static Future<void> newMessage({
    required String recipientId,
    required String senderName,
    required String bookingId,
    String? messagePreview,
  }) async {
    await notify(
      userId: recipientId,
      title: 'رسالة جديدة من $senderName',
      message: messagePreview ?? 'أرسل لك رسالة جديدة',
      type: 'chat_message',
      data: {
        'booking_id': bookingId, 
        'sender_name': senderName, 
        'sender_id': SupabaseService.currentUserId,
      },
    );
  }
}
