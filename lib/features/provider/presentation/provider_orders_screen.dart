import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:geolocator/geolocator.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/location_service.dart';
import 'provider_order_detail_screen.dart';
import 'provider_new_request_screen.dart';

class ProviderOrdersScreen extends StatefulWidget {
  const ProviderOrdersScreen({super.key});
  @override
  State<ProviderOrdersScreen> createState() => _ProviderOrdersScreenState();
}

class _ProviderOrdersScreenState extends State<ProviderOrdersScreen> {
  List<Map<String, dynamic>> _orders = [];
  List<Map<String, dynamic>> _broadcasts = [];
  bool _isLoading = true;
  int _tab = 0;
  StreamSubscription? _ordersSub;
  StreamSubscription? _broadcastsSub;
  int? _providerCategoryId;
  Position? _currentPos;
  double _searchRadiusKm = 20;
  final AudioPlayer _audioPlayer = AudioPlayer();
  Set<String> _seenBroadcastIds = {};
  String? _providerType;

  @override
  void initState() {
    super.initState();
    _load();
    _listen();
  }

  void _listen() {
    final uid = SupabaseService.currentUserId;
    if (uid == null) return;

    _ordersSub = SupabaseService.db
        .from('bookings')
        .stream(primaryKey: ['id'])
        .eq('provider_id', uid)
        .listen((data) {
      _load();
    });

    _broadcastsSub = SupabaseService.db
        .from('bookings')
        .stream(primaryKey: ['id'])
        .eq('status', 'pending')
        .listen((data) {
      _load();
    });
  }

  @override
  void dispose() {
    _ordersSub?.cancel();
    _broadcastsSub?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _playNotificationSound() async {
    try {
      await _audioPlayer.play(AssetSource('sounds/notification.mp3'));
    } catch (e) {
      debugPrint('Error playing notification sound: $e');
    }
  }

  void _showNewRequestNotification(Map<String, dynamic> request) {
    final clientName = request['profiles']?['full_name'] ?? 'عميل';
    final serviceName = request['services']?['title'] ?? 'خدمة';
    final distance = request['distance_km'];
    final distanceText =
        distance != null ? _formatDistance(distance) : 'غير محدد';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.notifications_rounded, color: AppTheme.surfaceColor),
            SizedBox(width: DesignTokens.space6),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'طلب جديد من $clientName',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.surfaceColor),
                  ),
                  Text(
                    '$serviceName - $distanceText',
                    style: TextStyle(
                        fontSize: DesignTokens.textBodyMedium,
                        color: Colors.white.withValues(alpha: 0.7)),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: AppTheme.primaryColor,
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'عرض',
          textColor: AppTheme.surfaceColor,
          onPressed: () {
            setState(() => _tab = 0);
          },
        ),
      ),
    );
  }

  double _haversineDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const R = 6371.0;
    final dLat = _degToRad(lat2 - lat1);
    final dLon = _degToRad(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degToRad(lat1)) *
            cos(_degToRad(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  double _degToRad(double deg) => deg * (pi / 180);

  String _formatDistance(double km) {
    if (km < 1) return '${(km * 1000).toStringAsFixed(0)} م';
    return '${km.toStringAsFixed(1)} كم';
  }

  Future<void> _load() async {
    final uid = SupabaseService.currentUserId;
    if (uid == null) return;
    try {
      final profile = await SupabaseService.db
          .from('provider_profiles')
          .select(
              'category_id, search_radius_km, latitude, longitude, provider_type')
          .eq('id', uid)
          .maybeSingle();

      if (profile != null) {
        final categoryId = profile['category_id'];
        _providerCategoryId = categoryId is int
            ? categoryId
            : int.tryParse(categoryId?.toString() ?? '');
        _searchRadiusKm =
            (profile['search_radius_km'] as num?)?.toDouble() ?? 20;
        _providerType = profile['provider_type'] as String?;
      }

      final pos = await LocationService.getCurrentPosition();
      if (pos != null) _currentPos = pos;

      final data = await SupabaseService.db
          .from('bookings')
          .select(
            '*, profiles!bookings_client_id_fkey(full_name), services(title, price, category_id)',
          )
          .eq('provider_id', uid)
          .order('created_at', ascending: false);

      List<Map<String, dynamic>> broadcasts;
      try {
        final rpcResult = await SupabaseService.db.rpc(
          'find_matching_requests_for_provider',
          params: {'p_provider_id': uid},
        );
        broadcasts = List<Map<String, dynamic>>.from(rpcResult);
      } catch (e) {
        debugPrint('RPC not available, falling back to manual filter: $e');
        broadcasts = await _loadBroadcastsManual();
      }

      if (mounted) {
        final newBroadcasts = broadcasts
            .where((b) => !_seenBroadcastIds.contains(b['id'].toString()))
            .toList();
        if (newBroadcasts.isNotEmpty && _tab == 1) {
          for (final b in newBroadcasts) {
            _seenBroadcastIds.add(b['id'].toString());
          }
          _playNotificationSound();
          _showNewRequestNotification(newBroadcasts.first);
        }

        setState(() {
          _orders = List<Map<String, dynamic>>.from(data);
          _broadcasts = broadcasts;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading orders: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<List<Map<String, dynamic>>> _loadBroadcastsManual() async {
    var query = SupabaseService.db
        .from('bookings')
        .select(
          '*, profiles!bookings_client_id_fkey(full_name), services(title, price, category_id)',
        )
        .filter('provider_id', 'is', 'null')
        .eq('status', 'pending');

    if (_providerCategoryId != null) {
      query = query.eq('services.category_id', _providerCategoryId!);
    } else {
      return [];
    }

    final rawBroadcasts = await query;
    List<Map<String, dynamic>> results =
        List<Map<String, dynamic>>.from(rawBroadcasts);

    if (_currentPos != null) {
      final withDistance = <Map<String, dynamic>>[];
      for (final b in results) {
        final lat = _toDouble(b['client_lat']);
        final lng = _toDouble(b['client_lng']);
        if (lat != null && lng != null) {
          final dist = _haversineDistance(
            _currentPos!.latitude,
            _currentPos!.longitude,
            lat,
            lng,
          );
          if (dist <= _searchRadiusKm) {
            b['distance_km'] = dist;
            withDistance.add(b);
          }
        } else {
          b['distance_km'] = null;
          withDistance.add(b);
        }
      }
      withDistance.sort((a, b) {
        final dA = a['distance_km'];
        final dB = b['distance_km'];
        if (dA == null && dB == null) return 0;
        if (dA == null) return 1;
        if (dB == null) return -1;
        return (dA as double).compareTo(dB as double);
      });
      return withDistance;
    }

    return results;
  }

  double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString());
  }

  List<Map<String, dynamic>> get _availableOrders {
    if (_tab == 0) return _broadcasts;
    return _orders.where((o) {
      return o['status'] == 'accepted' ||
          o['status'] == 'on_the_way' ||
          o['status'] == 'arrived' ||
          o['status'] == 'in_progress';
    }).toList();
  }

  String _getTimeAgo(String? createdAt) {
    if (createdAt == null) return '';
    try {
      final date = DateTime.parse(createdAt);
      final diff = DateTime.now().difference(date);
      if (diff.inMinutes < 1) return 'الآن';
      if (diff.inMinutes < 60) return '${diff.inMinutes} د';
      if (diff.inHours < 24) return '${diff.inHours} س';
      return '${diff.inDays} ي';
    } catch (_) {
      return '';
    }
  }

  String _statusText(String s) {
    switch (s) {
      case 'accepted':
        return 'تم القبول';
      case 'on_the_way':
        return 'في الطريق';
      case 'arrived':
        return 'وصلت';
      case 'in_progress':
        return 'جاري العمل';
      case 'completed':
        return 'مكتمل';
      default:
        return s;
    }
  }

  @override
  Widget build(BuildContext context) {
    final orders = _availableOrders;
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildTabs(),
            if (_tab == 0 && _providerCategoryId == null)
              _buildCategoryWarning(),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : orders.isEmpty
                      ? _buildEmptyState()
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView.builder(
                            padding: EdgeInsets.all(DesignTokens.space8.w),
                            itemCount: orders.length,
                            itemBuilder: (_, i) =>
                                _buildOrderCard(orders[i]),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.primaryColor,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        DesignTokens.space8.w,
        DesignTokens.space6.h,
        DesignTokens.space8.w,
        DesignTokens.space4.h,
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.bolt_rounded,
                    color: AppTheme.warningColor,
                    size: 20.sp,
                  ),
                  SizedBox(width: DesignTokens.space2.w),
                  Text(
                    'طلبات الكابتن',
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: DesignTokens.space4.w,
                  vertical: DesignTokens.space1.h,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.textSecondary,
                  borderRadius: BorderRadius.circular(DesignTokens.radiusMd.r),
                  border: Border.all(
                    color: AppTheme.primaryColor,
                  ),
                ),
                child: Text(
                  'أونلاين',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: DesignTokens.space3.h),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      margin: EdgeInsets.fromLTRB(
        DesignTokens.space8.w,
        DesignTokens.space4.h,
        DesignTokens.space8.w,
        0,
      ),
      padding: EdgeInsets.all(4.sp),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(DesignTokens.radiusMd.r),
      ),
      child: Row(
        children: [
          Expanded(child: _tabBtn('الطلبات المتاحة (${_broadcasts.length})', 0)),
          Expanded(child: _tabBtn('المقبولة / الجارية', 1)),
        ],
      ),
    );
  }

  Widget _tabBtn(String label, int idx) {
    final sel = _tab == idx;
    return GestureDetector(
      onTap: () => setState(() => _tab = idx),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: DesignTokens.space3.h),
        decoration: BoxDecoration(
          color: sel ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(DesignTokens.radiusMd.r),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 10.sp,
              fontWeight: sel ? FontWeight.bold : FontWeight.w600,
              color: sel
                  ? AppTheme.primaryColor
                  : AppTheme.accentColor,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryWarning() {
    return Container(
      margin: EdgeInsets.fromLTRB(
        DesignTokens.space8.w,
        DesignTokens.space4.h,
        DesignTokens.space8.w,
        0,
      ),
      padding: EdgeInsets.all(DesignTokens.space6.w),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(DesignTokens.radiusMd.r),
        border: Border.all(color: AppTheme.dividerColor),
      ),
      child: Row(
        children: [
          Icon(Icons.info_rounded,
              color: AppTheme.errorColor, size: 16.sp),
          SizedBox(width: DesignTokens.space3.w),
          Expanded(
            child: Text(
              'حدد تخصصك أولاً من الملف الشخصي لتظهر لك الطلبات المناسبة',
              style: TextStyle(
                fontSize: 10.sp,
                color: AppTheme.errorColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final msg = _tab == 0
        ? 'لا توجد طلبات متاحة حالياً'
        : 'لا توجد طلبات قيد التنفيذ';
    final sub = _tab == 0
        ? 'ستظهر لك الطلبات الجديدة فور توفرها'
        : 'عند قبول طلب سيظهر هنا';
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _tab == 0
                ? Icons.location_on_rounded
                : Icons.article_outlined,
            size: 56.sp,
            color: AppTheme.textTertiary.withValues(alpha: 0.3),
          ),
          SizedBox(height: DesignTokens.space6.h),
          Text(
            msg,
            style: TextStyle(
              fontSize: 12.sp,
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: DesignTokens.space2.h),
          Text(
            sub,
            style: TextStyle(
              fontSize: 10.sp,
              color: AppTheme.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> o) {
    final isBroadcast = o['provider_id'] == null;
    final distanceKm = _toDouble(o['distance_km']);
    final client = o['profiles'];
    final clientName = client?['full_name'] ?? o['client_name'] ?? 'عميل';
    final price = o['total_price'] ?? o['price'] ?? 0;
    final orderId = '#${o['id']?.toString().padLeft(5, '0') ?? '00000'}';
    final serviceName = o['services']?['title'] ?? o['service_title'] ?? 'خدمة';

    return Container(
      margin: EdgeInsets.only(bottom: DesignTokens.space6.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(DesignTokens.radiusLg.r),
        border: Border.all(color: AppTheme.backgroundColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            // Left colored sidebar
            Container(
              width: 6.sp,
              decoration: BoxDecoration(
                color: isBroadcast
                    ? AppTheme.warningColor
                    : AppTheme.primaryColor,
                borderRadius: BorderRadius.only(
                  topRight: Radius.circular(DesignTokens.radiusLg.r),
                  bottomRight: Radius.circular(DesignTokens.radiusLg.r),
                ),
              ),
            ),
            // Content
            Expanded(
              child: GestureDetector(
                onTap: () async {
                  if (isBroadcast) {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              ProviderNewRequestScreen(booking: o)),
                    );
                  } else {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              ProviderOrderDetailScreen(booking: o)),
                    );
                    if (result == true && mounted) _load();
                  }
                },
                child: Padding(
                  padding: EdgeInsets.all(DesignTokens.space6.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top row: order number + status badge + price
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'رقم الطلب',
                                style: TextStyle(
                                  fontSize: 9.sp,
                                  color: AppTheme.textTertiary,
                                ),
                              ),
                              Text(
                                orderId,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11.sp,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: DesignTokens.space4.w,
                                  vertical: 2.h,
                                ),
                                decoration: BoxDecoration(
                                  color: isBroadcast
                                      ? AppTheme.surfaceColor
                                      : AppTheme.backgroundColor,
                                  borderRadius: BorderRadius.circular(
                                      DesignTokens.radiusSm.r),
                                ),
                                child: Text(
                                  isBroadcast ? 'طلب عاجل' : _statusText(o['status'] ?? ''),
                                  style: TextStyle(
                                    fontSize: 8.sp,
                                    fontWeight: FontWeight.bold,
                                    color: isBroadcast
                                        ? AppTheme.errorColor
                                        : AppTheme.infoColor,
                                  ),
                                ),
                              ),
                              Text(
                                '$price جنيه',
                                style: TextStyle(
                                  fontSize: 18.sp,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.darkBackgroundColor,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      SizedBox(height: DesignTokens.space4.h),
                      // Route details
                      Container(
                        padding: EdgeInsets.all(DesignTokens.space4.w),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceColor70,
                          borderRadius: BorderRadius.circular(
                              DesignTokens.radiusMd.r),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.store_rounded,
                                  color: AppTheme.infoColor,
                                  size: 10.sp,
                                ),
                                SizedBox(width: DesignTokens.space2.w),
                                Text(
                                  'من:',
                                  style: TextStyle(
                                    fontSize: 10.sp,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                                SizedBox(width: DesignTokens.space2.w),
                                Expanded(
                                  child: Text(
                                    o['pickup_name']?.toString() ?? serviceName,
                                    style: TextStyle(
                                      fontSize: 10.sp,
                                      color: AppTheme.textSecondary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: DesignTokens.space2.h),
                            Row(
                              children: [
                                Icon(
                                  Icons.location_on_rounded,
                                  color: AppTheme.warningColor,
                                  size: 10.sp,
                                ),
                                SizedBox(width: DesignTokens.space2.w),
                                Text(
                                  'إلى:',
                                  style: TextStyle(
                                    fontSize: 10.sp,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                                SizedBox(width: DesignTokens.space2.w),
                                Expanded(
                                  child: Text(
                                    '$clientName',
                                    style: TextStyle(
                                      fontSize: 10.sp,
                                      color: AppTheme.textSecondary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: DesignTokens.space4.h),
                      // Bottom row: distance + time + button
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.route_rounded,
                                size: 10.sp,
                                color: AppTheme.textTertiary,
                              ),
                              SizedBox(width: DesignTokens.space1.w),
                              Text(
                                distanceKm != null
                                    ? _formatDistance(distanceKm)
                                    : '-- كم',
                                style: TextStyle(
                                  fontSize: 9.sp,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textTertiary,
                                ),
                              ),
                              SizedBox(width: DesignTokens.space4.w),
                              Icon(
                                Icons.access_time_rounded,
                                size: 10.sp,
                                color: AppTheme.textTertiary,
                              ),
                              SizedBox(width: DesignTokens.space1.w),
                              Text(
                                '15 دقيقة',
                                style: TextStyle(
                                  fontSize: 9.sp,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textTertiary,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: DesignTokens.space4.w,
                              vertical: DesignTokens.space2.h,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor,
                              borderRadius: BorderRadius.circular(
                                  DesignTokens.radiusMd.r),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.primaryColor
                                      .withValues(alpha: 0.2),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'عرض وتفاصيل',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10.sp,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(width: DesignTokens.space1.w),
                                Icon(
                                  Icons.chevron_left_rounded,
                                  color: Colors.white,
                                  size: 8.sp,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
