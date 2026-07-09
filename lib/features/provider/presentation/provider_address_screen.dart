import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/widgets/map_picker_screen.dart';

class ProviderAddressScreen extends StatefulWidget {
  const ProviderAddressScreen({super.key});

  @override
  State<ProviderAddressScreen> createState() => _ProviderAddressScreenState();
}

class _ProviderAddressScreenState extends State<ProviderAddressScreen> {
  bool _isLoading = false;
  String? _address;
  double? _latitude;
  double? _longitude;

  @override
  void initState() {
    super.initState();
    _loadCurrentAddress();
  }

  Future<void> _loadCurrentAddress() async {
    final uid = SupabaseService.currentUserId;
    if (uid == null) return;
    try {
      final profile = await SupabaseService.db
          .from('provider_profiles')
          .select('address, latitude, longitude')
          .eq('id', uid)
          .maybeSingle();
      if (profile != null && mounted) {
        setState(() {
          _address = profile['address'];
          _latitude = double.tryParse(profile['latitude']?.toString() ?? '');
          _longitude = double.tryParse(profile['longitude']?.toString() ?? '');
        });
      }
    } catch (e) {
      debugPrint('Error loading address: $e');
    }
  }

  Future<void> _pickLocation() async {
    final initialLocation = LatLng(
      _latitude ?? 30.0444,
      _longitude ?? 31.2357,
    );

    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => MapPickerScreen(initialLocation: initialLocation),
      ),
    );

    if (result != null && mounted) {
      final location = result['location'] as LatLng;
      final address = result['address'] as String;

      setState(() {
        _address = address;
        _latitude = location.latitude;
        _longitude = location.longitude;
      });

      await _saveAddress(address, location.latitude, location.longitude);
    }
  }

  Future<void> _saveAddress(String address, double lat, double lng) async {
    setState(() => _isLoading = true);

    final uid = SupabaseService.currentUserId;
    if (uid == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final existing = await SupabaseService.db
          .from('provider_profiles')
          .select('id')
          .eq('id', uid)
          .maybeSingle();

      if (existing == null) {
        await SupabaseService.db.from('provider_profiles').insert({
          'id': uid,
          'address': address,
          'latitude': lat,
          'longitude': lng,
          'profession': 'مقدم خدمة',
          'rating': 0,
          'is_online': false,
          'wallet_balance': 0,
          'document_verification_status': 'pending',
          'updated_at': DateTime.now().toIso8601String(),
        });
      } else {
        await SupabaseService.db.from('provider_profiles').update({
          'address': address,
          'latitude': lat,
          'longitude': lng,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', uid);
      }

      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            content: const Text('تم تحديث العنوان بنجاح'),
            actions: [
              TextButton(
                child: const Text('حسنا'),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      debugPrint('Error saving address: $e');
      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            content: Text('فشل حفظ العنوان: $e'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(backgroundColor: AppTheme.backgroundColor, body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(24.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _address == null ? 'لم يتم تحديد العنوان بعد' : 'تغيير العنوان',
                      style: TextStyle(
                        fontSize: DesignTokens.textTitleSmall,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: DesignTokens.space8),
                    Text(
                      'هذا العنوان سيظهر للعملاء لمساعدتهم في تحديد موقعك',
                      style: TextStyle(
                        fontSize: DesignTokens.textBodyMedium,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    SizedBox(height: 24.h),

                    if (_address != null && _latitude != null && _longitude != null) ...[
                      Container(
                        padding: EdgeInsets.all(DesignTokens.space16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: DesignTokens.brLg,
                          border: Border.all(color: AppTheme.successColor.withValues(alpha: 0.5)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.check_circle_rounded, color: AppTheme.successColor, size: DesignTokens.iconMd),
                                SizedBox(width: DesignTokens.space8),
                                Text(
                                  'العنوان الحالي',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: DesignTokens.textTitleSmall,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: DesignTokens.space12),
                            Row(
                              children: [
                                Icon(Icons.location_on_rounded, color: AppTheme.primaryColor, size: DesignTokens.iconMd),
                                SizedBox(width: DesignTokens.space8),
                                Expanded(
                                  child: Text(
                                    _address!,
                                    style: TextStyle(
                                      fontSize: DesignTokens.textBodySmall,
                                      color: AppTheme.textSecondary,
                                    ),
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: DesignTokens.space8),
                            Text(
                              'lat: ${_latitude!.toStringAsFixed(6)}, lng: ${_longitude!.toStringAsFixed(6)}',
                              style: TextStyle(
                                fontSize: DesignTokens.textLabelSmall,
                                color: AppTheme.textSecondary.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 16.h),
                    ],

                    Container(
                      padding: EdgeInsets.all(DesignTokens.space16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: DesignTokens.brLg,
                        border: Border.all(color: AppTheme.textSecondary.withValues(alpha: 0.1)),
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _address == null
                                  ? Icons.location_on_rounded
                                  : Icons.my_location,
                              color: AppTheme.primaryColor,
                              size: DesignTokens.iconXl,
                            ),
                          ),
                          SizedBox(height: DesignTokens.space16),
                          Text(
                            _address == null ? 'لم يتم تحديد العنوان بعد' : 'تغيير العنوان',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: DesignTokens.space8),
                          Text(
                            _address == null
                                ? 'اضغط على الزر التالي لتحديد عنوان عملك على الخريطة'
                                : 'اضغط لتحديث عنوان عملك على الخريطة',
                            style: TextStyle(
                              fontSize: DesignTokens.textBodySmall,
                              color: AppTheme.textSecondary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: DesignTokens.space20),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton(
                              onPressed: _pickLocation,
                              style: ElevatedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
                                ),
                                padding: EdgeInsets.zero,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.map_rounded, color: Colors.white),
                                  SizedBox(width: DesignTokens.space8),
                                  Text(
                                    _address == null ? 'تحديد العنوان' : 'تغيير العنوان',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: DesignTokens.space24),

                    Container(
                      padding: EdgeInsets.all(DesignTokens.space16),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.05),
                        borderRadius: DesignTokens.brMd,
                        border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.1)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_rounded, color: AppTheme.primaryColor.withValues(alpha: 0.7)),
                          SizedBox(width: DesignTokens.space12),
                          Expanded(
                            child: Text(
                              'عنوانك سيُستخدم لعرضك على الخريطة للعملاء القريبين منك',
                              style: TextStyle(
                                fontSize: DesignTokens.textBodySmall,
                                color: AppTheme.primaryColor.withValues(alpha: 0.7),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
