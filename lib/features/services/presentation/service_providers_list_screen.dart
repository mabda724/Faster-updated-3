import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/services/supabase_service.dart';
import '../../provider/presentation/provider_details_screen.dart';

class ServiceProvidersListScreen extends StatefulWidget {
  final int serviceId;
  final String serviceTitle;
  final String serviceImage;
  final String servicePrice;
  final String categoryName;

  const ServiceProvidersListScreen({
    super.key,
    required this.serviceId,
    required this.serviceTitle,
    required this.serviceImage,
    required this.servicePrice,
    required this.categoryName,
  });

  @override
  State<ServiceProvidersListScreen> createState() =>
      _ServiceProvidersListScreenState();
}

class _ServiceProvidersListScreenState
    extends State<ServiceProvidersListScreen> {
  List<Map<String, dynamic>> _providers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProviders();
  }

  Future<void> _loadProviders() async {
    try {
      // Get providers who offer this service via provider_services junction
      final res = await SupabaseService.db
          .from('provider_services')
          .select('''
            provider_id,
            provider_profiles!prov_services_provider_id_fkey(
              id,
              rating,
              is_online,
              portfolio_images,
                profiles(full_name, avatar_url, is_verified)
            )
          ''')
          .eq('service_id', widget.serviceId);

      if (mounted) {
        setState(() {
          _providers = List<Map<String, dynamic>>.from(res);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading providers: $e');
      if (mounted) setState(() => _isLoading = false);
    }
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
          widget.serviceTitle,
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
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor),
            )
          : _providers.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
              itemCount: _providers.length,
              itemBuilder: (context, index) =>
                  _buildProviderCard(_providers[index]),
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_search_outlined, size: 80, color: Colors.grey[300]),
          const SizedBox(height: DesignTokens.space16),
          const Text(
            'لا يوجد مقدمي خدمة لهذه الخدمة حالياً',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: DesignTokens.space8),
          const Text(
            'يمكنك طلب الخدمة وسيتم إشعار المقدمين المناسبين',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildProviderCard(Map<String, dynamic> item) {
    final provider = item['provider_profiles'];
    if (provider == null) return const SizedBox.shrink();

    final profile = provider['profiles'] ?? {};
    final fullName = profile['full_name'] ?? 'مقدم خدمة';
    final avatarUrl = profile['avatar_url'];
    final rating = provider['rating']?.toString() ?? '0.0';
    final isOnline = provider['is_online'] ?? false;
    final isVerified = profile['is_verified'] == true;
    final portfolioImages = provider['portfolio_images'] ?? [];

    return Container(
      margin: EdgeInsets.only(bottom: 20.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Portfolio images carousel
          if (portfolioImages.isNotEmpty)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
              child: SizedBox(
                height: 180.h,
                child: PageView.builder(
                  itemCount: portfolioImages.length,
                  itemBuilder: (context, imgIndex) {
                    return Image.network(
                      portfolioImages[imgIndex],
                      width: double.infinity,
                      fit: BoxFit.cover,
                      semanticLabel: 'صورة مقدم الخدمة',
                      errorBuilder: (_, __, ___) => Container(
                        color: AppTheme.backgroundColor,
                        child: Icon(
                          Icons.image_not_supported,
                          color: Colors.grey[400],
                        ),
                      ),
                    );
                  },
                ),
              ),
            )
          else
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
              child: Container(
                height: 180.h,
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                child: Center(
                  child: Icon(
                    Icons.workspace_premium,
                    size: 60,
                    color: AppTheme.primaryColor.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ),

          // Provider info
          Padding(
            padding: const EdgeInsets.all(DesignTokens.space16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 28.r,
                      backgroundImage: avatarUrl != null
                          ? NetworkImage(avatarUrl)
                          : null,
                      backgroundColor: AppTheme.primaryColor.withValues(
                        alpha: 0.1,
                      ),
                      child: avatarUrl == null
                          ? Icon(
                              Icons.person,
                              size: 28,
                              color: AppTheme.primaryColor,
                            )
                          : null,
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  fullName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: AppTheme.textPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isVerified) ...[
                                SizedBox(width: DesignTokens.space4),
                                Icon(Icons.verified_rounded, size: 14, color: AppTheme.primaryColor),
                              ],
                            ],
                          ),
                          SizedBox(height: 4.h),
                          Row(
                            children: [
                              if (isOnline)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'متصل',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                    ),
                                  ),
                                )
                              else
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.grey,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'غير متصل',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                              SizedBox(width: 8.w),
                              Row(
                                children: [
                                  Icon(
                                    Icons.star_rounded,
                                    color: AppTheme.tertiaryColor,
                                    size: 16,
                                  ),
                                  SizedBox(width: 2.w),
                                  Text(
                                    rating,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16.h),
                Row(
                  children: [
                    Icon(
                      Icons.attach_money_rounded,
                      color: AppTheme.primaryColor,
                      size: 18,
                    ),
                    SizedBox(width: 4.w),
                    Text(
                      '${widget.servicePrice} جنيه',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    SizedBox(width: 16.w),
                    Icon(
                      Icons.category_rounded,
                      color: AppTheme.textSecondary,
                      size: 16,
                    ),
                    SizedBox(width: 4.w),
                    Expanded(
                      child: Text(
                        widget.categoryName,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16.h),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              ProviderDetailsScreen(providerId: provider['id']),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'عرض الملف الشخصي',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
