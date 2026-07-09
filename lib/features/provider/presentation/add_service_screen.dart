import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/design_tokens.dart';
import 'package:flutter/material.dart' show MaterialPageRoute, InputDecoration, OutlineInputBorder, TextFormField, DropdownButtonFormField, DropdownMenuItem, Form, FormState, GlobalKey;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:faster_app/core/services/supabase_service.dart';
import 'package:faster_app/core/utils/snackbar_utils.dart';

class AddServiceScreen extends ConsumerStatefulWidget {
  const AddServiceScreen({super.key});

  @override
  ConsumerState<AddServiceScreen> createState() => _AddServiceScreenState();
}

class _AddServiceScreenState extends ConsumerState<AddServiceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameArController = TextEditingController();
  final _nameEnController = TextEditingController();
  final _descArController = TextEditingController();
  final _descEnController = TextEditingController();
  final _priceController = TextEditingController();

  int? _selectedCategoryId;
  List<Map<String, dynamic>> _categories = [];
  bool _isLoading = false;
  XFile? _selectedImage;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final data = await SupabaseService.db.from('categories').select();

      // Deduplicate categories by id
      final uniqueCatsMap = <int, Map<String, dynamic>>{};
      for (var c in data) {
        final id = c['id'] as int;
        if (!uniqueCatsMap.containsKey(id)) {
          uniqueCatsMap[id] = Map<String, dynamic>.from(c);
        }
      }

      setState(() {
        _categories = uniqueCatsMap.values.toList();
      });
    } catch (e) {
      debugPrint('Error loading categories: $e');
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _selectedImage = image;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _selectedCategoryId == null) {
      if (_selectedCategoryId == null) {
        SnackBarUtils.showError(context, 'يرجى اختيار القسم');
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = SupabaseService.client.auth.currentUser;
      if (user == null) throw 'يجب تسجيل الدخول أولاً';

      // Check if user is a provider
      final providerProfile = await SupabaseService.db
          .from('provider_profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (providerProfile == null) {
        throw 'يجب إكمال ملفك الشخصي كمقدم خدمة أولاً لتتمكن من إضافة خدمات';
      }

      String? imageUrl;
      if (_selectedImage != null) {
        final fileExt = _selectedImage!.path.split('.').last.toLowerCase();
        final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';
        final filePath = '${user.id}/$fileName';

        // Determine content type
        String contentType = 'image/jpeg';
        if (fileExt == 'png') contentType = 'image/png';
        if (fileExt == 'webp') contentType = 'image/webp';
        if (fileExt == 'gif') contentType = 'image/gif';

        final bytes = await _selectedImage!.readAsBytes();
        await SupabaseService.client.storage.from('service-images').uploadBinary(
          filePath,
          bytes,
          fileOptions: FileOptions(contentType: contentType),
        );

        imageUrl = SupabaseService.client.storage.from('service-images').getPublicUrl(filePath);
      }

      await SupabaseService.db.from('services').insert({
        'title': _nameArController.text,
        'description': _descArController.text,
        'base_price': double.parse(_priceController.text),
        'price': double.parse(_priceController.text),
        'category_id': _selectedCategoryId,
        'provider_id': user.id,
        'image_url': imageUrl,
        'is_active': true,
      });

      if (mounted) {
        SnackBarUtils.showSuccess(context, 'تمت إضافة الخدمة بنجاح');
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint('Add service error: $e');
      if (mounted) {
        String errorMsg = e.toString();
        if (errorMsg.contains('42501')) {
          errorMsg = 'غير مسموح لك بإضافة خدمة. تأكد من أنك مسجل كمقدم خدمة.';
        }
        SnackBarUtils.showError(context, 'فشل في إضافة الخدمة: $errorMsg');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(backgroundColor: AppTheme.backgroundColor, body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(DesignTokens.space20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildImagePicker(),
                      SizedBox(height: DesignTokens.space20),
                      _buildTextField(_nameArController, 'اسم الخدمة (بالعربية)'),
                      SizedBox(height: DesignTokens.space16),
                      _buildTextField(_nameEnController, 'Service Name (English)'),
                      SizedBox(height: DesignTokens.space16),
                      _buildCategoryDropdown(),
                      SizedBox(height: DesignTokens.space16),
                      _buildTextField(_priceController, 'السعر', keyboardType: TextInputType.number),
                      SizedBox(height: DesignTokens.space16),
                      _buildTextField(_descArController, 'وصف الخدمة (بالعربية)', maxLines: 3),
                      SizedBox(height: DesignTokens.space16),
                      _buildTextField(_descEnController, 'Description (English)', maxLines: 3),
                      SizedBox(height: DesignTokens.space32),
                      SizedBox(
                        width: double.infinity,
                        height: DesignTokens.buttonHeight + 3,
                        child: ElevatedButton(
                          onPressed: _submit,
                          borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
                          child: Text(
                            'إضافة الخدمة',
                            style: TextStyle(
                              fontSize: DesignTokens.textTitleMedium,
                              fontWeight: FontWeight.w600,
                            ),
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

  Widget _buildImagePicker() {
    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        height: 150,
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppTheme.textSecondary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
          border: Border.all(color: AppTheme.textSecondary.withValues(alpha: 0.2)),
        ),
        child: _selectedImage != null
            ? ClipRRect(
                borderRadius: DesignTokens.brLg,
                child: kIsWeb
                    ? Image.network(_selectedImage!.path, fit: BoxFit.cover, semanticLabel: 'صورة الخدمة')
                    : Image.file(File(_selectedImage!.path), fit: BoxFit.cover),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.camera_alt_rounded, size: DesignTokens.iconXl, color: AppTheme.textSecondary),
                  SizedBox(height: DesignTokens.space10),
                  Text('إضافة صورة الخدمة', style: TextStyle(color: AppTheme.textSecondary)),
                ],
              ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, {TextInputType? keyboardType, int maxLines = 1}) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: DesignTokens.brLg),
      ),
      validator: (value) => value == null || value.isEmpty ? 'هذا الحقل مطلوب' : null,
    );
  }

  Widget _buildCategoryDropdown() {
    return DropdownButtonFormField<int>(
      initialValue: _selectedCategoryId,
      decoration: InputDecoration(
        labelText: 'القسم',
        filled: true,
        fillColor: Colors.white,
        prefixIcon: const Icon(Icons.grid_view_rounded, color: AppTheme.primaryColor),
        border: OutlineInputBorder(borderRadius: DesignTokens.brLg),
      ),
      items: _categories.map((cat) {
        return DropdownMenuItem<int>(
          value: cat['id'] as int,
          child: Text(cat['name_ar'] ?? cat['name_en'] ?? ''),
        );
      }).toList(),
      onChanged: (val) => setState(() => _selectedCategoryId = val),
      validator: (value) => value == null ? 'يرجى اختيار القسم' : null,
    );
  }
}
