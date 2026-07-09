import 'dart:io';
import '../../../core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/services/supabase_service.dart';

class SellerProductsScreen extends StatefulWidget {
  const SellerProductsScreen({super.key});

  @override
  State<SellerProductsScreen> createState() => _SellerProductsScreenState();
}

class _SellerProductsScreenState extends State<SellerProductsScreen> {
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _subcategories = [];
  Map<int, double> _activeDiscounts = {};
  bool _isLoading = true;
  String? _filterSubCat;

  static const Color _purple = AppTheme.primaryColor;
  static const Color _bgGray = AppTheme.surfaceColor70;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _isLoading = true);
    try {
      final uid = SupabaseService.currentUserId;
      if (uid == null) return;

      final results = await Future.wait([
        SupabaseService.db.from('products').select().eq('provider_id', uid).order('created_at', ascending: false),
        SupabaseService.db.from('product_subcategories').select().eq('provider_id', uid).eq('is_active', true).order('sort_order'),
        SupabaseService.db.from('merchant_discounts').select().eq('provider_id', uid).eq('is_active', true),
      ]);

      if (!mounted) return;
      _products = List<Map<String, dynamic>>.from(results[0]);
      _subcategories = List<Map<String, dynamic>>.from(results[1]);
      final discounts = List<Map<String, dynamic>>.from(results[2]);
      for (final d in discounts) {
        final pid = d['product_id'] as int?;
        final pct = (d['discount_percent'] as num?)?.toDouble();
        if (pid != null && pct != null) _activeDiscounts[pid] = pct;
      }
    } catch (e) {
      debugPrint('Load error: ');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  List<Map<String, dynamic>> get _filtered {
    if (_filterSubCat == null) return _products;
    return _products.where((p) => p['subcategory_id']?.toString() == _filterSubCat).toList();
  }

  Future<String?> _uploadImage(XFile file) async {
    try {
      final bytes = await file.readAsBytes();
      final fileName = 'products//.jpg';
      await SupabaseService.db.storage.from('booking-photos').uploadBinary(fileName, bytes);
      return SupabaseService.db.storage.from('booking-photos').getPublicUrl(fileName);
    } catch (e) {
      debugPrint('Upload error: ');
      return null;
    }
  }

  void _showProductDialog({Map<String, dynamic>? product}) {
    final nameCtrl = TextEditingController(text: product?['name'] ?? '');
    final priceCtrl = TextEditingController(text: product?['price']?.toString() ?? '');
    final stockCtrl = TextEditingController(text: product?['stock']?.toString() ?? '1');
    final descCtrl = TextEditingController(text: product?['description'] ?? '');
    int? subcatId = product?['subcategory_id'] as int?;
    XFile? newImage;
    bool saving = false;
    final isEdit = product != null;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
          title: Text(isEdit ? '????? ??????' : '????? ????', textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.sp, color: AppTheme.darkBackgroundColor)),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: nameCtrl, textDirection: TextDirection.rtl,
                  decoration: InputDecoration(hintText: '??? ?????? *', hintTextDirection: TextDirection.rtl,
                      filled: true, fillColor: _bgGray, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: BorderSide.none))),
              SizedBox(height: 8.h),
              Row(children: [
                Expanded(child: TextField(controller: priceCtrl, keyboardType: TextInputType.number, textDirection: TextDirection.rtl,
                    decoration: InputDecoration(hintText: '????? *', hintTextDirection: TextDirection.rtl,
                        filled: true, fillColor: _bgGray, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: BorderSide.none)))),
                SizedBox(width: 8.w),
                Expanded(child: TextField(controller: stockCtrl, keyboardType: TextInputType.number, textDirection: TextDirection.rtl,
                    decoration: InputDecoration(hintText: '???????', hintTextDirection: TextDirection.rtl,
                        filled: true, fillColor: _bgGray, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: BorderSide.none)))),
              ]),
              SizedBox(height: 8.h),
              TextField(controller: descCtrl, maxLines: 2, textDirection: TextDirection.rtl,
                  decoration: InputDecoration(hintText: '?????', hintTextDirection: TextDirection.rtl,
                      filled: true, fillColor: _bgGray, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: BorderSide.none))),
              SizedBox(height: 8.h),
              // Subcategory dropdown
              if (_subcategories.isNotEmpty)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12.w),
                  decoration: BoxDecoration(color: _bgGray, borderRadius: BorderRadius.circular(12.r)),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int?>(
                      value: subcatId,
                      isExpanded: true,
                      hint: const Text('???? ????? ????'),
                      items: [const DropdownMenuItem(value: null, child: Text('???? ?????')), ..._subcategories.map((s) => DropdownMenuItem(value: s['id'] as int, child: Text(s['name'] as String)))],
                      onChanged: (v) => setDialogState(() => subcatId = v),
                    ),
                  ),
                ),
              SizedBox(height: 8.h),
              // Image
              GestureDetector(
                onTap: () async {
                  final picker = ImagePicker();
                  final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
                  if (picked != null) setDialogState(() => newImage = picked);
                },
                child: Container(
                  width: double.infinity, height: 80,
                  decoration: BoxDecoration(color: _bgGray, borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(color: Colors.grey[200]!, style: BorderStyle.solid)),
                  child: newImage != null
                      ? ClipRRect(borderRadius: BorderRadius.circular(12.r), child: Image.file(File(newImage!.path), fit: BoxFit.cover))
                      : product?['image_url'] != null
                          ? ClipRRect(borderRadius: BorderRadius.circular(12.r), child: Image.network(product!['image_url'], fit: BoxFit.cover))
                          : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                              Icon(Icons.image_rounded, color: Colors.grey[400], size: 20),
                              SizedBox(width: 8.w),
                              Text('????? ????', style: TextStyle(color: Colors.grey[400], fontSize: 11.sp)),
                            ]),
                ),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('?????', style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              onPressed: saving ? null : () async {
                if (nameCtrl.text.trim().isEmpty || priceCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('???? ??? ?????? ??????')));
                  return;
                }
                setDialogState(() => saving = true);
                String? imgUrl;
                if (newImage != null) imgUrl = await _uploadImage(newImage!);
                try {
                  final data = {
                    'name': nameCtrl.text.trim(),
                    'price': double.tryParse(priceCtrl.text.trim()) ?? 0,
                    'stock': int.tryParse(stockCtrl.text.trim()) ?? 1,
                    'description': descCtrl.text.trim(),
                    'subcategory_id': subcatId,
                    if (imgUrl != null) 'image_url': imgUrl,
                  };
                  if (isEdit) {
                    await SupabaseService.db.from('products').update(data).eq('id', product!['id']);
                  } else {
                    data['provider_id'] = SupabaseService.currentUserId;
                    data['is_active'] = true;
                    await SupabaseService.db.from('products').insert(data);
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                  _loadAll();
                } catch (e) {
                  debugPrint('Save error: ');
                  setDialogState(() => saving = false);
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: _purple, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r))),
              child: saving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(isEdit ? '???' : '?????', style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteProduct(int id) async {
    final confirm = await showDialog<bool>(context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
        content: const Text('??? ??? ???????', textAlign: TextAlign.center),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('?????')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('???', style: TextStyle(color: Colors.white))),
        ],
      ),
    );
    if (confirm != true) return;
    await SupabaseService.db.from('products').delete().eq('id', id);
    _loadAll();
  }

  void _showSetDiscount(Map<String, dynamic> product) {
    final pid = product['id'] as int;
    final existing = _activeDiscounts[pid];
    final pctCtrl = TextEditingController(text: existing?.toStringAsFixed(0) ?? '');
    final daysCtrl = TextEditingController(text: '7');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
          title: Text(existing != null ? '????? ?????' : '????? ???', textAlign: TextAlign.center),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(product['name'] ?? '', style: TextStyle(fontSize: 12.sp, color: Colors.grey[500])),
            SizedBox(height: 12.h),
            TextField(controller: pctCtrl, keyboardType: TextInputType.number, textDirection: TextDirection.rtl,
                decoration: InputDecoration(hintText: '???? ????? %', filled: true, fillColor: _bgGray,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: BorderSide.none))),
            SizedBox(height: 8.h),
            TextField(controller: daysCtrl, keyboardType: TextInputType.number, textDirection: TextDirection.rtl,
                decoration: InputDecoration(hintText: '??? ??????', filled: true, fillColor: _bgGray,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: BorderSide.none))),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('?????')),
            ElevatedButton(
              onPressed: () async {
                final pct = double.tryParse(pctCtrl.text.trim());
                final days = int.tryParse(daysCtrl.text.trim()) ?? 7;
                if (pct == null || pct <= 0 || pct > 100) return;
                final endDate = DateTime.now().add(Duration(days: days)).toIso8601String();
                try {
                  if (existing != null) {
                    await SupabaseService.db.from('merchant_discounts').update({
                      'discount_percent': pct, 'end_date': endDate, 'is_active': true
                    }).eq('product_id', pid).eq('provider_id', SupabaseService.currentUserId ?? '');
                  } else {
                    await SupabaseService.db.from('merchant_discounts').insert({
'provider_id': SupabaseService.currentUserId ?? '',
                      'product_id': pid,
                      'discount_percent': pct,
                      'start_date': DateTime.now().toIso8601String(),
                      'end_date': endDate,
                    });
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                  _loadAll();
                } catch (e) {
                  debugPrint('Discount error: ');
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: _purple,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r))),
              child: Text(existing != null ? '?????' : '?????', style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showSubcategoryDialog() {
    final nameCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
        title: const Text('????? ???? ????', textAlign: TextAlign.center),
        content: TextField(controller: nameCtrl, textDirection: TextDirection.rtl,
            decoration: InputDecoration(hintText: '??? ???????', filled: true, fillColor: _bgGray,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: BorderSide.none))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('?????')),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              await SupabaseService.db.from('product_subcategories').insert({
                'provider_id': SupabaseService.currentUserId,
                'name': nameCtrl.text.trim(),
                'sort_order': _subcategories.length,
              });
              if (ctx.mounted) Navigator.pop(ctx);
              _loadAll();
            },
            style: ElevatedButton.styleFrom(backgroundColor: _purple,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r))),
            child: const Text('?????', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0,
        title: Text('???????', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15.sp, color: AppTheme.darkBackgroundColor)),
        centerTitle: true,
        actions: [
          IconButton(icon: Icon(Icons.add_rounded, color: _purple), onPressed: () => _showProductDialog()),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Subcategory chips + manage
                Container(
                  height: 48.h,
                  padding: EdgeInsets.symmetric(horizontal: 12.w),
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _subChip('????', null),
                      ..._subcategories.map((s) => _subChip(s['name'] as String, s['id'].toString())),
                      Padding(
                        padding: EdgeInsets.only(left: 8.w),
                        child: InkWell(
                          onTap: _showSubcategoryDialog,
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 12.w),
                            decoration: BoxDecoration(border: Border.all(color: _purple, style: BorderStyle.solid),
                                borderRadius: BorderRadius.circular(20.r)),
                            child: Row(children: [Icon(Icons.add, size: 14, color: _purple), SizedBox(width: 4.w),
                                Text('?????', style: TextStyle(fontSize: 10.sp, color: _purple, fontWeight: FontWeight.bold))]),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Product count
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                  child: Row(
                    children: [
                      Text(' ????', style: TextStyle(fontSize: 11.sp, color: Colors.grey[500])),
                      if (_activeDiscounts.isNotEmpty) ...[
                        SizedBox(width: 12.w),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                          decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(8.r)),
                          child: Text(' ??? ???',
                              style: TextStyle(fontSize: 9.sp, color: Colors.green[700], fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ],
                  ),
                ),
                Expanded(
                  child: filtered.isEmpty
                      ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.inventory_2_rounded, size: 48, color: Colors.grey[300]),
                          SizedBox(height: 12.h),
                          Text('?? ???? ??????', style: TextStyle(color: Colors.grey[400])),
                          SizedBox(height: 8.h),
                          ElevatedButton.icon(
                            onPressed: () => _showProductDialog(),
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('??? ????? ?????'),
                            style: ElevatedButton.styleFrom(backgroundColor: _purple,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r))),
                          ),
                        ]))
                      : ListView.builder(
                          padding: EdgeInsets.symmetric(horizontal: 16.w),
                          itemCount: filtered.length,
                          itemBuilder: (_, i) => _buildProductCard(filtered[i]),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _subChip(String label, String? value) {
    final active = _filterSubCat == value;
    return GestureDetector(
      onTap: () => setState(() => _filterSubCat = value),
      child: Container(
        margin: EdgeInsets.only(left: 8.w),
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
        decoration: BoxDecoration(
          color: active ? _purple : _bgGray,
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: Text(label, style: TextStyle(
            fontSize: 10.sp, fontWeight: FontWeight.bold,
            color: active ? Colors.white : Colors.grey[600])),
      ),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> p) {
    final pid = p['id'] as int;
    final name = p['name'] as String? ?? '';
    final price = (p['price'] as num?)?.toDouble() ?? 0;
    final stock = p['stock'] as int? ?? 0;
    final img = p['image_url'] as String?;
    final subcatId = p['subcategory_id'] as int?;
    final match = subcatId != null ? _subcategories.where((s) => s['id'] == subcatId).firstOrNull : null;
    final subcat = match?['name'] as String?;
    final discount = _activeDiscounts[pid];
    final discountedPrice = discount != null ? price * (1 - discount / 100) : null;
    final lowStock = stock > 0 && stock <= 5;

    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      padding: EdgeInsets.all(10.w),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: Colors.grey[100]!)),
      child: Row(
        children: [
          // Image
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(color: _bgGray, borderRadius: BorderRadius.circular(12.r)),
            child: img != null
                ? ClipRRect(borderRadius: BorderRadius.circular(12.r), child: Image.network(img, fit: BoxFit.cover))
                : Icon(Icons.image_rounded, color: Colors.grey[300], size: 24),
          ),
          SizedBox(width: 12.w),
          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.sp, color: AppTheme.darkBackgroundColor)),
                SizedBox(height: 4.h),
                Row(children: [
                  if (discount != null) ...[
                    Text(' ?',
                        style: TextStyle(fontSize: 10.sp, color: Colors.grey[400], decoration: TextDecoration.lineThrough)),
                    SizedBox(width: 4.w),
                  ],
                  Text(' ?',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12.sp, color: discount != null ? Colors.green[700]! : _purple)),
                ]),
                SizedBox(height: 4.h),
                Row(children: [
                  Icon(Icons.inventory_2_rounded, size: 10, color: lowStock ? Colors.red[300]! : Colors.grey[400]),
                  SizedBox(width: 4.w),
                  Text('', style: TextStyle(fontSize: 10.sp, color: lowStock ? Colors.red[300]! : Colors.grey[400])),
                  if (subcat != null) ...[
                    SizedBox(width: 8.w),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 1.h),
                      decoration: BoxDecoration(color: _bgGray, borderRadius: BorderRadius.circular(6.r)),
                      child: Text(subcat, style: TextStyle(fontSize: 8.sp, color: Colors.grey[500])),
                    ),
                  ],
                  if (discount != null) ...[
                    SizedBox(width: 8.w),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 1.h),
                      decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(6.r)),
                      child: Text('%', style: TextStyle(fontSize: 8.sp, color: Colors.green[700], fontWeight: FontWeight.bold)),
                    ),
                  ],
                ]),
              ],
            ),
          ),
          // Actions
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                onTap: () => _showProductDialog(product: p),
                child: Container(
                  padding: EdgeInsets.all(6.w),
                  decoration: BoxDecoration(color: _bgGray, borderRadius: BorderRadius.circular(8.r)),
                  child: Icon(Icons.edit_rounded, size: 14, color: _purple),
                ),
              ),
              SizedBox(height: 6.h),
              InkWell(
                onTap: () => _showSetDiscount(p),
                child: Container(
                  padding: EdgeInsets.all(6.w),
                  decoration: BoxDecoration(color: discount != null ? Colors.green[50]! : _bgGray, borderRadius: BorderRadius.circular(8.r)),
                  child: Icon(Icons.local_offer_rounded, size: 14, color: discount != null ? Colors.green[700]! : Colors.grey[400]),
                ),
              ),
              SizedBox(height: 6.h),
              InkWell(
                onTap: () => _deleteProduct(pid),
                child: Container(
                  padding: EdgeInsets.all(6.w),
                  decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(8.r)),
                  child: Icon(Icons.delete_outline_rounded, size: 14, color: Colors.red[300]),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
