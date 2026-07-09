import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/location_service.dart';

class ProviderDashboardController extends ChangeNotifier {
  bool isLoading = true;
  int totalOrders = 0, pendingOrders = 0, completedOrders = 0;
  double walletBalance = 0, rating = 0;
  String name = '';
  bool isOnline = false;
  bool isBanned = false;
  String docStatus = 'pending';
  int daysSinceReg = 0;
  List<String> portfolioImages = [];
  bool needsProfessionUpdate = false;
  String? categoryId;
  String? referralCode;
  int matchingRequestCount = 0;
  double completedCashServices = 0;
  double totalCommissionCalculated = 0;
  double settledAmount = 0;
  String? providerType;
  int totalProducts = 0, totalStock = 0;
  double totalSales = 0;
  int totalTrips = 0;
  double totalKilometers = 0;
  double dailyEarnings = 0;
  int dailyOrders = 0;
  double acceptanceRate = 0;
  List<double> weeklyEarnings = List.filled(7, 0);
  Map<String, dynamic>? firstMatchingRequest;
  XFile? proofImage;
  bool isSettling = false;

  StreamSubscription? _requestsSub;
  Timer? _requestCheckTimer;
  StreamSubscription? _settlementsSub;

  Future<void> load() async {
    isLoading = true;
    notifyListeners();
    final uid = SupabaseService.currentUserId;
    if (uid == null) {
      isLoading = false;
      notifyListeners();
      return;
    }
    try {
      final profile = await SupabaseService.db
          .from('profiles')
          .select('full_name, banned_at, avatar_url')
          .eq('id', uid)
          .single();
      name = profile['full_name'] ?? '';
      isBanned = profile['banned_at'] != null;

      final pp = await _ensureProviderProfile(uid);
      if (pp != null) {
        walletBalance = _parseDouble(pp['wallet_balance']);
        rating = _parseDouble(pp['rating']);
        isOnline = pp['is_online'] == true;
        docStatus = pp['document_verification_status'] ?? 'pending';
        portfolioImages = List<String>.from(pp['portfolio_images'] ?? []);
        final regDateStr = pp['created_at'];
        if (regDateStr != null) {
          try {
            final regDate = DateTime.parse(regDateStr);
            daysSinceReg = DateTime.now().difference(regDate).inDays;
          } catch (e) {
            debugPrint('Error parsing registration date: $e');
          }
        }
        categoryId = pp['category_id']?.toString();
        needsProfessionUpdate = categoryId == null;
        settledAmount = _parseDouble(pp['settled_amount']);
        providerType = pp['provider_type'] as String?;
      }

      await _loadProviderTypeStats(uid);

      try {
        final bookings = await SupabaseService.db
            .from('bookings')
            .select('id, status')
            .eq('provider_id', uid);
        totalOrders = bookings.length;
        pendingOrders = bookings
            .where((b) => ['pending','accepted','on_the_way','arrived','in_progress'].contains(b['status']))
            .length;
        completedOrders = bookings.where((b) => b['status'] == 'completed').length;
      } catch (e) {
        debugPrint('Error loading bookings stats: $e');
      }

      try {
        final cashBookings = await SupabaseService.db
            .from('bookings')
            .select('total_price, commission_amount, offered_price, created_at')
            .eq('provider_id', uid)
            .eq('status', 'completed');

        double totalCashPrice = 0, totalComm = 0, dailyCash = 0;
        int dailyCount = 0;
        final now = DateTime.now();
        final todayStart = DateTime(now.year, now.month, now.day);

        for (var b in (cashBookings as List)) {
          final price = _parseDouble((b['offered_price'] ?? b['total_price']));
          final comm = _parseDouble(b['commission_amount']);
          totalCashPrice += price;
          totalComm += comm;
          final createdAt = b['created_at']?.toString();
          if (createdAt != null) {
            try {
              final bDate = DateTime.parse(createdAt);
              if (bDate.isAfter(todayStart)) {
                dailyCash += price;
                dailyCount++;
              }
            } catch (_) {}
          }
        }

        completedCashServices = totalCashPrice;
        totalCommissionCalculated = totalComm;
        dailyEarnings = dailyCash;
        dailyOrders = dailyCount;

        weeklyEarnings = List.filled(7, 0);
        final weekStart = now.subtract(Duration(days: now.weekday % 7));
        for (var b in (cashBookings as List)) {
          final price = _parseDouble((b['offered_price'] ?? b['total_price']));
          final createdAt = b['created_at']?.toString();
          if (createdAt != null) {
            try {
              final bDate = DateTime.parse(createdAt);
              if (bDate.isAfter(weekStart.subtract(const Duration(days: 1)))) {
                final dayIndex = bDate.weekday % 7;
                weeklyEarnings[dayIndex] += price;
              }
            } catch (_) {}
          }
        }
      } catch (e) {
        debugPrint('Error loading cash stats: $e');
      }

      if (totalOrders > 0) {
        acceptanceRate = ((totalOrders - pendingOrders) / totalOrders) * 100;
      }
    } catch (e) {
      debugPrint('Dashboard load error: $e');
    }
    isLoading = false;
    notifyListeners();
    _loadReferralCode();
    _checkWalletThreshold();
    _loadFirstMatchingRequest();
  }

  Future<void> toggleOnline(bool val, BuildContext context) async {
    final uid = SupabaseService.currentUserId;
    if (uid == null) return;
    if (needsProfessionUpdate && val) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى تحديث بيانات تخصصك أولاً')),
      );
      return;
    }
    if (val) {
      bool has = await LocationService.handleLocationPermission();
      if (!has) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('صلاحية الوصول للموقع مطلوبة')),
        );
        return;
      }
    }
    isOnline = val;
    notifyListeners();
    await SupabaseService.db.from('provider_profiles').update({'is_online': val}).eq('id', uid);
  }

  Future<void> _loadFirstMatchingRequest() async {
    try {
      final uid = SupabaseService.currentUserId;
      if (uid == null || categoryId == null) return;
      final result = await SupabaseService.db.rpc(
        'find_matching_requests_for_provider',
        params: {'p_provider_id': uid},
      ) as List;
      if (result.isNotEmpty) {
        matchingRequestCount = result.length;
        firstMatchingRequest = result.first;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading first request: $e');
    }
  }

  Future<void> _loadReferralCode() async {
    try {
      final uid = SupabaseService.currentUserId;
      if (uid == null) return;
      final ref = await SupabaseService.db
          .from('referral_codes')
          .select('code, promo_value, uses_count')
          .eq('user_id', uid)
          .maybeSingle();
      if (ref != null) {
        referralCode = ref['code']?.toString();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading referral code: $e');
    }
  }

  Future<void> _loadProviderTypeStats(String uid) async {
    try {
      switch (providerType) {
        case 'merchant':
          final products = await SupabaseService.db
              .from('products')
              .select('stock, price')
              .eq('provider_id', uid);
          totalProducts = products.length;
          totalStock = products.fold<int>(0, (sum, p) => sum + (p['stock'] as int? ?? 0));
          totalSales = products.fold<double>(0, (sum, p) => sum + (p['price'] as num? ?? 0).toDouble());
          break;
        case 'driver':
          final trips = await SupabaseService.db
              .from('bookings')
              .select('distance_km')
              .eq('provider_id', uid)
              .eq('status', 'completed');
          totalTrips = trips.length;
          totalKilometers = trips.fold<double>(0, (sum, t) => sum + (t['distance_km'] as num? ?? 0).toDouble());
          break;
        default:
          break;
      }
    } catch (e) {
      debugPrint('Error loading provider type stats: $e');
    }
  }

  Future<void> _checkWalletThreshold() async {
    try {
      final setting = await SupabaseService.db
          .from('app_settings')
          .select('value')
          .eq('key', 'wallet_auto_offline_threshold')
          .maybeSingle();
      if (setting == null) return;
      final enabled = setting['value']?['enabled'] ?? false;
      if (!enabled) return;
      final threshold = (setting['value']?['value'] as num?)?.toDouble() ?? -50;
      if (walletBalance <= threshold && isOnline) {
        await SupabaseService.db.from('provider_profiles').update({'is_online': false}).eq('id', SupabaseService.currentUserId!);
        isOnline = false;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error checking wallet threshold: $e');
    }
  }

  Future<Map<String, dynamic>?> _ensureProviderProfile(String uid) async {
    try {
      var pp = await SupabaseService.db
          .from('provider_profiles')
          .select('id, profession, rating, wallet_balance, is_online, category_id, city, is_banned, document_verification_status, portfolio_images, created_at, search_radius_km, settled_amount, provider_type')
          .eq('id', uid)
          .maybeSingle();
      if (pp == null) {
        await SupabaseService.db.from('provider_profiles').insert({'id': uid});
        pp = await SupabaseService.db
            .from('provider_profiles')
            .select('id, profession, rating, wallet_balance, is_online, category_id, city, is_banned, document_verification_status, portfolio_images, created_at, search_radius_km, settled_amount, provider_type')
            .eq('id', uid)
            .single();
      }
      return pp;
    } catch (e) {
      debugPrint('Error ensuring provider profile: $e');
      return null;
    }
  }

  void startRequestCheckTimer() {
    _requestCheckTimer?.cancel();
    _requestCheckTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (isOnline) _loadFirstMatchingRequest();
    });
  }

  void stopRequestCheckTimer() {
    _requestCheckTimer?.cancel();
  }

  void startListeningToRequests() {
    _requestsSub = SupabaseService.db
        .from('bookings')
        .stream(primaryKey: ['id'])
        .eq('status', 'pending')
        .listen((data) {
      if (isOnline) _loadFirstMatchingRequest();
    });
  }

  void startListeningToSettlements() {
    final uid = SupabaseService.currentUserId;
    if (uid == null) return;
    _settlementsSub = SupabaseService.db
        .from('commission_settlements')
        .stream(primaryKey: ['id'])
        .eq('provider_id', uid)
        .listen((data) async {
      if (data.any((s) => s['status'] == 'verified')) {
        try {
          final verifiedSettlements = await SupabaseService.db
              .from('commission_settlements')
              .select('amount')
              .eq('provider_id', uid)
              .eq('status', 'verified');
          double totalVerified = 0;
          for (var s in verifiedSettlements) {
            totalVerified += _parseDouble(s['amount']);
          }
          await SupabaseService.db.from('provider_profiles').update({
            'settled_amount': totalVerified,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          }).eq('id', uid);
        } catch (e) {
          debugPrint('Error updating settled_amount: $e');
        }
        load();
      }
    });
  }

  double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    return double.tryParse(value.toString()) ?? 0.0;
  }

  @override
  void dispose() {
    _requestsSub?.cancel();
    _requestCheckTimer?.cancel();
    _settlementsSub?.cancel();
    super.dispose();
  }
}
