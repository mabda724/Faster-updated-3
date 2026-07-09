import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/cart_service.dart';
import 'client_subcategory_screen.dart';

class ClientStoreScreen extends StatefulWidget {
  final String merchantId;
  final String merchantName;
  final double merchantRating;
  final String? merchantLogo;
  const ClientStoreScreen({
    super.key,
    required this.merchantId,
    required this.merchantName,
    this.merchantRating = 0,
    this.merchantLogo,
  });

  @override
  State<ClientStoreScreen> createState() => _ClientStoreScreenState();
}

class _ClientStoreScreenState extends State<ClientStoreScreen> {
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _isLoading = true;
  final _searchCtrl = TextEditingController();
  String? _selectedSubCat;

  static const Color _purple = AppTheme.primaryColor;
  static const Color _bgGray = AppTheme.surfaceColor70;

  final _subCategories = ['حلويات', 'منظفات', 'منتجات الألبان', 'مياه ومشروبات', 'العروض'];

  @override
  void initState() {
    super.initState();
    _load();
    _searchCtrl.addListener(_filter);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final res = await SupabaseService.db
          .from('products')
          .select()
          .eq('provider_id', widget.merchantId)
          .eq('is_active', true)
          .order('created_at', ascending: false);
      if (!mounted) return;
      _products = List<Map<String, dynamic>>.from(res);
      _filter();
    } catch (e) {
      debugPrint('Error loading products: ');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  void _filter() {
    final query = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      if (_selectedSubCat != null) {
        _filtered = _products.where((p) {
          final name = (p['name'] as String?)?.toLowerCase() ?? '';
          final matchSearch = query.isEmpty || name.contains(query);
          return matchSearch && _matchesSubCat(name, _selectedSubCat!);
        }).toList();
      } else {
        _filtered = _products.where((p) {
          final name = (p['name'] as String?)?.toLowerCase() ?? '';
          return query.isEmpty || name.contains(query);
        }).toList();
      }
    });
  }

  bool _matchesSubCat(String name, String cat) {
    if (cat == 'منتجات الألبان') return name.contains('لبن') || name.contains('جبن') || name.contains('زبدة') || name.contains('زبادي') || name.contains('حليب');
    if (cat == 'مياه ومشروبات') return name.contains('ماء') || name.contains('مشروب') || name.contains('عصير');
    if (cat == 'منظفات') return name.contains('منظف') || name.contains('صابون') || name.contains('سائل');
    if (cat == 'حلويات') return name.contains('شوكولاتة') || name.contains('حلوى') || name.contains('بسكويت');
    if (cat == 'العروض') return name.contains('عرض') || name.contains('خصم');
    return false;
  }

  IconData _subIcon(String cat) {
    switch (cat) {
      case 'حلويات': return Icons.cake_rounded;
      case 'منظفات': return Icons.soap_rounded;
      case 'منتجات الألبان': return Icons.egg_rounded;
      case 'مياه ومشروبات': return Icons.local_drink_rounded;
      case 'العروض': return Icons.local_offer_rounded;
      default: return Icons.category_rounded;
    }
  }

  Color _subIconBg(String cat) {
    switch (cat) {
      case 'حلويات': return AppTheme.surfaceColor;
      case 'منظفات': return AppTheme.backgroundColor;
      case 'منتجات الألبان': return AppTheme.backgroundColor;
      case 'مياه ومشروبات': return AppTheme.backgroundColor;
      case 'العروض': return AppTheme.surfaceColor;
      default: return _bgGray;
    }
  }

  Color _subIconColor(String cat) {
    switch (cat) {
      case 'حلويات': return AppTheme.warningColor;
      case 'منظفات': return AppTheme.primaryColor;
      case 'منتجات الألبان': return Colors.blue;
      case 'مياه ومشروبات': return Colors.red;
      case 'العروض': return AppTheme.warningColor;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Status bar
          Container(
            padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
            color: Colors.white,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('9:41', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  Row(children: [
                    const Icon(Icons.signal_cellular_alt, size: 14), SizedBox(width: 4.w),
                    const Icon(Icons.wifi, size: 14), SizedBox(width: 4.w),
                    const Icon(Icons.battery_full, size: 16),
                  ]),
                ],
              ),
            ),
          ),
          // Header
          Container(
            color: Colors.white,
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                InkWell(onTap: () => Navigator.pop(context), child: Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(color: _bgGray, shape: BoxShape.circle),
                  child: const Icon(Icons.arrow_back_rounded, size: 14),
                )),
                Column(
                  children: [
                    Text(widget.merchantName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.darkBackgroundColor)),
                    SizedBox(height: 2.h),
                    Row(children: [
                      Icon(Icons.star_rounded, size: 10, color: Colors.amber[400]),
                      SizedBox(width: 2.w),
                      Text('  •  25 - 35 دقيقة',
                          style: TextStyle(fontSize: 10.sp, color: Colors.grey[400])),
                    ]),
                  ],
                ),
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(12.r)),
                  child: Center(
                    child: Text(widget.merchantName.isNotEmpty ? widget.merchantName[0].toUpperCase() : 'M',
                        style: TextStyle(color: Colors.blue[700], fontSize: 10.sp, fontWeight: FontWeight.w900)),
                  ),
                ),
              ],
            ),
          ),
          // Search
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
            child: Container(
              decoration: BoxDecoration(color: _bgGray, borderRadius: BorderRadius.circular(12.r)),
              child: TextField(
                controller: _searchCtrl,
                textDirection: TextDirection.rtl,
                decoration: InputDecoration(
                  hintText: 'ابحث عن منتج...',
                  hintTextDirection: TextDirection.rtl,
                  hintStyle: TextStyle(fontSize: 11.sp, color: Colors.grey[400]),
                  prefixIcon: Icon(Icons.search_rounded, color: Colors.grey[400], size: 16),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 10.h),
                  filled: true,
                  fillColor: _bgGray,
                ),
              ),
            ),
          ),
          // Subcategory chips
          Container(
            height: 72.h,
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: List.generate(_subCategories.length, (i) {
                final cat = _subCategories[i];
                return GestureDetector(
                  onTap: () {
                    _selectedSubCat = cat;
                    Navigator.push(context, MaterialPageRoute(builder: (_) => ClientSubcategoryScreen(
                      categoryName: widget.merchantName,
                      subcategory: cat,
                      merchantId: widget.merchantId,
                      merchantName: widget.merchantName,
                    ))).then((_) {
                      _selectedSubCat = null;
                    });
                  },
                  child: Container(
                    width: 64.w,
                    margin: EdgeInsets.only(left: 8.w),
                    child: Column(
                      children: [
                        Container(
                          width: 44, height: 44,
                          decoration: BoxDecoration(color: _subIconBg(cat), borderRadius: BorderRadius.circular(16.r)),
                          child: Icon(_subIcon(cat), color: _subIconColor(cat), size: 20),
                        ),
                        SizedBox(height: 6.h),
                        Text(cat, style: TextStyle(
                          fontSize: 10.sp, fontWeight: FontWeight.bold,
                          color: cat == 'منتجات الألبان' ? _purple : Colors.grey[600],
                        )),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
          // Promo banner
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: Container(
              height: 110.h,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AppTheme.infoColor, AppTheme.primaryColor]),
                borderRadius: BorderRadius.circular(16.r),
              ),
              child: Stack(
                children: [
                  Padding(
                    padding: EdgeInsets.all(16.w),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('خصم يصل إلى 30%',
                            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14.sp, color: Colors.white)),
                        SizedBox(height: 8.h),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8.r)),
                          child: Text('تسوق الآن',
                              style: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.bold, color: AppTheme.infoColor)),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    left: 12, top: 0, bottom: 0,
                    child: Icon(Icons.shopping_basket_rounded, color: Colors.white.withValues(alpha: 0.15), size: 64),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 12.h),
          // Products header
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: Row(
              children: [
                Text('الأكثر مبيعاً  ()',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.sp, color: AppTheme.darkBackgroundColor)),
              ],
            ),
          ),
          SizedBox(height: 8.h),
          // Products grid
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                    ? Center(child: Text(_searchCtrl.text.isNotEmpty ? 'لا توجد نتائج' : 'لا توجد منتجات', style: TextStyle(color: Colors.grey[400], fontWeight: FontWeight.bold)))
                    : GridView.builder(
                        padding: EdgeInsets.symmetric(horizontal: 16.w),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                          childAspectRatio: 0.6,
                        ),
                        itemCount: _filtered.length,
                        itemBuilder: (_, i) => _buildProductCard(_filtered[i]),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product) {
    final name = (product['name'] as String?) ?? '';
    final price = (product['price'] as num?)?.toDouble() ?? 0;
    final imageUrl = product['image_url'] as String?;
    final desc = (product['description'] as String?) ?? '';
    final unit = desc.isNotEmpty ? desc : '1 كجم';

    return Container(
      padding: EdgeInsets.all(8.w),
      decoration: BoxDecoration(color: _bgGray, borderRadius: BorderRadius.circular(16.r), border: Border.all(color: Colors.grey[100]!)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12.r)),
              child: imageUrl != null
                  ? ClipRRect(borderRadius: BorderRadius.circular(12.r), child: Image.network(imageUrl, fit: BoxFit.cover))
                  : Icon(Icons.image_rounded, color: Colors.grey[300], size: 28),
            ),
          ),
          SizedBox(height: 4.h),
          Text(name, maxLines: 2, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10.sp, color: AppTheme.darkBackgroundColor)),
          Text(unit, style: TextStyle(fontSize: 9.sp, color: Colors.grey[400])),
          SizedBox(height: 4.h),
          Container(
            padding: EdgeInsets.all(4.w),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8.r)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(' ج',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 9.sp, color: _purple)),
                InkWell(
                  onTap: () {
                    CartService().add(CartItem(
                      id: product['id'].toString(), name: name, price: price,
                      imageUrl: imageUrl, unit: unit,
                      merchantId: widget.merchantId, merchantName: widget.merchantName,
                    ));
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('تمت الإضافة', style: TextStyle(fontSize: 11.sp)),
                      duration: const Duration(seconds: 1),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                      margin: EdgeInsets.all(16.w),
                    ));
                  },
                  child: Container(
                    width: 20, height: 20,
                    decoration: BoxDecoration(color: _purple, borderRadius: BorderRadius.circular(6.r)),
                    child: const Icon(Icons.add, color: Colors.white, size: 12),
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
