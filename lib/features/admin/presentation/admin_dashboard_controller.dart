import 'package:flutter/material.dart';
import '../../../core/services/supabase_service.dart';

class AdminDashboardController extends ChangeNotifier {
  bool isLoading = true;
  int totalUsers = 0;
  int totalProviders = 0;
  int totalBookings = 0;
  int totalCompleted = 0;
  int pendingWithdrawals = 0;
  double totalRevenue = 0;
  double totalSales = 0;
  double withdrawalPendingAmount = 0;
  int onlineProvidersCount = 0;
  int paymentCashCount = 0;
  int paymentOnlineCount = 0;

  double expectedCommission = 0;
  double receivedCommission = 0;
  double pendingCommission = 0;
  double totalCompletedServicesValue = 0;
  int totalCompletedServicesCount = 0;

  List<Map<String, dynamic>> providerStats = [];
  List<Map<String, dynamic>> clientStats = [];
  List<Map<String, dynamic>> categoryStats = [];
  List<double> weeklyTrend = [];

  Future<void> loadStats() async {
    isLoading = true;
    notifyListeners();
    try {
      final db = SupabaseService.db;
      final users = await db.from('profiles').select('id').eq('role', 'client');
      final providers = await db.from('profiles').select('id').eq('role', 'provider');
      final onlineProvidersRes = await db.from('provider_profiles').select('id').eq('is_online', true);
      onlineProvidersCount = onlineProvidersRes.length;

      final allBookings = await db.from('bookings').select('id, client_id, status, payment_method, total_price, commission_amount, service_id, created_at, provider_id, offered_price');
      final completed = allBookings.where((b) => b['status'] == 'completed').toList();

      final withdrawals = await db.from('withdrawal_requests').select('amount').eq('status', 'pending');
      double pendingWithdrawAmt = 0;
      for (var w in withdrawals) { pendingWithdrawAmt += double.tryParse(w['amount']?.toString() ?? '0') ?? 0; }
      withdrawalPendingAmount = pendingWithdrawAmt;

      double rev = 0, sales = 0, totalComm = 0, totalServicesValue = 0;
      for (var b in completed) {
        final price = double.tryParse((b['offered_price'] ?? b['total_price'])?.toString() ?? '0') ?? 0;
        final comm = double.tryParse(b['commission_amount']?.toString() ?? '0') ?? 0;
        rev += comm; sales += price; totalComm += comm; totalServicesValue += price;
      }
      totalRevenue = rev; totalSales = sales; expectedCommission = totalComm;
      totalCompletedServicesValue = totalServicesValue; totalCompletedServicesCount = completed.length;

      try {
        final settlements = await db.from('commission_settlements').select('amount, status');
        double received = 0, pending = 0;
        for (var s in settlements) {
          final amount = double.tryParse(s['amount']?.toString() ?? '0') ?? 0;
          final status = s['status']?.toString();
          if (status == 'verified') received += amount;
          else if (status == 'pending') pending += amount;
        }
        receivedCommission = received;
        pendingCommission = pending;
      } catch (e) { debugPrint('Error loading settlements: \$e'); }

      final providerProfiles = await db.from('profiles').select('id, full_name').eq('role', 'provider');
      final clientProfiles = await db.from('profiles').select('id, full_name').eq('role', 'client');
      final providerMap = {for (var p in providerProfiles) p['id'] as String: p['full_name'] as String? ?? 'No name'};
      final clientMap = {for (var c in clientProfiles) c['id'] as String: c['full_name'] as String? ?? 'No name'};

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

      providerStats = allProviderIds.map((pid) => {
        'id': pid, 'name': providerMap[pid] ?? 'No name', 'earnings': providerEarnings[pid] ?? 0,
        'commissions': providerComm[pid] ?? 0, 'completed': providerCompleted[pid] ?? 0,
        'cancelled': providerCancelled[pid] ?? 0, 'pending': providerPending[pid] ?? 0,
      }).toList()..sort((a, b) => ((b['completed'] as int) + (b['pending'] as int)).compareTo((a['completed'] as int) + (a['pending'] as int)));

      final clientAgg = <String, int>{};
      for (var b in allBookings) { final cid = b['client_id'] as String?; if (cid != null) clientAgg[cid] = (clientAgg[cid] ?? 0) + 1; }
      clientStats = clientAgg.keys.map((cid) => {'id': cid, 'name': clientMap[cid] ?? 'No name', 'total': clientAgg[cid] ?? 0}).toList()..sort((a, b) => (b['total'] as int).compareTo(a['total'] as int));

      final servicesList = await db.from('services').select('id, category_id');
      final categoriesList = await db.from('categories').select('id, name');
      final serviceToCategory = {for (var s in servicesList) s['id']: s['category_id']};
      final categoryNames = {for (var c in categoriesList) c['id']: c['name'] as String? ?? 'Unknown'};
      final categoryCounts = <dynamic, int>{};
      for (var b in allBookings) {
        final sid = b['service_id'];
        if (sid == null) continue;
        final catId = serviceToCategory[sid];
        if (catId != null) categoryCounts[catId] = (categoryCounts[catId] ?? 0) + 1;
      }
      categoryStats = categoryCounts.entries.map((e) => {'id': e.key, 'name': categoryNames[e.key] ?? 'Unknown', 'count': e.value}).toList()..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));

      int cash = 0, online = 0;
      for (var b in allBookings) {
        final pm = b['payment_method']?.toString().toLowerCase() ?? 'cash';
        if (pm == 'cash') cash++; else online++;
      }
      paymentCashCount = cash;
      paymentOnlineCount = online;

      final now = DateTime.now();
      final dailyCounts = List<int>.filled(7, 0);
      for (var b in allBookings) {
        final dateStr = b['created_at'];
        if (dateStr == null) continue;
        try { final date = DateTime.parse(dateStr); final diffDays = now.difference(date).inDays; if (diffDays >= 0 && diffDays < 7) dailyCounts[6 - diffDays]++; } catch (_) {}
      }
      weeklyTrend = dailyCounts.map((e) => e.toDouble()).toList();

      totalUsers = users.length;
      totalProviders = providers.length;
      totalBookings = allBookings.length;
      totalCompleted = completed.length;
      totalRevenue = rev;
      totalSales = sales;
      pendingWithdrawals = withdrawals.length;
    } catch (e) {
      debugPrint('Dashboard load error: \$e');
    }
    isLoading = false;
    notifyListeners();
  }
}
