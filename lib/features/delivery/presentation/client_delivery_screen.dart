import 'dart:async';
import '../../../core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/services/cart_service.dart';
import 'client_merchants_screen.dart';
import 'client_cart_screen.dart';
import 'client_orders_screen.dart';

class ClientDeliveryScreen extends StatefulWidget {
  const ClientDeliveryScreen({super.key});

  @override
  State<ClientDeliveryScreen> createState() => _ClientDeliveryScreenState();
}

class _ClientDeliveryScreenState extends State<ClientDeliveryScreen> {
  static const Color _purple = AppTheme.primaryColor;
  static const Color _bannerGreen = AppTheme.successColor;
  static const Color _bgLight = AppTheme.backgroundColor;

  int _navIndex = 0;
  int _cartCount = 0;
  StreamSubscription? _cartSub;

  @override
  void initState() {
    super.initState();
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

  final _categories = [
    _CategoryData('السوبر ماركت', Icons.shopping_cart_rounded,
        'https://placehold.co/100x100/transparent/gray?text=Cart'),
    _CategoryData('المطاعم', Icons.restaurant_rounded,
        'https://placehold.co/100x100/transparent/gray?text=Burger'),
    _CategoryData('الصيدليات', Icons.local_pharmacy_rounded,
        'https://placehold.co/100x100/transparent/gray?text=Pharmacy'),
    _CategoryData('المخابز', Icons.bakery_dining_rounded,
        'https://placehold.co/100x100/transparent/gray?text=Bakery'),
    _CategoryData('الخضار والفواكه', Icons.spa_rounded,
        'https://placehold.co/100x100/transparent/gray?text=Fruits'),
    _CategoryData('اللحوم والدواجن', Icons.restaurant_menu_rounded,
        'https://placehold.co/100x100/transparent/gray?text=Meat'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgLight,
      body: Column(
        children: [
          // ========== STATUS BAR ==========
          Container(
            padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
            color: Colors.white,
            child: Padding(
              padding:
                  EdgeInsets.symmetric(horizontal: 24.w, vertical: 4.h),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('9:41',
                      style: TextStyle(
                          fontSize: 12.sp, fontWeight: FontWeight.bold)),
                  Row(
                    children: [
                      Icon(Icons.signal_cellular_alt, size: 14.sp),
                      SizedBox(width: 4.w),
                      Icon(Icons.wifi, size: 14.sp),
                      SizedBox(width: 4.w),
                      Icon(Icons.battery_full, size: 16.sp),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ========== HEADER ==========
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
                Text('السوبر ماركت والدليفري',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15.sp,
                      color: Colors.grey[900],
                    )),
                InkWell(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const ClientCartScreen()),
                  ),
                  child: Stack(
                    children: [
                      Icon(Icons.shopping_bag_outlined,
                          color: Colors.grey[800], size: 24),
                      if (_cartCount > 0)
                        Positioned(
                          top: 0,
                          right: 0,
                          child: Container(
                            padding: EdgeInsets.all(3.w),
                            decoration: BoxDecoration(
                              color: Colors.red[500],
                              shape: BoxShape.circle,
                            ),
                            constraints: BoxConstraints(
                                minWidth: 16, minHeight: 16),
                            child: Text('$_cartCount',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 8.sp,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ========== SCROLLABLE CONTENT ==========
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.w),
                    child: Column(
                      children: [
                        SizedBox(height: 12.h),

                        // -- Delivery Address Card --
                        _buildAddressCard(),

                        SizedBox(height: 16.h),

                        // -- Search Bar --
                        _buildSearchBar(),

                        SizedBox(height: 16.h),

                        // -- Offer Banner --
                        _buildOfferBanner(),
                      ],
                    ),
                  ),

                  SizedBox(height: 24.h),

                  // -- Category Grid --
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.w),
                    child: Column(
                      children: [
                        Text(
                          'اختر نوع الطلب',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14.sp,
                            color: Colors.grey[900],
                          ),
                        ),
                        SizedBox(height: 16.h),
                        _buildCategoryGrid(),
                      ],
                    ),
                  ),

                  SizedBox(height: 24.h),

                  // -- Feature Badges --
                  _buildFeatureBadges(),

                  SizedBox(height: 24.h),
                ],
              ),
            ),
          ),

          // ========== BOTTOM NAV ==========
          _buildBottomNav(),
        ],
      ),
    );
  }

  Widget _buildAddressCard() {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.grey[100]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.grey[50],
              shape: BoxShape.circle,
            ),
            child:
                Icon(Icons.location_on_rounded, color: Colors.grey[500], size: 16),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('التوصيل الي',
                    style: TextStyle(
                        fontSize: 10.sp,
                        color: Colors.grey[400],
                        fontWeight: FontWeight.bold)),
                Text('شارع السياحة - الغردقة',
                    style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800])),
              ],
            ),
          ),
          Icon(Icons.keyboard_arrow_down_rounded,
              color: Colors.grey[400], size: 18),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.grey[100]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        textDirection: TextDirection.rtl,
        decoration: InputDecoration(
          hintText: 'ابحث في السوبر ماركت...',
          hintTextDirection: TextDirection.rtl,
          hintStyle: TextStyle(
              fontSize: 11.sp,
              fontWeight: FontWeight.bold,
              color: Colors.grey[400]),
          prefixIcon: Icon(Icons.search_rounded,
              color: Colors.grey[400], size: 18),
          filled: true,
          fillColor: Colors.white,
          contentPadding: EdgeInsets.symmetric(
              horizontal: 16.w, vertical: 14.h),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16.r),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16.r),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16.r),
            borderSide: BorderSide(color: _purple.withValues(alpha: 0.3)),
          ),
        ),
      ),
    );
  }

  Widget _buildOfferBanner() {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: _bannerGreen,
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: _bannerGreen.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('عروض اليوم',
                  style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
              SizedBox(height: 4.h),
              Text('خصم يصل الي',
                  style: TextStyle(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.white70)),
              SizedBox(height: 4.h),
              Text('30%',
                  style: TextStyle(
                    fontSize: 36.sp,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.warningColor,
                    shadows: [
                      Shadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 4)
                    ],
                  )),
              SizedBox(height: 8.h),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(50.r),
                ),
                child: Text('تسوق الآن',
                    style: TextStyle(
                      fontSize: 10.sp,
                      fontWeight: FontWeight.bold,
                      color: _bannerGreen,
                    )),
              ),
            ],
          ),
          SizedBox(
            width: 100.w,
            height: 100.h,
            child: Icon(Icons.shopping_bag_rounded,
                color: Colors.white.withValues(alpha: 0.9), size: 72),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.3,
        crossAxisSpacing: 12.w,
        mainAxisSpacing: 12.h,
      ),
      itemCount: _categories.length,
      itemBuilder: (_, i) {
        final cat = _categories[i];
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20.r),
            border: Border.all(color: Colors.grey[100]!),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 15,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(20.r),
            child: InkWell(
              borderRadius: BorderRadius.circular(20.r),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      ClientMerchantsScreen(categoryName: cat.label),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 64.w,
                    height: 56.h,
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Icon(cat.icon, color: _purple, size: 28),
                  ),
                  SizedBox(height: 12.h),
                  Text(cat.label,
                      style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800])),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFeatureBadges() {
    final features = [
      _FeatureData(Icons.lock_rounded, Colors.blue[500]!, 'دفع آمن'),
      _FeatureData(Icons.local_offer_rounded, Colors.blue[500]!, 'أسعار مناسبة'),
      _FeatureData(Icons.local_shipping_rounded, Colors.blue[500]!,
          'توصيل سريع'),
    ];
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24.w),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: features
            .map((f) => Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12.w),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(f.icon, size: 16.sp, color: f.color),
                      SizedBox(width: 4.w),
                      Text(f.label,
                          style: TextStyle(
                              fontSize: 10.sp,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[500])),
                    ],
                  ),
                ))
            .toList(),
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
        height: 56.h,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _navItem(Icons.home_rounded, 0, Colors.grey[400]!),
            _navItemImage(Icons.description_outlined, 1, Colors.grey[400]!),
            _navCenterBolt(),
            _navItemImage(Icons.shopping_bag_outlined, 3, _purple),
            _navItem(Icons.person_outline_rounded, 4, Colors.grey[400]!),
          ],
        ),
      ),
    );
  }

  Widget _navItem(IconData icon, int index, Color color) {
    final active = _navIndex == index;
    return InkWell(
      onTap: () => setState(() => _navIndex = index),
      child: Icon(icon,
          color: active ? _purple : color, size: 22.sp),
    );
  }

  Widget _navItemImage(IconData icon, int index, Color color) {
    final active = _navIndex == index;
    return InkWell(
      onTap: () {
        setState(() => _navIndex = index);
        if (index == 1) {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const ClientOrdersScreen()));
        } else if (index == 3) {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const ClientCartScreen()));
        }
      },
      child: Icon(icon,
          color: active ? _purple : color, size: 22.sp),
    );
  }

  Widget _navCenterBolt() {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: _purple,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: _purple.withValues(alpha: 0.4),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 24),
    );
  }
}

class _CategoryData {
  final String label;
  final IconData icon;
  final String imageUrl;
  const _CategoryData(this.label, this.icon, this.imageUrl);
}

class _FeatureData {
  final IconData icon;
  final Color color;
  final String label;
  const _FeatureData(this.icon, this.color, this.label);
}
