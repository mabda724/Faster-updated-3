import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'dart:io';
import 'package:pdf/widgets.dart' as pw;
import 'package:excel/excel.dart' as excel;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/services/supabase_service.dart';

class AdminReportsScreen extends StatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen> {
  DateTime? _startDate;
  DateTime? _endDate;
  String _statusFilter = 'all';
  String? _categoryFilter;
  String? _providerFilter;

  bool _isLoading = true;
  final Map<String, dynamic> _stats = {
    'totalRevenue': 0.0,
    'thisMonthRevenue': 0.0,
    'lastMonthRevenue': 0.0,
    'totalBookings': 0,
    'completedBookings': 0,
    'cancelledBookings': 0,
    'pendingBookings': 0,
    'acceptedBookings': 0,
    'inProgressBookings': 0,
    'totalProviders': 0,
    'totalClients': 0,
    'avgOrderValue': 0.0,
    'growthRate': 0.0,
    'completionRate': 0.0,
  };
  List<Map<String, dynamic>> _topProviders = [];
  List<Map<String, dynamic>> _allProviderStats = [];
  List<Map<String, dynamic>> _recentBookings = [];
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _providers = [];
  List<Map<String, dynamic>> _dailyRevenue = [];
  double _maxDailyRevenue = 0;

  @override
  void initState() { super.initState(); _loadMeta(); _loadData(); }

  Future<void> _loadMeta() async {
    try {
      final cats = await SupabaseService.db.from('categories').select('id, name_ar').order('name_ar');
      final provs = await SupabaseService.db.from('profiles').select('id, full_name').eq('role', 'provider').order('full_name');
      if (mounted) setState(() { _categories = List<Map<String, dynamic>>.from(cats); _providers = List<Map<String, dynamic>>.from(provs); });
    } catch (_) {}
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final db = SupabaseService.db;
      final now = DateTime.now();

      final thisMonthStart = DateTime(now.year, now.month, 1);
      final lastMonthStart = DateTime(now.year, now.month - 1, 1);
      final lastMonthEnd = DateTime(now.year, now.month, 0);

      var query = db.from('bookings').select('id, provider_id, client_id, status, commission_amount, total_price, created_at, completed_at, service_id, category_id');
      if (_startDate != null && _endDate != null) {
        final adjustedEnd = DateTime(_endDate!.year, _endDate!.month, _endDate!.day, 23, 59, 59);
        query = query.gte('created_at', _startDate!.toUtc().toIso8601String()).lte('created_at', adjustedEnd.toUtc().toIso8601String());
      }
      if (_statusFilter != 'all') query = query.eq('status', _statusFilter);
      final catFilter = _categoryFilter;
      if (catFilter != null) query = query.eq('category_id', catFilter);
      final provFilter = _providerFilter;
      if (provFilter != null) query = query.eq('provider_id', provFilter);

      final bookingsRes = await query.order('created_at', ascending: false);
      final List bookingsList = bookingsRes as List;

      _stats['totalBookings'] = bookingsList.length;

      double totalRev = 0;
      double thisMonthRev = 0;
      double lastMonthRev = 0;
      int completedCount = 0;
      int cancelledCount = 0;
      double totalValue = 0;
      final Map<String, double> dailyRev = {};

      final Map<String, int> statusCounts = {for (var s in ['pending', 'accepted', 'on_the_way', 'arrived', 'in_progress', 'completed', 'cancelled']) s: 0};
      final provCompleted = <String, int>{};
      final provCancelled = <String, int>{};
      final provPending = <String, int>{};
      final provEarnings = <String, double>{};
      final provComm = <String, double>{};

      for (var b in bookingsList) {
        final st = b['status'] as String? ?? 'pending';
        if (statusCounts.containsKey(st)) statusCounts[st] = statusCounts[st]! + 1;

        final commission = double.tryParse(b['commission_amount']?.toString() ?? '0') ?? 0;
        final totalVal = double.tryParse(b['total_price']?.toString() ?? '0') ?? 0;

        if (st == 'completed') {
          totalRev += commission;
          totalValue += totalVal;
          completedCount++;
        } else if (st == 'cancelled') {
          cancelledCount++;
        }

        final createdStr = b['created_at'] as String?;
        if (createdStr != null) {
          final bDate = DateTime.tryParse(createdStr);
          if (bDate != null) {
            if (st == 'completed') {
              if (bDate.isAfter(thisMonthStart)) {
                thisMonthRev += commission;
              } else if (bDate.isAfter(lastMonthStart) && bDate.isBefore(lastMonthEnd)) {
                lastMonthRev += commission;
              }
            }
            final dayKey = '${bDate.year}-${bDate.month.toString().padLeft(2, '0')}-${bDate.day.toString().padLeft(2, '0')}';
            if (st == 'completed') {
              dailyRev[dayKey] = (dailyRev[dayKey] ?? 0) + commission;
            }
          }
        }

        final pid = b['provider_id']?.toString();
        if (pid != null && pid.isNotEmpty) {
          if (st == 'completed') { provCompleted[pid] = (provCompleted[pid] ?? 0) + 1; provEarnings[pid] = (provEarnings[pid] ?? 0) + (totalVal - commission); provComm[pid] = (provComm[pid] ?? 0) + commission; }
          else if (st == 'cancelled') provCancelled[pid] = (provCancelled[pid] ?? 0) + 1;
          else provPending[pid] = (provPending[pid] ?? 0) + 1;
        }
      }

      final totalProvidersRes = await db.from('profiles').select('id').eq('role', 'provider');
      final totalClientsRes = await db.from('profiles').select('id').eq('role', 'client');

      _stats['totalRevenue'] = totalRev;
      _stats['thisMonthRevenue'] = thisMonthRev;
      _stats['lastMonthRevenue'] = lastMonthRev;
      _stats['completedBookings'] = statusCounts['completed']!;
      _stats['cancelledBookings'] = statusCounts['cancelled']!;
      _stats['pendingBookings'] = statusCounts['pending']!;
      _stats['acceptedBookings'] = statusCounts['accepted']!;
      _stats['inProgressBookings'] = statusCounts['in_progress']!;
      _stats['totalProviders'] = (totalProvidersRes as List).length;
      _stats['totalClients'] = (totalClientsRes as List).length;
      _stats['avgOrderValue'] = completedCount > 0 ? (totalValue / completedCount) : 0;
      _stats['completionRate'] = bookingsList.length > 0 ? (completedCount / bookingsList.length * 100) : 0;
      _stats['growthRate'] = lastMonthRev > 0 ? ((thisMonthRev - lastMonthRev) / lastMonthRev * 100) : 0;

      _dailyRevenue = dailyRev.entries.map((e) => {'date': e.key, 'revenue': e.value}).toList()..sort((a, b) => a['date'].toString().compareTo(b['date'].toString()));
      _maxDailyRevenue = _dailyRevenue.isEmpty ? 1 : _dailyRevenue.map((d) => (d['revenue'] as double)).reduce((a, b) => a > b ? a : b);

      final providerProfiles = await db.from('profiles').select('id, full_name').eq('role', 'provider');
      final provNameMap = {for (var p in providerProfiles) p['id'] as String: p['full_name'] as String? ?? 'بدون اسم'};

      final allProviderIds = <String>{};
      for (var p in providerProfiles) allProviderIds.add(p['id'] as String);
      for (var b in bookingsList) {
        final pid = b['provider_id']?.toString();
        if (pid != null) allProviderIds.add(pid);
      }

      _allProviderStats = allProviderIds.map((pid) => {
        'name': provNameMap[pid] ?? 'بدون اسم',
        'completed': provCompleted[pid] ?? 0, 'cancelled': provCancelled[pid] ?? 0,
        'pending': provPending[pid] ?? 0, 'earnings': provEarnings[pid] ?? 0,
        'commissions': provComm[pid] ?? 0,
      }).toList()..sort((a, b) => (b['completed'] as int).compareTo(a['completed'] as int));

      _topProviders = _allProviderStats.toList()..sort((a, b) => (b['earnings'] as double).compareTo(a['earnings'] as double));

      List<Map<String, dynamic>> recent = [];
      final recentList = bookingsList.take(10).toList();
      for (var b in recentList) {
        String serviceName = '-';
        if (b['service_id'] != null) {
          try {
            final svc = await db.from('services').select('title').eq('id', b['service_id']).maybeSingle();
            serviceName = svc?['title'] ?? '-';
          } catch (_) {}
        }
        recent.add({
          'id': b['id'], 'service': serviceName, 'status': b['status'] ?? 'pending',
          'amount': b['total_price'] ?? 0, 'created_at': b['created_at'],
        });
      }
      _recentBookings = recent;

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Error loading reports: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context, firstDate: DateTime(2020), lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: _startDate != null && _endDate != null ? DateTimeRange(start: _startDate!, end: _endDate!) : null,
      locale: const Locale('ar'),
      builder: (ctx, child) => Theme(data: Theme.of(ctx).copyWith(colorScheme: ColorScheme.light(primary: AppTheme.primaryColor)), child: child!),
    );
    if (picked != null) { setState(() { _startDate = picked.start; _endDate = picked.end; }); _loadData(); }
  }

  void _clearFilter() { setState(() { _startDate = null; _endDate = null; _statusFilter = 'all'; _categoryFilter = null; _providerFilter = null; }); _loadData(); }

  // ─── HELPERS ───────────────────────────────────────────────────────────────

  String _fmt(DateTime? dt) => dt == null ? '' : '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  String _fmtDate(String? iso) { if (iso == null) return '-'; try { final dt = DateTime.parse(iso); return '${dt.day}/${dt.month}'; } catch (_) { return '-'; } }

  Future<void> _exportExcel() async {
    final ex = excel.Excel.createExcel();
    final sheet = ex['Report'];
    sheet.appendRow([excel.TextCellValue('ID'), excel.TextCellValue('Service'), excel.TextCellValue('Status'), excel.TextCellValue('Amount'), excel.TextCellValue('Date')]);
    for (var b in _recentBookings) {
      sheet.appendRow([excel.TextCellValue(b['id'].toString()), excel.TextCellValue(b['service'].toString()), excel.TextCellValue(b['status'].toString()), excel.IntCellValue(int.tryParse(b['amount'].toString()) ?? 0), excel.TextCellValue(b['created_at'].toString())]);
    }
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/faster_report.xlsx');
    await file.writeAsBytes(ex.save()!);
    await Share.shareXFiles([XFile(file.path)], text: 'تقرير Faster');
  }

  Future<void> _exportPdf() async {
    final pdf = pw.Document();
    pdf.addPage(pw.Page(build: (pw.Context context) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Text('Faster Admin Report', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 20),
      pw.Text('Total Revenue: ${(_stats['totalRevenue'] as double).toStringAsFixed(0)} EGP'),
      pw.Text('Total Bookings: ${_stats['totalBookings']}'),
      pw.SizedBox(height: 20),
      pw.Text('Recent Bookings:'),
      pw.TableHelper.fromTextArray(data: [
        ['Service', 'Status', 'Amount', 'Date'],
        ..._recentBookings.map((b) => [b['service'], b['status'], '${b['amount']} EGP', _fmtDate(b['created_at'] as String?)]),
      ]),
    ])));
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/faster_report.pdf');
    await file.writeAsBytes(await pdf.save());
    await Share.shareXFiles([XFile(file.path)], text: 'تقرير Faster PDF');
  }

  Color _statusColor(String s) { switch (s) { case 'pending': return AppTheme.tertiaryColor; case 'accepted': return AppTheme.primaryColor; case 'completed': return AppTheme.successColor; case 'cancelled': return AppTheme.errorColor; case 'rejected': return AppTheme.errorColor; default: return AppTheme.textSecondary; } }
  String _statusText(String s) { switch (s) { case 'pending': return 'معلق'; case 'accepted': return 'مقبول'; case 'completed': return 'مكتمل'; case 'cancelled': return 'ملغي'; case 'rejected': return 'مرفوض'; default: return s; } }

  // ─── BUILD ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceColor, elevation: 0, centerTitle: true,
        title: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.bar_chart_rounded, color: AppTheme.primaryColor, size: DesignTokens.iconMd),
          SizedBox(width: DesignTokens.space4),
          Text('التقارير والإحصائيات', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: DesignTokens.textTitleMedium)),
        ]),
        leading: IconButton(icon: Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.textPrimary), tooltip: 'العودة', onPressed: () => Navigator.pop(context)),
        actions: [
          IconButton(icon: Icon(Icons.file_download_outlined, color: AppTheme.primaryColor), onPressed: _exportExcel, tooltip: 'Export Excel'),
          IconButton(icon: Icon(Icons.picture_as_pdf_outlined, color: AppTheme.errorColor), onPressed: _exportPdf, tooltip: 'Export PDF'),
          IconButton(icon: Icon(Icons.refresh_rounded, color: AppTheme.primaryColor), tooltip: 'تحديث', onPressed: _loadData),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.all(DesignTokens.space24),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _buildFilters(),
                  SizedBox(height: DesignTokens.space24),
                  _sectionTitle('نظرة عامة', Icons.dashboard_rounded),
                  SizedBox(height: DesignTokens.space12),
                  _buildOverviewGrid(),
                  SizedBox(height: DesignTokens.space24),
                  _sectionTitle('مقارنة الإيرادات', Icons.trending_up_rounded),
                  SizedBox(height: DesignTokens.space12),
                  _buildRevenueComparison(),
                  SizedBox(height: DesignTokens.space24),
                  _sectionTitle('تحليل الإيرادات اليومية', Icons.show_chart_rounded),
                  SizedBox(height: DesignTokens.space12),
                  _buildDailyChart(),
                  SizedBox(height: DesignTokens.space24),
                  _sectionTitle('توزيع حالة الطلبات', Icons.pie_chart_rounded),
                  SizedBox(height: DesignTokens.space12),
                  _buildPieChart(),
                  SizedBox(height: DesignTokens.space24),
                  _sectionTitle('أفضل 5 مقدمي خدمة', Icons.emoji_events_rounded),
                  SizedBox(height: DesignTokens.space12),
                  _buildTopProviders(),
                  SizedBox(height: DesignTokens.space24),
                  _sectionTitle('تقرير جميع مقدمي الخدمة', Icons.table_chart_rounded),
                  SizedBox(height: DesignTokens.space12),
                  _buildProviderTable(),
                  SizedBox(height: DesignTokens.space24),
                  _sectionTitle('آخر الطلبات', Icons.receipt_long_rounded),
                  SizedBox(height: DesignTokens.space12),
                  _buildRecentBookings(),
                  SizedBox(height: DesignTokens.space32),
                ]),
              ),
            ),
    );
  }

  // ─── FILTERS ──────────────────────────────────────────────────────────────

  Widget _buildFilters() {
    return Container(
      padding: EdgeInsets.all(DesignTokens.space16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor, borderRadius: DesignTokens.brXl,
        boxShadow: DesignTokens.shadow2(AppTheme.textPrimary),
        border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.1)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: EdgeInsets.all(DesignTokens.space6), decoration: BoxDecoration(color: AppTheme.primaryColor.withValues(alpha: 0.08), borderRadius: DesignTokens.brMd),
            child: Icon(Icons.filter_alt_rounded, color: AppTheme.primaryColor, size: DesignTokens.iconMd)),
          SizedBox(width: DesignTokens.space8),
          Text('تصفية متقدمة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: DesignTokens.textTitleSmall, color: AppTheme.textPrimary)),
          Spacer(),
          if (_startDate != null || _statusFilter != 'all' || _categoryFilter != null || _providerFilter != null)
            TextButton.icon(
              onPressed: _clearFilter,
              icon: Icon(Icons.close_rounded, size: DesignTokens.iconSm, color: AppTheme.errorColor),
              label: Text('إزالة الكل', style: TextStyle(color: AppTheme.errorColor, fontSize: DesignTokens.textLabelSmall)),
            ),
        ]),
        SizedBox(height: DesignTokens.space12),
        Row(children: [
          Expanded(child: _buildDateFilterChip(_startDate == null ? 'اختر الفترة' : '${_fmt(_startDate)} → ${_fmt(_endDate)}', Icons.date_range_rounded, _selectDateRange)),
          SizedBox(width: DesignTokens.space4),
          Expanded(child: _buildDropdownFilter('الحالة', _statusFilter, ['all', 'pending', 'accepted', 'completed', 'cancelled'],
            ['الكل', 'معلق', 'مقبول', 'مكتمل', 'ملغي'], (v) { setState(() => _statusFilter = v!); _loadData(); })),
        ]),
        SizedBox(height: DesignTokens.space4),
        Row(children: [
          Expanded(child: _buildDropdownFilter('التصنيف', _categoryFilter ?? 'all',
            ['all', ..._categories.map((c) => c['id'].toString())],
            ['الكل', ..._categories.map((c) => c['name_ar'].toString())], (v) { setState(() => _categoryFilter = v == 'all' ? null : v); _loadData(); })),
          SizedBox(width: DesignTokens.space4),
          Expanded(child: _buildDropdownFilter('مقدم الخدمة', _providerFilter ?? 'all',
            ['all', ..._providers.map((p) => p['id'].toString())],
            ['الكل', ..._providers.map((p) => p['full_name'].toString())], (v) { setState(() => _providerFilter = v == 'all' ? null : v); _loadData(); },
            maxLabelLen: 20)),
        ]),
      ]),
    );
  }

  Widget _buildDateFilterChip(String label, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: DesignTokens.space4, vertical: DesignTokens.space3),
        decoration: BoxDecoration(color: AppTheme.backgroundColor, borderRadius: DesignTokens.brSm, border: Border.all(color: AppTheme.textPrimary.withValues(alpha: 0.08))),
        child: Row(children: [
          Icon(icon, size: DesignTokens.iconXs, color: AppTheme.primaryColor),
          SizedBox(width: DesignTokens.space2),
          Expanded(child: Text(label, style: TextStyle(fontSize: DesignTokens.textLabelSmall, color: AppTheme.textPrimary), overflow: TextOverflow.ellipsis)),
        ]),
      ),
    );
  }

  Widget _buildDropdownFilter(String hint, String value, List<String> values, List<String> labels, ValueChanged<String?> onChanged, {int maxLabelLen = 30}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: DesignTokens.space4),
      decoration: BoxDecoration(color: AppTheme.backgroundColor, borderRadius: DesignTokens.brSm, border: Border.all(color: AppTheme.textPrimary.withValues(alpha: 0.08))),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true, value: value, dropdownColor: AppTheme.surfaceColor,
          hint: Text(hint, style: TextStyle(fontSize: DesignTokens.textLabelSmall, color: AppTheme.textTertiary)),
          items: List.generate(values.length, (i) => DropdownMenuItem(value: values[i], child: Text(labels[i].length > maxLabelLen ? '${labels[i].substring(0, maxLabelLen)}...' : labels[i], style: TextStyle(fontSize: DesignTokens.textLabelSmall, color: AppTheme.textPrimary)))),
          onChanged: onChanged,
        ),
      ),
    );
  }

  // ─── OVERVIEW ─────────────────────────────────────────────────────────────

  Widget _buildOverviewGrid() {
    return GridView.count(
      shrinkWrap: true, physics: NeverScrollableScrollPhysics(),
      crossAxisCount: 2, mainAxisSpacing: DesignTokens.space10, crossAxisSpacing: DesignTokens.space10,
      childAspectRatio: 1.4,
      children: [
        _statCard('إجمالي الإيرادات', '${(_stats['totalRevenue'] as double).toStringAsFixed(0)} ج.م', Icons.monetization_on_rounded, AppTheme.successColor),
        _statCard('الإيرادات هذا الشهر', '${(_stats['thisMonthRevenue'] as double).toStringAsFixed(0)} ج.م', Icons.trending_up_rounded, AppTheme.primaryColor),
        _statCard('معدل النمو', '${(_stats['growthRate'] as double).toStringAsFixed(1)}%', Icons.analytics_rounded, (_stats['growthRate'] as double) >= 0 ? AppTheme.successColor : AppTheme.errorColor),
        _statCard('متوسط قيمة الطلب', '${(_stats['avgOrderValue'] as double).toStringAsFixed(0)} ج.م', Icons.shopping_cart_rounded, AppTheme.infoColor),
        _statCard('معدل الإنجاز', '${(_stats['completionRate'] as double).toStringAsFixed(1)}%', Icons.check_circle_rounded, AppTheme.successColor),
        _statCard('الطلبات', '${_stats['totalBookings']} (${_stats['completedBookings']} تم)', Icons.receipt_long_rounded, AppTheme.primaryColor),
        _statCard('مقدمي الخدمة', '${_stats['totalProviders']}', Icons.engineering_rounded, AppTheme.tertiaryColor),
        _statCard('العملاء', '${_stats['totalClients']}', Icons.people_rounded, AppTheme.infoColor),
      ],
    );
  }

  Widget _statCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(DesignTokens.space10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor, borderRadius: DesignTokens.brLg,
        border: Border(top: BorderSide(color: color, width: 3), left: BorderSide(color: AppTheme.textPrimary.withValues(alpha: 0.05)), right: BorderSide(color: AppTheme.textPrimary.withValues(alpha: 0.05)), bottom: BorderSide(color: AppTheme.textPrimary.withValues(alpha: 0.05))),
        boxShadow: DesignTokens.shadow1(AppTheme.textPrimary),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: EdgeInsets.all(DesignTokens.space4), decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: DesignTokens.brSm),
            child: Icon(icon, size: DesignTokens.iconSm, color: color)),
          Spacer(),
        ]),
        Spacer(),
        FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: TextStyle(fontSize: DesignTokens.textTitleMedium, fontWeight: FontWeight.bold, color: color))),
        Text(title, style: TextStyle(fontSize: DesignTokens.textLabelSmall, color: AppTheme.textSecondary)),
      ]),
    );
  }

  // ─── REVENUE COMPARISON ──────────────────────────────────────────────────

  Widget _buildRevenueComparison() {
    final thisMonth = _stats['thisMonthRevenue'] as double;
    final lastMonth = _stats['lastMonthRevenue'] as double;
    final maxVal = (thisMonth > lastMonth ? thisMonth : lastMonth) * 1.2;
    if (maxVal == 0) return _emptyBox(Icons.bar_chart_outlined, 'لا توجد بيانات للمقارنة');

    return Container(
      padding: EdgeInsets.all(DesignTokens.space20),
      decoration: BoxDecoration(color: AppTheme.surfaceColor, borderRadius: DesignTokens.brXl, border: Border.all(color: AppTheme.textPrimary.withValues(alpha: 0.05)), boxShadow: DesignTokens.shadow1(AppTheme.textPrimary)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildBar('الشهر الحالي', thisMonth, maxVal, AppTheme.successColor),
        SizedBox(height: DesignTokens.space16),
        _buildBar('الشهر الماضي', lastMonth, maxVal, AppTheme.primaryColor),
        SizedBox(height: DesignTokens.space12),
        Center(
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: DesignTokens.space8, vertical: DesignTokens.space3),
            decoration: BoxDecoration(
              color: (_stats['growthRate'] as double) >= 0 ? AppTheme.successColor.withValues(alpha: 0.08) : AppTheme.errorColor.withValues(alpha: 0.08),
              borderRadius: DesignTokens.brFull,
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon((_stats['growthRate'] as double) >= 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded, size: DesignTokens.iconSm, color: (_stats['growthRate'] as double) >= 0 ? AppTheme.successColor : AppTheme.errorColor),
              SizedBox(width: DesignTokens.space2),
              Text('${(_stats['growthRate'] as double).toStringAsFixed(1)}% مقارنة بالشهر الماضي', style: TextStyle(fontSize: DesignTokens.textLabelSmall, fontWeight: FontWeight.bold, color: (_stats['growthRate'] as double) >= 0 ? AppTheme.successColor : AppTheme.errorColor)),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _buildBar(String label, double value, double max, Color color) {
    final width = max > 0 ? (value / max).clamp(0.0, 1.0) : 0.0;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text(label, style: TextStyle(fontSize: DesignTokens.textBodyMedium, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
        Spacer(),
        Text('${value.toStringAsFixed(0)} ج.م', style: TextStyle(fontSize: DesignTokens.textBodySmall, fontWeight: FontWeight.bold, color: color)),
      ]),
      SizedBox(height: DesignTokens.space4),
      ClipRRect(borderRadius: DesignTokens.brXs, child: SizedBox(height: DesignTokens.space8, child: Stack(children: [
        Container(width: double.infinity, height: DesignTokens.space8, decoration: BoxDecoration(color: AppTheme.textSecondary.withValues(alpha: 0.08), borderRadius: DesignTokens.brXs)),
        FractionallySizedBox(widthFactor: width, child: Container(height: DesignTokens.space8, decoration: BoxDecoration(gradient: LinearGradient(colors: [color, color.withValues(alpha: 0.7)], begin: Alignment.centerLeft, end: Alignment.centerRight), borderRadius: DesignTokens.brXs))),
      ]))),
    ]);
  }

  // ─── DAILY CHART ──────────────────────────────────────────────────────────

  Widget _buildDailyChart() {
    if (_dailyRevenue.isEmpty) return _emptyBox(Icons.show_chart_outlined, 'لا توجد بيانات يومية');

    return Container(
      padding: EdgeInsets.all(DesignTokens.space16),
      decoration: BoxDecoration(color: AppTheme.surfaceColor, borderRadius: DesignTokens.brXl, border: Border.all(color: AppTheme.textPrimary.withValues(alpha: 0.05)), boxShadow: DesignTokens.shadow1(AppTheme.textPrimary)),
      child: SizedBox(
        height: 180,
        child: BarChart(BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: _maxDailyRevenue * 1.2,
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, i, rod, _) => BarTooltipItem(
                '${rod.toY.toStringAsFixed(0)} ج.م',
                TextStyle(color: AppTheme.surfaceColor, fontWeight: FontWeight.bold, fontSize: DesignTokens.textLabelSmall),
              ),
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (v, _) {
                  final idx = v.toInt();
                  if (idx < _dailyRevenue.length) {
                    return Padding(
                      padding: EdgeInsets.only(top: DesignTokens.space4),
                      child: Text(
                        _dailyRevenue[idx]['date'].toString().substring(5),
                        style: TextStyle(fontSize: DesignTokens.textLabelSmall - 2, color: AppTheme.textSecondary),
                      ),
                    );
                  }
                  return SizedBox();
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (v, _) => Text(
                  '${v.toInt()}',
                  style: TextStyle(fontSize: DesignTokens.textLabelSmall - 2, color: AppTheme.textSecondary),
                ),
              ),
            ),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: _maxDailyRevenue > 0 ? _maxDailyRevenue / 4 : 1),
          borderData: FlBorderData(show: false),
          barGroups: List.generate(_dailyRevenue.length, (i) => BarChartGroupData(
            x: i,
            barRods: [BarChartRodData(
              toY: _dailyRevenue[i]['revenue'] as double,
              color: AppTheme.primaryColor,
              width: 12,
              borderRadius: BorderRadius.circular(4),
            )],
          )),
        )),
      ),
    );
  }

  // ─── PIE CHART ────────────────────────────────────────────────────────────

  Widget _buildPieChart() {
    final hasData = (_stats['pendingBookings'] as int) > 0 || (_stats['acceptedBookings'] as int) > 0 || (_stats['inProgressBookings'] as int) > 0 || (_stats['completedBookings'] as int) > 0 || (_stats['cancelledBookings'] as int) > 0;
    if (!hasData) return _emptyBox(Icons.pie_chart_outline, 'لا توجد بيانات');

    return Container(
      padding: EdgeInsets.all(DesignTokens.space20),
      decoration: BoxDecoration(color: AppTheme.surfaceColor, borderRadius: DesignTokens.brXl, border: Border.all(color: AppTheme.textPrimary.withValues(alpha: 0.05)), boxShadow: DesignTokens.shadow1(AppTheme.textPrimary)),
      child: Column(children: [
        SizedBox(height: 200, child: PieChart(PieChartData(
          sections: [
            PieChartSectionData(value: (_stats['pendingBookings'] as int).toDouble(), title: 'معلق', color: AppTheme.tertiaryColor, radius: 50, titleStyle: TextStyle(fontSize: DesignTokens.textLabelSmall, fontWeight: FontWeight.bold, color: Colors.white)),
            PieChartSectionData(value: (_stats['acceptedBookings'] as int).toDouble(), title: 'مقبول', color: AppTheme.primaryColor, radius: 50, titleStyle: TextStyle(fontSize: DesignTokens.textLabelSmall, fontWeight: FontWeight.bold, color: Colors.white)),
            PieChartSectionData(value: (_stats['inProgressBookings'] as int).toDouble(), title: 'قيد التنفيذ', color: AppTheme.primaryColor, radius: 50, titleStyle: TextStyle(fontSize: DesignTokens.textLabelSmall, fontWeight: FontWeight.bold, color: Colors.white)),
            PieChartSectionData(value: (_stats['completedBookings'] as int).toDouble(), title: 'مكتمل', color: AppTheme.successColor, radius: 50, titleStyle: TextStyle(fontSize: DesignTokens.textLabelSmall, fontWeight: FontWeight.bold, color: Colors.white)),
            PieChartSectionData(value: (_stats['cancelledBookings'] as int).toDouble(), title: 'ملغي', color: AppTheme.errorColor, radius: 50, titleStyle: TextStyle(fontSize: DesignTokens.textLabelSmall, fontWeight: FontWeight.bold, color: Colors.white)),
          ],
          centerSpaceRadius: 40, sectionsSpace: 2,
        ))),
        SizedBox(height: DesignTokens.space12),
        Wrap(spacing: DesignTokens.space6, runSpacing: DesignTokens.space4, children: [
          _legendItem(AppTheme.tertiaryColor, 'معلق ${_stats['pendingBookings']}'),
          _legendItem(AppTheme.primaryColor, 'مقبول ${_stats['acceptedBookings']}'),
          _legendItem(AppTheme.primaryColor, 'قيد التنفيذ ${_stats['inProgressBookings']}'),
          _legendItem(AppTheme.successColor, 'مكتمل ${_stats['completedBookings']}'),
          _legendItem(AppTheme.errorColor, 'ملغي ${_stats['cancelledBookings']}'),
        ]),
      ]),
    );
  }

  Widget _legendItem(Color color, String label) => Row(mainAxisSize: MainAxisSize.min, children: [
    Container(width: DesignTokens.space8, height: DesignTokens.space8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
    SizedBox(width: DesignTokens.space4),
    Text(label, style: TextStyle(fontSize: DesignTokens.textLabelSmall, color: AppTheme.textSecondary)),
  ]);

  // ─── TOP PROVIDERS ────────────────────────────────────────────────────────

  Widget _buildTopProviders() {
    if (_topProviders.isEmpty) return _emptyBox(Icons.people_outline_rounded, 'لا توجد بيانات كافية');
    return Container(
      decoration: BoxDecoration(color: AppTheme.surfaceColor, borderRadius: DesignTokens.brXl, border: Border.all(color: AppTheme.textPrimary.withValues(alpha: 0.05)), boxShadow: DesignTokens.shadow1(AppTheme.textPrimary)),
      child: Column(children: _topProviders.take(5).toList().asMap().entries.map((e) => _buildProviderRankItem(e.key, e.value)).toList()),
    );
  }

  Widget _buildProviderRankItem(int index, Map<String, dynamic> provider) {
    final colors = [AppTheme.tertiaryColor, AppTheme.textSecondary, AppTheme.textTertiary, AppTheme.textPrimary, AppTheme.textPrimary];
    final rankColor = index < colors.length ? colors[index] : AppTheme.textPrimary;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: DesignTokens.space16, vertical: DesignTokens.space12),
      decoration: BoxDecoration(border: index < 4 ? Border(bottom: BorderSide(color: AppTheme.textPrimary.withValues(alpha: 0.05))) : null),
      child: Row(children: [
        Container(width: DesignTokens.space14, height: DesignTokens.space14, decoration: BoxDecoration(color: rankColor.withValues(alpha: 0.1), shape: BoxShape.circle, border: Border.all(color: rankColor.withValues(alpha: 0.3))),
          child: Center(child: Text('${index + 1}', style: TextStyle(fontWeight: FontWeight.bold, color: rankColor, fontSize: DesignTokens.textLabelLarge)))),
        SizedBox(width: DesignTokens.space8),
        Expanded(child: Text(provider['name'] as String, style: TextStyle(fontWeight: FontWeight.w600, fontSize: DesignTokens.textBodyMedium, color: AppTheme.textPrimary), overflow: TextOverflow.ellipsis)),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('${(provider['earnings'] as double).toStringAsFixed(0)} ج.م', style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold, fontSize: DesignTokens.textBodyMedium)),
          Text('${provider['completed']} خدمات', style: TextStyle(fontSize: DesignTokens.textLabelSmall, color: AppTheme.textSecondary)),
        ]),
      ]),
    );
  }

  // ─── PROVIDER TABLE ───────────────────────────────────────────────────────

  Widget _buildProviderTable() {
    if (_allProviderStats.isEmpty) return _emptyBox(Icons.table_chart_outlined, 'لا توجد بيانات');
    return Container(
      decoration: BoxDecoration(color: AppTheme.surfaceColor, borderRadius: DesignTokens.brXl, border: Border.all(color: AppTheme.textPrimary.withValues(alpha: 0.05)), boxShadow: DesignTokens.shadow1(AppTheme.textPrimary)),
      child: Column(children: [
        Container(padding: EdgeInsets.symmetric(horizontal: DesignTokens.space16, vertical: DesignTokens.space10), decoration: BoxDecoration(color: AppTheme.backgroundColor, borderRadius: BorderRadius.vertical(top: Radius.circular(DesignTokens.radiusXl))),
          child: Row(children: [
            Expanded(flex: 3, child: Text('الاسم', style: TextStyle(fontSize: DesignTokens.textLabelSmall, fontWeight: FontWeight.bold, color: AppTheme.textSecondary))),
            Expanded(flex: 2, child: Text('مكتمل', style: TextStyle(fontSize: DesignTokens.textLabelSmall, fontWeight: FontWeight.bold, color: AppTheme.successColor), textAlign: TextAlign.center)),
            Expanded(flex: 2, child: Text('ملغي', style: TextStyle(fontSize: DesignTokens.textLabelSmall, fontWeight: FontWeight.bold, color: AppTheme.errorColor), textAlign: TextAlign.center)),
            Expanded(flex: 3, child: Text('الربح', style: TextStyle(fontSize: DesignTokens.textLabelSmall, fontWeight: FontWeight.bold, color: AppTheme.textSecondary), textAlign: TextAlign.end)),
          ]),
        ),
        ..._allProviderStats.map((p) => _buildProviderTableRow(p)),
      ]),
    );
  }

  Widget _buildProviderTableRow(Map<String, dynamic> p) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: DesignTokens.space16, vertical: DesignTokens.space10),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppTheme.textPrimary.withValues(alpha: 0.05)))),
      child: Row(children: [
        Expanded(flex: 3, child: Text(p['name'] as String, style: TextStyle(fontWeight: FontWeight.w600, fontSize: DesignTokens.textLabelSmall, color: AppTheme.textPrimary), overflow: TextOverflow.ellipsis)),
        Expanded(flex: 2, child: Text('${p['completed']}', style: TextStyle(color: AppTheme.successColor, fontWeight: FontWeight.bold, fontSize: DesignTokens.textLabelSmall), textAlign: TextAlign.center)),
        Expanded(flex: 2, child: Text('${p['cancelled']}', style: TextStyle(color: AppTheme.errorColor, fontWeight: FontWeight.bold, fontSize: DesignTokens.textLabelSmall), textAlign: TextAlign.center)),
        Expanded(flex: 3, child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('${(p['earnings'] as double).toStringAsFixed(0)} ج', style: TextStyle(fontWeight: FontWeight.bold, fontSize: DesignTokens.textLabelSmall, color: AppTheme.successColor)),
          Text('عمولة: ${(p['commissions'] as double).toStringAsFixed(0)} ج', style: TextStyle(fontSize: DesignTokens.textLabelSmall, color: AppTheme.textSecondary)),
        ])),
      ]),
    );
  }

  // ─── RECENT BOOKINGS ──────────────────────────────────────────────────────

  Widget _buildRecentBookings() {
    if (_recentBookings.isEmpty) return _emptyBox(Icons.receipt_long_outlined, 'لا توجد طلبات');
    return Column(children: _recentBookings.map((b) => Container(
      margin: EdgeInsets.only(bottom: DesignTokens.space6),
      decoration: BoxDecoration(color: AppTheme.surfaceColor, borderRadius: DesignTokens.brLg, border: Border.all(color: AppTheme.textPrimary.withValues(alpha: 0.05)), boxShadow: DesignTokens.shadow1(AppTheme.textPrimary)),
      child: Padding(padding: EdgeInsets.symmetric(horizontal: DesignTokens.space16, vertical: DesignTokens.space10), child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(b['service'] as String, style: TextStyle(fontWeight: FontWeight.bold, fontSize: DesignTokens.textBodyMedium, color: AppTheme.textPrimary), overflow: TextOverflow.ellipsis),
          SizedBox(height: DesignTokens.space2),
          Row(children: [Icon(Icons.calendar_today_rounded, size: DesignTokens.iconXs, color: AppTheme.textSecondary), SizedBox(width: DesignTokens.space2), Text(_fmtDate(b['created_at'] as String?), style: TextStyle(fontSize: DesignTokens.textLabelSmall, color: AppTheme.textSecondary))]),
        ])),
        SizedBox(width: DesignTokens.space8),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('${b['amount']} ج.م', style: TextStyle(fontWeight: FontWeight.bold, fontSize: DesignTokens.textBodyMedium, color: AppTheme.textPrimary)),
          SizedBox(height: DesignTokens.space2),
          Container(padding: EdgeInsets.symmetric(horizontal: DesignTokens.space6, vertical: DesignTokens.space1), decoration: BoxDecoration(color: _statusColor(b['status'] as String).withValues(alpha: 0.1), borderRadius: DesignTokens.brSm),
            child: Text(_statusText(b['status'] as String), style: TextStyle(fontSize: DesignTokens.textLabelSmall, fontWeight: FontWeight.bold, color: _statusColor(b['status'] as String))),
          ),
        ]),
      ])),
    )).toList());
  }

  // ─── UTILITIES ────────────────────────────────────────────────────────────

  Widget _sectionTitle(String title, IconData icon) {
    return Row(children: [
      Container(padding: EdgeInsets.all(DesignTokens.space6), decoration: BoxDecoration(color: AppTheme.primaryColor.withValues(alpha: 0.08), borderRadius: DesignTokens.brSm),
        child: Icon(icon, size: DesignTokens.iconSm, color: AppTheme.primaryColor)),
      SizedBox(width: DesignTokens.space8),
      Text(title, style: TextStyle(fontSize: DesignTokens.textTitleSmall, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
    ]);
  }

  Widget _emptyBox(IconData icon, String message) {
    return Container(
      padding: EdgeInsets.all(DesignTokens.space24),
      decoration: BoxDecoration(color: AppTheme.surfaceColor, borderRadius: DesignTokens.brXl, border: Border.all(color: AppTheme.textPrimary.withValues(alpha: 0.05))),
      child: Center(child: Column(children: [
        Icon(icon, size: DesignTokens.iconXl, color: AppTheme.textSecondary.withValues(alpha: DesignTokens.opacityMuted)),
        SizedBox(height: DesignTokens.space8),
        Text(message, style: TextStyle(color: AppTheme.textSecondary, fontSize: DesignTokens.textBodyMedium)),
      ])),
    );
  }
}