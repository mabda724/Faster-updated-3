import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/services/supabase_service.dart';
import '../../auth/data/auth_repository.dart';
import '../../booking/presentation/booking_screen.dart';
import '../../delivery/presentation/client_delivery_screen.dart';
import 'home_controller.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final HomeController _controller;
  String _currentAddress = 'موقعي الحالي';
  int _activeOrdersCount = 0;
  bool _showTopBanner = true;
  bool _showPromoBanner = true;
  final PageController _sliderController = PageController();
  Timer? _sliderTimer;
  int _currentSliderPage = 0;

  @override
  void initState() {
    super.initState();
    _controller = HomeController();
    _controller.loadData();
    _startSliderAutoScroll();
  }

  @override
  void dispose() {
    _controller.dispose();
    _sliderController.dispose();
    _sliderTimer?.cancel();
    super.dispose();
  }

  void _startSliderAutoScroll() {
    _sliderTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (_sliderController.hasClients) {
        final nextPage = _currentSliderPage + 1;
        if (nextPage < _sliderSlides.length) {
          _sliderController.animateToPage(nextPage,
              duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
        } else {
          _sliderController.animateToPage(0,
              duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildHeader(),
              _buildOurServices(),
              _buildCategoryGrid(),
              if (_showPromoBanner) _buildPromoBanner(),
              SizedBox(height: DesignTokens.space8.h),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primaryColor, Color(0xFF1A237E)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(40),
          bottomRight: Radius.circular(40),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          DesignTokens.space8.w,
          DesignTokens.space6.h,
          DesignTokens.space8.w,
          DesignTokens.space8.h,
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: () {},
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: DesignTokens.space3.w, vertical: DesignTokens.space1.h),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(DesignTokens.radiusMd.r),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.location_on_rounded,
                            color: AppTheme.warningColor, size: 16.sp),
                        SizedBox(width: DesignTokens.space1.w),
                        Text(
                          _currentAddress,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(width: DesignTokens.space1.w),
                        Icon(Icons.keyboard_arrow_down_rounded,
                            color: Colors.white.withValues(alpha: 0.8), size: 14.sp),
                      ],
                    ),
                  ),
                ),
                Image.asset(
                  'assets/images/logo (1)/logo_faster.png',
                  width: 100,
                  height: 40,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Row(
                    children: [
                      Icon(Icons.bolt_rounded,
                          color: AppTheme.warningColor,
                          size: 20.sp),
                      SizedBox(width: DesignTokens.space2.w),
                      Text(
                        'Faster',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22.sp,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),
                Stack(
                  children: [
                    IconButton(
                      onPressed: () {},
                      icon: Icon(Icons.notifications_outlined,
                          color: Colors.white, size: 22.sp),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    if (_activeOrdersCount > 0)
                      Positioned(
                        top: 3,
                        right: 3,
                        child: Container(
                          width: 8.sp,
                          height: 8.sp,
                          decoration: const BoxDecoration(
                            color: AppTheme.errorColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            SizedBox(height: DesignTokens.space4.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.star_rounded, color: AppTheme.warningColor, size: 14.sp),
                SizedBox(width: DesignTokens.space2.w),
                Text(
                  'كل الخدمات التي تحتاجها في مكان واحد',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 13.sp,
                  ),
                ),
              ],
            ),
            SizedBox(height: DesignTokens.space6.h),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(DesignTokens.radiusXl.r),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextField(
                textDirection: TextDirection.rtl,
                decoration: InputDecoration(
                  hintText: 'ابحث عن خدمة أو صنايعي...',
                  hintTextDirection: TextDirection.rtl,
                  prefixIcon: Icon(Icons.search_rounded,
                      color: AppTheme.textTertiary, size: 20.sp),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: DesignTokens.space6.w,
                    vertical: DesignTokens.space3.h,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(DesignTokens.radiusXl.r),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(DesignTokens.radiusXl.r),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(DesignTokens.radiusXl.r),
                    borderSide: BorderSide(
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ),
            ),
            if (_showTopBanner) ...[
              SizedBox(height: DesignTokens.space6.h),
              _buildTopBanner(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTopBanner() {
    return SizedBox(
      height: 150.h,
      child: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _sliderController,
              onPageChanged: (i) => setState(() => _currentSliderPage = i),
              itemCount: _sliderSlides.length,
              itemBuilder: (_, i) => _buildSliderSlide(_sliderSlides[i]),
            ),
          ),
          SizedBox(height: DesignTokens.space2.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_sliderSlides.length, (i) => AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: EdgeInsets.symmetric(horizontal: 2.w),
              width: _currentSliderPage == i ? 20.sp : 8.sp,
              height: 6.sp,
              decoration: BoxDecoration(
                color: _currentSliderPage == i
                    ? AppTheme.warningColor
                    : Colors.white.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(3.r),
              ),
            )),
          ),
        ],
      ),
    );
  }

  Widget _buildSliderSlide(Map<String, dynamic> slide) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [slide['color1'] as Color, slide['color2'] as Color],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(DesignTokens.radiusLg.r),
      ),
      padding: EdgeInsets.all(DesignTokens.space6.w),
      child: Row(
        children: [
          Expanded(
            flex: 6,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  slide['title'] as String,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: DesignTokens.space1.h),
                Text(
                  slide['subtitle'] as String,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 12.sp,
                  ),
                ),
                SizedBox(height: DesignTokens.space3.h),
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const BookingScreen(serviceId: '', serviceName: '', serviceImage: '', servicePrice: ''),
                      ),
                    );
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: DesignTokens.space6.w,
                      vertical: DesignTokens.space2.h,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(DesignTokens.radiusSm.r),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      slide['action'] as String,
                      style: TextStyle(
                        color: slide['color1'] as Color,
                        fontSize: 11.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          Container(
            width: 80.sp,
            height: 80.sp,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              slide['icon'] as IconData,
              color: Colors.white,
              size: 36.sp,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOurServices() {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        DesignTokens.space8.w,
        DesignTokens.space4.h,
        DesignTokens.space8.w,
        DesignTokens.space2.h,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.dashboard_rounded, color: AppTheme.primaryColor, size: 18.sp),
              SizedBox(width: DesignTokens.space2.w),
              Text(
                'خدماتنا',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                'عرض الكل',
                style: TextStyle(
                  fontSize: 11.sp,
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Icon(Icons.arrow_back_rounded, color: AppTheme.primaryColor, size: 14.sp),
            ],
          ),
          SizedBox(height: DesignTokens.space4.h),
          SizedBox(
            height: 100.h,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: _serviceItems.length,
              separatorBuilder: (_, __) => SizedBox(width: DesignTokens.space4.w),
              itemBuilder: (_, i) => _buildServiceCard(_serviceItems[i]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceCard(Map<String, dynamic> item) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const BookingScreen(serviceId: '', serviceName: '', serviceImage: '', servicePrice: ''),
          ),
        );
      },
      child: Container(
        width: 80.sp,
        padding: EdgeInsets.symmetric(vertical: DesignTokens.space4.h),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(DesignTokens.radiusLg.r),
          border: Border.all(color: AppTheme.dividerColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 44.sp,
              height: 44.sp,
              decoration: BoxDecoration(
                color: item['bgColor'] as Color,
                borderRadius: BorderRadius.circular(DesignTokens.radiusMd.r),
              ),
              child: Icon(
                item['icon'] as IconData,
                color: item['color'] as Color,
                size: 24.sp,
              ),
            ),
            SizedBox(height: DesignTokens.space2.h),
            Text(
              item['label'] as String,
              style: TextStyle(
                fontSize: 10.sp,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  static const _sliderSlides = [
    {
      'title': 'خدمات سريعة',
      'subtitle': 'موثوقة وأسعار عادلة',
      'action': 'اطلب الآن',
      'icon': Icons.settings_rounded,
      'color1': AppTheme.primaryColor,
      'color2': AppTheme.primaryColor,
    },
    {
      'title': 'توصيل سريع',
      'subtitle': 'في أقل من 30 دقيقة',
      'action': 'اطلب توصيل',
      'icon': Icons.delivery_dining_rounded,
      'color1': AppTheme.successColor,
      'color2': AppTheme.primaryColor,
    },
    {
      'title': 'عروض حصرية',
      'subtitle': 'خصم 20% على أول طلب',
      'action': 'استفد الآن',
      'icon': Icons.local_offer_rounded,
      'color1': AppTheme.warningColor,
      'color2': AppTheme.tertiaryColor,
    },
  ];

  final _serviceItems = [
    {
      'label': 'صيانة',
      'icon': Icons.build_rounded,
      'color': AppTheme.primaryColor,
      'bgColor': AppTheme.primaryColor,
    },
    {
      'label': 'توصيل',
      'icon': Icons.motorcycle_rounded,
      'color': AppTheme.successColor,
      'bgColor': AppTheme.successColor,
    },
    {
      'label': 'سباكة',
      'icon': Icons.water_drop_rounded,
      'color': AppTheme.infoColor,
      'bgColor': AppTheme.infoColor,
    },
    {
      'label': 'كهرباء',
      'icon': Icons.bolt_rounded,
      'color': AppTheme.warningColor,
      'bgColor': AppTheme.warningColor,
    },
    {
      'label': 'دهانات',
      'icon': Icons.format_paint_rounded,
      'color': AppTheme.tertiaryColor,
      'bgColor': AppTheme.tertiaryColor,
    },
    {
      'label': 'نظافة',
      'icon': Icons.cleaning_services_rounded,
      'color': AppTheme.successColor,
      'bgColor': AppTheme.successColor,
    },
  ];

  Widget _buildCategoryGrid() {
    return Padding(
      padding: EdgeInsets.all(DesignTokens.space8.w),
      child: Column(
        children: [
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: DesignTokens.space4.w,
              mainAxisSpacing: DesignTokens.space4.h,
              childAspectRatio: 0.82,
            ),
            itemCount: _categoryItems.length,
            itemBuilder: (_, i) => _buildCategoryCard(_categoryItems[i]),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(Map<String, dynamic> cat) {
    final enabled = cat['enabled'] as bool;
    return GestureDetector(
      onTap: enabled
          ? () {
              final name = cat['name'] as String;
              if (name == 'السوبر ماركت والتوصيل') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ClientDeliveryScreen(),
                  ),
                );
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const BookingScreen(serviceId: '', serviceName: '', serviceImage: '', servicePrice: ''),
                  ),
                );
              }
            }
          : null,
      child: Opacity(
        opacity: enabled ? 1.0 : 0.75,
        child: Container(
          decoration: BoxDecoration(
            color: cat['bgColor'] as Color,
            borderRadius: BorderRadius.circular(DesignTokens.radiusLg.r),
            border: Border.all(
              color: cat['borderColor'] as Color,
            ),
          ),
          padding: EdgeInsets.all(DesignTokens.space6.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.all(DesignTokens.space2.w),
                decoration: BoxDecoration(
                  color: cat['color'] as Color,
                  borderRadius:
                      BorderRadius.circular(DesignTokens.radiusMd.r),
                ),
                child: Icon(
                  cat['icon'] as IconData,
                  color: Colors.white,
                  size: 20.sp,
                ),
              ),
              const Spacer(),
              Text(
                cat['name'] as String,
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: DesignTokens.space1.h),
              Text(
                cat['desc'] as String,
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 9.sp,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: DesignTokens.space2.h),
              Align(
                alignment: Alignment.centerRight,
                child: Container(
                  width: 24.sp,
                  height: 24.sp,
                  decoration: BoxDecoration(
                    color: cat['arrowColor'] as Color,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(
                      enabled
                          ? Icons.arrow_back_rounded
                          : Icons.more_horiz_rounded,
                      color: Colors.white,
                      size: 12.sp,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPromoBanner() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: DesignTokens.space8.w),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primaryColor, AppTheme.primaryColor],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(DesignTokens.radiusLg.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: EdgeInsets.all(DesignTokens.space6.w),
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            child: GestureDetector(
              onTap: () {
                setState(() => _showPromoBanner = false);
              },
              child: Padding(
                padding: EdgeInsets.all(DesignTokens.space1.w),
                child: Icon(
                  Icons.close_rounded,
                  color: AppTheme.borderColor,
                  size: 14.sp,
                ),
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'توصيل سريع في الغردقة',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: DesignTokens.space1.h),
                    Text(
                      'خصم 20% على أول طلب',
                      style: TextStyle(
                        color: AppTheme.warningColor,
                        fontSize: 12.sp,
                      ),
                    ),
                    SizedBox(height: DesignTokens.space2.h),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: DesignTokens.space4.w,
                        vertical: DesignTokens.space1.h,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius:
                            BorderRadius.circular(DesignTokens.radiusSm.r),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'استخدم الكود:',
                            style: TextStyle(
                              color: AppTheme.dividerColor,
                              fontSize: 10.sp,
                            ),
                          ),
                          SizedBox(width: DesignTokens.space1.w),
                          Text(
                            'FAST20',
                            style: TextStyle(
                              color: AppTheme.warningColor,
                              fontSize: 12.sp,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: DesignTokens.space4.w),
              Icon(
                Icons.local_shipping_rounded,
                color: AppTheme.warningColor.withValues(alpha: 0.9),
                size: 40.sp,
              ),
            ],
          ),
        ],
      ),
    );
  }

  static const _categoryItems = [
    {
      'name': 'خدمة صناعية',
      'desc': 'فنيين محترفين لكل أعمال الأعطال والصيانة',
      'icon': Icons.build_rounded,
      'color': AppTheme.infoColor,
      'bgColor': AppTheme.backgroundColor,
      'borderColor': AppTheme.dividerColor,
      'arrowColor': AppTheme.primaryColor,
      'enabled': true,
    },
    {
      'name': 'السوبر ماركت والتوصيل',
      'desc': 'طلبات من السوبر ماركت تصل لحد باب البيت',
      'icon': Icons.shopping_basket_rounded,
      'color': AppTheme.whatsappColor,
      'bgColor': AppTheme.backgroundColor,
      'borderColor': AppTheme.dividerColor,
      'arrowColor': AppTheme.whatsappColor,
      'enabled': true,
    },
    {
      'name': 'التوصيل والمشاوير',
      'desc': 'توصيل سريع ومشاوير بأمان',
      'icon': Icons.motorcycle_rounded,
      'color': AppTheme.primaryColor,
      'bgColor': AppTheme.backgroundColor,
      'borderColor': AppTheme.backgroundColor,
      'arrowColor': AppTheme.primaryColor,
      'enabled': true,
    },
    {
      'name': 'قريباً',
      'desc': 'خدمات ثانية كثير جاية ليك',
      'icon': Icons.card_giftcard_rounded,
      'color': AppTheme.warningColor,
      'bgColor': AppTheme.surfaceColor,
      'borderColor': AppTheme.dividerColor,
      'arrowColor': AppTheme.warningColor,
      'enabled': false,
    },
  ];
}
