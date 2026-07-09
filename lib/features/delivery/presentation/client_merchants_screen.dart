import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/cart_service.dart';
import 'client_store_screen.dart';
import 'client_cart_screen.dart';

class ClientMerchantsScreen extends StatefulWidget {
  final String categoryName;
  const ClientMerchantsScreen({super.key, required this.categoryName});

  @override
  State<ClientMerchantsScreen> createState() => _ClientMerchantsScreenState();
}

class _ClientMerchantsScreenState extends State<ClientMerchantsScreen> {
  static const Color _purple = AppTheme.primaryColor;

  List<Map<String, dynamic>> _merchants = [];
  bool _isLoading = true;
  int _activeTab = 0;
  int _cartCount = 0;
  StreamSubscription? _cartSub;
  final _tabs = ['الكل', 'الأقرب', 'الأعلى تقييماً', 'العروض'];

  @override
  void initState() {
    super.initState();
    _load();
    _cartCount = CartService().count;
    _cartSub = CartService().stream.listen((_) {
      if (mounted) setState(() => _cartCount = CartService().count);
    });
  }

  @override
  void dispose() {
    _cartSub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final res = await SupabaseService.db
          .from('provider_profiles')
          .select('*, profiles(full_name, avatar_url)')
          .eq('provider_type', 'merchant')
          .eq('is_verified', true)
          .order('avg_rating', ascending: false)
          .limit(50);
      if (!mounted) return;
      _merchants = List<Map<String, dynamic>>.from(res);
    } catch (e) {
      debugPrint('Error loading merchants: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  List<Map<String, dynamic>> _getFiltered() {
    switch (_activeTab) {
      case 1:
        _merchants.sort((a, b) => (a['delivery_area']?.toString() ?? '')
            .compareTo(b['delivery_area']?.toString() ?? ''));
        return _merchants;
      case 2:
        return List.from(_merchants)
          ..sort((a, b) => ((b['avg_rating'] as num?)?.toDouble() ?? 0)
              .compareTo((a['avg_rating'] as num?)?.toDouble() ?? 0));
      default:
        return _merchants;
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _getFiltered();
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Column(
        children: [
          // Status bar
          Container(
            padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
            color: Colors.white,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 4.h),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('9:41',
                      style: TextStyle(
                          fontSize: 12.sp, fontWeight: FontWeight.bold)),
                  Row(children: [
                    Icon(Icons.signal_cellular_alt, size: 14.sp),
                    SizedBox(width: 4.w),
                    Icon(Icons.wifi, size: 14.sp),
                    SizedBox(width: 4.w),
                    Icon(Icons.battery_full, size: 16.sp),
                  ]),
                ],
              ),
            ),
          ),
          // Header
          Container(
            color: Colors.white,
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                InkWell(
                  onTap: () => Navigator.pop(context),
                  child: Icon(Icons.arrow_back_rounded,
                      color: Colors.grey[800], size: 22),
                ),
                Text(widget.categoryName,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15.sp,
                        color: Colors.grey[900])),
                InkWell(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const ClientCartScreen()),
                  ),
                  child: Stack(
                    children: [
                      Icon(Icons.shopping_bag_outlined,
                          color: Colors.grey[800], size: 22),
                      if (_cartCount > 0)
                        Positioned(
                          top: 0,
                          right: 0,
                          child: Container(
                            padding: EdgeInsets.all(2.w),
                            decoration: BoxDecoration(
                              color: Colors.red[500],
                              shape: BoxShape.circle,
                            ),
                            constraints: BoxConstraints(
                                minWidth: 14, minHeight: 14),
                            child: Text('$_cartCount',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 7.sp,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Filter tabs
          Container(
            color: Colors.white,
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: SizedBox(
              height: 36.h,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: List.generate(_tabs.length, (i) {
                  final active = _activeTab == i;
                  return Padding(
                    padding: EdgeInsets.only(left: 8.w),
                    child: GestureDetector(
                      onTap: () => setState(() => _activeTab = i),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 24.w, vertical: 6.h),
                        decoration: BoxDecoration(
                          color: active ? _purple : Colors.white,
                          borderRadius: BorderRadius.circular(50.r),
                          border: active
                              ? null
                              : Border.all(color: Colors.grey[100]!),
                          boxShadow: active
                              ? [
                                  BoxShadow(
                                      color: _purple.withValues(alpha: 0.2),
                                      blurRadius: 8)
                                ]
                              : null,
                        ),
                        child: Text(_tabs[i],
                            style: TextStyle(
                              fontSize: 11.sp,
                              fontWeight: FontWeight.bold,
                              color: active
                                  ? Colors.white
                                  : Colors.grey[500],
                            )),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
          SizedBox(height: 8.h),
          // Merchant list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? Center(
                        child: Text('لا يوجد متاجر متاحة',
                            style: TextStyle(
                                color: Colors.grey[400],
                                fontWeight: FontWeight.bold)))
                    : ListView.builder(
                        padding: EdgeInsets.symmetric(
                            horizontal: 16.w, vertical: 8.h),
                        itemCount: filtered.length,
                        itemBuilder: (_, i) =>
                            _buildMerchantCard(filtered[i]),
                      ),
          ),
          // Bottom nav
          _buildBottomNav(),
        ],
      ),
    );
  }

  Widget _buildMerchantCard(Map<String, dynamic> merchant) {
    final profile = merchant['profiles'] as Map<String, dynamic>?;
    final name = profile?['full_name'] ?? 'متجر';
    final rating =
        (merchant['avg_rating'] as num?)?.toDouble() ?? 0;
    final storePhoto = merchant['store_photo_url'] as String?;
    final ratingCount = (merchant['total_reviews'] as num?)?.toInt() ?? 0;
    final hasOffer = rating > 4.5;
    final isFreeDelivery = rating > 4.5;

    final merchantId = merchant['id']?.toString() ?? '';
    final logoUrl = merchant['store_photo_url'] as String?;

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ClientStoreScreen(
            merchantId: merchantId,
            merchantName: name,
            merchantRating: rating,
            merchantLogo: logoUrl,
          ),
        ),
      ),
      borderRadius: BorderRadius.circular(16.r),
      child: Container(
      margin: EdgeInsets.only(bottom: 16.h),
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.grey[50]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Product image
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(Icons.shopping_bag_rounded,
                        color: _purple.withValues(alpha: 0.3), size: 32),
                    if (hasOffer)
                      Positioned(
                        bottom: 0,
                        child: Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 8.w, vertical: 2.h),
                          decoration: BoxDecoration(
                            color: AppTheme.warningColor,
                            borderRadius: BorderRadius.circular(4.r),
                          ),
                          child: Text('عرض',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 8.sp,
                                fontWeight: FontWeight.bold,
                              )),
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(width: 12.w),
              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13.sp,
                            color: Colors.grey[900])),
                    SizedBox(height: 4.h),
                    Row(
                      children: [
                        Text(rating.toStringAsFixed(1),
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 10.sp,
                                color: Colors.grey[900])),
                        SizedBox(width: 4.w),
                        Icon(Icons.star_rounded,
                            color: Colors.amber[400], size: 12),
                        SizedBox(width: 4.w),
                        Text('|',
                            style: TextStyle(
                                color: Colors.grey[300], fontSize: 10.sp)),
                        SizedBox(width: 4.w),
                        Text('25 - 35 دقيقة',
                            style: TextStyle(
                                fontSize: 10.sp,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[400])),
                      ],
                    ),
                    SizedBox(height: 2.h),
                    Text('توصيل',
                        style: TextStyle(
                            fontSize: 10.sp,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[400])),
                  ],
                ),
              ),
              // Logo
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8.r),
                  border: Border.all(color: Colors.grey[50]!),
                ),
                child: storePhoto != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8.r),
                        child: Image.network(storePhoto,
                            fit: BoxFit.contain),
                      )
                    : Center(
                        child: Text(name.isNotEmpty ? name[0] : '?',
                            style: TextStyle(
                                color: _purple,
                                fontWeight: FontWeight.bold,
                                fontSize: 20.sp)),
                      ),
              ),
            ],
          ),
          // Promo banner
          if (isFreeDelivery)
            Container(
              margin: EdgeInsets.only(top: 14.h),
              padding: EdgeInsets.symmetric(vertical: 6.h),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8.r),
                border: Border.all(color: Colors.green[100]!),
              ),
              child: Text(
                'توصيل مجاني للطلبات + 200 ج',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.green[700],
                ),
              ),
            ),
        ],
      ),
    ),
    );
  }

  Widget _buildBottomNav() {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.only(bottom: bottom),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[100]!)),
      ),
      child: SizedBox(
        height: 48.h,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Icon(Icons.home_rounded, color: Colors.grey[400], size: 22.sp),
            Icon(Icons.list_alt_rounded,
                color: Colors.grey[400], size: 22.sp),
            Container(
              width: 48,
              height: 48,
              margin: EdgeInsets.only(bottom: 8.h),
              decoration: BoxDecoration(
                color: _purple,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                      color: _purple.withValues(alpha: 0.4),
                      blurRadius: 15,
                      offset: const Offset(0, 4)),
                ],
              ),
              child: const Icon(Icons.bolt_rounded,
                  color: Colors.white, size: 24),
            ),
            Icon(Icons.shopping_cart_rounded,
                color: _purple, size: 22.sp),
            Icon(Icons.person_outline_rounded,
                color: Colors.grey[400], size: 22.sp),
          ],
        ),
      ),
    );
  }
}
