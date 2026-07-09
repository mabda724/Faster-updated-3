
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class AdminCarouselScreen extends StatefulWidget {
  const AdminCarouselScreen({super.key});
  @override
  State<AdminCarouselScreen> createState() => _AdminCarouselScreenState();
}

class _AdminCarouselScreenState extends State<AdminCarouselScreen> {
  List<Map<String, dynamic>> _images = [];
  bool _isLoading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final data = await SupabaseService.db.from('carousel_images').select().order('created_at', ascending: false);
      if (mounted) setState(() { _images = List<Map<String, dynamic>>.from(data); _isLoading = false; });
    } catch (e) { if (mounted) setState(() => _isLoading = false); }
  }

  Future<void> _upload() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1200, imageQuality: 85);
    if (file == null) return;
    setState(() => _isLoading = true);
    try {
      final bytes = await File(file.path).readAsBytes();
      final name = 'carousel_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await SupabaseService.storage.from('carousel').uploadBinary(name, bytes, fileOptions: const FileOptions(contentType: 'image/jpeg'));
      final url = SupabaseService.storage.from('carousel').getPublicUrl(name);
      await SupabaseService.db.from('carousel_images').insert({'image_url': url, 'title': 'بانر جديد', 'is_active': true});
      await _load();
    } catch (e) {
      if (mounted) { setState(() => _isLoading = false); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ في الرفع: $e'), backgroundColor: AppTheme.errorColor)); }
    }
  }

  Future<void> _delete(String id) async {
    await SupabaseService.db.from('carousel_images').delete().eq('id', id);
    _load();
  }

  Future<void> _toggle(String id, bool current) async {
    await SupabaseService.db.from('carousel_images').update({'is_active': !current}).eq('id', id);
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
        title: Text('إدارة الكاروسيل', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: DesignTokens.textTitleMedium)),
        leading: IconButton(icon: Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.textPrimary), tooltip: 'العودة', onPressed: () => Navigator.pop(context)),
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          borderRadius: DesignTokens.brXl,
          boxShadow: DesignTokens.shadow3(AppTheme.primaryColor),
        ),
        child: FloatingActionButton.extended(
          onPressed: _upload,
          backgroundColor: AppTheme.primaryColor,
          icon: Icon(Icons.add_photo_alternate_rounded, color: AppTheme.surfaceColor),
          label: Text('رفع صورة', style: TextStyle(color: AppTheme.surfaceColor, fontWeight: FontWeight.bold, fontSize: DesignTokens.textTitleSmall)),
          shape: RoundedRectangleBorder(borderRadius: DesignTokens.brXl),
        ),
      ),
      body: _isLoading
        ? Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
        : _images.isEmpty
          ? Center(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Container(
                  padding: EdgeInsets.all(DesignTokens.space6),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.08),
                    borderRadius: DesignTokens.brFull,
                  ),
                  child: Icon(Icons.photo_library_outlined, size: DesignTokens.iconXl, color: AppTheme.primaryColor.withValues(alpha: 0.4)),
                ),
                SizedBox(height: DesignTokens.space8),
                Text('لا توجد صور في الكاروسيل', style: TextStyle(color: AppTheme.textSecondary, fontSize: DesignTokens.textTitleSmall)),
                SizedBox(height: DesignTokens.space2),
                Text('اضغط على زر الرفع لإضافة بانر جديد', style: TextStyle(color: AppTheme.textTertiary, fontSize: DesignTokens.textBodySmall)),
              ]),
            )
          : ListView.builder(
              padding: EdgeInsets.all(DesignTokens.space24),
              itemCount: _images.length,
              itemBuilder: (ctx, i) {
                final img = _images[i];
                final isActive = img['is_active'] == true;
                return Container(
                  margin: EdgeInsets.only(bottom: DesignTokens.space12),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceColor,
                    borderRadius: DesignTokens.brXl,
                    boxShadow: DesignTokens.shadow2(AppTheme.textPrimary),
                    border: Border.all(
                      color: isActive
                        ? AppTheme.successColor.withValues(alpha: 0.2)
                        : AppTheme.textPrimary.withValues(alpha: 0.06),
                      width: isActive ? 1.5 : 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.vertical(top: Radius.circular(DesignTokens.radiusXl)),
                            child: Image.network(
                              img['image_url'] ?? '',
                              height: 180.h,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              semanticLabel: 'صورة العرض',
                              errorBuilder: (_, __, ___) => Container(
                                height: 180.h,
                                color: AppTheme.backgroundColor,
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.broken_image_outlined, size: DesignTokens.iconLg, color: AppTheme.textTertiary),
                                      SizedBox(height: DesignTokens.space2),
                                      Text('تعذر تحميل الصورة', style: TextStyle(color: AppTheme.textTertiary, fontSize: DesignTokens.textBodySmall)),
                                    ],
                                  ),
                                ),
                              ),
                              loadingBuilder: (_, child, progress) {
                                if (progress == null) return child;
                                return Container(
                                  height: 180.h,
                                  color: AppTheme.backgroundColor,
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      color: AppTheme.primaryColor,
                                      value: progress.expectedTotalBytes != null ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes! : null,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          Positioned(
                            top: DesignTokens.space4,
                            right: DesignTokens.space4,
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: DesignTokens.space3, vertical: DesignTokens.space1),
                              decoration: BoxDecoration(
                                color: isActive ? AppTheme.successColor : AppTheme.textSecondary,
                                borderRadius: DesignTokens.brSm,
                                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 4)],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isActive ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                                    size: DesignTokens.iconXs,
                                    color: AppTheme.surfaceColor,
                                  ),
                                  SizedBox(width: DesignTokens.space1),
                                  Text(
                                    isActive ? 'ظاهر' : 'مخفي',
                                    style: TextStyle(color: AppTheme.surfaceColor, fontWeight: FontWeight.bold, fontSize: DesignTokens.textLabelSmall),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: DesignTokens.space6, vertical: DesignTokens.space4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Text(
                                  img['title'] ?? 'بانر',
                                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: DesignTokens.textBodyMedium, color: AppTheme.textPrimary),
                                ),
                                if (img['created_at'] != null) ...[
                                  SizedBox(width: DesignTokens.space3),
                                  Text(
                                    _formatDate(img['created_at']),
                                    style: TextStyle(fontSize: DesignTokens.textLabelSmall, color: AppTheme.textTertiary),
                                  ),
                                ],
                              ],
                            ),
                            Row(
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    color: isActive ? AppTheme.successColor.withValues(alpha: 0.1) : AppTheme.textSecondary.withValues(alpha: 0.1),
                                    borderRadius: DesignTokens.brSm,
                                  ),
                                  child: Switch(
                                    value: isActive,
                                    onChanged: (_) => _toggle(img['id'].toString(), isActive),
                                    activeColor: AppTheme.surfaceColor,
                                    activeTrackColor: AppTheme.successColor.withValues(alpha: 0.5),
                                    thumbColor: WidgetStatePropertyAll(isActive ? AppTheme.successColor : AppTheme.textTertiary),
                                  ),
                                ),
                                SizedBox(width: DesignTokens.space1),
                                Container(
                                  decoration: BoxDecoration(
                                    color: AppTheme.errorColor.withValues(alpha: 0.1),
                                    borderRadius: DesignTokens.brSm,
                                  ),
                                  child: IconButton(
                                    icon: Icon(Icons.delete_outline_rounded, color: AppTheme.errorColor, size: DesignTokens.iconMd),
                                    tooltip: 'حذف',
                                    onPressed: () => _confirmDelete(img['id'].toString()),
                                    splashRadius: DesignTokens.touchTargetMin / 2,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  void _confirmDelete(String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('تأكيد الحذف', style: TextStyle(fontSize: DesignTokens.textTitleSmall, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
        content: Text('هل أنت متأكد من حذف هذه الصورة؟', style: TextStyle(fontSize: DesignTokens.textBodyMedium, color: AppTheme.textSecondary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('إلغاء', style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () { Navigator.pop(ctx); _delete(id); },
            child: Text('حذف', style: TextStyle(color: AppTheme.errorColor, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return '';
    try {
      final dt = DateTime.parse(dateString);
      final months = ['يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو', 'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'];
      return '${dt.day} ${months[dt.month - 1]}';
    } catch (_) { return ''; }
  }
}