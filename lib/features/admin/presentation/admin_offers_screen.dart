import 'dart:io';


import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/services/supabase_service.dart';

class AdminOffersScreen extends StatefulWidget {
  const AdminOffersScreen({super.key});
  @override
  State<AdminOffersScreen> createState() => _AdminOffersScreenState();
}

class _AdminOffersScreenState extends State<AdminOffersScreen> {
  List<Map<String, dynamic>> _offers = [];
  bool _isLoading = true;
  List<Map<String, dynamic>> _services = [];
  List<Map<String, dynamic>> _categories = [];

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final data = await SupabaseService.db.from('offers').select().order('created_at', ascending: false);
      if (mounted) setState(() { _offers = List<Map<String, dynamic>>.from(data); _isLoading = false; });

      try {
        final servicesData = await SupabaseService.db.from('services').select('id, name_ar, category_id').order('name_ar');
        final categoriesData = await SupabaseService.db.from('categories').select('id, name_ar').order('name_ar');
        if (mounted) {
          setState(() {
            _services = List<Map<String, dynamic>>.from(servicesData);
            _categories = List<Map<String, dynamic>>.from(categoriesData);
          });
        }
      } catch (e) {
        debugPrint('Error loading services/categories: $e');
      }
    } catch (e) { if (mounted) setState(() => _isLoading = false); }
  }

  void _showAddDialog({Map<String, dynamic>? existing}) {
    final titleCtrl = TextEditingController(text: existing?['title'] ?? '');
    final descCtrl = TextEditingController(text: existing?['description'] ?? '');
    final discountCtrl = TextEditingController(text: existing?['discount_percentage']?.toString() ?? '');
    final actionDataCtrl = TextEditingController(text: existing?['action_data'] ?? '');
    String actionType = existing?['action_type'] ?? 'none';
    String? currentImageUrl = existing?['image_url'];

    bool isSaving = false;
    XFile? pickedImage;
    final picker = ImagePicker();

    String? selectedServiceId;
    String? selectedCategoryId;
    if (existing != null && existing['action_data'] != null) {
      if (existing['action_type'] == 'service') {
        selectedServiceId = existing['action_data'];
      } else if (existing['action_type'] == 'category') {
        selectedCategoryId = existing['action_data'];
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.fromLTRB(DesignTokens.space24, DesignTokens.space20, DesignTokens.space24, MediaQuery.of(ctx).viewInsets.bottom + DesignTokens.space24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppTheme.surfaceColor, AppTheme.backgroundColor],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(DesignTokens.radius2xl)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: DesignTokens.space40,
                  height: DesignTokens.space4,
                  decoration: BoxDecoration(
                    color: AppTheme.textSecondary.withValues(alpha: 0.15),
                    borderRadius: DesignTokens.brSm,
                  ),
                ),
                SizedBox(height: DesignTokens.space20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: DesignTokens.padding12,
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius: DesignTokens.brMd,
                      ),
                      child: Icon(
                        existing != null ? Icons.edit_rounded : Icons.add_rounded,
                        size: DesignTokens.iconSm,
                        color: AppTheme.surfaceColor,
                      ),
                    ),
                    SizedBox(width: DesignTokens.space6),
                    Text(
                      existing != null ? 'تعديل العرض' : 'إضافة عرض جديد',
                      style: const TextStyle(
                        fontSize: DesignTokens.textTitleLarge,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: DesignTokens.space24),

                _sectionHeader('صورة العرض', Icons.image_outlined),
                SizedBox(height: DesignTokens.space6),
                GestureDetector(
                  onTap: () async {
                    final img = await picker.pickImage(source: ImageSource.gallery);
                    if (img != null) setModalState(() => pickedImage = img);
                  },
                  child: Container(
                    width: double.infinity,
                    height: 60.h,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppTheme.backgroundColor, AppTheme.surfaceColor],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: DesignTokens.brLg,
                      border: Border.all(
                        color: AppTheme.primaryColor.withValues(alpha: 0.2),
                        width: 1.5,
                      ),
                      boxShadow: DesignTokens.shadow1(AppTheme.textPrimary),
                    ),
                    child: pickedImage != null
                      ? ClipRRect(borderRadius: DesignTokens.brLg, child: Image.file(File(pickedImage!.path), fit: BoxFit.cover))
                      : (currentImageUrl != null && currentImageUrl!.isNotEmpty)
                        ? ClipRRect(borderRadius: DesignTokens.brLg, child: Image.network(currentImageUrl!, fit: BoxFit.cover, semanticLabel: 'صورة العرض'))
                        : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Container(
                              padding: DesignTokens.padding12,
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                                borderRadius: DesignTokens.brFull,
                              ),
                              child: const Icon(Icons.add_photo_alternate_outlined, size: DesignTokens.iconLg, color: AppTheme.primaryColor),
                            ),
                            SizedBox(height: DesignTokens.space4),
                            const Text(
                              'صورة العرض الجانبية',
                              style: TextStyle(color: AppTheme.textSecondary, fontSize: DesignTokens.textBodySmall, fontWeight: FontWeight.w500),
                            ),
                          ]),
                  ),
                ),
                SizedBox(height: DesignTokens.space20),

                _sectionHeader('تفاصيل العرض', Icons.description_outlined),
                SizedBox(height: DesignTokens.space6),
                _field(titleCtrl, 'عنوان العرض', Icons.title),
                SizedBox(height: DesignTokens.space6),
                _field(descCtrl, 'وصف العرض', Icons.description_outlined),
                SizedBox(height: DesignTokens.space6),
                _field(discountCtrl, 'نسبة الخصم %', Icons.percent, type: TextInputType.number),
                SizedBox(height: DesignTokens.space20),

                _sectionHeader('إجراء النقر', Icons.touch_app_outlined),
                SizedBox(height: DesignTokens.space6),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: DesignTokens.space16),
                  decoration: BoxDecoration(
                    color: AppTheme.backgroundColor,
                    borderRadius: DesignTokens.brLg,
                    border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.1)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: actionType,
                      icon: const Icon(Icons.expand_more_rounded, color: AppTheme.primaryColor),
                      style: const TextStyle(fontSize: DesignTokens.textBodyMedium, color: AppTheme.textPrimary),
                      items: const [
                        DropdownMenuItem(value: 'none', child: Text('بدون إجراء', style: TextStyle(fontSize: DesignTokens.textBodyMedium))),
                        DropdownMenuItem(value: 'service', child: Text('فتح خدمة معينة', style: TextStyle(fontSize: DesignTokens.textBodyMedium))),
                        DropdownMenuItem(value: 'category', child: Text('فتح قسم كامل', style: TextStyle(fontSize: DesignTokens.textBodyMedium))),
                        DropdownMenuItem(value: 'url', child: Text('فتح رابط خارجي', style: TextStyle(fontSize: DesignTokens.textBodyMedium))),
                      ],
                      onChanged: (v) {
                        if (v != null) {
                          setModalState(() {
                            actionType = v;
                            if (v != 'service') selectedServiceId = null;
                            if (v != 'category') selectedCategoryId = null;
                          });
                        }
                      },
                    ),
                  ),
                ),
                SizedBox(height: DesignTokens.space6),
                if (actionType == 'service')
                  _dropdownSection(
                    hint: 'اختر الخدمة',
                    value: selectedServiceId,
                    items: _services.map((s) => DropdownMenuItem(
                      value: s['id'].toString(),
                      child: Text(s['name_ar'] ?? 'بدون اسم', style: const TextStyle(fontSize: DesignTokens.textBodyMedium)),
                    )).toList(),
                    onChanged: (v) => setModalState(() => selectedServiceId = v),
                  )
                else if (actionType == 'category')
                  _dropdownSection(
                    hint: 'اختر القسم',
                    value: selectedCategoryId,
                    items: _categories.map((c) => DropdownMenuItem(
                      value: c['id'].toString(),
                      child: Text(c['name_ar'] ?? 'بدون اسم', style: const TextStyle(fontSize: DesignTokens.textBodyMedium)),
                    )).toList(),
                    onChanged: (v) => setModalState(() => selectedCategoryId = v),
                  )
                else if (actionType == 'url')
                  _field(actionDataCtrl, 'رابط الويب', Icons.link),

                SizedBox(height: DesignTokens.space24),
                SizedBox(
                  width: double.infinity,
                  height: DesignTokens.buttonHeight,
                  child: ElevatedButton(
                    onPressed: isSaving ? null : () async {
                      if (titleCtrl.text.isEmpty) return;
                      if (actionType == 'service' && selectedServiceId == null) return;
                      if (actionType == 'category' && selectedCategoryId == null) return;
                      if (actionType == 'url' && actionDataCtrl.text.trim().isEmpty) return;
                      setModalState(() => isSaving = true);

                      try {
                        String? finalUrl = currentImageUrl;
                        if (pickedImage != null) {
                          final bytes = await File(pickedImage!.path).readAsBytes();
                          final path = 'offers/${DateTime.now().millisecondsSinceEpoch}.jpg';
                          await SupabaseService.storage.from('offer-images').uploadBinary(path, bytes);
                          finalUrl = SupabaseService.storage.from('offer-images').getPublicUrl(path);
                        }

                        String? actionData;
                        if (actionType == 'service') {
                          actionData = selectedServiceId;
                        } else if (actionType == 'category') {
                          actionData = selectedCategoryId;
                        } else if (actionType == 'url') {
                          actionData = actionDataCtrl.text.trim();
                        }

                        final data = {
                          'title': titleCtrl.text,
                          'description': descCtrl.text,
                          'discount_percentage': double.tryParse(discountCtrl.text) ?? 0,
                          'image_url': finalUrl,
                          'action_type': actionType,
                          'action_data': actionData,
                          'is_active': true
                        };

                        if (existing != null) {
                          await SupabaseService.db.from('offers').update(data).eq('id', existing['id']);
                        } else {
                          await SupabaseService.db.from('offers').insert(data);
                        }

                        if (ctx.mounted) Navigator.pop(ctx);
                        _load();
                      } catch (e) {
                        debugPrint('Error saving offer: $e');
                        setModalState(() => isSaving = false);
                      }
                    },
                    child: isSaving
                      ? const SizedBox(width: DesignTokens.space20, height: DesignTokens.space20, child: CircularProgressIndicator(color: AppTheme.surfaceColor, strokeWidth: 2))
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(existing != null ? Icons.save_rounded : Icons.add_circle_outline_rounded, size: DesignTokens.iconSm),
                            SizedBox(width: DesignTokens.space4),
                            Text(
                              existing != null ? 'تحديث العرض' : 'إضافة العرض',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: DesignTokens.textTitleSmall),
                            ),
                          ],
                        ),
                  ),
                ),
                SizedBox(height: DesignTokens.space8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _delete(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف العرض', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
        content: const Text('هل أنت متأكد من حذف هذا العرض؟ لا يمكن التراجع.', style: TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف', style: TextStyle(color: AppTheme.surfaceColor)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await SupabaseService.db.from('offers').delete().eq('id', id);
      _load();
    }
  }

  Future<void> _toggle(String id, bool v) async {
    await SupabaseService.db.from('offers').update({'is_active': !v}).eq('id', id);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceColor,
        elevation: 0,
        centerTitle: true,
        title: const Text('العروض والإعلانات', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: DesignTokens.textTitleMedium)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.textPrimary, size: DesignTokens.iconSm),
          tooltip: 'العودة',
          onPressed: () => Navigator.pop(context),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddDialog(),
        backgroundColor: AppTheme.primaryColor,
        icon: const Icon(Icons.add_rounded, color: AppTheme.surfaceColor, size: DesignTokens.iconSm),
        label: const Text('عرض جديد', style: TextStyle(color: AppTheme.surfaceColor, fontWeight: FontWeight.bold, fontSize: DesignTokens.textTitleSmall)),
        shape: RoundedRectangleBorder(borderRadius: DesignTokens.brLg),
      ),
      body: _isLoading
        ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
        : _offers.isEmpty
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
                      Icons.local_offer_outlined,
                      size: DesignTokens.iconDoctorAvatar,
                      color: AppTheme.primaryColor.withValues(alpha: 0.2),
                    ),
                  ),
                  SizedBox(height: DesignTokens.space16),
                  const Text(
                    'لا توجد عروض',
                    style: TextStyle(fontSize: DesignTokens.textTitleSmall, color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
                  ),
                  SizedBox(height: DesignTokens.space4),
                  const Text(
                    'اضغط على "عرض جديد" لإضافة أول عرض',
                    style: TextStyle(fontSize: DesignTokens.textBodySmall, color: AppTheme.textTertiary),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: EdgeInsets.all(DesignTokens.space12),
              itemCount: _offers.length,
              itemBuilder: (_, i) {
                final o = _offers[i];
                final isActive = o['is_active'] == true;
                return GestureDetector(
                  onTap: () => _showAddDialog(existing: o),
                  child: AnimatedContainer(
                    duration: DesignTokens.durationNormal,
                    curve: DesignTokens.curveEaseInOut,
                    margin: EdgeInsets.only(bottom: DesignTokens.space6),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceColor,
                      borderRadius: DesignTokens.brMd,
                      border: Border.all(
                        color: isActive
                          ? AppTheme.tertiaryColor.withValues(alpha: 0.2)
                          : AppTheme.textTertiary.withValues(alpha: 0.15),
                      ),
                      boxShadow: DesignTokens.shadow1(AppTheme.textPrimary),
                    ),
                    child: IntrinsicHeight(
                      child: Row(children: [
                        Container(
                          width: 76,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: isActive
                                ? [AppTheme.tertiaryColor.withValues(alpha: 0.25), AppTheme.tertiaryColor.withValues(alpha: 0.05)]
                                : [AppTheme.textTertiary.withValues(alpha: 0.15), AppTheme.textTertiary.withValues(alpha: 0.03)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: const BorderRadius.only(
                              topRight: Radius.circular(DesignTokens.radiusSm),
                              bottomRight: Radius.circular(DesignTokens.radiusSm),
                            ),
                          ),
                          child: (o['image_url'] != null && o['image_url'].isNotEmpty)
                            ? ClipRRect(
                                borderRadius: const BorderRadius.only(
                                  topRight: Radius.circular(DesignTokens.radiusSm),
                                  bottomRight: Radius.circular(DesignTokens.radiusSm),
                                ),
                                child: Image.network(o['image_url'], fit: BoxFit.cover, semanticLabel: 'صورة العرض',
                                  errorBuilder: (_,__,___) => _offerPlaceholder(isActive)),
                              )
                            : _offerPlaceholder(isActive),
                        ),
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: DesignTokens.space6, vertical: DesignTokens.space6),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  o['title'] ?? '',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: DesignTokens.textBodyMedium,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                                if (o['description'] != null && o['description'].toString().isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: DesignTokens.space1),
                                    child: Text(
                                      o['description'],
                                      style: const TextStyle(fontSize: DesignTokens.textBodySmall, color: AppTheme.textSecondary),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                if (o['discount_percentage'] != null && (o['discount_percentage'] as num) > 0)
                                  Padding(
                                    padding: const EdgeInsets.only(top: DesignTokens.space2),
                                    child: Container(
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
                                          Icon(Icons.percent_rounded, size: DesignTokens.iconXs, color: AppTheme.primaryColor),
                                          SizedBox(width: DesignTokens.space1),
                                          Text(
                                            'خصم ${o['discount_percentage']}%',
                                            style: const TextStyle(
                                              color: AppTheme.primaryColor,
                                              fontWeight: FontWeight.bold,
                                              fontSize: DesignTokens.textBodySmall,
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
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              height: DesignTokens.touchTargetMin,
                              child: Switch(
                                value: isActive,
                                onChanged: (_) => _toggle(o['id'].toString(), isActive),
                                activeTrackColor: AppTheme.primaryColor.withValues(alpha: DesignTokens.opacityMedium),
                                activeColor: AppTheme.primaryColor,
                              ),
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
                              onPressed: () => _delete(o['id'].toString()),
                              constraints: const BoxConstraints(minWidth: DesignTokens.touchTargetMin, minHeight: DesignTokens.touchTargetMin),
                            ),
                          ],
                        ),
                      ]),
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _offerPlaceholder(bool isActive) {
    return Container(
      width: 76,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isActive
            ? [AppTheme.tertiaryColor.withValues(alpha: 0.12), AppTheme.tertiaryColor.withValues(alpha: 0.04)]
            : [AppTheme.textTertiary.withValues(alpha: 0.08), AppTheme.textTertiary.withValues(alpha: 0.02)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Icon(
        isActive ? Icons.local_offer_rounded : Icons.local_offer_outlined,
        size: DesignTokens.iconMd,
        color: isActive ? AppTheme.tertiaryColor : AppTheme.textTertiary,
      ),
    );
  }

  Widget _dropdownSection({
    required String hint,
    required String? value,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: DesignTokens.space16),
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: DesignTokens.brLg,
        border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.1)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          hint: Row(children: [
            Icon(Icons.arrow_drop_down_circle_outlined, size: DesignTokens.iconXs, color: AppTheme.primaryColor),
            SizedBox(width: DesignTokens.space2),
            Text(hint, style: const TextStyle(color: AppTheme.textSecondary, fontSize: DesignTokens.textBodyMedium)),
          ]),
          value: value,
          icon: const Icon(Icons.expand_more_rounded, color: AppTheme.primaryColor),
          style: const TextStyle(fontSize: DesignTokens.textBodyMedium, color: AppTheme.textPrimary),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: DesignTokens.iconXs, color: AppTheme.primaryColor),
        SizedBox(width: DesignTokens.space2),
        Text(
          title,
          style: const TextStyle(
            fontSize: DesignTokens.textLabelLarge,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        SizedBox(width: DesignTokens.space4),
        Expanded(
          child: Container(
            height: 1,
            color: AppTheme.primaryColor.withValues(alpha: 0.1),
          ),
        ),
      ],
    );
  }

  Widget _field(TextEditingController c, String h, IconData ic, {TextInputType type = TextInputType.text}) {
    return TextField(
      controller: c,
      keyboardType: type,
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