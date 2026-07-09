
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:faster_app/core/theme/app_theme.dart';
import 'package:faster_app/core/theme/design_tokens.dart';
import 'package:faster_app/core/services/supabase_service.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';

class AdminServicesScreen extends StatefulWidget {
  const AdminServicesScreen({super.key});
  @override
  State<AdminServicesScreen> createState() => _AdminServicesScreenState();
}

class _AdminServicesScreenState extends State<AdminServicesScreen> {
  List<dynamic> _services = [];
  List<dynamic> _categories = [];
  bool _isLoading = true;

  @override
  void initState() { super.initState(); _loadData(); }

  Future<void> _loadData() async {
    try {
      final services = await SupabaseService.db
          .from('services')
          .select('*, categories(*)')
          .order('created_at', ascending: false);
      final categories = await SupabaseService.db
          .from('categories')
          .select()
          .order('created_at', ascending: false);
      if (!mounted) return;
      setState(() { _services = services; _categories = categories; _isLoading = false; });
    } catch (e) {
      debugPrint('Error loading services: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteService(dynamic serviceId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف الخدمة'),
        content: const Text('هل أنت متأكد من حذف هذه الخدمة؟ لا يمكن التراجع.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await SupabaseService.db.from('services').delete().eq('id', serviceId);
        _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم حذف الخدمة'), backgroundColor: AppTheme.successColor),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('خطأ في الحذف: $e'), backgroundColor: AppTheme.errorColor),
          );
        }
      }
    }
  }

  Future<void> _showServiceDialog([dynamic service]) async {
    bool isSaving = false;
    final bool isEditing = service != null;
    XFile? pickedImage;
    final String? currentImageUrl = isEditing ? service['image_url'] : null;
    String? selectedCategoryId = isEditing ? service['category_id']?.toString() : null;

    final titleCtrl = TextEditingController(text: isEditing ? service['title'] : '');
    final descCtrl = TextEditingController(text: isEditing ? service['description'] : '');
    final priceCtrl = TextEditingController(text: isEditing ? service['price']?.toString() : '');
    final existingCommission = double.tryParse(
      (service?['commission_rate'] ?? '0.10').toString(),
    );
    final commissionPercent = existingCommission == null
        ? '10'
        : (existingCommission > 1
              ? existingCommission
              : existingCommission * 100)
            .toString();
    final commissionCtrl = TextEditingController(
      text: isEditing ? commissionPercent : '10',
    );

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateModal) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: DesignTokens.brLg),
          titlePadding: EdgeInsets.zero,
          title: Container(
            padding: const EdgeInsets.all(DesignTokens.space24),
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(DesignTokens.radiusLg),
                topRight: Radius.circular(DesignTokens.radiusLg),
              ),
            ),
            child: Row(children: [
              Container(
                padding: DesignTokens.padding8,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: DesignTokens.brSm,
                ),
                child: Icon(
                  isEditing ? Icons.edit_rounded : Icons.add_rounded,
                  size: DesignTokens.iconSm,
                  color: Colors.white,
                ),
              ),
              SizedBox(width: DesignTokens.space6),
              Text(
                isEditing ? 'تعديل خدمة' : 'إضافة خدمة جديدة',
                style: const TextStyle(
                  fontSize: DesignTokens.textTitleMedium,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ]),
          ),
          contentPadding: EdgeInsets.fromLTRB(DesignTokens.space24, DesignTokens.space20, DesignTokens.space24, DesignTokens.space8),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              GestureDetector(
                onTap: isSaving ? null : () async {
                  final img = await ImagePicker().pickImage(source: ImageSource.gallery);
                  if (img != null) setStateModal(() => pickedImage = img);
                },
                child: Container(
                  height: 130.h,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppTheme.backgroundColor, AppTheme.surfaceColor],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: DesignTokens.brLg,
                    border: Border.all(
                      color: pickedImage == null && currentImageUrl == null
                        ? AppTheme.errorColor.withValues(alpha: 0.3)
                        : AppTheme.primaryColor.withValues(alpha: 0.2),
                      width: 1.5,
                    ),
                  ),
                  child: pickedImage != null
                    ? ClipRRect(
                        borderRadius: DesignTokens.brLg,
                        child: kIsWeb
                          ? Image.network(pickedImage!.path, fit: BoxFit.cover, semanticLabel: 'صورة الخدمة')
                          : Image.file(File(pickedImage!.path), fit: BoxFit.cover),
                      )
                    : currentImageUrl != null
                        ? ClipRRect(
                            borderRadius: DesignTokens.brLg,
                            child: Image.network(currentImageUrl, fit: BoxFit.cover, semanticLabel: 'صورة الخدمة'),
                          )
                        : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Container(
                              padding: DesignTokens.padding12,
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                                borderRadius: DesignTokens.brFull,
                              ),
                              child: const Icon(Icons.add_a_photo_outlined, size: DesignTokens.iconLg, color: AppTheme.primaryColor),
                            ),
                            SizedBox(height: DesignTokens.space4),
                            const Text(
                              'إضافة صورة (مطلوب)',
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: DesignTokens.textBodySmall,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ]),
                ),
              ),
              SizedBox(height: DesignTokens.space16),
              Container(
                padding: EdgeInsets.symmetric(horizontal: DesignTokens.space16),
                decoration: BoxDecoration(
                  color: AppTheme.backgroundColor,
                  borderRadius: DesignTokens.brLg,
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: selectedCategoryId,
                    hint: Row(children: [
                      Icon(Icons.category_outlined, size: DesignTokens.iconXs, color: AppTheme.primaryColor),
                      SizedBox(width: DesignTokens.space2),
                      const Text('اختر القسم', style: TextStyle(color: AppTheme.textSecondary, fontSize: DesignTokens.textBodyMedium)),
                    ]),
                    items: _categories.map((c) => DropdownMenuItem(
                      value: c['id'].toString(),
                      child: Text((c['name_ar'] ?? c['name_en'] ?? c['name'] ?? '').toString(),
                        style: const TextStyle(fontSize: DesignTokens.textBodyMedium, color: AppTheme.textPrimary)),
                    )).toList(),
                    onChanged: isSaving ? null : (v) => setStateModal(() => selectedCategoryId = v),
                  ),
                ),
              ),
              SizedBox(height: DesignTokens.space6),
              _dialogField(titleCtrl, 'اسم الخدمة', Icons.title_rounded, enabled: !isSaving),
              SizedBox(height: DesignTokens.space6),
              _dialogField(descCtrl, 'وصف الخدمة', Icons.description_outlined, maxLines: 2, enabled: !isSaving),
              SizedBox(height: DesignTokens.space6),
              Row(children: [
                Expanded(
                  child: _dialogField(priceCtrl, 'السعر (جنيه)', Icons.monetization_on_outlined,
                    type: TextInputType.number, enabled: !isSaving),
                ),
                SizedBox(width: DesignTokens.space4),
                Expanded(
                  child: _dialogField(commissionCtrl, 'العمولة (%)', Icons.percent_rounded,
                    type: TextInputType.number, enabled: !isSaving),
                ),
              ]),
            ]),
          ),
          actionsPadding: EdgeInsets.fromLTRB(DesignTokens.space24, DesignTokens.space4, DesignTokens.space24, DesignTokens.space20),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(ctx),
              child: const Text('إلغاء', style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w500)),
            ),
            ElevatedButton(
              onPressed: isSaving ? null : () async {
                if (titleCtrl.text.isEmpty || selectedCategoryId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يرجى ملء البيانات الأساسية'), backgroundColor: AppTheme.warningColor));
                  return;
                }
                if (pickedImage == null && currentImageUrl == null) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يرجى إضافة صورة للخدمة'), backgroundColor: AppTheme.warningColor));
                  return;
                }

                setStateModal(() => isSaving = true);
                final messenger = ScaffoldMessenger.of(context);

                try {
                  String? imageUrl = currentImageUrl;
                  if (pickedImage != null) {
                    final path = 'services/${DateTime.now().millisecondsSinceEpoch}.jpg';
                    if (kIsWeb) {
                      final bytes = await pickedImage!.readAsBytes();
                      await SupabaseService.client.storage.from('app_assets').uploadBinary(path, bytes);
                    } else {
                      await SupabaseService.client.storage.from('app_assets').upload(path, File(pickedImage!.path));
                    }
                    imageUrl = SupabaseService.client.storage.from('app_assets').getPublicUrl(path);
                  }

                  final data = {
                    'title': titleCtrl.text, 'description': descCtrl.text,
                    'base_price': double.tryParse(priceCtrl.text) ?? 0,
                    'price': double.tryParse(priceCtrl.text) ?? 0,
                    'commission_rate': (double.tryParse(commissionCtrl.text) ?? 10.0) / 100,
                    'category_id': int.parse(selectedCategoryId!), 'is_active': true,
                    'image_url': imageUrl,
                  };

                  if (isEditing) { await SupabaseService.db.from('services').update(data).eq('id', service['id']); }
                  else { await SupabaseService.db.from('services').insert(data); }

                  if (ctx.mounted) Navigator.pop(ctx);
                  _loadData();
                } catch (e) {
                  messenger.showSnackBar(SnackBar(content: Text('خطأ: $e'), backgroundColor: AppTheme.errorColor));
                  setStateModal(() => isSaving = false);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: DesignTokens.brMd),
              ),
              child: isSaving
                ? const SizedBox(width: DesignTokens.space5, height: DesignTokens.space5, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(isEditing ? Icons.save_rounded : Icons.add_circle_outline_rounded, size: DesignTokens.iconSm),
                    SizedBox(width: DesignTokens.space2),
                    Text(isEditing ? 'تحديث' : 'إضافة', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ]),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('إدارة الخدمات والأسعار', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: DesignTokens.textBodyMedium)),
        backgroundColor: AppTheme.surfaceColor,
        elevation: 0,
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showServiceDialog(),
        backgroundColor: AppTheme.primaryColor,
        child: const Icon(Icons.add, color: Colors.white, size: DesignTokens.iconSm),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
          : _services.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(DesignTokens.space24),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.05),
                        borderRadius: DesignTokens.brFull,
                      ),
                      child: Icon(
                        Icons.build_outlined,
                        size: DesignTokens.iconDoctorAvatar,
                        color: AppTheme.primaryColor.withValues(alpha: 0.2),
                      ),
                    ),
                    SizedBox(height: DesignTokens.space16),
                    const Text(
                      'لا توجد خدمات',
                      style: TextStyle(fontSize: DesignTokens.textTitleSmall, color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
                    ),
                    SizedBox(height: DesignTokens.space4),
                    const Text(
                      'اضغط على + لإضافة أول خدمة',
                      style: TextStyle(fontSize: DesignTokens.textBodySmall, color: AppTheme.textTertiary),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                padding: EdgeInsets.all(DesignTokens.space8),
                itemCount: _services.length,
                itemBuilder: (context, index) {
                  final s = _services[index];
                  final crValue = double.tryParse(
                    (s['commission_rate'] ?? '0.10').toString(),
                  ) ?? 0.10;
                  final cr = crValue > 1 ? crValue : crValue * 100;
                  final category = s['categories'] is Map<String, dynamic>
                      ? s['categories'] as Map<String, dynamic>
                      : <String, dynamic>{};
                  return AnimatedContainer(
                    duration: DesignTokens.durationNormal,
                    curve: DesignTokens.curveEaseInOut,
                    margin: EdgeInsets.only(bottom: DesignTokens.space6),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceColor,
                      borderRadius: DesignTokens.brMd,
                      border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.08)),
                      boxShadow: DesignTokens.shadow1(AppTheme.textPrimary),
                    ),
                    child: IntrinsicHeight(
                      child: Row(children: [
                        Container(
                          width: 4,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [AppTheme.primaryColor, AppTheme.primaryColor.withValues(alpha: 0.3)],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                            borderRadius: const BorderRadius.only(
                              topRight: Radius.circular(DesignTokens.radiusSm),
                              bottomRight: Radius.circular(DesignTokens.radiusSm),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: DesignTokens.cardPadding,
                            child: Row(children: [
                              Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [AppTheme.primaryColor.withValues(alpha: 0.1), AppTheme.primaryColor.withValues(alpha: 0.03)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: DesignTokens.brMd,
                                ),
                                child: s['image_url'] != null
                                  ? ClipRRect(
                                      borderRadius: DesignTokens.brMd,
                                      child: Image.network(
                                        s['image_url'],
                                        width: 52,
                                        height: 52,
                                        fit: BoxFit.cover,
                                        semanticLabel: 'صورة الخدمة',
                                        errorBuilder: (_, __, ___) => const Icon(Icons.build, color: AppTheme.primaryColor, size: DesignTokens.iconSm),
                                      ),
                                    )
                                  : const Icon(Icons.build, color: AppTheme.primaryColor, size: DesignTokens.iconSm),
                              ),
                              SizedBox(width: DesignTokens.space6),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      s['title'] ?? 'بدون عنوان',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: DesignTokens.textBodyMedium, color: AppTheme.textPrimary),
                                    ),
                                    SizedBox(height: DesignTokens.space1),
                                    Row(
                                      children: [
                                        Icon(Icons.category_outlined, size: DesignTokens.iconXs, color: AppTheme.textSecondary),
                                        SizedBox(width: DesignTokens.space1),
                                        Text(
                                          (category['name_ar'] ?? category['name_en'] ?? category['name'] ?? 'غير محدد').toString(),
                                          style: const TextStyle(fontSize: DesignTokens.textLabelSmall, color: AppTheme.textSecondary),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: DesignTokens.space2),
                                    Wrap(
                                      spacing: DesignTokens.space2,
                                      runSpacing: DesignTokens.space1,
                                      children: [
                                        Container(
                                          padding: EdgeInsets.symmetric(horizontal: DesignTokens.space4, vertical: DesignTokens.space1),
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [AppTheme.primaryColor.withValues(alpha: 0.12), AppTheme.primaryColor.withValues(alpha: 0.04)],
                                              begin: Alignment.centerLeft,
                                              end: Alignment.centerRight,
                                            ),
                                            borderRadius: DesignTokens.brSm,
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.monetization_on_outlined, size: DesignTokens.iconXs, color: AppTheme.primaryColor),
                                              SizedBox(width: DesignTokens.space1),
                                              Text(
                                                '${s['price']} جنيه',
                                                style: const TextStyle(fontSize: DesignTokens.textLabelSmall, color: AppTheme.primaryColor, fontWeight: FontWeight.bold),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Container(
                                          padding: EdgeInsets.symmetric(horizontal: DesignTokens.space4, vertical: DesignTokens.space1),
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [AppTheme.tertiaryColor.withValues(alpha: 0.15), AppTheme.tertiaryColor.withValues(alpha: 0.05)],
                                              begin: Alignment.centerLeft,
                                              end: Alignment.centerRight,
                                            ),
                                            borderRadius: DesignTokens.brSm,
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.percent_rounded, size: DesignTokens.iconXs, color: AppTheme.tertiaryColor),
                                              SizedBox(width: DesignTokens.space1),
                                              Text(
                                                'عمولة: $cr%',
                                                style: const TextStyle(fontSize: DesignTokens.textLabelSmall, color: AppTheme.tertiaryColor, fontWeight: FontWeight.bold),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  IconButton(
                                    icon: Container(
                                      padding: DesignTokens.padding4,
                                      decoration: BoxDecoration(
                                        color: AppTheme.primaryColor.withValues(alpha: 0.1),
                                        borderRadius: DesignTokens.brSm,
                                      ),
                                      child: const Icon(Icons.edit_outlined, color: AppTheme.primaryColor, size: DesignTokens.iconXs),
                                    ),
                                    tooltip: 'تعديل',
                                    onPressed: () => _showServiceDialog(s),
                                    constraints: const BoxConstraints(minWidth: DesignTokens.touchTargetMin, minHeight: DesignTokens.touchTargetMin),
                                  ),
                                  IconButton(
                                    icon: Container(
                                      padding: DesignTokens.padding4,
                                      decoration: BoxDecoration(
                                        color: AppTheme.errorColor.withValues(alpha: 0.1),
                                        borderRadius: DesignTokens.brSm,
                                      ),
                                      child: const Icon(Icons.delete_outline, color: AppTheme.errorColor, size: DesignTokens.iconXs),
                                    ),
                                    tooltip: 'حذف',
                                    onPressed: () => _deleteService(s['id']),
                                    constraints: const BoxConstraints(minWidth: DesignTokens.touchTargetMin, minHeight: DesignTokens.touchTargetMin),
                                  ),
                                ],
                              ),
                            ]),
                          ),
                        ),
                      ]),
                    ),
                  );
                },
              ),
    );
  }

  Widget _dialogField(TextEditingController c, String h, IconData ic, {TextInputType type = TextInputType.text, int maxLines = 1, bool enabled = true}) {
    return TextField(
      controller: c,
      keyboardType: type,
      maxLines: maxLines,
      enabled: enabled,
      textAlign: TextAlign.right,
      decoration: InputDecoration(
        hintText: h,
        prefixIcon: Icon(ic, color: AppTheme.primaryColor, size: DesignTokens.iconMd),
        filled: true,
        fillColor: AppTheme.backgroundColor,
        border: OutlineInputBorder(
          borderRadius: DesignTokens.brLg,
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: DesignTokens.space16, vertical: DesignTokens.space3),
      ),
    );
  }
}