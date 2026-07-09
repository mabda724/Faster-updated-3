import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/design_tokens.dart';

class PartnerDocumentUploadScreen extends StatefulWidget {
  const PartnerDocumentUploadScreen({super.key});

  @override
  State<PartnerDocumentUploadScreen> createState() => _PartnerDocumentUploadScreenState();
}

class _PartnerDocumentUploadScreenState extends State<PartnerDocumentUploadScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _role;
  String _docStatus = 'pending';

  // Provider fields
  String? _nationalIdNumber;
  String? _idDocumentUrl;
  String? _profilePhotoUrl;

  // Seller fields
  String? _commercialRegUrl;
  String? _taxId;
  String? _storePhotoUrl;

  // Driver fields
  String? _licenseUrl;
  String? _vehicleRegUrl;
  String? _vehiclePhotoUrl;

  // Delivery fields
  String? _vehicleInsuranceUrl;

  List<String> _otherDocuments = [];

  bool _isUploadingId = false;
  bool _isUploadingProfile = false;
  String _uploadingField = '';

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadExistingDocuments();
  }

  Future<void> _loadExistingDocuments() async {
    final uid = SupabaseService.currentUserId;
    if (uid == null) return;

    try {
      final userProfile = await SupabaseService.db
          .from('profiles')
          .select('role')
          .eq('id', uid)
          .single();
      _role = userProfile['role'] as String?;

      final profile = await SupabaseService.db
          .from('provider_profiles')
          .select()
          .eq('id', uid)
          .maybeSingle();

      if (profile != null && mounted) {
        setState(() {
          _nationalIdNumber = profile['national_id_number'];
          _idDocumentUrl = profile['id_document_url'];
          _profilePhotoUrl = profile['profile_document_url'];
          _commercialRegUrl = profile['commercial_registration_url'];
          _taxId = profile['tax_id'];
          _storePhotoUrl = profile['store_photo_url'];
          _licenseUrl = profile['license_url'];
          _vehicleRegUrl = profile['vehicle_registration_url'];
          _vehiclePhotoUrl = profile['vehicle_photo_url'];
          _vehicleInsuranceUrl = profile['vehicle_insurance_url'];
          _otherDocuments = List<String>.from(profile['other_documents'] ?? []);
          _docStatus = profile['document_verification_status'] ?? 'pending';
        });
      }
    } catch (e) {
      debugPrint('Error loading documents: $e');
    }
  }

  Future<void> _pickAndUploadImage({
    required String field,
    required Function(String) onUploadComplete,
  }) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );

      if (image == null) return;

      setState(() => _uploadingField = field);

      final bytes = await image.readAsBytes();
      final fileName = 'docs/${SupabaseService.currentUserId}/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final response = await SupabaseService.db.storage
          .from('provider-documents')
          .uploadBinary(fileName, bytes);

      if (response.isNotEmpty) {
        final publicUrl = SupabaseService.db.storage
            .from('provider-documents')
            .getPublicUrl(fileName);
        onUploadComplete(publicUrl);
      }
    } catch (e) {
      debugPrint('Upload error: $e');
      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            content: Text('خطأ في الرفع: $e'),
            actions: [
              TextButton(
                child: const Text('حسنا'),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      }
    } finally {
      setState(() => _uploadingField = '');
    }
  }

  Future<void> _uploadFile({
    required String column,
    required String label,
  }) async {
    final uid = SupabaseService.currentUserId;
    if (uid == null) return;
    await _pickAndUploadImage(
      field: column,
      onUploadComplete: (url) async {
        await SupabaseService.db
            .from('provider_profiles')
            .update({column: url})
            .eq('id', uid);
        setState(() {
          if (column == 'id_document_url') _idDocumentUrl = url;
          if (column == 'profile_document_url') _profilePhotoUrl = url;
          if (column == 'commercial_registration_url') _commercialRegUrl = url;
          if (column == 'store_photo_url') _storePhotoUrl = url;
          if (column == 'license_url') _licenseUrl = url;
          if (column == 'vehicle_registration_url') _vehicleRegUrl = url;
          if (column == 'vehicle_photo_url') _vehiclePhotoUrl = url;
          if (column == 'vehicle_insurance_url') _vehicleInsuranceUrl = url;
        });
        if (mounted) {
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              content: Text('تم رفع $label'),
              actions: [
                TextButton(
                  child: const Text('حسنا'),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          );
        }
      },
    );
  }

  Future<void> _submit() async {
    if (_role == 'provider' && !_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    setState(() => _isLoading = true);
    try {
      final uid = SupabaseService.currentUserId;
      if (uid == null) return;

      final updateData = <String, dynamic>{
        'document_verification_status': 'pending',
      };
      if (_role == 'provider' || _role == 'seller') {
        updateData['national_id_number'] = _nationalIdNumber;
      }
      if (_role == 'seller') {
        updateData['tax_id'] = _taxId;
      }

      await SupabaseService.db
          .from('provider_profiles')
          .update(updateData)
          .eq('id', uid);

      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            content: const Text('تم حفظ البيانات'),
            actions: [
              TextButton(
                child: const Text('حسنا'),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        );
        _loadExistingDocuments();
      }
    } catch (e) {
      debugPrint('Submit error: $e');
      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            content: Text('خطأ: $e'),
            actions: [
              TextButton(
                child: const Text('حسنا'),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, String>> _getDocumentFields() {
    switch (_role) {
      case 'seller':
        return [
          {'column': 'commercial_registration_url', 'label': 'السجل التجاري'},
          {'column': 'id_document_url', 'label': 'بطاقة الهوية'},
          {'column': 'store_photo_url', 'label': 'صورة المتجر'},
          {'column': 'profile_document_url', 'label': 'الصورة الشخصية'},
        ];
      case 'driver':
        return [
          {'column': 'license_url', 'label': 'رخصة القيادة'},
          {'column': 'vehicle_registration_url', 'label': 'رخصة المركبة'},
          {'column': 'vehicle_photo_url', 'label': 'صورة المركبة'},
          {'column': 'profile_document_url', 'label': 'الصورة الشخصية'},
        ];
      case 'delivery':
        return [
          {'column': 'license_url', 'label': 'رخصة القيادة'},
          {'column': 'vehicle_insurance_url', 'label': 'تأمين المركبة'},
          {'column': 'vehicle_photo_url', 'label': 'صورة المركبة'},
          {'column': 'profile_document_url', 'label': 'الصورة الشخصية'},
        ];
      default: // provider
        return [
          {'column': 'id_document_url', 'label': 'بطاقة الهوية'},
          {'column': 'profile_document_url', 'label': 'الصورة الشخصية'},
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(backgroundColor: AppTheme.backgroundColor, body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(DesignTokens.space8),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Status card
                      Container(
                        decoration: BoxDecoration(
                          color: _docStatus == 'approved'
                              ? AppTheme.successColor.withValues(alpha: 0.1)
                              : AppTheme.tertiaryColor.withValues(alpha: 0.1),
                          borderRadius: DesignTokens.brLg,
                        ),
                        padding: const EdgeInsets.all(DesignTokens.space12),
                        child: Row(
                          children: [
                            Icon(
                              _docStatus == 'approved'
                                  ? Icons.check_circle_rounded
                                  : Icons.schedule_rounded,
                              color: _docStatus == 'approved'
                                  ? AppTheme.successColor
                                  : AppTheme.tertiaryColor,
                              size: DesignTokens.iconLg,
                            ),
                            const SizedBox(width: DesignTokens.space12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _docStatus == 'approved' ? 'تم التحقق من حسابك' : 'في انتظار التحقق',
                                    style: TextStyle(
                                      color: _docStatus == 'approved'
                                          ? AppTheme.successColor
                                          : AppTheme.tertiaryColor,
                                      fontSize: DesignTokens.textBodyMedium,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const Text(
                                    'يرجى رفع الوثائق للمراجعة',
                                    style: TextStyle(fontSize: DesignTokens.textBodySmall),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: DesignTokens.space8),

                      // Role-specific fields
                      if (_role == 'provider') ...[
                        Text('رقم الهوية', style: TextStyle(fontSize: DesignTokens.textBodyMedium)),
                        SizedBox(height: DesignTokens.space2),
                        TextFormField(
                          initialValue: _nationalIdNumber,
                          decoration: InputDecoration(
                            hintText: 'أدخل رقم الهوية',
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(borderRadius: DesignTokens.brMd),
                          ),
                          keyboardType: TextInputType.number,
                          onSaved: (v) => _nationalIdNumber = v?.trim(),
                        ),
                        SizedBox(height: DesignTokens.space8),
                      ],
                      if (_role == 'seller') ...[
                        Text('السجل التجاري', style: TextStyle(fontSize: DesignTokens.textBodyMedium)),
                        SizedBox(height: DesignTokens.space2),
                        TextFormField(
                          initialValue: _taxId,
                          decoration: InputDecoration(
                            hintText: 'أدخل رقم السجل التجاري',
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(borderRadius: DesignTokens.brMd),
                          ),
                          keyboardType: TextInputType.number,
                          onSaved: (v) => _taxId = v?.trim(),
                        ),
                        SizedBox(height: DesignTokens.space8),
                      ],

                      // Document upload buttons
                      ..._getDocumentFields().map((doc) {
                        final column = doc['column']!;
                        final label = doc['label']!;
                        final isUploading = _uploadingField == column;
                        final value = {
                          'id_document_url': _idDocumentUrl,
                          'profile_document_url': _profilePhotoUrl,
                          'commercial_registration_url': _commercialRegUrl,
                          'store_photo_url': _storePhotoUrl,
                          'license_url': _licenseUrl,
                          'vehicle_registration_url': _vehicleRegUrl,
                          'vehicle_photo_url': _vehiclePhotoUrl,
                          'vehicle_insurance_url': _vehicleInsuranceUrl,
                        }[column];

                        return Padding(
                          padding: EdgeInsets.only(bottom: 8.h),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(label, style: TextStyle(fontSize: DesignTokens.textBodyMedium)),
                              SizedBox(height: 4.h),
                              Row(
                                children: [
                                  ElevatedButton(
                                    onPressed: isUploading ? null : () => _uploadFile(column: column, label: label),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.primaryColor,
                                      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
                                    ),
                                    child: isUploading
                                        ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white))
                                        : Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: const [
                                              Icon(Icons.cloud_upload_rounded, color: Colors.white),
                                              SizedBox(width: 4),
                                              Text('رفع'),
                                            ],
                                          ),
                                  ),
                                  SizedBox(width: 8.w),
                                  if (value != null)
                                    Expanded(
                                      child: Row(
                                        children: [
                                          Icon(Icons.check_circle_rounded, color: AppTheme.successColor, size: DesignTokens.iconSm),
                                          SizedBox(width: 4.w),
                                          Expanded(
                                            child: Text('تم الرفع',
                                                style: TextStyle(color: AppTheme.successColor, fontSize: 12)),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }),

                      // Submit
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
                            ),
                          ),
                          child: _isLoading
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text('حفظ وإرسال للمراجعة'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
