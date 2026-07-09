import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/services/supabase_service.dart';

class SellerStoreProfileScreen extends StatefulWidget {
  const SellerStoreProfileScreen({super.key});
  @override
  State<SellerStoreProfileScreen> createState() =>
      _SellerStoreProfileScreenState();
}

class _SellerStoreProfileScreenState extends State<SellerStoreProfileScreen> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _hoursCtrl = TextEditingController();
  Map<String, dynamic>? _providerProfile;
  String? _avatarUrl;
  bool _isLoading = true;
  bool _isSaving = false;
  XFile? _newLogo;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _addressCtrl.dispose();
    _hoursCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final uid = SupabaseService.currentUserId;
    if (uid == null) return;
    try {
      final profile = await SupabaseService.db
          .from('profiles')
          .select('full_name, email, phone, avatar_url')
          .eq('id', uid)
          .single();
      _nameCtrl.text = profile['full_name'] ?? '';
      _emailCtrl.text = profile['email'] ?? '';
      _phoneCtrl.text = profile['phone'] ?? '';
      _avatarUrl = profile['avatar_url'];

      _providerProfile = await SupabaseService.db
          .from('provider_profiles')
          .select('description, business_hours, address')
          .eq('id', uid)
          .maybeSingle();
      if (_providerProfile != null) {
        _descCtrl.text = _providerProfile!['description'] ?? '';
        _hoursCtrl.text = _providerProfile!['business_hours'] ?? '';
        _addressCtrl.text = _providerProfile!['address'] ?? '';
      }

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Error loading store profile: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickLogo() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
        source: ImageSource.gallery, maxWidth: 512, maxHeight: 512);
    if (picked != null) {
      setState(() => _newLogo = picked);
    }
  }

  Future<void> _save() async {
    final uid = SupabaseService.currentUserId;
    if (uid == null) return;
    setState(() => _isSaving = true);
    try {
      String? avatarUrl = _avatarUrl;
      if (_newLogo != null) {
        final bytes = await File(_newLogo!.path).readAsBytes();
        final ext = _newLogo!.name.split('.').last;
        final path = 'avatars/$uid.$ext';
        await SupabaseService.storage.from('avatars').uploadBinary(path, bytes,
            fileOptions: const FileOptions(upsert: true));
        avatarUrl = SupabaseService.storage.from('avatars').getPublicUrl(path);
      }

      await SupabaseService.db.from('profiles').update({
        'full_name': _nameCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'avatar_url': avatarUrl,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', uid);

      await SupabaseService.db.from('provider_profiles').upsert({
        'id': uid,
        'description': _descCtrl.text.trim(),
        'business_hours': _hoursCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حفظ التغييرات بنجاح'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error saving store profile: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('حدث خطأ أثناء الحفظ'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
    if (mounted) setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('ملف المتجر'),
        backgroundColor: AppTheme.backgroundColor,
        elevation: 0,
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor))
          : SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: DesignTokens.space24,
                vertical: DesignTokens.space16,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildAvatarSection(),
                  SizedBox(height: DesignTokens.space24),
                  _buildField('اسم المتجر', _nameCtrl, Icons.store_rounded),
                  SizedBox(height: DesignTokens.space16),
                  _buildField('الوصف', _descCtrl, Icons.description_rounded,
                      maxLines: 3),
                  SizedBox(height: DesignTokens.space16),
                  _buildField('رقم الهاتف', _phoneCtrl, Icons.phone_rounded,
                      keyboardType: TextInputType.phone),
                  SizedBox(height: DesignTokens.space16),
                  _buildField(
                      'البريد الإلكتروني', _emailCtrl, Icons.email_rounded,
                      keyboardType: TextInputType.emailAddress),
                  SizedBox(height: DesignTokens.space16),
                  _buildField('العنوان', _addressCtrl, Icons.location_on_rounded),
                  SizedBox(height: DesignTokens.space16),
                  _buildField('ساعات العمل', _hoursCtrl, Icons.schedule_rounded),
                  SizedBox(height: DesignTokens.space32),
                  SizedBox(
                    width: double.infinity,
                    height: 48.h,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: DesignTokens.brLg,
                        ),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'حفظ التغييرات',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  SizedBox(height: DesignTokens.space24),
                ],
              ),
            ),
    );
  }

  Widget _buildAvatarSection() {
    return Center(
      child: GestureDetector(
        onTap: _pickLogo,
        child: Stack(
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                border:
                    Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
                image: _newLogo != null
                    ? DecorationImage(
                        image: FileImage(File(_newLogo!.path)),
                        fit: BoxFit.cover,
                      )
                    : _avatarUrl != null
                        ? DecorationImage(
                            image: NetworkImage(_avatarUrl!),
                            fit: BoxFit.cover,
                          )
                        : null,
              ),
              child: _newLogo == null && _avatarUrl == null
                  ? Icon(Icons.store_rounded,
                      color: AppTheme.primaryColor, size: 40)
                  : null,
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: AppTheme.primaryColor,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.camera_alt_rounded,
                    color: Colors.white, size: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(
      String label, TextEditingController ctrl, IconData icon,
      {int maxLines = 1, TextInputType? keyboardType}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: DesignTokens.textBodyMedium.sp,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        SizedBox(height: DesignTokens.space4),
        TextFormField(
          controller: ctrl,
          maxLines: maxLines,
          keyboardType: keyboardType,
          style: TextStyle(
            fontSize: DesignTokens.textBodyLarge.sp,
            color: AppTheme.textPrimary,
          ),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: AppTheme.textTertiary, size: 20),
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
            border: OutlineInputBorder(
              borderRadius: DesignTokens.brLg,
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: DesignTokens.brLg,
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: DesignTokens.brLg,
              borderSide:
                  const BorderSide(color: AppTheme.primaryColor, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
