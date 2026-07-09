import 'package:flutter/material.dart';
import 'package:flutter/material.dart' show SliverAppBar, FlexibleSpaceBar, SliverToBoxAdapter;
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:carousel_slider/carousel_slider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../../booking/presentation/booking_screen.dart';

class ProviderDetailsScreen extends StatefulWidget {
  final String providerId;

  const ProviderDetailsScreen({super.key, required this.providerId});

  @override
  State<ProviderDetailsScreen> createState() => _ProviderDetailsScreenState();
}

class _ProviderDetailsScreenState extends State<ProviderDetailsScreen> {
  Map<String, dynamic>? _provider;
  List<dynamic> _services = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProviderData();
  }

  Future<void> _loadProviderData() async {
    try {
      final data = await SupabaseService.db
          .from('provider_profiles')
          .select('''
            *,
            profiles(*)
          ''')
          .eq('id', widget.providerId)
          .single();

      final providerServices = await SupabaseService.db
          .from('provider_services')
          .select('services(*)')
          .eq('provider_id', widget.providerId);
      final servicesData = providerServices
          .map((item) => item['services'])
          .where((service) => service != null)
          .toList();

      if (mounted) {
        setState(() {
          _provider = data;
          _services = servicesData;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading provider details: $e');
      setState(() => _isLoading = false);
    }
  }

  void _showMessage(String msg) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        content: Text(msg),
        actions: [
          TextButton(
            isDefaultAction: true,
            child: const Text('حسنا'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(backgroundColor: AppTheme.backgroundColor, body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_provider == null) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        const child: const SafeArea(
          child: Center(
            child: Text('عفواً، لم يتم العثور على بيانات مقدم الخدمة'),
          ),
        ),
      );
    }

    final profile = _provider!['profiles'];

    // Extract images
    List<String> workImages = [];
    if (_provider!['portfolio_images'] != null) {
      workImages = List<String>.from(_provider!['portfolio_images']);
    }

    if (workImages.isEmpty) {
      workImages = [
        'https://images.unsplash.com/photo-1581578731548-c64695cc6952?w=800&q=80',
      ];
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: CustomScrollView(
        slivers: [
          // Carousel Header
          SliverAppBar(
            expandedHeight: 250.h,
            pinned: true,
            backgroundColor: AppTheme.primaryColor,
            leading: ElevatedButton(
              padding: EdgeInsets.zero,
              child: const Icon(
                Icons.arrow_back_rounded,
                color: Colors.white,
              ),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: CarouselSlider(
                options: CarouselOptions(
                  height: 300.h,
                  viewportFraction: 1.0,
                  enableInfiniteScroll: workImages.length > 1,
                  autoPlay: true,
                ),
                items: workImages.map((img) {
                  return Image.network(
                    img,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    semanticLabel: 'صورة',
                    errorBuilder: (_, __, ___) =>
                        Container(color: AppTheme.textSecondary.withValues(alpha: 0.1)),
                  );
                }).toList(),
              ),
            ),
          ),

          // Provider Profile Info
          SliverToBoxAdapter(
            child: Transform.translate(
              offset: const Offset(0, -30),
              child: Container(
                decoration: const BoxDecoration(
                  color: AppTheme.backgroundColor,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                ),
                padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 24.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Profile Header
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 4.0),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withValues(alpha: 0.5),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                          child: Container(
                            width: 80.r,
                            height: 80.r,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppTheme.primaryColor.withValues(alpha: 0.1),
                              image: profile['avatar_url'] != null
                                  ? DecorationImage(
                                      image: NetworkImage(profile['avatar_url']),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child: profile['avatar_url'] == null
                                ? Icon(Icons.person_rounded, color: AppTheme.primaryColor, size: DesignTokens.iconXl)
                                : null,
                          ),
                        ),
                        SizedBox(width: 16.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      profile['full_name'] ?? 'مقدم خدمة',
                                      style: TextStyle(
                                        fontSize: DesignTokens.textTitleLarge,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.textPrimary,
                                      ),
                                    ),
                                  ),
                                  if (profile['is_verified'] == true) ...[
                                    const SizedBox(width: 6),
                                    Icon(Icons.verified_rounded, size: 18, color: AppTheme.primaryColor),
                                  ],
                                ],
                              ),
                              SizedBox(height: 4.h),
                              Text(
                                _provider!['profession'] ?? 'مقدم خدمة',
                                style: TextStyle(
                                  fontSize: DesignTokens.textBodyMedium,
                                  color: AppTheme.primaryColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Rating
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: DesignTokens.space12,
                            vertical: DesignTokens.space6,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.tertiaryColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(DesignTokens.radiusXl),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.star_rounded,
                                color: AppTheme.tertiaryColor,
                                size: DesignTokens.iconMd,
                              ),
                              SizedBox(width: 4.w),
                              Text(
                                (_provider!['rating'] ?? 0.0).toString(),
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.tertiaryColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 24.h),

                    // Bio
                    Text(
                      'نبذة عني',
                      style: TextStyle(
                        fontSize: DesignTokens.textTitleMedium,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    SizedBox(height: DesignTokens.space8),
                    Text(
                      _provider!['bio']?.isNotEmpty == true
                          ? _provider!['bio']
                          : 'لا يوجد نبذة إضافية.',
                      style: TextStyle(
                        fontSize: DesignTokens.textBodyMedium,
                        color: AppTheme.textSecondary,
                        height: 1.5,
                      ),
                    ),

                    SizedBox(height: 24.h),

                    // Services List
                    Text(
                      'الخدمات المقدمة',
                      style: TextStyle(
                        fontSize: DesignTokens.textTitleMedium,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    SizedBox(height: DesignTokens.space16),

                    if (_services.isEmpty)
                      const Text(
                        'لا توجد خدمات مضافة',
                        style: TextStyle(color: AppTheme.textSecondary),
                      )
                    else
                      ..._services.map(
                        (service) => Container(
                          margin: EdgeInsets.only(bottom: 12.h),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: DesignTokens.brMd,
                            border: Border.all(
                              color: AppTheme.textPrimary.withValues(alpha: 0.05),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                child: Text(
                                  service['title'],
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: DesignTokens.textTitleSmall,
                                  ),
                                ),
                              ),
                              Text(
                                '${service['price']} ج/س',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      bottomContainer(
        padding: EdgeInsets.all(24.w),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withValues(alpha: 0.5),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              if (_services.isNotEmpty) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => BookingScreen(
                      serviceId: _services.first['id'].toString(),
                      serviceName: _services.first['title'],
                      serviceImage: workImages.isNotEmpty ? workImages.first : 'https://images.unsplash.com/photo-1581578731548-c64695cc6952?w=800&q=80',
                      servicePrice: _services.first['price'].toString(),
                    ),
                  ),
                );
              } else {
                _showMessage('عفواً، لا توجد خدمات لطلبها حالياً');
              }
            },
            padding: const EdgeInsets.symmetric(vertical: DesignTokens.space12),
            borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
            child: Text(
              'اطلب الآن',
              style: TextStyle(
                fontSize: DesignTokens.textTitleSmall,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
