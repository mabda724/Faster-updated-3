import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import '../theme/design_tokens.dart';
import '../services/supabase_service.dart';
import '../../features/booking/presentation/tracking_screen.dart';

class ActiveBookingBanner extends StatefulWidget {
  final bool forProvider;
  const ActiveBookingBanner({super.key, this.forProvider = false});

  @override
  State<ActiveBookingBanner> createState() => _ActiveBookingBannerState();
}

class _ActiveBookingBannerState extends State<ActiveBookingBanner> {
  List<Map<String, dynamic>> _activeBookings = [];
  RealtimeChannel? _channel;

  static const _activeStatuses = ['accepted', 'on_the_way', 'arrived', 'in_progress'];

  @override
  void initState() { super.initState(); _load(); _subscribe(); }

  Future<void> _load() async {
    final uid = SupabaseService.currentUserId;
    if (uid == null) return;
    try {
      final field = widget.forProvider ? 'provider_id' : 'client_id';
      final data = await SupabaseService.db
          .from('bookings')
          .select('id, status, services(title)')
          .eq(field, uid)
          .inFilter('status', _activeStatuses)
          .order('created_at', ascending: false);
      if (mounted) setState(() => _activeBookings = List<Map<String, dynamic>>.from(data));
    } catch (_) {}
  }

  void _subscribe() {
    final uid = SupabaseService.currentUserId;
    if (uid == null) return;
    _channel = SupabaseService.client
        .channel('active_banner')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public', table: 'bookings',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: widget.forProvider ? 'provider_id' : 'client_id', value: uid),
          callback: (_) => _load(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public', table: 'bookings',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: widget.forProvider ? 'provider_id' : 'client_id', value: uid),
          callback: (_) => _load(),
        )
        .subscribe();
  }

  @override
  void dispose() { _channel?.unsubscribe(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    if (_activeBookings.isEmpty) return const SizedBox.shrink();
    return Column(children: _activeBookings.map((b) {
      final status = b['status'] as String?;
      final icon = status == 'accepted' ? Icons.directions_car_rounded
          : status == 'on_the_way' ? Icons.route_rounded
          : status == 'arrived' ? Icons.location_on_rounded
          : Icons.build_rounded;
      final label = status == 'accepted' ? 'في الطريق'
          : status == 'on_the_way' ? 'في الطريق'
          : status == 'arrived' ? 'تم الوصول'
          : 'قيد التنفيذ';
      final svc = b['services'] is Map ? (b['services']['title'] ?? b['services']['description'] ?? '') : '';
      return GestureDetector(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TrackingScreen(bookingId: b['id'].toString()))),
        child: Container(
          margin: EdgeInsets.fromLTRB(DesignTokens.space24, 0, DesignTokens.space24, DesignTokens.space8),
          padding: EdgeInsets.symmetric(horizontal: DesignTokens.space16, vertical: DesignTokens.space12),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [AppTheme.primaryColor, AppTheme.primaryColor.withValues(alpha: 0.85)]),
            borderRadius: DesignTokens.brLg,
            boxShadow: [BoxShadow(color: AppTheme.primaryColor.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: Row(children: [
            Container(
              padding: DesignTokens.padding8,
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: DesignTokens.brMd),
              child: Icon(icon, color: Colors.white, size: DesignTokens.iconMd),
            ),
            SizedBox(width: DesignTokens.space12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('لديك خدمة $label', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: DesignTokens.textBodyMedium)),
              if (svc.isNotEmpty) Text(svc, style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: DesignTokens.textLabelSmall)),
            ])),
            Icon(Icons.arrow_forward_ios_rounded, color: Colors.white.withValues(alpha: 0.5), size: DesignTokens.iconSm),
          ]),
        ),
      );
    }).toList());
  }
}
