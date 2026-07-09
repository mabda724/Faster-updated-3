import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/services/supabase_service.dart';
import 'provider_order_detail_screen.dart';

class ProviderTripHistoryScreen extends StatefulWidget {
  const ProviderTripHistoryScreen({super.key});
  @override
  State<ProviderTripHistoryScreen> createState() =>
      _ProviderTripHistoryScreenState();
}

class _ProviderTripHistoryScreenState extends State<ProviderTripHistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _allTrips = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  int _offset = 0;
  static const int _pageSize = 20;
  bool _hasMore = true;
  StreamSubscription? _subscription;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) setState(() {});
    });
    _load();
    _listen();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _subscription?.cancel();
    super.dispose();
  }

  void _listen() {
    final uid = SupabaseService.currentUserId;
    if (uid == null) return;
    _subscription = SupabaseService.db
        .from('bookings')
        .stream(primaryKey: ['id'])
        .eq('provider_id', uid)
        .listen((_) => _load());
  }

  Future<void> _load() async {
    final uid = SupabaseService.currentUserId;
    if (uid == null) return;
    try {
      final res = await SupabaseService.db
          .from('bookings')
          .select(
              '*, profiles!bookings_client_id_fkey(full_name, avatar_url), services(title)')
          .eq('provider_id', uid)
          .inFilter('status', ['completed', 'cancelled'])
          .order('updated_at', ascending: false)
          .limit(_pageSize);
      _allTrips = List<Map<String, dynamic>>.from(res);
      _hasMore = res.length >= _pageSize;
      _offset = _pageSize;
      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Error loading trips: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    final uid = SupabaseService.currentUserId;
    if (uid == null) return;
    setState(() => _isLoadingMore = true);
    try {
      final res = await SupabaseService.db
          .from('bookings')
          .select(
              '*, profiles!bookings_client_id_fkey(full_name, avatar_url), services(title)')
          .eq('provider_id', uid)
          .inFilter('status', ['completed', 'cancelled'])
          .order('updated_at', ascending: false)
          .range(_offset, _offset + _pageSize - 1);
      if (res.isNotEmpty) {
        _allTrips.addAll(List<Map<String, dynamic>>.from(res));
        _offset += res.length;
        _hasMore = res.length >= _pageSize;
      } else {
        _hasMore = false;
      }
      if (mounted) setState(() => _isLoadingMore = false);
    } catch (e) {
      debugPrint('Error loading more trips: $e');
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  List<Map<String, dynamic>> _getFilteredTrips() {
    switch (_tabController.index) {
      case 0:
        return _allTrips;
      case 1:
        return _allTrips
            .where((t) => t['status'] == 'completed')
            .toList();
      case 2:
        return _allTrips
            .where((t) => t['status'] == 'cancelled')
            .toList();
      default:
        return _allTrips;
    }
  }

  String _formatDateTime(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final diff = now.difference(date);
      if (diff.inDays == 0) {
        return 'اليوم - ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')} م';
      } else if (diff.inDays == 1) {
        return 'أمس - ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')} م';
      } else {
        return '${date.day}/${date.month}/${date.year} - ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
      }
    } catch (_) {
      return '';
    }
  }

  String _getTripNumber(Map<String, dynamic> trip) {
    final code = trip['order_code']?.toString();
    if (code != null && code.isNotEmpty) return '#$code';
    return '#${trip['id']?.toString()?.substring(0, 4) ?? ''}';
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'completed':
        return AppTheme.successColor;
      case 'cancelled':
        return AppTheme.errorColor;
      default:
        return AppTheme.textSecondary;
    }
  }

  Color _statusBgColor(String? status) {
    switch (status) {
      case 'completed':
        return AppTheme.successColor.withValues(alpha: 0.1);
      case 'cancelled':
        return AppTheme.errorColor.withValues(alpha: 0.1);
      default:
        return Colors.grey[100]!;
    }
  }

  String _statusLabel(String? status) {
    switch (status) {
      case 'completed':
        return 'مكتملة';
      case 'cancelled':
        return 'ملغية';
      default:
        return '';
    }
  }

  double _getTripPrice(Map<String, dynamic> trip) {
    return double.tryParse(
            trip['total_price']?.toString() ??
                trip['price']?.toString() ??
                '0') ??
        0;
  }

  String _getTripLocation(Map<String, dynamic> trip) {
    return trip['address']?.toString() ?? 'غير محدد';
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _getFilteredTrips();
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: AppTheme.successColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.chevron_right,
              color: Colors.white, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'تاريخ الرحلات',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded,
                color: Colors.white70, size: 20),
            onPressed: () {},
          ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(56.h),
          child: Container(
            margin: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: AppTheme.successColor,
              unselectedLabelColor: Colors.white,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
              dividerColor: Colors.transparent,
              tabs: const [
                Tab(text: 'الكل'),
                Tab(text: 'مكتملة'),
                Tab(text: 'ملغية'),
              ],
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : filtered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.history_rounded,
                          size: 64, color: Colors.grey[300]),
                      SizedBox(height: 16.h),
                      Text(
                        _tabController.index == 2
                            ? 'لا توجد رحلات ملغية'
                            : _tabController.index == 1
                                ? 'لا توجد رحلات مكتملة'
                                : 'لا توجد رحلات بعد',
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontWeight: FontWeight.bold,
                          fontSize: DesignTokens.textTitleMedium,
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: EdgeInsets.all(16.w),
                    itemCount: filtered.length + (_hasMore ? 1 : 0),
                    itemBuilder: (ctx, i) {
                      if (i >= filtered.length) {
                        _loadMore();
                        return Padding(
                          padding: EdgeInsets.symmetric(vertical: 16.h),
                          child: const Center(
                              child: CircularProgressIndicator()),
                        );
                      }
                      final trip = filtered[i];
                      return _buildTripCard(trip);
                    },
                  ),
                ),
    );
  }

  Widget _buildTripCard(Map<String, dynamic> trip) {
    final status = trip['status'] as String?;
    final isCancelled = status == 'cancelled';
    final client = trip['profiles'] as Map<String, dynamic>?;
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProviderOrderDetailScreen(booking: trip),
          ),
        ),
        borderRadius: DesignTokens.brLg,
        child: Container(
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: isCancelled
                ? Colors.white.withValues(alpha: 0.8)
                : Colors.white,
            borderRadius: DesignTokens.brLg,
            border: Border.all(
              color: isCancelled
                  ? AppTheme.errorColor.withValues(alpha: 0.3)
                  : Colors.grey[100]!,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: isCancelled
                            ? AppTheme.errorColor.withValues(alpha: 0.1)
                            : AppTheme.successColor
                                .withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.schedule_rounded,
                        size: DesignTokens.iconSm,
                        color: isCancelled
                            ? AppTheme.errorColor
                            : AppTheme.successColor,
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getTripNumber(trip),
                          style: TextStyle(
                            color: isCancelled
                                ? AppTheme.textSecondary
                                : AppTheme.successColor,
                            fontWeight: FontWeight.bold,
                            fontSize: DesignTokens.textLabelMedium,
                            decoration: isCancelled
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          _getTripLocation(trip),
                          style: TextStyle(
                            fontSize: DesignTokens.textLabelMedium,
                            fontWeight: FontWeight.bold,
                            color: isCancelled
                                ? AppTheme.textSecondary
                                : AppTheme.textPrimary,
                          ),
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          _formatDateTime(
                              trip['updated_at']?.toString()),
                          style: TextStyle(
                            fontSize: DesignTokens.textLabelSmall,
                            color: AppTheme.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${_getTripPrice(trip).toStringAsFixed(0)} EGP',
                    style: TextStyle(
                      fontSize: DesignTokens.textTitleMedium,
                      fontWeight: FontWeight.bold,
                      color: isCancelled
                          ? Colors.grey[400]
                          : AppTheme.textPrimary,
                      decoration: isCancelled
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: 8.w, vertical: 2.h),
                    decoration: BoxDecoration(
                      color: _statusBgColor(status),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _statusLabel(status),
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: _statusColor(status),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
