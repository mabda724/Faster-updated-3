import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/cart_service.dart';

class ClientSubcategoryScreen extends StatefulWidget {
  final String categoryName;
  final String subcategory;
  final String merchantId;
  final String merchantName;
  const ClientSubcategoryScreen({
    super.key,
    required this.categoryName,
    required this.subcategory,
    required this.merchantId,
    required this.merchantName,
  });

  @override
  State<ClientSubcategoryScreen> createState() => _ClientSubcategoryScreenState();
}

class _ClientSubcategoryScreenState extends State<ClientSubcategoryScreen> {
  List<Map<String, dynamic>> _products = [];
  bool _isLoading = true;
  static const Color _purple = AppTheme.primaryColor;
  static const Color _bgGray = AppTheme.surfaceColor70;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final all = await SupabaseService.db
          .from('products')
          .select()
          .eq('provider_id', widget.merchantId)
          .eq('is_active', true);
      if (!mounted) return;
      final filtered = (List<Map<String, dynamic>>.from(all)).where((p) {
        final name = (p['name'] as String?)?.toLowerCase() ?? '';
        final cat = widget.subcategory;
        if (cat == 'منتجات الألبان') return name.contains('لبن') || name.contains('جبن') || name.contains('زبدة') || name.contains('زبادي') || name.contains('حليب');
        if (cat == 'مياه ومشروبات') return name.contains('ماء') || name.contains('مشروب') || name.contains('عصير');
        if (cat == 'منظفات') return name.contains('منظف') || name.contains('صابون') || name.contains('سائل');
        if (cat == 'حلويات') return name.contains('شوكولاتة') || name.contains('حلوى') || name.contains('بسكويت');
        if (cat == 'العروض') return name.contains('عرض') || name.contains('خصم');
        return true;
      }).toList();
      setState(() => _products = filtered);
    } catch (e) {
      debugPrint('Error: ');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  IconData _productIcon(String name) {
    final n = name.toLowerCase();
    if (n.contains('حليب') || n.contains('لبن')) return Icons.water_drop_rounded;
    if (n.contains('جبن') || n.contains('زبدة') || n.contains('زبادي')) return Icons.egg_rounded;
    if (n.contains('بيض')) return Icons.egg_rounded;
    if (n.contains('زيت')) return Icons.oil_barrel_rounded;
    if (n.contains('سكر') || n.contains('أرز')) return Icons.inventory_2_rounded;
    if (n.contains('ماء') || n.contains('مشروب')) return Icons.water_drop_rounded;
    if (n.contains('صابون') || n.contains('منظف')) return Icons.cleaning_services_rounded;
    return Icons.inventory_2_rounded;
  }

  Color _iconBgColor(String name) {
    final n = name.toLowerCase();
    if (n.contains('حليب') || n.contains('لبن') || n.contains('ماء')) return Colors.blue[50]!;
    if (n.contains('جبن') || n.contains('زبدة') || n.contains('زبادي')) return Colors.yellow[50]!;
    if (n.contains('زيت')) return Colors.amber[50]!;
    if (n.contains('بيض')) return Colors.orange[50]!;
    if (n.contains('صابون') || n.contains('منظف')) return Colors.purple[50]!;
    return Colors.grey[50]!;
  }

  Color _iconColor(String name) {
    final n = name.toLowerCase();
    if (n.contains('حليب') || n.contains('لبن') || n.contains('ماء')) return Colors.blue[500]!;
    if (n.contains('جبن') || n.contains('زبدة') || n.contains('زبادي')) return Colors.yellow[700]!;
    if (n.contains('زيت')) return Colors.amber[600]!;
    if (n.contains('بيض')) return Colors.orange[600]!;
    if (n.contains('صابون') || n.contains('منظف')) return Colors.purple[500]!;
    return Colors.grey[500]!;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: AppTheme.darkBackgroundColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(widget.subcategory, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.sp, color: AppTheme.darkBackgroundColor)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.filter_list_rounded, color: Colors.grey[500], size: 20),
            onPressed: () {},
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _products.isEmpty
              ? Center(child: Text('لا توجد منتجات', style: TextStyle(color: Colors.grey[400])))
              : ListView.builder(
                  padding: EdgeInsets.all(16.w),
                  itemCount: _products.length,
                  itemBuilder: (_, i) {
                    final p = _products[i];
                    final name = (p['name'] as String?) ?? '';
                    final price = (p['price'] as num?)?.toDouble() ?? 0;
                    final imageUrl = p['image_url'] as String?;
                    final desc = (p['description'] as String?) ?? '';
                    final unit = desc.isNotEmpty ? desc : '1 كجم';
                    return Container(
                      margin: EdgeInsets.only(bottom: 10.h),
                      padding: EdgeInsets.all(10.w),
                      decoration: BoxDecoration(color: _bgGray, borderRadius: BorderRadius.circular(16.r), border: Border.all(color: Colors.grey[100]!)),
                      child: Row(
                        children: [
                          Container(
                            width: 48, height: 48,
                            decoration: BoxDecoration(color: _iconBgColor(name), borderRadius: BorderRadius.circular(12.r), border: Border.all(color: _iconBgColor(name).withValues(alpha: 0.5))),
                            child: imageUrl != null
                                ? ClipRRect(borderRadius: BorderRadius.circular(12.r), child: Image.network(imageUrl, fit: BoxFit.cover))
                                : Icon(_productIcon(name), color: _iconColor(name), size: 20),
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.sp, color: AppTheme.darkBackgroundColor)),
                                SizedBox(height: 4.h),
                                Text(' ج',
                                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10.sp, color: _purple)),
                              ],
                            ),
                          ),
                          InkWell(
                            onTap: () {
                              CartService().add(CartItem(
                                id: p['id'].toString(), name: name, price: price,
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
                              width: 24, height: 24,
                              decoration: BoxDecoration(color: _purple, borderRadius: BorderRadius.circular(8.r)),
                              child: const Icon(Icons.add, color: Colors.white, size: 14),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
