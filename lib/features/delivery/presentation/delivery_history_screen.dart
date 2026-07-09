import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/services/supabase_service.dart';

class DeliveryHistoryScreen extends StatefulWidget {
  const DeliveryHistoryScreen({super.key});
  @override
  State<DeliveryHistoryScreen> createState() => _DeliveryHistoryScreenState();
}

class _DeliveryHistoryScreenState extends State<DeliveryHistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _allDeliveries = [];
  bool _isLoading = true;

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
    setState(() => _isLoading = true);
    final uid = SupabaseService.currentUserId;
    if (uid == null) return;
    try {
      final res = await SupabaseService.db
          .from('bookings')
          .select('*, services(name_ar), profiles!bookings_client_id_fkey(full_name)')
          .eq('provider_id', uid)
          .eq('status', 'completed')
          .order('created_at', ascending: false);
      _allDeliveries = List<Map<String, dynamic>>.from(res);
    } catch (e) {
      debugPrint('Error loading history: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  List<Map<String, dynamic>> get _filteredDeliveries {
    final now = DateTime.now();
    switch (_tabController.index) {
      case 0: // اليوم
        final todayStart = DateTime(now.year, now.month, now.day);
        return _allDeliveries.where((d) {
          final date = DateTime.tryParse(d['created_at'] ?? '');
          return date != null && date.isAfter(todayStart);
        }).toList();
      case 1: // هذا الأسبوع
        final weekStart = now.subtract(Duration(days: now.weekday - 1));
        final weekStartDate = DateTime(weekStart.year, weekStart.month, weekStart.day);
        return _allDeliveries.where((d) {
          final date = DateTime.tryParse(d['created_at'] ?? '');
          return date != null && date.isAfter(weekStartDate);
        }).toList();
      default: // الكل
        return _allDeliveries;
    }
  }

  double get _totalEarnings => _filteredDeliveries.fold(
      0, (sum, d) => sum + (double.tryParse(d['total_price']?.toString() ?? '0') ?? 0));

  int get _totalCount => _filteredDeliveries.length;

  double get _avgRating {
    final rated = _filteredDeliveries.where((d) => d['client_rating'] != null).toList();
    if (rated.isEmpty) return 0;
    final total = rated.fold<double>(0, (sum, d) => sum + (d['client_rating'] as num? ?? 0).toDouble());
    return total / rated.length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('سجل التوصيلات'),
        centerTitle: true,
        backgroundColor: AppTheme.backgroundColor,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          onTap: (_) => setState(() {}),
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: AppTheme.textSecondary,
          indicatorColor: AppTheme.primaryColor,
          indicatorWeight: 3,
          labelStyle: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: DesignTokens.textBodyMedium,
          ),
          unselectedLabelStyle: TextStyle(
            fontWeight: FontWeight.normal,
            fontSize: DesignTokens.textBodyMedium,
          ),
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
                _buildStatsBar(),
                Expanded(
                  child: _filteredDeliveries.isEmpty
                      ? _buildEmptyState()
                      : RefreshIndicator(
                          onRefresh: _load,
                          color: AppTheme.primaryColor,
                          child: ListView.separated(
                            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
                            itemCount: _filteredDeliveries.length,
                            separatorBuilder: (_, __) => SizedBox(height: 10.h),
                            itemBuilder: (context, index) =>
                                _buildDeliveryCard(_filteredDeliveries[index]),
                          ),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildStatsBar() {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.fromLTRB(20.w, 0, 20.w, 8.h),
      padding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: DesignTokens.brLg,
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: DesignTokens.shadow1(Colors.black),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildMiniStat('$_totalCount', 'التوصيلات'),
          _buildDivider(),
          _buildMiniStat('${_totalEarnings.toStringAsFixed(0)} ج.م', 'الأرباح'),
          _buildDivider(),
          _buildMiniStat('${_avgRating.toStringAsFixed(1)} ⭐', 'التقييم'),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: DesignTokens.textTitleMedium,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        SizedBox(height: 2.h),
        Text(
          label,
          style: TextStyle(
            fontSize: DesignTokens.textLabelSmall,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 30.h,
      color: Colors.grey.shade200,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.local_shipping_outlined, size: 80.sp, color: AppTheme.textTertiary),
          SizedBox(height: DesignTokens.space16),
          Text(
            'لا توجد توصيلات',
            style: TextStyle(fontSize: DesignTokens.textTitleMedium, color: AppTheme.textSecondary),
          ),
          SizedBox(height: DesignTokens.space4),
          Text(
            'ستظهر توصيلاتك المكتملة هنا',
            style: TextStyle(fontSize: DesignTokens.textBodySmall, color: AppTheme.textTertiary),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryCard(Map<String, dynamic> delivery) {
    final client = delivery['profiles'] as Map<String, dynamic>?;
    final service = delivery['services'] as Map<String, dynamic>?;
    final address = delivery['address'] as String? ?? '';
    final destinationAddress = delivery['destination_address'] as String? ?? '';
    final price = double.tryParse(delivery['total_price']?.toString() ?? '0') ?? 0;
    final rating = (delivery['client_rating'] as num?)?.toDouble();
    final dateStr = delivery['created_at'] as String?;
    String dateText = '';
    if (dateStr != null) {
      final date = DateTime.tryParse(dateStr);
      if (date != null) {
        dateText = '${date.day}/${date.month}/${date.year}';
      }
    }

    return Container(
      padding: EdgeInsets.all(DesignTokens.space12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: DesignTokens.brLg,
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: DesignTokens.shadow1(Colors.black),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  client?['full_name'] ?? 'عميل',
                  style: TextStyle(
                    fontSize: DesignTokens.textBodyLarge,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (rating != null)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                  decoration: BoxDecoration(
                    color: AppTheme.tertiaryColor.withValues(alpha: 0.1),
                    borderRadius: DesignTokens.brFull,
                  ),
                  child: Text(
                    '${rating.toStringAsFixed(1)} ⭐',
                    style: TextStyle(
                      fontSize: DesignTokens.textLabelSmall,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.tertiaryColor,
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: 8.h),
          // Route: pickup -> destination
          Row(
            children: [
              Icon(Icons.circle, size: 8, color: AppTheme.tertiaryColor),
              SizedBox(width: 6.w),
              Expanded(
                child: Text(
                  address.isNotEmpty ? address : 'نقطة الاستلام',
                  style: TextStyle(
                    fontSize: DesignTokens.textBodySmall,
                    color: AppTheme.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          Padding(
            padding: EdgeInsets.only(left: 20.w),
            child: Container(width: 1, height: 12.h, color: Colors.grey.shade300),
          ),
          Row(
            children: [
              Icon(Icons.location_on, size: 8, color: AppTheme.successColor),
              SizedBox(width: 6.w),
              Expanded(
                child: Text(
                  destinationAddress.isNotEmpty ? destinationAddress : 'الوجهة',
                  style: TextStyle(
                    fontSize: DesignTokens.textBodySmall,
                    color: AppTheme.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                dateText,
                style: TextStyle(
                  fontSize: DesignTokens.textLabelSmall,
                  color: AppTheme.textTertiary,
                ),
              ),
              Text(
                '${price.toStringAsFixed(0)} ج.م',
                style: TextStyle(
                  fontSize: DesignTokens.textBodyLarge,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.successColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
