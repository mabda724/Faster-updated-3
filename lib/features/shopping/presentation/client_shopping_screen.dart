import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/services/supabase_service.dart';

class ClientShoppingScreen extends StatefulWidget {
  const ClientShoppingScreen({super.key});

  @override
  State<ClientShoppingScreen> createState() => _ClientShoppingScreenState();
}

class _ClientShoppingScreenState extends State<ClientShoppingScreen> {
  List<Map<String, dynamic>> _sellers = [];
  List<Map<String, dynamic>> _products = [];
  bool _isLoading = true;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final sellers = await SupabaseService.db
          .from('provider_profiles')
          .select('*, profiles(full_name)')
          .eq('provider_type', 'seller')
          .eq('is_verified', true)
          .limit(20);
      final products = await SupabaseService.db
          .from('products')
          .select('*, provider_profiles(profiles(full_name))')
          .eq('is_active', true)
          .limit(20);
      if (!mounted) return;
      _sellers = List<Map<String, dynamic>>.from(sellers);
      _products = List<Map<String, dynamic>>.from(products);
    } catch (e) {
      debugPrint('Error loading shopping data: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('تسوق'),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: EdgeInsets.all(16.w),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'ابحث عن منتجات...',
                      prefixIcon: const Icon(Icons.search_rounded),
                      border: OutlineInputBorder(
                        borderRadius: DesignTokens.brLg,
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: AppTheme.backgroundColor,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                Expanded(
                  child: CustomScrollView(
                    slivers: [
                      // Sellers section
                      if (_sellers.isNotEmpty) ...[
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 8.h),
                            child: Text('المتاجر',
                                style: TextStyle(
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textPrimary,
                                )),
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: SizedBox(
                            height: 100.h,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              padding: EdgeInsets.symmetric(horizontal: 16.w),
                              itemCount: _sellers.length,
                              itemBuilder: (_, i) {
                                final s = _sellers[i];
                                final p = s['profiles'] as Map?;
                                final name = p?['full_name'] ?? 'متجر';
                                return Container(
                                  width: 80.w,
                                  margin: EdgeInsets.only(left: 12.w),
                                  child: Column(
                                    children: [
                                      Container(
                                        width: 56,
                                        height: 56,
                                        decoration: BoxDecoration(
                                          color: AppTheme.primaryColor
                                              .withValues(alpha: 0.1),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(Icons.person_circle_rounded,
                                            color: AppTheme.primaryColor, size: 28),
                                      ),
                                      SizedBox(height: 4.h),
                                      Text(name,
                                          style: TextStyle(fontSize: 11.sp),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          textAlign: TextAlign.center),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                      // Products grid
                      if (_products.isNotEmpty) ...[
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 8.h),
                            child: Text('المنتجات',
                                style: TextStyle(
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textPrimary,
                                )),
                          ),
                        ),
                        SliverPadding(
                          padding: EdgeInsets.symmetric(horizontal: 16.w),
                          sliver: SliverGrid.builder(
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              childAspectRatio: 0.7,
                              crossAxisSpacing: 12.w,
                              mainAxisSpacing: 12.h,
                            ),
                            itemCount: _products.length,
                            itemBuilder: (_, i) {
                              final p = _products[i];
                              final name = p['name'] ?? p['title'] ?? 'منتج';
                              final price = p['price'] ?? 0;
                              return Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: DesignTokens.brLg,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.04),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Container(
                                        width: double.infinity,
                                        decoration: BoxDecoration(
                                          color: AppTheme.primaryColor
                                              .withValues(alpha: 0.05),
                                          borderRadius: BorderRadius.only(
                                              topLeft: Radius.circular(DesignTokens.radiusLg),
                                              topRight: Radius.circular(DesignTokens.radiusLg)),
                                        ),
                                        child: Center(
                                          child: Icon(Icons.photo_rounded,
                                              color: AppTheme.primaryColor
                                                  .withValues(alpha: 0.3),
                                              size: 40),
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: EdgeInsets.all(8.w),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(name,
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12.sp,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis),
                                          SizedBox(height: 4.h),
                                          Text('$price ج.م',
                                              style: TextStyle(
                                                color: AppTheme.primaryColor,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13.sp,
                                              )),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                      SliverToBoxAdapter(child: SizedBox(height: 24.h)),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
