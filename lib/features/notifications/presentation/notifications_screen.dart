import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/notification_badge_service.dart';
import '../../booking/presentation/tracking_screen.dart';
import '../../booking/presentation/my_bookings_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;
  StreamSubscription? _sub;
  final bool _selectMode = false;
  final Set<String> _selectedIds = {};

  @override
  void initState() { super.initState(); _load(); _subscribe(); }

  Future<void> _load() async {
    final uid = SupabaseService.currentUserId;
    if (uid == null) return;
    try {
      final data = await SupabaseService.db
          .from('notifications')
          .select()
          .eq('user_id', uid)
          .order('created_at', ascending: false)
          .limit(50);
      if (mounted) setState(() { _notifications = List<Map<String, dynamic>>.from(data); _isLoading = false; });
    } catch (_) { if (mounted) setState(() => _isLoading = false); }
  }

  void _subscribe() {
    final uid = SupabaseService.currentUserId;
    if (uid == null) return;
    SupabaseService.client
        .channel('notif_page')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public', table: 'notifications',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'user_id', value: uid),
          callback: (_) => _load(),
        )
        .subscribe();
  }

  Future<void> _markRead(String id) async {
    await SupabaseService.db.from('notifications').update({'is_read': true, 'read_at': DateTime.now().toIso8601String()}).eq('id', id);
    await NotificationBadgeService().loadUnreadCount();
    _load();
  }

  Future<void> _markAllRead() async {
    final uid = SupabaseService.currentUserId;
    if (uid == null) return;
    await SupabaseService.db.from('notifications').update({'is_read': true, 'read_at': DateTime.now().toIso8601String()}).eq('user_id', uid).eq('is_read', false);
    await NotificationBadgeService().loadUnreadCount();
    _load();
  }

  void _onTap(Map<String, dynamic> notif) {
    if (_selectMode) {
      setState(() {
        if (_selectedIds.contains(notif['id'])) {
          _selectedIds.remove(notif['id']);
        } else {
          _selectedIds.add(notif['id'] as String);
        }
      });
      return;
    }
    _markRead(notif['id'] as String);
    final type = notif['type'] as String?;
    final data = notif['data'];
    final bookingId = data is Map ? data['booking_id']?.toString() : null;
    final partnerId = data is Map ? data['sender_id']?.toString() : null;

    if (type == 'chat_message' && bookingId != null && partnerId != null) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => TrackingScreen(bookingId: bookingId)));
    } else if (type == 'order_status' && bookingId != null) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => TrackingScreen(bookingId: bookingId)));
    } else if (type == 'new_booking' && bookingId != null) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => TrackingScreen(bookingId: bookingId)));
    } else if (type == 'withdrawal_request') {
      Navigator.pushNamed(context, '/admin/withdrawals');
    } else {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const MyBookingsScreen()));
    }
  }

  IconData _iconForType(String? type) {
    switch (type) {
      case 'chat_message': return Icons.chat_bubble_rounded;
      case 'order_status': return Icons.receipt_long_rounded;
      case 'new_booking': return Icons.fiber_new_rounded;
      case 'withdrawal_request': return Icons.account_balance_wallet_rounded;
      case 'withdrawal_update': return Icons.check_circle_outline;
      default: return Icons.notifications_rounded;
    }
  }

  Color _colorForType(String? type) {
    switch (type) {
      case 'chat_message': return AppTheme.primaryColor;
      case 'order_status': return AppTheme.primaryColor;
      case 'new_booking': return AppTheme.whatsappColor;
      case 'withdrawal_request': return Colors.orange;
      default: return AppTheme.textSecondary;
    }
  }

  @override
  void dispose() { _sub?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final unread = _notifications.where((n) => n['is_read'] != true).length;
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: DesignTokens.elevation0, centerTitle: true,
        title: Text('الإشعارات${unread > 0 ? " ($unread)" : ""}', style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.textPrimary), tooltip: 'العودة', onPressed: () => Navigator.pop(context)),
        actions: [
          if (unread > 0)
            TextButton(onPressed: _markAllRead, child: const Text('تحديد الكل كمقروء', style: TextStyle(fontSize: DesignTokens.textBodySmall))),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
          : _notifications.isEmpty
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.notifications_off_rounded, size: DesignTokens.space64, color: Colors.grey.shade300),
                  SizedBox(height: DesignTokens.space16),
                  Text('لا توجد إشعارات', style: TextStyle(color: AppTheme.textSecondary, fontSize: DesignTokens.textBodyLarge)),
                ]))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: EdgeInsets.all(DesignTokens.space16),
                    itemCount: _notifications.length,
                    itemBuilder: (_, i) {
                      final n = _notifications[i];
                      final isUnread = n['is_read'] != true;
                      final type = n['type'] as String?;
                      return GestureDetector(
                        onTap: () => _onTap(n),
                        child: Container(
                          margin: EdgeInsets.only(bottom: DesignTokens.space8),
                          padding: const EdgeInsets.all(DesignTokens.space16),
                          decoration: BoxDecoration(
                            color: isUnread ? AppTheme.primaryColor.withValues(alpha: 0.04) : Colors.white,
                            borderRadius: DesignTokens.brMd,
                            border: Border.all(color: isUnread ? AppTheme.primaryColor.withValues(alpha: 0.1) : Colors.grey.shade100),
                          ),
                          child: Row(children: [
                            Container(
                              padding: const EdgeInsets.all(DesignTokens.space12),
                              decoration: BoxDecoration(color: _colorForType(type).withValues(alpha: 0.1), borderRadius: DesignTokens.brMd),
                              child: Icon(_iconForType(type), color: _colorForType(type), size: 22),
                            ),
                            SizedBox(width: DesignTokens.space12),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Row(children: [
                                Expanded(child: Text(n['title'] ?? '', style: TextStyle(fontWeight: isUnread ? FontWeight.bold : FontWeight.normal, fontSize: 13))),
                                if (isUnread) Container(width: DesignTokens.space8, height: DesignTokens.space8, decoration: const BoxDecoration(color: AppTheme.primaryColor, shape: BoxShape.circle)),
                              ]),
                              SizedBox(height: DesignTokens.space4),
                              Text(n['message'] ?? n['body'] ?? '', style: TextStyle(color: AppTheme.textSecondary, fontSize: DesignTokens.textBodySmall), maxLines: 2, overflow: TextOverflow.ellipsis),
                              SizedBox(height: DesignTokens.space4),
                              Text(_timeAgo(n['created_at'] as String?), style: TextStyle(color: Colors.grey.shade400, fontSize: DesignTokens.textLabelSmall)),
                            ])),
                          ]),
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  String _timeAgo(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'الآن';
      if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} د';
      if (diff.inHours < 24) return 'منذ ${diff.inHours} س';
      return 'منذ ${diff.inDays} ي';
    } catch (_) { return ''; }
  }
}
