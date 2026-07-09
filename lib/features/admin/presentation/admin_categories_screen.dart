import 'dart:io';


import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/services/supabase_service.dart';

class AdminCategoriesScreen extends StatefulWidget {
  const AdminCategoriesScreen({super.key});
  @override
  State<AdminCategoriesScreen> createState() => _AdminCategoriesScreenState();
}

class _AdminCategoriesScreenState extends State<AdminCategoriesScreen> {
  List<Map<String, dynamic>> _cats = [];
  bool _isLoading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final data = await SupabaseService.db
          .from('categories')
          .select()
          .order('created_at', ascending: false);
      if (mounted) setState(() { _cats = List<Map<String, dynamic>>.from(data); _isLoading = false; });
    } catch (e) { if (mounted) setState(() => _isLoading = false); }
  }

  Future<void> _showAddDialog({Map<String, dynamic>? existing}) async {
    String existingCommission = '10';
    String existingColor = '#3B82F6';
    String? selectedIconUrl = existing?['icon_url'];
    if (existing != null) {
      try {
        final setting = await SupabaseService.db.from('app_settings').select('value').eq('key', 'category_commission_${existing['id']}').maybeSingle();
        if (setting != null) existingCommission = setting['value'].toString();
        existingColor = existing['icon_color'] ?? '#3B82F6';
        selectedIconUrl = existing['icon_url'];
      } catch (_) {}
    }
    if (!mounted) return;

    final arCtrl = TextEditingController(text: existing?['name_ar'] ?? '');
    final enCtrl = TextEditingController(text: existing?['name_en'] ?? '');
    final commCtrl = TextEditingController(text: existingCommission);
  final colorCtrl = TextEditingController(text: existingColor.replaceAll('#', ''));
  String? selectedProviderType = existing?['provider_type'] ?? 'handyman';
  bool isSaving = false;
    XFile? pickedImageFile;
    final ImagePicker picker = ImagePicker();

    Future<void> pickImage(StateSetter setModalState) async {
      final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 512, maxHeight: 512);
      if (picked != null) {
        setModalState(() { pickedImageFile = picked; });
      }
    }

    Future<String?> uploadIcon() async {
      if (pickedImageFile != null) {
        try {
          final bytes = await File(pickedImageFile!.path).readAsBytes();
          final fileName = 'category_icons/${DateTime.now().millisecondsSinceEpoch}_icon.png';
          await SupabaseService.storage.from('category-icons').uploadBinary(
            fileName,
            bytes,
            retryAttempts: 3,
          );
          final url = SupabaseService.storage.from('category-icons').getPublicUrl(fileName);
          return url;
        } catch (e) {
          debugPrint('Upload error: $e');
          return null;
        }
      }
      return selectedIconUrl;
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
            child: Column(mainAxisSize: MainAxisSize.min, children: [
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
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(width: DesignTokens.space6),
                  Text(
                    existing != null ? 'تعديل القسم' : 'إضافة قسم جديد',
                    style: const TextStyle(
                      fontSize: DesignTokens.textTitleLarge,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
              SizedBox(height: DesignTokens.space24),

              _sectionHeader('معلومات القسم', Icons.info_outline_rounded),
              SizedBox(height: DesignTokens.space6),
              _field(arCtrl, 'اسم القسم (عربي)', Icons.title),
              SizedBox(height: DesignTokens.space6),
              _field(enCtrl, 'اسم القسم (إنجليزي)', Icons.translate),
              SizedBox(height: DesignTokens.space6),

  _sectionHeader('الإعدادات', Icons.tune_rounded),
  SizedBox(height: DesignTokens.space6),
  _field(commCtrl, 'العمولة (%)', Icons.percent_rounded, type: TextInputType.number),
  SizedBox(height: DesignTokens.space6),
  _field(colorCtrl, 'كود اللون (hex بدون #)', Icons.color_lens_outlined),
  SizedBox(height: DesignTokens.space6),
  _providerTypeRow(selectedProviderType, (v) => setModalState(() => selectedProviderType = v)),
  SizedBox(height: DesignTokens.space20),

              _sectionHeader('أيقونة القسم', Icons.image_outlined),
              SizedBox(height: DesignTokens.space6),
              GestureDetector(
                onTap: () => pickImage(setModalState),
                child: Container(
                  width: double.infinity,
                  height: 120.h,
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
                  child: pickedImageFile != null
                    ? ClipRRect(
                        borderRadius: DesignTokens.brLg,
                        child: Image.file(File(pickedImageFile!.path), fit: BoxFit.cover),
                      )
                    : (selectedIconUrl != null && selectedIconUrl.startsWith('http'))
                      ? ClipRRect(
                          borderRadius: DesignTokens.brLg,
                          child: Image.network(selectedIconUrl, fit: BoxFit.cover, semanticLabel: 'أيقونة الخدمة',
                            errorBuilder: (_,__,___) => const Icon(Icons.image_outlined, size: DesignTokens.iconLg, color: AppTheme.textSecondary)),
                        )
                      : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Container(
                            padding: DesignTokens.padding12,
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withValues(alpha: 0.1),
                              borderRadius: DesignTokens.brFull,
                            ),
                            child: Icon(
                              selectedIconUrl != null ? _getIconFromCode(selectedIconUrl) : Icons.add_photo_alternate_outlined,
                              size: DesignTokens.iconLg,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                          SizedBox(height: DesignTokens.space4),
                          const Text(
                            'اضغط لاختيار صورة',
                            style: TextStyle(
                              fontSize: DesignTokens.textLabelSmall,
                              color: AppTheme.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ]),
                ),
              ),
              SizedBox(height: DesignTokens.space24),

              SizedBox(
                width: double.infinity,
                height: DesignTokens.buttonHeight,
                child: ElevatedButton(
                  onPressed: isSaving ? null : () async {
                    if (arCtrl.text.isEmpty || enCtrl.text.isEmpty) return;
                    setModalState(() => isSaving = true);

                    final colorHex = colorCtrl.text.trim().isEmpty ? '3B82F6' : colorCtrl.text.trim();
                    final iconUrl = await uploadIcon();
  final data = {
    'name': arCtrl.text,
    'name_ar': arCtrl.text,
    'name_en': enCtrl.text,
    'icon_url': iconUrl ?? '',
    'icon_color': '#$colorHex',
    'provider_type': selectedProviderType ?? 'handyman',
  };

                    try {
                      int categoryId;
                      if (existing != null) {
                        await SupabaseService.db.from('categories').update(data).eq('id', existing['id']);
                        categoryId = existing['id'];
                      } else {
                        final inserted = await SupabaseService.db.from('categories').insert(data).select().single();
                        categoryId = inserted['id'];
                      }

                      final commValue = commCtrl.text.trim().isEmpty ? '10' : commCtrl.text.trim();
                      final settingExists = await SupabaseService.db.from('app_settings').select('id').eq('key', 'category_commission_$categoryId').maybeSingle();
                      if (settingExists != null) {
                        await SupabaseService.db.from('app_settings').update({'value': commValue}).eq('key', 'category_commission_$categoryId');
                      } else {
                        await SupabaseService.db.from('app_settings').insert({'key': 'category_commission_$categoryId', 'value': commValue});
                      }
                      if (ctx.mounted) Navigator.pop(ctx);
                      _load();
                    } catch (e) {
                      setModalState(() => isSaving = false);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: DesignTokens.brLg),
                    elevation: DesignTokens.elevation0,
                  ),
                  child: isSaving
                    ? const SizedBox(
                        height: DesignTokens.space20,
                        width: DesignTokens.space20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            existing != null ? Icons.save_rounded : Icons.add_circle_outline_rounded,
                            size: DesignTokens.iconSm,
                          ),
                          SizedBox(width: DesignTokens.space4),
                          Text(
                            existing != null ? 'تحديث القسم' : 'إضافة القسم',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: DesignTokens.textTitleSmall,
                            ),
                          ),
                        ],
                      ),
                ),
              ),
              SizedBox(height: DesignTokens.space8),
            ]),
          ),
        ),
      ),
    );
  }

  Future<void> _delete(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف القسم'),
        content: const Text('هل أنت متأكد من حذف هذا القسم؟ لا يمكن التراجع.'),
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
      await SupabaseService.db.from('categories').delete().eq('id', id);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddDialog(),
        backgroundColor: AppTheme.primaryColor,
        icon: const Icon(Icons.add_rounded, color: Colors.white, size: DesignTokens.iconSm),
        label: const Text('قسم جديد', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: DesignTokens.textTitleSmall)),
        shape: RoundedRectangleBorder(borderRadius: DesignTokens.brLg),
      ),
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: DesignTokens.space24, vertical: DesignTokens.space12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [
                  Container(
                    padding: DesignTokens.padding12,
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: DesignTokens.brMd,
                    ),
                    child: const Icon(Icons.category_rounded, size: DesignTokens.iconSm, color: Colors.white),
                  ),
                  SizedBox(width: DesignTokens.space6),
                  const Text(
                    'الأقسام والأصناف',
                    style: TextStyle(
                      fontSize: DesignTokens.textBodyMedium,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ]),
                Container(
                  padding: DesignTokens.hPadding16 + DesignTokens.vPadding8,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: DesignTokens.brFull,
                  ),
                  child: Text(
                    '${_cats.length} قسم',
                    style: const TextStyle(
                      fontSize: DesignTokens.textLabelSmall,
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
              : _cats.isEmpty
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
                            Icons.category_outlined,
                            size: DesignTokens.iconDoctorAvatar,
                            color: AppTheme.primaryColor.withValues(alpha: 0.2),
                          ),
                        ),
                        SizedBox(height: DesignTokens.space16),
                        const Text(
                          'لا توجد أقسام',
                          style: TextStyle(
                            fontSize: DesignTokens.textTitleSmall,
                            color: AppTheme.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: DesignTokens.space4),
                        const Text(
                          'اضغط على "قسم جديد" لإضافة أول قسم',
                          style: TextStyle(
                            fontSize: DesignTokens.textBodySmall,
                            color: AppTheme.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.symmetric(horizontal: DesignTokens.space12),
                    itemCount: _cats.length,
                    itemBuilder: (_, i) {
                      final c = _cats[i];
                      final iconColorHex = (c['icon_color'] ?? '#3B82F6').replaceAll('#', '');
                      final iconColor = Color(int.parse('FF$iconColorHex', radix: 16));
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
                                  colors: [iconColor, iconColor.withValues(alpha: 0.3)],
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
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [iconColor.withValues(alpha: 0.15), iconColor.withValues(alpha: 0.05)],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: DesignTokens.brSm,
                                    ),
                                    child: (c['icon_url'] != null && c['icon_url'].toString().startsWith('http'))
                                      ? ClipRRect(
                                          borderRadius: DesignTokens.brSm,
                                          child: Image.network(
                                            c['icon_url'],
                                            fit: BoxFit.cover,
                                            semanticLabel: 'أيقونة الخدمة',
                                            errorBuilder: (_,__,___) => Icon(_getIconFromCode(c['icon_url']), color: iconColor, size: DesignTokens.iconSm),
                                          ),
                                        )
                                      : Icon(_getIconFromCode(c['icon_url']), color: iconColor, size: DesignTokens.iconSm),
                                  ),
                                  SizedBox(width: DesignTokens.space6),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          c['name_ar'] ?? '',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: DesignTokens.textBodyMedium,
                                            color: AppTheme.textPrimary,
                                          ),
                                        ),
                                        Text(
                                          (c['name_en'] ?? c['name'] ?? '').toString(),
                                          style: const TextStyle(
                                            fontSize: DesignTokens.textLabelSmall,
                                            color: AppTheme.textSecondary,
                                          ),
                                        ),
                                          FutureBuilder(
                                            future: SupabaseService.db.from('app_settings').select('value').eq('key', 'category_commission_${c['id']}').maybeSingle(),
                                            builder: (context, snap) {
                                              if (snap.connectionState != ConnectionState.done) {
                                                return SizedBox(width: DesignTokens.space12, height: DesignTokens.space12, child: CircularProgressIndicator(strokeWidth: 2));
                                              }
                                              if (snap.hasError) {
                                                return Text('خطأ', style: TextStyle(fontSize: DesignTokens.textLabelSmall, color: AppTheme.errorColor));
                                              }
                                              final comm = snap.data?['value'] ?? '10';
                                            return Container(
                                              margin: const EdgeInsets.only(top: DesignTokens.space2),
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
                                                    'عمولة: $comm%',
                                                    style: const TextStyle(
                                                      fontSize: DesignTokens.textLabelSmall,
                                                      color: AppTheme.tertiaryColor,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
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
                                    onPressed: () => _showAddDialog(existing: c),
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
                                    onPressed: () => _delete(c['id']),
                                    constraints: const BoxConstraints(minWidth: DesignTokens.touchTargetMin, minHeight: DesignTokens.touchTargetMin),
                                  ),
                                ]),
                              ),
                            ),
                          ]),
                        ),
                      );
                    },
                  ),
          ),
        ]),
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

IconData _getIconFromCode(dynamic code) {
  if (code == null) return Icons.category_rounded;
  final strCode = code.toString();
  if (strCode.startsWith('http')) return Icons.image_rounded;
  return Icons.category_rounded;
}

Widget _providerTypeRow(String? selected, void Function(String?) onChange) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text('نوع مقدم الخدمة', style: TextStyle(fontSize: 14, color: AppTheme.textPrimary)),
      const SizedBox(height: DesignTokens.space4),
      Row(
        children: [
          Expanded(
            child: _typeChoiceChip(
              label: 'تسوق',
              value: 'merchant',
              selected: selected == 'merchant',
              color: AppTheme.successColor,
              onChange: onChange,
            ),
          ),
          SizedBox(width: DesignTokens.space8),
          Expanded(
            child: _typeChoiceChip(
              label: 'توصيل مشاوير',
              value: 'driver',
              selected: selected == 'driver',
              color: AppTheme.successColor,
              onChange: onChange,
            ),
          ),
          SizedBox(width: DesignTokens.space8),
          Expanded(
            child: _typeChoiceChip(
              label: 'خدمة منزلية',
              value: 'handyman',
              selected: selected == 'handyman',
              color: AppTheme.primaryColor,
              onChange: onChange,
            ),
          ),
        ],
      ),
    ],
  );
}

Widget _typeChoiceChip({
  required String label,
  required String value,
  required bool selected,
  required Color color,
  required void Function(String?) onChange,
}) {
  return GestureDetector(
    onTap: () => onChange(value),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      decoration: BoxDecoration(
        gradient: selected ? LinearGradient(colors: [color, color.withValues(alpha: 0.7)], begin: Alignment.topLeft, end: Alignment.bottomRight) : null,
        color: selected ? null : AppTheme.backgroundColor,
        borderRadius: DesignTokens.brMd,
        border: selected ? null : Border.all(color: AppTheme.textPrimary.withValues(alpha: 0.12)),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: DesignTokens.textLabelMedium,
          fontWeight: FontWeight.bold,
          color: selected ? Colors.white : AppTheme.textSecondary,
        ),
      ),
    ),
  );
}
}