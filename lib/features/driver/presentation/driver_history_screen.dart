import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/services/supabase_service.dart';

class DriverHistoryScreen extends StatefulWidget {
  const DriverHistoryScreen({super.key});
  @override
  State<DriverHistoryScreen> createState() => _DriverHistoryScreenState();
}

class _DriverHistoryScreenState extends State<DriverHistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _allRides = [];
  bool _isLoading = true;

  // Stats
  int _totalTrips = 0;
  double _totalEarnings = 0;
  double _avgRating = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final uid = SupabaseService.currentUserId;
    if (uid == null) return;
    try {
      final res = await SupabaseService.db
          .from('bookings')
          .select('*, profiles(full_name), services(name)')
          .eq('provider_id', uid)
          .eq('status', 'completed')
          .order('completed_at', ascending: false);
      _allRides = List<Map<String, dynamic>>.from(res);

      // Calculate stats
      _totalTrips = _allRides.length;
      _totalEarnings = 0;
      double totalRating = 0;
      int ratedCount = 0;
      for (var r in _allRides) {
        final price = double.tryParse(
                (r['offered_price'] ?? r['total_price'])?.toString() ?? '0') ??
            0;
        final comm =
            double.tryParse(r['commission_amount']?.toString() ?? '0') ?? 0;
        _totalEarnings += (price - comm);
        final rating = double.tryParse(r['rating']?.toString() ?? '');
        if (rating != null && rating > 0) {
          totalRating += rating;
          ratedCount++;
        }
      }
      _avgRating = ratedCount > 0 ? totalRating / ratedCount : 0;

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Error loading history: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> _getFilteredRides(int tabIndex) {
    final now = DateTime.now();
    switch (tabIndex) {
      case 0: // اليوم
        return _allRides.where((r) {
          final dateStr = r['completed_at'] ?? r['created_at'];
          if (dateStr == null) return false;
          try {
            final date = DateTime.parse(dateStr);
            return date.year == now.year && date.month == now.month && date.day == now.day;
          } catch (_) {
            return false;
          }
        }).toList();
      case 1: // هذا الأسبوع
        return _allRides.where((r) {
          final dateStr = r['completed_at'] ?? r['created_at'];
          if (dateStr == null) return false;
          try {
            final date = DateTime.parse(dateStr);
            final weekAgo = now.subtract(const Duration(days: 7));
            return date.isAfter(weekAgo);
          } catch (_) {
            return false;
          }
        }).toList();
      case 2: // الكل
        return _allRides;
      default:
        return _allRides;
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}/${date.month}/${date.year}';
    } catch (_) {
      return '';
    }
  }

  String _formatTime(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('سجل الرحلات',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            )),
        backgroundColor: AppTheme.backgroundColor,
        elevation: 0,
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: AppTheme.textSecondary,
          indicatorColor: AppTheme.primaryColor,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: DesignTokens.textBodyLarge),
          tabs: const [
            Tab(text: 'اليوم'),
            Tab(text: 'هذا الأسبوع'),
            Tab(text: 'الكل'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
          : Column(
              children: [
                _buildStatsHeader(),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildRideList(_getFilteredRides(0)),
                      _buildRideList(_getFilteredRides(1)),
                      _buildRideList(_getFilteredRides(2)),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildStatsHeader() {
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: DesignTokens.space8.w,
        vertical: DesignTokens.space6.h,
      ),
      padding: const EdgeInsets.all(DesignTokens.space8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: DesignTokens.brLg,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildStatItem('عدد الرحلات', '$_totalTrips', Icons.route_rounded, AppTheme.primaryColor),
          Container(width: 1, height: 36, color: Colors.grey.shade200),
          _buildStatItem('إجمالي الأرباح', '${_totalEarnings.toStringAsFixed(0)} ج.م', Icons.account_balance_wallet_rounded, AppTheme.successColor),
          Container(width: 1, height: 36, color: Colors.grey.shade200),
          _buildStatItem('متوسط التقييم', _avgRating.toStringAsFixed(1), Icons.star_rounded, AppTheme.tertiaryColor),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          SizedBox(height: DesignTokens.space2.h),
          Text(value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: DesignTokens.textBodyLarge,
                color: AppTheme.textPrimary,
              )),
          SizedBox(height: DesignTokens.space1.h),
          Text(label,
              style: TextStyle(
                fontSize: DesignTokens.textLabelSmall,
                color: AppTheme.textSecondary,
              )),
        ],
      ),
    );
  }

  Widget _buildRideList(List<Map<String, dynamic>> rides) {
    if (rides.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.directions_car_filled_outlined,
                size: 64, color: AppTheme.textSecondary.withValues(alpha: 0.3)),
            SizedBox(height: DesignTokens.space6.h),
            const Text('لا توجد رحلات في هذا الوقت',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: DesignTokens.textBodyLarge)),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      color: AppTheme.primaryColor,
      child: ListView.builder(
        padding: EdgeInsets.symmetric(
          horizontal: DesignTokens.space8.w,
          vertical: DesignTokens.space4.h,
        ),
        itemCount: rides.length,
        itemBuilder: (context, index) => _buildRideCard(rides[index]),
      ),
    );
  }

  Widget _buildRideCard(Map<String, dynamic> ride) {
    final clientProfile = ride['profiles'];
    final clientName = clientProfile is Map ? (clientProfile['full_name'] ?? 'عميل') : 'عميل';
    final serviceName = ride['services'] is Map ? (ride['services']['name'] ?? 'خدمة') : 'خدمة';
    final pickup = ride['pickup_address'] ?? 'نقطة الانطلاق';
    final destination = ride['destination_address'] ?? 'الوجهة';
    final price = double.tryParse(
            (ride['offered_price'] ?? ride['total_price'])?.toString() ?? '0') ??
        0;
    final rating = double.tryParse(ride['rating']?.toString() ?? '');
    final dateStr = ride['completed_at'] ?? ride['created_at'];

    return Container(
      margin: EdgeInsets.only(bottom: DesignTokens.space4.h),
      padding: const EdgeInsets.all(DesignTokens.space6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: DesignTokens.brLg,
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.person, color: AppTheme.primaryColor, size: 18),
                  ),
                  SizedBox(width: DesignTokens.space4.w),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(clientName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: DesignTokens.textBodyLarge,
                          )),
                      Text(serviceName,
                          style: TextStyle(
                            fontSize: DesignTokens.textBodySmall,
                            color: AppTheme.textSecondary,
                          )),
                    ],
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${price.toStringAsFixed(0)} ج.م',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: DesignTokens.textBodyLarge,
                      color: AppTheme.successColor,
                    ),
                  ),
                  if (rating != null && rating > 0)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star_rounded, color: AppTheme.tertiaryColor, size: 14),
                        SizedBox(width: DesignTokens.space1.w),
                        Text(rating.toStringAsFixed(1),
                            style: TextStyle(
                              fontSize: DesignTokens.textBodySmall,
                              color: AppTheme.tertiaryColor,
                              fontWeight: FontWeight.bold,
                            )),
                      ],
                    ),
                ],
              ),
            ],
          ),
          SizedBox(height: DesignTokens.space4.h),
          // Route
          Container(
            padding: const EdgeInsets.all(DesignTokens.space4),
            decoration: BoxDecoration(
              color: AppTheme.backgroundColor,
              borderRadius: DesignTokens.brMd,
            ),
            child: Row(
              children: [
                Column(
                  children: [
                    Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppTheme.successColor, shape: BoxShape.circle)),
                    Container(width: 1, height: 20, color: AppTheme.textSecondary.withValues(alpha: 0.3)),
                    Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppTheme.errorColor, shape: BoxShape.circle)),
                  ],
                ),
                SizedBox(width: DesignTokens.space4.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(pickup,
                          style: TextStyle(fontSize: DesignTokens.textBodySmall, color: AppTheme.textSecondary),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      SizedBox(height: DesignTokens.space6.h),
                      Text(destination,
                          style: TextStyle(fontSize: DesignTokens.textBodySmall, color: AppTheme.textSecondary),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: DesignTokens.space4.h),
          // Date
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Icon(Icons.access_time_rounded, size: 14, color: AppTheme.textSecondary.withValues(alpha: 0.5)),
              SizedBox(width: DesignTokens.space1.w),
              Text('${_formatDate(dateStr)} ${_formatTime(dateStr)}',
                  style: TextStyle(
                    fontSize: DesignTokens.textLabelSmall,
                    color: AppTheme.textSecondary.withValues(alpha: 0.7),
                  )),
            ],
          ),
        ],
      ),
    );
  }
}
