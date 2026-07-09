import 'package:flutter/foundation.dart';
import 'supabase_service.dart';

/// Service to periodically clean up expired chat messages.
/// Calls the Supabase RPC function `cleanup_expired_chats` which
/// deletes messages from bookings completed more than 30 days ago.
class ChatCleanupService {
  static DateTime? _lastCleanupTime;
  static const _cleanupInterval = Duration(hours: 24);

  /// Run chat cleanup if enough time has passed since last run.
  /// Called from app startup and periodically.
  static Future<void> runIfNeeded() async {
    if (_lastCleanupTime != null &&
        DateTime.now().difference(_lastCleanupTime!) < _cleanupInterval) {
      return; // Not enough time has passed
    }

    try {
      await SupabaseService.db.rpc('cleanup_expired_chats');
      _lastCleanupTime = DateTime.now();
      debugPrint('Chat cleanup completed successfully');
    } catch (e) {
      debugPrint('Chat cleanup error (may need SQL migration): $e');
    }
  }

  /// Force run cleanup regardless of time since last run.
  static Future<int> forceCleanup() async {
    try {
      await SupabaseService.db.rpc('cleanup_expired_chats');
      _lastCleanupTime = DateTime.now();
      debugPrint('Forced chat cleanup completed');
      return 1;
    } catch (e) {
      debugPrint('Forced chat cleanup error: $e');
      return 0;
    }
  }
}
