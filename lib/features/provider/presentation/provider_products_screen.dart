import 'package:flutter/material.dart';
import 'package:flutter/material.dart' show MaterialPageRoute, TextField, InputDecoration, TextInputType;
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/services/supabase_service.dart';

class ProviderProductsScreen extends StatefulWidget {
  const ProviderProductsScreen({super.key});

  @override
  State<ProviderProductsScreen> createState() => _ProviderProductsScreenState();
}

class _ProviderProductsScreenState extends State<ProviderProductsScreen> {
  List<Map<String, dynamic>> _products = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoading = true);
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) return;

      final products = await SupabaseService.db
          .from('products')
          .select()
          .eq('provider_id', userId)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _products = List<Map<String, dynamic>>.from(products);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading products: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showMessage(String msg, {bool isError = false}) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        content: Text(msg),
        actions: [
          TextButton(
            child: const Text('حسنا'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  void _showAddProductDialog() {
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final stockCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إضافة منتج جديد'),
        content: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(hintText: 'اسم المنتج')),
              const SizedBox(height: DesignTokens.space8),
              TextField(controller: priceCtrl, decoration: const InputDecoration(hintText: 'السعر'), keyboardType: TextInputType.number),
              const SizedBox(height: DesignTokens.space8),
              TextField(controller: stockCtrl, decoration: const InputDecoration(hintText: 'المخزون'), keyboardType: TextInputType.number),
              const SizedBox(height: DesignTokens.space8),
              TextField(controller: descCtrl, decoration: const InputDecoration(hintText: 'الوصف (اختياري)'), maxLines: 2),
            ],
          ),
        ),
        actions: [
          TextButton(
            child: const Text('إلغاء'),
            onPressed: () => Navigator.pop(ctx),
          ),
          TextButton(
            child: const Text('إضافة'),
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty || priceCtrl.text.trim().isEmpty) {
                Navigator.pop(ctx);
                _showMessage('أدخل اسم المنتج والسعر', isError: true);
                return;
              }
              Navigator.pop(ctx);
              await _addProduct(
                name: nameCtrl.text.trim(),
                price: double.tryParse(priceCtrl.text.trim()) ?? 0,
                stock: int.tryParse(stockCtrl.text.trim()) ?? 0,
                description: descCtrl.text.trim(),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _addProduct({required String name, required double price, required int stock, String description = ''}) async {
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) return;

      await SupabaseService.db.from('products').insert({
        'provider_id': userId, 'name': name, 'price': price, 'stock': stock, 'description': description, 'is_active': true,
      });

      _loadProducts();
      if (mounted) _showMessage('تمت إضافة المنتج بنجاح');
    } catch (e) {
      debugPrint('Error adding product: $e');
      if (mounted) _showMessage('فشل إضافة المنتج', isError: true);
    }
  }

  void _showEditProductDialog(Map<String, dynamic> product) {
    final nameCtrl = TextEditingController(text: product['name']?.toString() ?? '');
    final priceCtrl = TextEditingController(text: product['price']?.toString() ?? '');
    final stockCtrl = TextEditingController(text: product['stock']?.toString() ?? '');
    final descCtrl = TextEditingController(text: product['description']?.toString() ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تعديل المنتج'),
        content: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(hintText: 'اسم المنتج')),
              const SizedBox(height: DesignTokens.space8),
              TextField(controller: priceCtrl, decoration: const InputDecoration(hintText: 'السعر'), keyboardType: TextInputType.number),
              const SizedBox(height: DesignTokens.space8),
              TextField(controller: stockCtrl, decoration: const InputDecoration(hintText: 'المخزون'), keyboardType: TextInputType.number),
              const SizedBox(height: DesignTokens.space8),
              TextField(controller: descCtrl, decoration: const InputDecoration(hintText: 'الوصف'), maxLines: 2),
            ],
          ),
        ),
        actions: [
          TextButton(child: const Text('إلغاء'), onPressed: () => Navigator.pop(ctx)),
          TextButton(
            child: const Text('حفظ'),
            onPressed: () async {
              Navigator.pop(ctx);
              await _updateProduct(
                productId: product['id'],
                name: nameCtrl.text.trim(),
                price: double.tryParse(priceCtrl.text.trim()) ?? 0,
                stock: int.tryParse(stockCtrl.text.trim()) ?? 0,
                description: descCtrl.text.trim(),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _updateProduct({required dynamic productId, required String name, required double price, required int stock, String description = ''}) async {
    try {
      await SupabaseService.db.from('products').update({
        'name': name, 'price': price, 'stock': stock, 'description': description,
      }).eq('id', productId);

      _loadProducts();
      if (mounted) _showMessage('تم تحديث المنتج');
    } catch (e) {
      debugPrint('Error updating product: $e');
    }
  }

  Future<void> _deleteProduct(dynamic productId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف المنتج'),
        content: const Text('هل أنت متأكد من حذف هذا المنتج؟'),
        actions: [
          TextButton(child: const Text('إلغاء'), onPressed: () => Navigator.pop(ctx, false)),
          TextButton(
            child: const Text('حذف'),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await SupabaseService.db.from('products').delete().eq('id', productId);
      _loadProducts();
      if (mounted) _showMessage('تم حذف المنتج');
    } catch (e) {
      debugPrint('Error deleting product: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(backgroundColor: AppTheme.backgroundColor, body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _products.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inventory_2_rounded, size: 80.sp, color: AppTheme.textSecondary),
                      SizedBox(height: DesignTokens.space16),
                      Text('لا توجد منتجات بعد', style: TextStyle(fontSize: DesignTokens.textTitleMedium, color: AppTheme.textSecondary)),
                      SizedBox(height: DesignTokens.space8),
                      Text('ابدأ بإضافة منتجاتك الآن', style: TextStyle(fontSize: DesignTokens.textLabelMedium, color: AppTheme.textSecondary)),
                      SizedBox(height: DesignTokens.space24),
                      ElevatedButton(
                        onPressed: _showAddProductDialog,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.add_rounded),
                            SizedBox(width: 8),
                            Text('إضافة منتج'),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
              : SafeArea(
                  child: ListView.builder(
                    padding: EdgeInsets.all(DesignTokens.space16),
                    itemCount: _products.length,
                    itemBuilder: (context, index) => _buildProductCard(_products[index]),
                  ),
                ),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product) {
    final imageUrl = product['image_url'] as String?;
    final name = product['name'] as String? ?? '';
    final price = product['price'] as num? ?? 0;
    final stock = product['stock'] as int? ?? 0;
    final isActive = product['is_active'] as bool? ?? true;

    return Container(
      margin: EdgeInsets.only(bottom: DesignTokens.space16),
      padding: EdgeInsets.all(DesignTokens.space16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: DesignTokens.brXl,
        border: Border.all(
          color: isActive ? Colors.grey : AppTheme.errorColor.withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.5),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Product Image
          Container(
            width: 80.w,
            height: 80.h,
            decoration: BoxDecoration(
              color: Colors.grey,
              borderRadius: DesignTokens.brMd,
            ),
            child: imageUrl != null && imageUrl.isNotEmpty
                ? ClipRRect(
                    borderRadius: DesignTokens.brMd,
                    child: Image.network(imageUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Icon(Icons.photo_rounded, color: AppTheme.textSecondary)),
                  )
                : Icon(Icons.photo_rounded, color: AppTheme.textSecondary),
          ),
          SizedBox(width: DesignTokens.space16),
          // Product Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: TextStyle(fontSize: DesignTokens.textTitleMedium, fontWeight: FontWeight.w600, color: AppTheme.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
                SizedBox(height: DesignTokens.space4),
                Text('$price ج.م', style: TextStyle(fontSize: DesignTokens.textLabelLarge, fontWeight: FontWeight.w600, color: AppTheme.primaryColor)),
                SizedBox(height: DesignTokens.space4),
                Row(
                  children: [
                    Icon(Icons.inventory_2_rounded, size: 16.sp, color: stock > 0 ? AppTheme.successColor : AppTheme.errorColor),
                    SizedBox(width: DesignTokens.space4),
                    Text('المخزون: $stock', style: TextStyle(fontSize: DesignTokens.textLabelSmall, color: stock > 0 ? AppTheme.successColor : AppTheme.errorColor)),
                  ],
                ),
              ],
            ),
          ),
          // Actions
          Column(
            children: [
              ElevatedButton(
                child: Padding(
                  padding: EdgeInsets.zero,
                  child: Icon(Icons.edit_rounded, color: AppTheme.primaryColor),
                ),
                onPressed: () => _showEditProductDialog(product),
              ),
              ElevatedButton(
                child: Padding(
                  padding: EdgeInsets.zero,
                  child: Icon(Icons.delete_rounded, color: AppTheme.errorColor),
                ),
                onPressed: () => _deleteProduct(product['id']),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
