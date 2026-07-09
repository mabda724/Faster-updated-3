import 'package:flutter/material.dart';
import 'package:flutter/material.dart' show Material, Icons, RefreshIndicator, IconData, TextButton;
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/services/supabase_service.dart';

class ProviderAnalyticsScreen extends StatefulWidget {
  const ProviderAnalyticsScreen({super.key});

  @override
  State<ProviderAnalyticsScreen> createState() =>
      _ProviderAnalyticsScreenState();
}

class _ProviderAnalyticsScreenState extends State<ProviderAnalyticsScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _analytics;
  List<Map<String, dynamic>> _recentBookings = [];

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    final providerId = SupabaseService.currentUserId;
    if (providerId == null) return;

    try {
      final analytics = await SupabaseService.db
          .from('provider_analytics')
          .select('total_bookings, completed_bookings, cancelled_bookings, total_earnings, average_rating')
          .eq('provider_id', providerId)
          .maybeSingle();

      final bookings = await SupabaseService.db
          .from('bookings')
          .select('*')
          .eq('provider_id', providerId)
          .order('created_at', ascending: false)
          .limit(10);

      if (mounted) {
        setState(() {
          _analytics = analytics;
          _recentBookings = List<Map<String, dynamic>>.from(bookings);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading analytics: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(backgroundColor: AppTheme.backgroundColor, body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: EdgeInsets.all(24.w),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _buildOverviewCards(),
                      SizedBox(height: DesignTokens.space24),
                      _buildEarningsChart(),
                      SizedBox(height: DesignTokens.space24),
                      _buildBookingsChart(),
                      SizedBox(height: DesignTokens.space24),
                      _buildRatingSection(),
                      SizedBox(height: DesignTokens.space24),
                      _buildRecentBookings(),
                    ]),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildOverviewCards() {
    final total = _analytics?['total_bookings'] ?? 0;
    final completed = _analytics?['completed_bookings'] ?? 0;
    final cancelled = _analytics?['cancelled_bookings'] ?? 0;
    final earnings = _analytics?['total_earnings'] ?? 0.0;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'إجمالي الحجوزات',
                total.toString(),
                Icons.article_outlined,
                AppTheme.infoColor,
              ),
            ),
            SizedBox(width: DesignTokens.space12),
            Expanded(
              child: _buildStatCard(
                'المكتملة',
                completed.toString(),
                Icons.check_circle_outline_rounded,
                AppTheme.successColor,
              ),
            ),
          ],
        ),
        SizedBox(height: DesignTokens.space12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'الإلغاءات',
                cancelled.toString(),
                Icons.cancel_rounded,
                AppTheme.errorColor,
              ),
            ),
            SizedBox(width: DesignTokens.space12),
            Expanded(
              child: _buildStatCard(
                'أجمالي الأرباح',
                '${earnings.toStringAsFixed(0)} ج',
                Icons.shopping_bag_rounded,
                AppTheme.primaryColor,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: EdgeInsets.all(DesignTokens.space16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade100,
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(8.w),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: DesignTokens.brMd,
            ),
            child: Icon(icon, color: color, size: DesignTokens.iconMd),
          ),
          SizedBox(height: DesignTokens.space12),
          Text(
            value,
            style: TextStyle(
              fontSize: DesignTokens.textDisplayMedium,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          SizedBox(height: DesignTokens.space4),
          Text(title, style: TextStyle(fontSize: DesignTokens.textBodySmall, color: AppTheme.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildEarningsChart() {
    return Container(
      padding: EdgeInsets.all(DesignTokens.space20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(DesignTokens.radiusXl),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade100,
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'الأرباح',
                style: TextStyle(fontSize: DesignTokens.textTitleMedium, fontWeight: FontWeight.bold),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: DesignTokens.space12, vertical: DesignTokens.space4),
                decoration: BoxDecoration(
                  color: AppTheme.successColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(DesignTokens.radiusXl),
                ),
                child: Text(
                  'هذا الشهر',
                  style: TextStyle(fontSize: DesignTokens.textBodySmall, color: AppTheme.successColor),
                ),
              ),
            ],
          ),
          SizedBox(height: DesignTokens.space24),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: 5000,
                barTouchData: BarTouchData(enabled: false),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        const days = [
                          'إثنين',
                          'ثلاثاء',
                          'أربعاء',
                          'خميس',
                          'جمعة',
                          'سبت',
                          'أحد',
                        ];
                        return Text(
                          days[value.toInt() % 7],
                          style: TextStyle(fontSize: DesignTokens.textLabelSmall),
                        );
                      },
                      reservedSize: 30,
                    ),
                  ),
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(show: false),
                gridData: const FlGridData(show: false),
                barGroups: List.generate(7, (index) {
                  return BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                        toY: 0,
                        color: AppTheme.primaryColor,
                        width: DesignTokens.space20,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(DesignTokens.radiusSm),
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingsChart() {
    final completed = _analytics?['completed_bookings'] ?? 0;
    final pending = (_analytics?['total_bookings'] ?? 0) - completed;

    return Container(
      padding: EdgeInsets.all(DesignTokens.space20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(DesignTokens.radiusXl),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade100,
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'توزيع الحجوزات',
            style: TextStyle(fontSize: DesignTokens.textTitleMedium, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: DesignTokens.space24),
          SizedBox(
            height: 180,
            child: Row(
              children: [
                Expanded(
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 40,
                      sections: [
                        PieChartSectionData(
                          color: AppTheme.successColor,
                          value: completed.toDouble(),
                          title: '$completed',
                          titleStyle: const TextStyle(
                            fontSize: DesignTokens.textBodyMedium,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                          radius: 50,
                        ),
                        PieChartSectionData(
                          color: AppTheme.warningColor,
                          value: pending.toDouble(),
                          title: '$pending',
                          titleStyle: const TextStyle(
                            fontSize: DesignTokens.textBodyMedium,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                          radius: 50,
                        ),
                      ],
                    ),
                  ),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLegendItem('مكتمل', AppTheme.successColor, completed),
                    SizedBox(height: DesignTokens.space12),
                    _buildLegendItem('معلق', AppTheme.warningColor, pending),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

Widget _buildLegendItem(String label, Color color, int value) {
  return Row(
    children: [
      Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: color,
          borderRadius: DesignTokens.brXs,
        ),
      ),
      SizedBox(width: DesignTokens.space8),
      Text(
        '$label: $value',
        style: TextStyle(fontSize: DesignTokens.textBodySmall, color: AppTheme.textSecondary),
      ),
    ],
  );
}

   Widget _buildRatingSection() {
     final rating = _analytics?['average_rating'] ?? 0.0;

     return Container(
       padding: EdgeInsets.all(DesignTokens.space20),
       decoration: BoxDecoration(
         color: Colors.white,
         borderRadius: BorderRadius.circular(DesignTokens.radiusXl),
         boxShadow: [
           BoxShadow(
             color: Colors.grey.shade100,
             blurRadius: 10,
           ),
         ],
       ),
       child: Column(
         crossAxisAlignment: CrossAxisAlignment.start,
         children: [
           Row(
             children: [
               const Text(
                 'تقييمك',
                 style: TextStyle(fontSize: DesignTokens.textTitleMedium, fontWeight: FontWeight.bold),
               ),
               const Spacer(),
               TextButton(onPressed: () {}, child: const Text('عرض الكل')),
             ],
           ),
           SizedBox(height: DesignTokens.space16),
           Row(
             children: [
               Container(
                 padding: EdgeInsets.all(DesignTokens.space20),
                 decoration: BoxDecoration(
                   color: AppTheme.warningColor.withValues(alpha: 0.1),
                   borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
                 ),
                 child: Column(
                   children: [
                     Text(
                       rating.toStringAsFixed(1),
                       style: TextStyle(
                         fontSize: DesignTokens.textDisplayMedium + 12,
                         fontWeight: FontWeight.bold,
                         color: AppTheme.warningColor,
                       ),
                     ),
                     Row(
                       children: List.generate(5, (index) {
                         return Icon(
                           index < rating.round()
                               ? Icons.star_rounded
                               : Icons.star_rounded,
                           color: AppTheme.tertiaryColor,
                           size: DesignTokens.iconMd,
                         );
                       }),
                     ),
                   ],
                 ),
               ),
               SizedBox(width: DesignTokens.space16),
               Expanded(
                 child: Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     Text(
                       rating >= 4.5
                           ? 'ممتاز!'
                           : rating >= 4.0
                           ? 'جيد جداً'
                           : rating >= 3.0
                           ? 'جيد'
                           : 'يحتاج تحسين',
                       style: const TextStyle(
                         fontSize: DesignTokens.textBodyLarge,
                         fontWeight: FontWeight.bold,
                       ),
                     ),
                     SizedBox(height: DesignTokens.space4),
                     Text(
                       'بناءً على تقييمات العملاء',
                       style: TextStyle(fontSize: DesignTokens.textBodySmall, color: AppTheme.textSecondary),
                     ),
                   ],
                 ),
               ),
             ],
           ),
        ],
      ),
    );
  }
    
  Widget _buildRecentBookings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'أحدث الحجوزات',
              style: TextStyle(fontSize: DesignTokens.textTitleMedium, fontWeight: FontWeight.bold),
            ),
            TextButton(onPressed: () {}, child: const Text('عرض الكل')),
          ],
        ),
        SizedBox(height: DesignTokens.space12),
        if (_recentBookings.isEmpty)
          Center(
            child: Column(
              children: [
                SizedBox(height: DesignTokens.space24),
                Icon(
                  Icons.article_outlined,
                  size: DesignTokens.iconAvatar,
                  color: AppTheme.textTertiary,
                ),
                SizedBox(height: DesignTokens.space8),
                const Text(
                  'لا توجد حجوزات',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
              ],
            ),
          )
        else
          ..._recentBookings
              .take(5)
              .map((booking) => _buildBookingItem(booking)),
      ],
    );
  }

  Widget _buildBookingItem(Map<String, dynamic> booking) {
    final status = booking['status'] ?? '';
    final statusColor = _getStatusColor(status);
    final price = booking['total_price'] ?? 0;
    final date = booking['created_at'] != null
        ? _formatDate(booking['created_at'])
        : '';

    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
        padding: EdgeInsets.all(DesignTokens.space12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
        border: Border.all(color: AppTheme.textSecondary.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(10.w),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
            ),
            child: Icon(_getStatusIcon(status), color: statusColor, size: DesignTokens.iconMd),
          ),
          SizedBox(width: DesignTokens.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${price.toStringAsFixed(0)} جنيه',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  date,
                  style: TextStyle(fontSize: DesignTokens.textLabelSmall, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: DesignTokens.space4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(DesignTokens.radiusXl),
            ),
            child: Text(
              _getStatusText(status),
              style: TextStyle(
                fontSize: DesignTokens.textLabelSmall,
                color: statusColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return AppTheme.warningColor;
      case 'accepted':
        return AppTheme.infoColor;
      case 'completed':
        return AppTheme.successColor;
      case 'cancelled':
        return AppTheme.errorColor;
      default:
        return AppTheme.textSecondary;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'pending':
return Icons.schedule_rounded;
      case 'completed':
        return Icons.check_circle_rounded;
      case 'accepted':
        return Icons.verified_rounded;
      case 'cancelled':
        return Icons.cancel_rounded;
      default:
        return Icons.article_outlined;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending':
        return 'بانتظار';
      case 'accepted':
        return 'تم القبول';
      case 'completed':
        return 'مكتمل';
      case 'cancelled':
        return 'ملغي';
      default:
        return status;
    }
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return '';
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (_) {
      return dateString;
    }
  }
}
