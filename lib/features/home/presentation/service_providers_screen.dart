import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/provider_search_service.dart';
import '../../provider/presentation/provider_details_screen.dart';
import 'package:carousel_slider/carousel_slider.dart';
import '../../booking/presentation/booking_screen.dart';

class ServiceProvidersScreen extends StatefulWidget {
  final String serviceName;
  final Color serviceColor;

  const ServiceProvidersScreen({
    super.key,
    required this.serviceName,
    required this.serviceColor,
  });

  @override
  State<ServiceProvidersScreen> createState() => _ServiceProvidersScreenState();
}

class _ServiceProvidersScreenState extends State<ServiceProvidersScreen> {
  List<dynamic> _services = [];
  bool _isLoading = true;
  String? _selectedRatingTier;
  final List<String> _ratingTiers = ['الكل', 'ذهبي (4.5+)', 'فضي (4.0+)', 'برونزي (3.5+)', 'جديد (<3.5)'];

  @override
  void initState() {
    super.initState();
    _loadServices();
  }

  Future<void> _loadServices() async {
    try {
      // Find category first
      final catRes = await SupabaseService.db
          .from('categories')
          .select('id')
          .eq('name_ar', widget.serviceName)
          .limit(1);

      if (catRes.isNotEmpty) {
        final categoryId = catRes.first['id'];
        
        // Apply rating filter if selected
        List<dynamic> res;
        if (_selectedRatingTier != null && _selectedRatingTier != 'الكل') {
          String tier = '';
          switch (_selectedRatingTier) {
            case 'ذهبي (4.5+)': tier = 'gold'; break;
            case 'فضي (4.0+)': tier = 'silver'; break;
            case 'برونزي (3.5+)': tier = 'bronze'; break;
            case 'جديد (<3.5)': tier = 'new'; break;
          }
          
          // Get providers by rating tier first
          final providers = await ProviderSearchService.findByRatingTier(
            ratingTier: tier,
            lat: 30.0444, // Default Cairo coordinates
            lng: 31.2357,
            radiusKm: 50,
          );
          
          final providerIds = providers.map((p) => p['id']).toList();
          
          // Then fetch services for these providers
          if (providerIds.isNotEmpty) {
            res = await SupabaseService.db
                .from('services')
                .select('''
              *,
              provider_profiles!services_provider_id_fkey(
                *,
                profiles(*)
              )
            ''')
                .eq('category_id', categoryId)
                .eq('is_active', true)
                .inFilter('provider_id', providerIds);
          } else {
            res = [];
          }
        } else {
          // Fetch all services with provider info
          res = await SupabaseService.db
              .from('services')
              .select('''
            *,
            provider_profiles!services_provider_id_fkey(
              *,
              profiles(*)
            )
          ''')
              .eq('category_id', categoryId)
              .eq('is_active', true);
        }

        setState(() {
          _services = res;
        });
      }
    } catch (e) {
      debugPrint('Error loading services: $e');
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          widget.serviceName,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppTheme.textPrimary,
            size: 20,
          ),
          tooltip: 'العودة',
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Rating filter chips
          if (!_isLoading)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _ratingTiers.map((tier) {
                    final isSelected = _selectedRatingTier == tier;
                    return Padding(
                      padding: EdgeInsets.only(left: 8.w),
                      child: FilterChip(
                        label: Text(tier),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            _selectedRatingTier = selected ? tier : null;
                            _isLoading = true;
                          });
                          _loadServices();
                        },
                        selectedColor: AppTheme.primaryColor.withValues(alpha: 0.2),
                        checkmarkColor: AppTheme.primaryColor,
                        labelStyle: TextStyle(
                          color: isSelected ? AppTheme.primaryColor : AppTheme.textSecondary,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                        side: BorderSide(
                          color: isSelected ? AppTheme.primaryColor : Colors.grey.shade300,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          // Service list
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppTheme.primaryColor),
                  )
                : _services.isEmpty
                ? const Center(
                    child: Text(
                      'لا توجد خدمات متاحة حالياً في هذا القسم',
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
                    itemCount: _services.length,
                    itemBuilder: (context, index) {
                      final service = _services[index];
                      return _buildProviderCard(service, context);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildProviderCard(dynamic service, BuildContext context) {
    final provider = service['provider_profiles'];
    final profile = provider != null ? provider['profiles'] : null;
    final List<dynamic> portfolioImages = provider != null
        ? (provider['portfolio_images'] ?? [])
        : [];

    // Get rating tier
    final ratingTier = provider != null ? (provider['rating_tier'] ?? 'new') : 'new';
    final avgRating = provider != null ? (provider['avg_rating'] ?? 0.0) : 0.0;
    final totalReviews = provider != null ? (provider['total_reviews'] ?? 0) : 0;

    // Use service image if available, else portfolio, else default
    final List<String> images = [];
    if (service['image_url'] != null) {
      images.add(service['image_url']);
    } else if (portfolioImages.isNotEmpty) {
      images.addAll(portfolioImages.map((img) => img.toString()));
    } else {
      images.add(
        'https://images.unsplash.com/photo-1581578731548-c64695cc6952?w=800&q=80',
      );
    }

    return GestureDetector(
      onTap: () {
        if (provider != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  ProviderDetailsScreen(providerId: provider['id']),
            ),
          );
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => BookingScreen(
                serviceId: service['id'].toString(),
                serviceName: service['title'] ?? 'خدمة',
                serviceImage: service['image_url'] ?? 'https://images.unsplash.com/photo-1581578731548-c64695cc6952?w=800&q=80',
                servicePrice: service['price']?.toString() ?? '0',
              ),
            ),
          );
        }
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 24.h),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Work Carousel
            Stack(
              children: [
                CarouselSlider(
                  options: CarouselOptions(
                    height: 200.h,
                    viewportFraction: 1.0,
                    enableInfiniteScroll: images.length > 1,
                  ),
                  items: images.map((img) {
                    return Image.network(
                      img,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      semanticLabel: 'صورة مقدم الخدمة',
                      errorBuilder: (_, __, ___) => Container(
                        color: Colors.grey[200],
                        child: const Icon(
                          Icons.image_not_supported_rounded,
                          color: AppTheme.textSecondary,
                          size: 40,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                Positioned(
                  top: 16,
                  right: 16,
                  child: Row(
                    children: [
                      // Rating tier badge
                      if (provider != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _getTierColor(ratingTier),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _getTierIcon(ratingTier),
                                color: Colors.white,
                                size: 14,
                              ),
                              SizedBox(width: 4),
                              Text(
                                _getTierLabel(ratingTier),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      SizedBox(width: 8),
                      // Price badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${service['price']} ج/س',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Provider Info
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 25.r,
                    backgroundImage:
                        (profile != null && profile['avatar_url'] != null)
                        ? NetworkImage(profile['avatar_url'])
                        : null,
                    backgroundColor: AppTheme.primaryColor.withValues(
                      alpha: 0.1,
                    ),
                    child: (profile == null || profile['avatar_url'] == null)
                        ? const Icon(
                            Icons.verified_user_rounded,
                            color: AppTheme.primaryColor,
                          )
                        : null,
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          service['title'] ?? 'خدمة',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Row(
                          children: [
                            Text(
                              profile != null
                                  ? (profile['full_name'] ?? 'مقدم خدمة')
                                  : 'فريق Faster المعتمد',
                              style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 14,
                              ),
                            ),
                            if (profile?['is_verified'] == true) ...[
                              SizedBox(width: 4),
                              Icon(Icons.verified_rounded, size: 14, color: AppTheme.primaryColor),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            color: AppTheme.tertiaryColor,
                            size: 20,
                          ),
                          SizedBox(width: 4.w),
                          Text(
                            avgRating.toStringAsFixed(1),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          if (totalReviews > 0) ...[
                            SizedBox(width: 4.w),
                            Text(
                              '($totalReviews)',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getTierColor(String tier) {
    switch (tier) {
      case 'gold': return AppTheme.warningColor;
      case 'silver': return AppTheme.textTertiary;
      case 'bronze': return AppTheme.warningColor;
      default: return Colors.grey;
    }
  }

  IconData _getTierIcon(String tier) {
    switch (tier) {
      case 'gold': return Icons.workspace_premium;
      case 'silver': return Icons.verified;
      case 'bronze': return Icons.military_tech;
      default: return Icons.person;
    }
  }

  String _getTierLabel(String tier) {
    switch (tier) {
      case 'gold': return 'ذهبي';
      case 'silver': return 'فضي';
      case 'bronze': return 'برونزي';
      default: return 'جديد';
    }
  }
}
