import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/services/supabase_service.dart';
import 'admin_carousel_screen.dart';
import 'admin_categories_screen.dart';
import 'admin_offers_screen.dart';
import 'admin_orders_screen.dart';
import 'admin_providers_screen.dart';
import 'admin_withdrawals_screen.dart';
import 'admin_services_screen.dart';
import 'admin_reports_screen.dart';
import 'admin_settlements_screen.dart';
import 'admin_dashboard_controller.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});
  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> with TickerProviderStateMixin {
  int _totalUsers = 0, _totalProviders = 0, _totalBookings = 0, _totalCompleted = 0, _pendingWithdrawals = 0;
  double _totalRevenue = 0;
  double _totalSales = 0;
  double _withdrawalPendingAmount = 0;
  int _onlineProvidersCount = 0;
  int _paymentCashCount = 0;
  int _paymentOnlineCount = 0;
  bool _isLoading = true;

  double _expectedCommission = 0;
  double _receivedCommission = 0;
  double _pendingCommission = 0;
  double _totalCompletedServicesValue = 0;
  int _totalCompletedServicesCount = 0;

  List<Map<String, dynamic>> _providerStats = [];
  List<Map<String, dynamic>> _clientStats = [];
  List<Map<String, dynamic>> _categoryStats = [];
  List<double> _weeklyTrend = [];

  late AdminDashboardController _controller;
  late AnimationController _staggerController;
  late Animation<double> _fadeIn;
  late Animation<Offset> _slideUp;

  @override
  void initState() {
    super.initState();
    _controller = AdminDashboardController();
    _controller.loadStats();
  }

  @override
  void dispose() {
    _controller.dispose();
    _staggerController.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    try {
      final db = SupabaseService.db;
      final users = await db.from('profiles').select('id').eq('role', 'client');
      final providers = await db.from('profiles').select('id').eq('role', 'provider');

      final onlineProvidersRes = await db.from('provider_profiles').select('id').eq('is_online', true);
      _onlineProvidersCount = onlineProvidersRes.length;

      final allBookings = await db.from('bookings').select('id, client_id, status, payment_method, total_price, commission_amount, service_id, created_at, provider_id, offered_price');
      final completed = allBookings.where((b) => b['status'] == 'completed').toList();

      final withdrawals = await db.from('withdrawal_requests').select('amount').eq('status', 'pending');
      double pendingWithdrawAmt = 0;
      for (var w in withdrawals) { pendingWithdrawAmt += double.tryParse(w['amount']?.toString() ?? '0') ?? 0; }
      _withdrawalPendingAmount = pendingWithdrawAmt;

      double rev = 0, sales = 0, totalComm = 0, totalServicesValue = 0;
      for (var b in completed) {
        final price = double.tryParse((b['offered_price'] ?? b['total_price'])?.toString() ?? '0') ?? 0;
        final comm = double.tryParse(b['commission_amount']?.toString() ?? '0') ?? 0;
        rev += comm; sales += price; totalComm += comm; totalServicesValue += price;
      }
      _totalRevenue = rev; _totalSales = sales; _expectedCommission = totalComm;
      _totalCompletedServicesValue = totalServicesValue; _totalCompletedServicesCount = completed.length;

      try {
        final settlements = await db.from('commission_settlements').select('amount, status');
        double received = 0, pending = 0;
        for (var s in settlements) {
          final amount = double.tryParse(s['amount']?.toString() ?? '0') ?? 0;
          final status = s['status']?.toString();
          if (status == 'verified') received += amount;
          else if (status == 'pending') pending += amount;
        }
        _receivedCommission = received; _pendingCommission = pending;
      } catch (e) { debugPrint('Error loading settlements: $e'); }

      final providerProfiles = await db.from('profiles').select('id, full_name').eq('role', 'provider');
      final clientProfiles = await db.from('profiles').select('id, full_name').eq('role', 'client');
      final providerMap = {for (var p in providerProfiles) p['id'] as String: p['full_name'] as String? ?? 'بدون اسم'};
      final clientMap = {for (var c in clientProfiles) c['id'] as String: c['full_name'] as String? ?? 'بدون اسم'};

      final providerEarnings = <String, double>{};
      final providerComm = <String, double>{};
      final providerCompleted = <String, int>{};
      for (var b in completed) {
        final pid = b['provider_id'] as String?;
        if (pid == null) continue;
        final price = double.tryParse(b['total_price']?.toString() ?? '0') ?? 0;
        final comm = double.tryParse(b['commission_amount']?.toString() ?? '0') ?? 0;
        providerEarnings[pid] = (providerEarnings[pid] ?? 0) + (price - comm);
        providerComm[pid] = (providerComm[pid] ?? 0) + comm;
        providerCompleted[pid] = (providerCompleted[pid] ?? 0) + 1;
      }

      final providerCancelled = <String, int>{};
      final providerPending = <String, int>{};
      for (var b in allBookings) {
        final pid = b['provider_id'] as String?;
        if (pid == null) continue;
        final st = b['status'] as String?;
        if (st == 'cancelled' || st == 'rejected') providerCancelled[pid] = (providerCancelled[pid] ?? 0) + 1;
        else if (st == 'pending' || st == 'accepted' || st == 'tracking') providerPending[pid] = (providerPending[pid] ?? 0) + 1;
      }

      final allProviderIds = <String>{};
      for (var p in providers) allProviderIds.add(p['id'] as String);
      for (var b in allBookings) { final pid = b['provider_id'] as String?; if (pid != null) allProviderIds.add(pid); }

      _providerStats = allProviderIds.map((pid) => {
        'id': pid, 'name': providerMap[pid] ?? 'بدون اسم', 'earnings': providerEarnings[pid] ?? 0,
        'commissions': providerComm[pid] ?? 0, 'completed': providerCompleted[pid] ?? 0,
        'cancelled': providerCancelled[pid] ?? 0, 'pending': providerPending[pid] ?? 0,
      }).toList()..sort((a, b) => ((b['completed'] as int) + (b['pending'] as int)).compareTo((a['completed'] as int) + (a['pending'] as int)));

      final clientAgg = <String, int>{};
      for (var b in allBookings) { final cid = b['client_id'] as String?; if (cid != null) clientAgg[cid] = (clientAgg[cid] ?? 0) + 1; }
      _clientStats = clientAgg.keys.map((cid) => {'id': cid, 'name': clientMap[cid] ?? 'بدون اسم', 'total': clientAgg[cid] ?? 0}).toList()..sort((a, b) => (b['total'] as int).compareTo(a['total'] as int));

      final servicesList = await db.from('services').select('id, category_id');
      final categoriesList = await db.from('categories').select('id, name');
      final serviceToCategory = {for (var s in servicesList) s['id']: s['category_id']};
      final categoryNames = {for (var c in categoriesList) c['id']: c['name'] as String? ?? 'قسم غير معروف'};
      final categoryCounts = <dynamic, int>{};
      for (var b in allBookings) {
        final sid = b['service_id'];
        if (sid == null) continue;
        final catId = serviceToCategory[sid];
        if (catId != null) categoryCounts[catId] = (categoryCounts[catId] ?? 0) + 1;
      }
      _categoryStats = categoryCounts.entries.map((e) => {'id': e.key, 'name': categoryNames[e.key] ?? 'قسم غير معروف', 'count': e.value}).toList()..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));

      int cash = 0, online = 0;
      for (var b in allBookings) {
        final pm = b['payment_method']?.toString().toLowerCase() ?? 'cash';
        if (pm == 'cash') cash++; else online++;
      }
      _paymentCashCount = cash; _paymentOnlineCount = online;

      final now = DateTime.now();
      final dailyCounts = List<int>.filled(7, 0);
      for (var b in allBookings) {
        final dateStr = b['created_at'];
        if (dateStr == null) continue;
        try { final date = DateTime.parse(dateStr); final diffDays = now.difference(date).inDays; if (diffDays >= 0 && diffDays < 7) dailyCounts[6 - diffDays]++; } catch (_) {}
      }
      _weeklyTrend = dailyCounts.map((e) => e.toDouble()).toList();

      if (mounted) {
        setState(() {
          _totalUsers = users.length; _totalProviders = providers.length; _totalBookings = allBookings.length;
          _totalCompleted = completed.length; _totalRevenue = rev; _totalSales = sales; _pendingWithdrawals = withdrawals.length;
          _isLoading = false;
        });
        _staggerController.forward();
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppTheme.primaryColor),
              )
            : RefreshIndicator(
                onRefresh: () async { _staggerController.reset(); await _loadStats(); },
                color: AppTheme.primaryColor,
                child: FadeTransition(
                  opacity: _fadeIn,
                  child: SlideTransition(
                    position: _slideUp,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.symmetric(horizontal: DesignTokens.space16, vertical: DesignTokens.space12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHeader(),
                          SizedBox(height: DesignTokens.space16),
                          _buildSmartInsights(),
                          SizedBox(height: DesignTokens.space16),
                          _buildStatsGrid(),
                          SizedBox(height: DesignTokens.space16),
                          _buildFinancialStats(),
                          SizedBox(height: DesignTokens.space16),
                          if (_pendingWithdrawals > 0) _buildAlert(),
                          if (_pendingWithdrawals > 0) SizedBox(height: DesignTokens.space16),
                          _buildQuickActions(),
                          SizedBox(height: DesignTokens.space16),
                          _buildProfessionalCharts(),
                          SizedBox(height: DesignTokens.space16),
                          _buildProviderBreakdown(),
                          SizedBox(height: DesignTokens.space16),
                          _buildClientBreakdown(),
                          SizedBox(height: DesignTokens.space32),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.all(DesignTokens.space16),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: DesignTokens.brXl,
        boxShadow: [
          BoxShadow(color: AppTheme.primaryColor.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8)),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('لوحة التحكم', style: TextStyle(fontSize: DesignTokens.textDisplayMedium, fontWeight: FontWeight.bold, color: AppTheme.surfaceColor)),
                SizedBox(height: DesignTokens.space4),
                Text('مرحباً بك في نظام الإدارة', style: TextStyle(fontSize: DesignTokens.textBodyMedium, color: AppTheme.surfaceColor.withValues(alpha: 0.7))),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.all(DesignTokens.space12),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor.withValues(alpha: 0.15),
              borderRadius: DesignTokens.brLg,
            ),
            child: const Icon(Icons.admin_panel_settings_rounded, color: AppTheme.surfaceColor, size: DesignTokens.iconLg),
          ),
        ],
      ),
    );
  }

  Widget _buildSmartInsights() {
    String topCategory = _categoryStats.isNotEmpty ? _categoryStats.first['name'] : 'الخدمات العامة';
    double cancelRate = _totalBookings > 0 ? ((_totalBookings - _totalCompleted) / _totalBookings * 100) : 0;
    double aov = _totalCompleted > 0 ? _totalSales / _totalCompleted : 0;
    double conversionRate = _totalBookings > 0 ? (_totalCompleted / _totalBookings * 100) : 0;

    return Container(
      padding: EdgeInsets.all(DesignTokens.space16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: DesignTokens.brXl,
        border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.06)),
        boxShadow: [BoxShadow(color: AppTheme.primaryColor.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(DesignTokens.space8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                  ),
                  borderRadius: DesignTokens.brMd,
                ),
                child: const Icon(Icons.analytics_rounded, color: AppTheme.surfaceColor, size: DesignTokens.iconSm),
              ),
              SizedBox(width: DesignTokens.space8),
              Text('تحليلات وحالة الأعمال', style: TextStyle(fontWeight: FontWeight.bold, fontSize: DesignTokens.textBodyMedium, color: AppTheme.textPrimary)),
            ],
          ),
          SizedBox(height: DesignTokens.space12),
          Row(children: [
            Expanded(child: _insightItem('القسم الأكثر طلباً', topCategory, Icons.star_rounded, AppTheme.tertiaryColor)),
            Container(width: 1, height: DesignTokens.space16, color: AppTheme.textSecondary.withValues(alpha: 0.08)),
            Expanded(child: _insightItem('متوسط قيمة الطلب', '${aov.toStringAsFixed(0)} ج.م', Icons.shopping_bag_rounded, AppTheme.successColor)),
          ]),
          SizedBox(height: DesignTokens.space8),
          Divider(height: 1, color: AppTheme.textSecondary.withValues(alpha: 0.08)),
          SizedBox(height: DesignTokens.space8),
          Row(children: [
            Expanded(child: _insightItem('معدل إكمال العمليات', '${conversionRate.toStringAsFixed(0)}%', Icons.check_circle_rounded, AppTheme.primaryColor)),
            Container(width: 1, height: DesignTokens.space16, color: AppTheme.textSecondary.withValues(alpha: 0.08)),
            Expanded(child: _insightItem('معدل الإلغاء', '${cancelRate.toStringAsFixed(0)}%', Icons.cancel_rounded, AppTheme.errorColor)),
          ]),
        ],
      ),
    );
  }

  Widget _insightItem(String label, String value, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(DesignTokens.space4),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: DesignTokens.brSm),
          child: Icon(icon, color: color, size: DesignTokens.iconXs),
        ),
        SizedBox(width: DesignTokens.space8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(fontSize: DesignTokens.textLabelSmall, color: AppTheme.textSecondary)),
            Text(value, style: TextStyle(fontSize: DesignTokens.textBodySmall, fontWeight: FontWeight.bold, color: AppTheme.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
          ]),
        ),
      ],
    );
  }

  Widget _buildStatsGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: DesignTokens.space8,
      mainAxisSpacing: DesignTokens.space8,
      childAspectRatio: 1.5,
      children: [
        _statCard('العملاء', '$_totalUsers', Icons.people_rounded, AppTheme.secondaryColor),
        _statCard('مقدمي الخدمة', '$_totalProviders', Icons.engineering_rounded, AppTheme.tertiaryColor, subtitle: '$_onlineProvidersCount متصل'),
        _statCard('الحجوزات المكتملة', '$_totalCompleted من $_totalBookings', Icons.receipt_long_rounded, AppTheme.successColor),
        _statCard('إجمالي العمولات', '${_totalRevenue.toStringAsFixed(0)} ج', Icons.monetization_on_rounded, AppTheme.primaryColor),
        _statCard('حجم مبيعات العمليات', '${_totalSales.toStringAsFixed(0)} ج', Icons.shopping_cart_rounded, AppTheme.primaryColor),
        _statCard('سحوبات معلقة', '${_withdrawalPendingAmount.toStringAsFixed(0)} ج', Icons.payment_rounded, AppTheme.errorColor),
      ],
    );
  }

  Widget _statCard(String title, String value, IconData icon, Color color, {String? subtitle}) {
    return Container(
      padding: EdgeInsets.all(DesignTokens.space12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: DesignTokens.brLg,
        border: Border.all(color: color.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: EdgeInsets.all(DesignTokens.space8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [color.withValues(alpha: 0.15), color.withValues(alpha: 0.05)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: DesignTokens.brMd,
                ),
                child: Icon(icon, color: color, size: DesignTokens.iconSm),
              ),
              if (subtitle != null)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: DesignTokens.space6, vertical: DesignTokens.space2),
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: DesignTokens.brXl),
                  child: Text(subtitle, style: TextStyle(fontSize: DesignTokens.textLabelSmall, fontWeight: FontWeight.bold, color: color)),
                ),
            ],
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value, style: TextStyle(fontSize: DesignTokens.textTitleMedium, fontWeight: FontWeight.bold, color: color)),
            Text(title, style: TextStyle(fontSize: DesignTokens.textLabelSmall, color: AppTheme.textSecondary)),
          ]),
        ],
      ),
    );
  }

  Widget _buildFinancialStats() {
    final collectionRate = _expectedCommission > 0 ? (_receivedCommission / _expectedCommission) * 100 : 0.0;

    return Container(
      padding: EdgeInsets.all(DesignTokens.space16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: DesignTokens.brXl,
        border: Border.all(color: AppTheme.successColor.withValues(alpha: 0.08)),
        boxShadow: [BoxShadow(color: AppTheme.successColor.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: EdgeInsets.all(DesignTokens.space8),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [AppTheme.successColor, AppTheme.successColor], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: DesignTokens.brMd,
            ),
            child: const Icon(Icons.account_balance_rounded, color: AppTheme.surfaceColor, size: DesignTokens.iconSm),
          ),
          SizedBox(width: DesignTokens.space8),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('الإحصائيات المالية', style: TextStyle(fontWeight: FontWeight.bold, fontSize: DesignTokens.textBodyMedium, color: AppTheme.textPrimary)),
            Text('تقارير العمولات والأرباح', style: TextStyle(fontSize: DesignTokens.textLabelSmall, color: AppTheme.textSecondary)),
          ]),
        ]),
        SizedBox(height: DesignTokens.space12),
        Row(children: [
          Expanded(child: _financialStatCard('الربح المتوقع', '${_expectedCommission.toStringAsFixed(0)} ج.م', 'مجموع العمولات', Icons.trending_up_rounded, AppTheme.primaryColor)),
          SizedBox(width: DesignTokens.space8),
          Expanded(child: _financialStatCard('الربح الفعلي', '${_receivedCommission.toStringAsFixed(0)} ج.م', 'تم استلامها', Icons.check_circle_rounded, AppTheme.successColor)),
        ]),
        SizedBox(height: DesignTokens.space8),
        Row(children: [
          Expanded(child: _financialStatCard('عمولات مستحقة', '${_pendingCommission.toStringAsFixed(0)} ج.م', 'قيد المراجعة', Icons.pending_rounded, AppTheme.tertiaryColor)),
          SizedBox(width: DesignTokens.space8),
          Expanded(child: _financialStatCard('قيمة الخدمات', '${_totalCompletedServicesValue.toStringAsFixed(0)} ج.م', '$_totalCompletedServicesCount خدمة', Icons.receipt_long_rounded, AppTheme.primaryColor)),
        ]),
        SizedBox(height: DesignTokens.space12),
        Container(
          padding: EdgeInsets.all(DesignTokens.space12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppTheme.primaryColor.withValues(alpha: 0.05), AppTheme.secondaryColor.withValues(alpha: 0.03)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            borderRadius: DesignTokens.brLg,
            border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.1)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('نسبة الاستلام', style: TextStyle(fontWeight: FontWeight.bold, fontSize: DesignTokens.textBodySmall, color: AppTheme.textPrimary)),
              Text('المتبقي: ${(_expectedCommission - _receivedCommission).toStringAsFixed(0)} ج.م', style: TextStyle(fontSize: DesignTokens.textLabelSmall, color: AppTheme.textSecondary)),
            ]),
            SizedBox(height: DesignTokens.space8),
            ClipRRect(
              borderRadius: DesignTokens.brXs,
              child: LinearProgressIndicator(
                value: collectionRate / 100,
                backgroundColor: AppTheme.textSecondary.withValues(alpha: 0.1),
                valueColor: AlwaysStoppedAnimation<Color>(collectionRate > 80 ? AppTheme.successColor : AppTheme.tertiaryColor),
                minHeight: DesignTokens.space4,
              ),
            ),
            SizedBox(height: DesignTokens.space4),
            Text('${collectionRate.toStringAsFixed(1)}%', style: TextStyle(fontSize: DesignTokens.textLabelSmall, fontWeight: FontWeight.bold, color: collectionRate > 80 ? AppTheme.successColor : AppTheme.tertiaryColor)),
          ]),
        ),
      ]),
    );
  }

  Widget _financialStatCard(String title, String value, String subtitle, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(DesignTokens.space10),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [color.withValues(alpha: 0.06), color.withValues(alpha: 0.02)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: DesignTokens.brLg,
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, color: color, size: DesignTokens.iconSm),
          SizedBox(width: DesignTokens.space4),
          Expanded(child: Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: DesignTokens.textBodySmall, color: color))),
        ]),
        SizedBox(height: DesignTokens.space6),
        Text(value, style: TextStyle(fontSize: DesignTokens.textTitleMedium, fontWeight: FontWeight.bold, color: color)),
        SizedBox(height: DesignTokens.space2),
        Text(subtitle, style: TextStyle(fontSize: DesignTokens.textLabelSmall, color: AppTheme.textSecondary)),
      ]),
    );
  }

  Widget _buildAlert() {
    return Container(
      padding: EdgeInsets.all(DesignTokens.space12),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [AppTheme.tertiaryColor.withValues(alpha: 0.1), AppTheme.tertiaryColor.withValues(alpha: 0.04)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: DesignTokens.brLg,
        border: Border.all(color: AppTheme.tertiaryColor.withValues(alpha: 0.25)),
      ),
      child: Row(children: [
        Container(
          padding: EdgeInsets.all(DesignTokens.space8),
          decoration: BoxDecoration(color: AppTheme.tertiaryColor.withValues(alpha: 0.15), borderRadius: DesignTokens.brMd),
          child: const Icon(Icons.warning_amber_rounded, color: AppTheme.tertiaryColor, size: DesignTokens.iconSm),
        ),
        SizedBox(width: DesignTokens.space8),
        Expanded(child: Text('$_pendingWithdrawals طلب سحب مستني الموافقة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: DesignTokens.textBodySmall, color: AppTheme.tertiaryColor))),
        GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminWithdrawalsScreen())),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: DesignTokens.space12, vertical: DesignTokens.space6),
            decoration: BoxDecoration(color: AppTheme.tertiaryColor, borderRadius: DesignTokens.brXl),
            child: Text('عرض', style: TextStyle(color: AppTheme.surfaceColor, fontWeight: FontWeight.bold, fontSize: DesignTokens.textLabelSmall)),
          ),
        ),
      ]),
    );
  }

  Widget _buildQuickActions() {
    final actions = [
      {'title': 'الطلبات', 'icon': Icons.receipt_long_rounded, 'color': AppTheme.secondaryColor, 'screen': const AdminOrdersScreen()},
      {'title': 'مقدمي الخدمة', 'icon': Icons.verified_user_rounded, 'color': AppTheme.tertiaryColor, 'screen': const AdminProvidersScreen()},
      {'title': 'الأقسام', 'icon': Icons.category_rounded, 'color': AppTheme.successColor, 'screen': const AdminCategoriesScreen()},
      {'title': 'الخدمات', 'icon': Icons.build_rounded, 'color': AppTheme.primaryColor, 'screen': const AdminServicesScreen()},
      {'title': 'سحب الأرباح', 'icon': Icons.account_balance_wallet_rounded, 'color': AppTheme.errorColor, 'screen': const AdminWithdrawalsScreen()},
      {'title': 'البانر', 'icon': Icons.photo_library_rounded, 'color': Colors.pink, 'screen': const AdminCarouselScreen()},
      {'title': 'العروض', 'icon': Icons.local_offer_rounded, 'color': AppTheme.tertiaryColor, 'screen': const AdminOffersScreen()},
      {'title': 'مراجعة التوريد', 'icon': Icons.fact_check_rounded, 'color': AppTheme.textSecondary, 'screen': const AdminSettlementsScreen()},
      {'title': 'التقارير', 'icon': Icons.bar_chart_rounded, 'color': AppTheme.primaryColor, 'screen': const AdminReportsScreen()},
    ];

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('إدارة التطبيق', style: TextStyle(fontSize: DesignTokens.textBodyMedium, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
      SizedBox(height: DesignTokens.space8),
      GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, crossAxisSpacing: DesignTokens.space8, mainAxisSpacing: DesignTokens.space8, childAspectRatio: 1.8,
        ),
        itemCount: actions.length,
        itemBuilder: (context, index) {
          final action = actions[index];
          return _actionCard(action['title'] as String, action['icon'] as IconData, action['color'] as Color,
            () => Navigator.push(context, MaterialPageRoute(builder: (_) => action['screen'] as Widget)));
        },
      ),
    ]);
  }

  Widget _actionCard(String title, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(DesignTokens.space10),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [AppTheme.surfaceColor, color.withValues(alpha: 0.03)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: DesignTokens.brLg,
          border: Border.all(color: color.withValues(alpha: 0.12)),
          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Row(children: [
          Container(
            padding: EdgeInsets.all(DesignTokens.space8),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [color.withValues(alpha: 0.15), color.withValues(alpha: 0.05)], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: DesignTokens.brMd,
            ),
            child: Icon(icon, color: color, size: DesignTokens.iconSm),
          ),
          SizedBox(width: DesignTokens.space8),
          Expanded(child: Text(title, style: TextStyle(fontWeight: FontWeight.w600, fontSize: DesignTokens.textBodySmall, color: AppTheme.textPrimary))),
          Icon(Icons.arrow_forward_ios_rounded, size: 12, color: color.withValues(alpha: 0.5)),
        ]),
      ),
    );
  }

  int _chartTab = 0;

  Widget _buildProfessionalCharts() {
    return Container(
      padding: EdgeInsets.all(DesignTokens.space16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: DesignTokens.brXl,
        border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.06)),
        boxShadow: [BoxShadow(color: AppTheme.primaryColor.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('الرسوم البيانية', style: TextStyle(fontWeight: FontWeight.bold, fontSize: DesignTokens.textBodyMedium, color: AppTheme.textPrimary)),
          Row(children: [
            _chartTabBtn('النشاط', 0), SizedBox(width: DesignTokens.space4),
            _chartTabBtn('الأقسام', 1), SizedBox(width: DesignTokens.space4),
            _chartTabBtn('الدفع', 2),
          ]),
        ]),
        SizedBox(height: DesignTokens.space16),
        SizedBox(height: 90.h, child: _chartTab == 0 ? _buildWeeklyTrendChart() : _chartTab == 1 ? _buildCategoryPieChart() : _buildPaymentPieChart()),
      ]),
    );
  }

  Widget _chartTabBtn(String title, int index) {
    bool active = _chartTab == index;
    return GestureDetector(
      onTap: () => setState(() => _chartTab = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: DesignTokens.space8, vertical: DesignTokens.space4),
        decoration: BoxDecoration(
          gradient: active ? LinearGradient(colors: [AppTheme.primaryColor, AppTheme.secondaryColor], begin: Alignment.topLeft, end: Alignment.bottomRight) : null,
          color: active ? null : AppTheme.backgroundColor,
          borderRadius: DesignTokens.brXl,
          border: active ? null : Border.all(color: AppTheme.textSecondary.withValues(alpha: 0.1)),
        ),
        child: Text(title, style: TextStyle(fontSize: DesignTokens.textLabelSmall, fontWeight: FontWeight.bold, color: active ? AppTheme.surfaceColor : AppTheme.textSecondary)),
      ),
    );
  }

  Widget _buildWeeklyTrendChart() {
    if (_weeklyTrend.isEmpty || _weeklyTrend.every((e) => e == 0)) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.timeline_rounded, size: DesignTokens.iconLg, color: AppTheme.textSecondary.withValues(alpha: 0.3)),
        SizedBox(height: DesignTokens.space8),
        Text('لا توجد بيانات حركة للأسبوع الحالي', style: TextStyle(fontSize: DesignTokens.textBodySmall, color: AppTheme.textSecondary)),
      ]));
    }
    final maxVal = _weeklyTrend.reduce((max, e) => e > max ? e : max);
    final spots = List.generate(_weeklyTrend.length, (i) => FlSpot(i.toDouble(), _weeklyTrend[i]));
    return LineChart(LineChartData(
      gridData: FlGridData(show: false),
      titlesData: FlTitlesData(
        show: true,
        bottomTitles: AxisTitles(sideTitles: SideTitles(
          showTitles: true,
          getTitlesWidget: (val, meta) {
            final days = ['الأحد', 'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت'];
            final dayIdx = (DateTime.now().weekday - (6 - val.toInt())) % 7;
            final normalizedIdx = dayIdx < 0 ? dayIdx + 7 : dayIdx;
            return Padding(padding: const EdgeInsets.only(top: DesignTokens.space2), child: Text(days[normalizedIdx].substring(0, 3), style: const TextStyle(fontSize: DesignTokens.textLabelSmall, color: AppTheme.textSecondary)));
          }, interval: 1,
        )),
        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      borderData: FlBorderData(show: false),
      minX: 0, maxX: 6, minY: 0, maxY: (maxVal == 0 ? 10 : maxVal * 1.3),
      lineBarsData: [LineChartBarData(
        spots: spots, isCurved: true,
        gradient: LinearGradient(colors: [AppTheme.primaryColor, AppTheme.secondaryColor, AppTheme.accentColor]),
        barWidth: 3, isStrokeCapRound: true,
        dotData: const FlDotData(show: true),
        belowBarData: BarAreaData(show: true, gradient: LinearGradient(
          colors: [AppTheme.primaryColor.withValues(alpha: 0.2), AppTheme.primaryColor.withValues(alpha: 0.0)],
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
        )),
      )],
    ));
  }

  Widget _buildCategoryPieChart() {
    if (_categoryStats.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.pie_chart_rounded, size: DesignTokens.iconLg, color: AppTheme.textSecondary.withValues(alpha: 0.3)),
        SizedBox(height: DesignTokens.space8),
        Text('لا توجد بيانات أقسام', style: TextStyle(fontSize: DesignTokens.textBodySmall, color: AppTheme.textSecondary)),
      ]));
    }
    final colors = [AppTheme.primaryColor, AppTheme.tertiaryColor, AppTheme.successColor, AppTheme.secondaryColor, Colors.pink];
    final total = _categoryStats.fold(0, (sum, e) => sum + (e['count'] as int));
    return Row(children: [
      Expanded(flex: 4, child: PieChart(PieChartData(
        sectionsSpace: 2, centerSpaceRadius: 35,
        sections: List.generate(_categoryStats.take(5).length, (i) {
          final c = _categoryStats[i]; final count = c['count'] as int; final pct = total > 0 ? (count / total * 100) : 0;
          return PieChartSectionData(color: colors[i], value: count.toDouble(), title: '${pct.toStringAsFixed(0)}%', radius: 40,
            titleStyle: const TextStyle(fontSize: DesignTokens.textLabelSmall, fontWeight: FontWeight.bold, color: AppTheme.surfaceColor));
        }),
      ))),
      SizedBox(width: DesignTokens.space12),
      Expanded(flex: 5, child: Column(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(_categoryStats.take(5).length, (i) {
        final c = _categoryStats[i];
        return Padding(padding: EdgeInsets.symmetric(vertical: DesignTokens.space2), child: Row(children: [
          Container(width: DesignTokens.space4, height: DesignTokens.space4, decoration: BoxDecoration(color: colors[i], shape: BoxShape.circle)),
          SizedBox(width: DesignTokens.space6),
          Expanded(child: Text('${c['name']}: ${c['count']}', style: const TextStyle(fontSize: DesignTokens.textLabelSmall, color: AppTheme.textPrimary, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis)),
        ]));
      }))),
    ]);
  }

  Widget _buildPaymentPieChart() {
    int total = _paymentCashCount + _paymentOnlineCount;
    if (total == 0) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.payments_rounded, size: DesignTokens.iconLg, color: AppTheme.textSecondary.withValues(alpha: 0.3)),
        SizedBox(height: DesignTokens.space8),
        Text('لا توجد معاملات دفع', style: TextStyle(fontSize: DesignTokens.textBodySmall, color: AppTheme.textSecondary)),
      ]));
    }
    double cashPct = total > 0 ? (_paymentCashCount / total * 100) : 0;
    double onlinePct = total > 0 ? (_paymentOnlineCount / total * 100) : 0;
    return Row(children: [
      Expanded(flex: 4, child: PieChart(PieChartData(
        sectionsSpace: 2, centerSpaceRadius: 35,
        sections: [
          PieChartSectionData(color: AppTheme.successColor, value: _paymentCashCount.toDouble(), title: '${cashPct.toStringAsFixed(0)}%', radius: 40,
            titleStyle: const TextStyle(fontSize: DesignTokens.textLabelSmall, fontWeight: FontWeight.bold, color: AppTheme.surfaceColor)),
          PieChartSectionData(color: AppTheme.primaryColor, value: _paymentOnlineCount.toDouble(), title: '${onlinePct.toStringAsFixed(0)}%', radius: 40,
            titleStyle: const TextStyle(fontSize: DesignTokens.textLabelSmall, fontWeight: FontWeight.bold, color: AppTheme.surfaceColor)),
        ],
      ))),
      SizedBox(width: DesignTokens.space12),
      Expanded(flex: 5, child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Row(children: [Container(width: DesignTokens.space4, height: DesignTokens.space4, decoration: BoxDecoration(color: AppTheme.successColor, shape: BoxShape.circle)), SizedBox(width: DesignTokens.space6),
          Text('نقدي: $_paymentCashCount', style: const TextStyle(fontSize: DesignTokens.textLabelSmall, color: AppTheme.textPrimary, fontWeight: FontWeight.w600))]),
        SizedBox(height: DesignTokens.space6),
        Row(children: [Container(width: DesignTokens.space4, height: DesignTokens.space4, decoration: BoxDecoration(color: AppTheme.primaryColor, shape: BoxShape.circle)), SizedBox(width: DesignTokens.space6),
          Text('إلكتروني: $_paymentOnlineCount', style: const TextStyle(fontSize: DesignTokens.textLabelSmall, color: AppTheme.textPrimary, fontWeight: FontWeight.w600))]),
      ])),
    ]);
  }

  Widget _buildProviderBreakdown() {
    if (_providerStats.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: EdgeInsets.all(DesignTokens.space16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: DesignTokens.brXl,
        border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.06)),
        boxShadow: [BoxShadow(color: AppTheme.primaryColor.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Row(children: [
            Container(
              padding: EdgeInsets.all(DesignTokens.space6),
              decoration: BoxDecoration(color: AppTheme.primaryColor.withValues(alpha: 0.1), borderRadius: DesignTokens.brMd),
              child: const Icon(Icons.engineering_rounded, color: AppTheme.primaryColor, size: DesignTokens.iconSm),
            ),
            SizedBox(width: DesignTokens.space8),
            Text('تقرير مقدمي الخدمة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: DesignTokens.textBodyMedium, color: AppTheme.textPrimary)),
          ]),
          Container(
            padding: EdgeInsets.symmetric(horizontal: DesignTokens.space8, vertical: DesignTokens.space4),
            decoration: BoxDecoration(color: AppTheme.primaryColor.withValues(alpha: 0.1), borderRadius: DesignTokens.brXl),
            child: Text('${_providerStats.length} مقدم', style: TextStyle(fontSize: DesignTokens.textLabelSmall, color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
          ),
        ]),
        SizedBox(height: DesignTokens.space12),
        Container(
          padding: EdgeInsets.symmetric(vertical: DesignTokens.space8, horizontal: DesignTokens.space8),
          decoration: BoxDecoration(color: AppTheme.backgroundColor, borderRadius: DesignTokens.brLg),
          child: Row(children: [
            Expanded(flex: 3, child: Text('الاسم', style: TextStyle(fontSize: DesignTokens.textLabelSmall, fontWeight: FontWeight.bold, color: AppTheme.textSecondary))),
            Expanded(flex: 2, child: Text('مكتمل', style: TextStyle(fontSize: DesignTokens.textLabelSmall, fontWeight: FontWeight.bold, color: AppTheme.successColor), textAlign: TextAlign.center)),
            Expanded(flex: 2, child: Text('ملغي', style: TextStyle(fontSize: DesignTokens.textLabelSmall, fontWeight: FontWeight.bold, color: AppTheme.errorColor), textAlign: TextAlign.center)),
            Expanded(flex: 2, child: Text('معلق', style: TextStyle(fontSize: DesignTokens.textLabelSmall, fontWeight: FontWeight.bold, color: AppTheme.tertiaryColor), textAlign: TextAlign.center)),
            Expanded(flex: 3, child: Text('الربح', style: TextStyle(fontSize: DesignTokens.textLabelSmall, fontWeight: FontWeight.bold, color: AppTheme.textSecondary), textAlign: TextAlign.end)),
          ]),
        ),
        SizedBox(height: DesignTokens.space8),
        ...List.generate(_providerStats.length, (i) {
          final p = _providerStats[i];
          return Padding(
            padding: EdgeInsets.only(bottom: DesignTokens.space6),
            child: Row(children: [
              Expanded(flex: 3, child: Text(p['name'] as String, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: DesignTokens.textLabelSmall, color: AppTheme.textPrimary))),
              Expanded(flex: 2, child: Text('${p['completed']}', style: TextStyle(color: AppTheme.successColor, fontWeight: FontWeight.bold, fontSize: DesignTokens.textLabelSmall), textAlign: TextAlign.center)),
              Expanded(flex: 2, child: Text('${p['cancelled']}', style: TextStyle(color: AppTheme.errorColor, fontWeight: FontWeight.bold, fontSize: DesignTokens.textLabelSmall), textAlign: TextAlign.center)),
              Expanded(flex: 2, child: Text('${p['pending']}', style: TextStyle(color: AppTheme.tertiaryColor, fontWeight: FontWeight.bold, fontSize: DesignTokens.textLabelSmall), textAlign: TextAlign.center)),
              Expanded(flex: 3, child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('${(p['earnings'] as double).toStringAsFixed(0)} ج', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: DesignTokens.textLabelSmall, color: AppTheme.successColor)),
                Text('عمولة: ${(p['commissions'] as double).toStringAsFixed(0)} ج', style: TextStyle(fontSize: DesignTokens.textLabelSmall, color: AppTheme.textSecondary)),
              ])),
            ]),
          );
        }),
      ]),
    );
  }

  Widget _buildClientBreakdown() {
    if (_clientStats.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: EdgeInsets.all(DesignTokens.space16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: DesignTokens.brXl,
        border: Border.all(color: AppTheme.secondaryColor.withValues(alpha: 0.06)),
        boxShadow: [BoxShadow(color: AppTheme.secondaryColor.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: EdgeInsets.all(DesignTokens.space6),
            decoration: BoxDecoration(color: AppTheme.secondaryColor.withValues(alpha: 0.1), borderRadius: DesignTokens.brMd),
            child: const Icon(Icons.people_rounded, color: AppTheme.secondaryColor, size: DesignTokens.iconSm),
          ),
          SizedBox(width: DesignTokens.space8),
          Text('طلبات العملاء', style: TextStyle(fontWeight: FontWeight.bold, fontSize: DesignTokens.textBodyMedium, color: AppTheme.textPrimary)),
          const Spacer(),
          Container(
            padding: EdgeInsets.symmetric(horizontal: DesignTokens.space8, vertical: DesignTokens.space4),
            decoration: BoxDecoration(color: AppTheme.secondaryColor.withValues(alpha: 0.1), borderRadius: DesignTokens.brXl),
            child: Text('${_clientStats.length} عميل', style: TextStyle(fontSize: DesignTokens.textLabelSmall, color: AppTheme.secondaryColor, fontWeight: FontWeight.bold)),
          ),
        ]),
        SizedBox(height: DesignTokens.space12),
        ...List.generate(_clientStats.length, (i) {
          final c = _clientStats[i];
          return Padding(
            padding: EdgeInsets.only(bottom: DesignTokens.space6),
            child: Row(children: [
              Container(
                width: DesignTokens.space16, height: DesignTokens.space16,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [AppTheme.secondaryColor, AppTheme.primaryColor], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: DesignTokens.brSm,
                ),
                alignment: Alignment.center,
                child: Text('${i + 1}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.surfaceColor, fontSize: DesignTokens.textBodySmall)),
              ),
              SizedBox(width: DesignTokens.space8),
              Expanded(child: Text(c['name'] as String, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: DesignTokens.textBodySmall, color: AppTheme.textPrimary))),
              Container(
                padding: EdgeInsets.symmetric(horizontal: DesignTokens.space8, vertical: DesignTokens.space4),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [AppTheme.secondaryColor.withValues(alpha: 0.15), AppTheme.secondaryColor.withValues(alpha: 0.05)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: DesignTokens.brXl,
                ),
                child: Text('${c['total']} طلب', style: TextStyle(fontSize: DesignTokens.textLabelSmall, color: AppTheme.secondaryColor, fontWeight: FontWeight.w600)),
              ),
            ]),
          );
        }),
      ]),
    );
  }
}