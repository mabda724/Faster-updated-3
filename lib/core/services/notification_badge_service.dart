import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

class NotificationBadgeService {
  static final NotificationBadgeService _instance = NotificationBadgeService._();
  factory NotificationBadgeService() => _instance;
  NotificationBadgeService._();

  final StreamController<int> _badgeController = StreamController<int>.broadcast();
  Stream<int> get badgeStream => _badgeController.stream;
  
  int _unreadCount = 0;
  int get unreadCount => _unreadCount;

  Future<void> initialize() async {
    await loadUnreadCount();
    _subscribeToNotifications();
  }

  Future<void> loadUnreadCount() async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return;

    try {
      final response = await SupabaseService.db
          .from('notifications')
          .select('id')
          .eq('user_id', userId)
          .eq('is_read', false)
          .count(CountOption.exact);

      _unreadCount = response.count;
      _badgeController.add(_unreadCount);
    } catch (e) {
      debugPrint('Error loading notification count: $e');
    }
  }

  void _subscribeToNotifications() {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return;

    SupabaseService.client
        .channel('public:notifications:user_id=eq.$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            _unreadCount++;
            _badgeController.add(_unreadCount);
          },
        )
        .subscribe();
  }

  Future<void> markAsRead(List<String> ids) async {
    if (ids.isEmpty) return;

    try {
      await SupabaseService.db
          .from('notifications')
          .update({'is_read': true, 'read_at': DateTime.now().toIso8601String()})
          .inFilter('id', ids);

      _unreadCount = (_unreadCount - ids.length).clamp(0, _unreadCount);
      _badgeController.add(_unreadCount);
    } catch (e) {
      debugPrint('Error marking notifications as read: $e');
    }
  }

  Future<void> markAllAsRead() async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return;

    try {
      await SupabaseService.db
          .from('notifications')
          .update({'is_read': true, 'read_at': DateTime.now().toIso8601String()})
          .eq('user_id', userId)
          .eq('is_read', false);

      _unreadCount = 0;
      _badgeController.add(_unreadCount);
    } catch (e) {
      debugPrint('Error marking all notifications as read: $e');
    }
  }

  void dispose() {
    _badgeController.close();
  }
}