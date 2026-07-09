import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/services/supabase_service.dart';
import '../../booking/presentation/service_details_screen.dart';

class ServicesScreen extends StatefulWidget {
  final int? initialCategoryId;
  final String? searchQuery;
  
  const ServicesScreen({super.key, this.initialCategoryId, this.searchQuery});
  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  List<Map<String, dynamic>> _services = [];
  List<Map<String, dynamic>> _categories = [];
  Set<int> _favoriteServiceIds = {};
  int? _selectedCategoryId;
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _selectedCategoryId = widget.initialCategoryId;
    _searchQuery = widget.searchQuery ?? '';
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..forward();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final cats = await SupabaseService.db.from('categories').select().order('name_ar');
      _categories = List<Map<String, dynamic>>.from(cats);
      await _loadServices();
      await _loadFavorites();
    } catch (e) {
      debugPrint('Error loading data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadFavorites() async {
    try {
      final uid = SupabaseService.currentUserId;
      if (uid == null) return;
      final favs = await SupabaseService.db
          .from('favorite_services')
          .select('service_id')
          .eq('client_id', uid);
      if (mounted) {
        setState(() {
          _favoriteServiceIds = favs.map<int>((f) => f['service_id'] as int).toSet();
        });
      }
    } catch (_) {}
  }

  Future<void> _toggleFavorite(int serviceId) async {
    final uid = SupabaseService.currentUserId;
    if (uid == null) return;
    try {
      if (_favoriteServiceIds.contains(serviceId)) {
        await SupabaseService.db
            .from('favorite_services')
            .delete()
            .eq('client_id', uid)
            .eq('service_id', serviceId);
        setState(() => _favoriteServiceIds.remove(serviceId));
      } else {
        await SupabaseService.db
            .from('favorite_services')
            .insert({
              'client_id': uid,
              'service_id': serviceId,
            });
        setState(() => _favoriteServiceIds.add(serviceId));
      }
    } catch (_) {}
  }

  Future<void> _loadServices() async {
    setState(() => _isLoading = true);
    try {
      var query = SupabaseService.db.from('services').select('''
        *,
        categories(name_ar, name_en)
      ''').eq('is_active', true);

      if (_selectedCategoryId != null) {
        query = query.eq('category_id', _selectedCategoryId!);
      }

      final res = await query.order('created_at', ascending: false);

      final enriched = <Map<String, dynamic>>[];
      for (final s in res) {
        final provCount = await SupabaseService.db
            .from('provider_services')
            .select('provider_id')
            .eq('service_id', s['id']);
        enriched.add({
          ...s,
          'provider_count': provCount.length,
        });
      }

      if (mounted) {
        setState(() {
          _services = enriched;
          _isLoading = false;
        });
        _animController.reset();
        _animController.forward();
      }
    } catch (e) {
      debugPrint('Error loading services: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  IconData _getIcon(String name) {
    if (name.contains('تنظيف')) return Icons.cleaning_services_rounded;
    if (name.contains('كهرباء')) return Icons.electrical_services_rounded;
    if (name.contains('سباكة')) return Icons.plumbing_rounded;
    if (name.contains('صيانة')) return Icons.home_repair_service_rounded;
    if (name.contains('نقل')) return Icons.local_shipping_rounded;
    if (name.contains('دهان')) return Icons.format_paint_rounded;
    if (name.contains('حشر')) return Icons.pest_control_rounded;
    if (name.contains('حدائق')) return Icons.yard_rounded;
    if (name.contains('تكييف')) return Icons.ac_unit_rounded;
    return Icons.miscellaneous_services_rounded;
  }

  String _getServiceImage(Map<String, dynamic> service) {
    final imageUrl = service['image_url'];
    if (imageUrl != null && imageUrl.toString().startsWith('http')) {
      return imageUrl.toString();
    }
    return 'https://images.unsplash.com/photo-1581578731548-c64695cc6952?w=400&q=80';
  }

  List<Map<String, dynamic>> get _filteredServices {
    if (_searchQuery.isEmpty) return _services;
    return _services.where((s) {
      final title = (s['title'] ?? '').toString().toLowerCase();
      final cat = (s['categories']?['name_ar'] ?? '').toString().toLowerCase();
      final q = _searchQuery.toLowerCase();
      return title.contains(q) || cat.contains(q);
    }).toList();
  }

  @override
  void dispose() { _animController.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(24.w, 16.h, 24.w, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('الخدمات', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                        SizedBox(height: 4.h),
                        Text('${_services.length} خدمة متاحة', style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
                      ]),
                    ],
                  ),
                  SizedBox(height: 16.h),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 16.w),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.textPrimary.withValues(alpha: 0.08)),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))],
                    ),
                    child: TextField(
                      onChanged: (v) => setState(() => _searchQuery = v),
                      decoration: const InputDecoration(
                        hintText: 'ابحث عن خدمة...',
                        border: InputBorder.none,
                        prefixIcon: Icon(Icons.search_rounded, color: AppTheme.primaryColor),
                        hintStyle: TextStyle(color: AppTheme.textSecondary),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 12.h),
            SizedBox(
              height: 44,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: 20.w),
                itemCount: _categories.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    final isSelected = _selectedCategoryId == null;
                    return Semantics(
                      label: 'الكل',
                      child: GestureDetector(
                      onTap: () {
                        setState(() => _selectedCategoryId = null);
                        _loadServices();
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: EdgeInsets.only(right: 10.w),
                        padding: EdgeInsets.symmetric(horizontal: DesignTokens.space10, vertical: 10),
                        decoration: BoxDecoration(
                          gradient: isSelected ? AppTheme.primaryGradient : null,
                          color: isSelected ? null : AppTheme.surfaceColor,
                          borderRadius: BorderRadius.circular(22),
                          border: isSelected ? null : Border.all(color: AppTheme.textPrimary.withValues(alpha: 0.1)),
                        ),
                        child: Text('الكل', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isSelected ? AppTheme.surfaceColor : AppTheme.textSecondary)),
                      ),
                    ),
                    );
                  }
                  final cat = _categories[index - 1];
                  final isSelected = _selectedCategoryId == cat['id'];
                  return Semantics(
                    label: cat['name_ar'] ?? '',
                    child: GestureDetector(
                    onTap: () {
                      setState(() => _selectedCategoryId = cat['id']);
                      _loadServices();
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: EdgeInsets.only(right: 10.w),
                      padding: EdgeInsets.symmetric(horizontal: DesignTokens.space10, vertical: 10),
                      decoration: BoxDecoration(
                        gradient: isSelected ? AppTheme.primaryGradient : null,
                        color: isSelected ? null : AppTheme.surfaceColor,
                        borderRadius: BorderRadius.circular(22),
                        border: isSelected ? null : Border.all(color: AppTheme.textPrimary.withValues(alpha: 0.1)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_getIcon(cat['name_ar'] ?? ''), size: 16, color: isSelected ? AppTheme.surfaceColor : AppTheme.textSecondary),
                          SizedBox(width: 6.w),
                          Text(cat['name_ar'] ?? '', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isSelected ? AppTheme.surfaceColor : AppTheme.textSecondary)),
                        ],
                      ),
                    ),
                  ),
                  );
                },
              ),
            ),
            SizedBox(height: 8.h),
            Expanded(
              child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
                : _filteredServices.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off_rounded, size: 64, color: AppTheme.textTertiary),
                          SizedBox(height: 12.h),
                          const Text('لا توجد خدمات متاحة', style: TextStyle(color: AppTheme.textSecondary, fontSize: 16)),
                        ],
                      ),
                    )
                  : GridView.builder(
                      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 16.w, mainAxisSpacing: 16.h, childAspectRatio: 0.72),
                      itemCount: _filteredServices.length,
                      itemBuilder: (context, index) => _buildServiceCard(_filteredServices[index], index),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceCard(Map<String, dynamic> service, int index) {
    final title = service['title'] ?? '';
    final category = service['categories'] ?? {};
    final categoryName = category['name_ar'] ?? category['name_en'] ?? '';
    final price = service['price']?.toString() ?? '0';
    final imageUrl = _getServiceImage(service);
    final providerCount = service['provider_count'] ?? 0;
    final rating = (service['rating'] as num?)?.toDouble() ?? 0.0;
    final reviewsCount = (service['reviews_count'] as num?)?.toInt() ?? 0;

    return AnimatedBuilder(
      animation: _animController,
      builder: (context, child) {
        final delay = index * 0.06;
        final v = Curves.easeOutBack.transform((_animController.value - delay).clamp(0.0, 1.0));
        return Transform.translate(offset: Offset(0, 30 * (1 - v)), child: Opacity(opacity: v.clamp(0.0, 1.0), child: child));
      },
      child: Semantics(
        label: 'تفاصيل الخدمة',
        child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ServiceDetailsScreen(
                serviceName: title,
                imageUrl: imageUrl,
                price: price,
                rating: rating,
                reviewsCount: reviewsCount,
                serviceId: service['id'].toString(),
              ),
            ),
          );
        },
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.textPrimary.withValues(alpha: 0.06)),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 3,
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                      child: Image.network(
                        imageUrl,
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.cover,
                        semanticLabel: 'صورة الخدمة',
                        errorBuilder: (c, e, s) => Container(
                          color: AppTheme.primaryColor.withValues(alpha: 0.1),
                          child: Center(child: Icon(_getIcon(categoryName), size: 40, color: AppTheme.primaryColor)),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(color: AppTheme.primaryColor, borderRadius: BorderRadius.circular(12)),
                        child: Text('$price ج', style: const TextStyle(color: AppTheme.surfaceColor, fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    // Favorite star button
                    Positioned(
                      bottom: 10,
                      right: 10,
                      child: Semantics(
                        label: 'المفضلة',
                        child: GestureDetector(
                        onTap: () => _toggleFavorite(service['id'] as int),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceColor,
                            shape: BoxShape.circle,
                            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 4)],
                          ),
                          child: Icon(
                            _favoriteServiceIds.contains(service['id'])
                                ? Icons.star_rounded
                                : Icons.star_border_rounded,
color: _favoriteServiceIds.contains(service['id'])
                                ? Colors.amber
                                : AppTheme.textSecondary,
                            size: 20,
                          ),
                        ),
                      ),
                      ),
                    ),
                    // Provider count badge
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: DesignTokens.space4, vertical: 
                        DesignTokens.space2),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.flash_on_rounded, color: AppTheme.surfaceColor, size: 12),
                            SizedBox(width: 3.w),
                            Text('$providerCount متاح', style: const TextStyle(color: AppTheme.surfaceColor, fontSize: 11, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: DesignTokens.space6, vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textPrimary),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 4.h),
                      Row(
                        children: [
                          Icon(Icons.category_outlined, size: 12, color: AppTheme.textSecondary),
                          SizedBox(width: 4.w),
                          Expanded(
                            child: Text(
                              categoryName,
                              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 6.h),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 10, vertical: DesignTokens.space2),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.send_rounded, size: 12, color: AppTheme.primaryColor),
                            SizedBox(width: 4.w),
                            Text(
                              'احجز الآن',
                              style: TextStyle(fontSize: 11, color: AppTheme.primaryColor, fontWeight: FontWeight.bold),
                            ),
                          ],
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
    );
  }
}