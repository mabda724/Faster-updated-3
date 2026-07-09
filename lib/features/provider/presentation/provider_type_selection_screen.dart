import 'package:flutter/material.dart';
import 'package:flutter/material.dart' show IconData;
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/services/supabase_service.dart';

class ProviderTypeSelectionScreen extends StatefulWidget {
  const ProviderTypeSelectionScreen({super.key});

  @override
  State<ProviderTypeSelectionScreen> createState() =>
      _ProviderTypeSelectionScreenState();
}

class _ProviderTypeSelectionScreenState
    extends State<ProviderTypeSelectionScreen> {
  String? _selectedType;
  bool _isLoading = false;

  final List<Map<String, dynamic>> _providerTypes = [
    {
      'type': 'merchant',
      'title': 'تاجر',
      'subtitle': 'رفع منتجاتك وبيعها للعملاء',
      'icon': Icons.store_rounded,
      'color': AppTheme.whatsappColor,
      'examples': ['سوبر ماركت', 'صيدلية', 'مخبز', 'خضار وفاكهة', 'جزار', 'فكهاني'],
    },
    {
      'type': 'driver',
      'title': 'سواق',
      'subtitle': 'توصيل الطلبات والمشاوير',
      'icon': Icons.directions_car_rounded,
      'color': AppTheme.successColor,
      'examples': ['توصيل طلبات', 'توصيل مشاوير', 'نقل بضائع'],
    },
    {
      'type': 'handyman',
      'title': 'صنايعي',
      'subtitle': 'تقديم خدمات منزلية وصيانة',
      'icon': Icons.build_rounded,
      'color': AppTheme.warningColor,
      'examples': ['كهربائي', 'سباك', 'تكييف', 'نجار', 'دهانات', 'تنظيف'],
    },
  ];

  Future<void> _saveProviderType() async {
    if (_selectedType == null) {
      _snack('الرجاء اختيار نوع مقدم الخدمة');
      return;
    }
    setState(() => _isLoading = true);
    try {
      final userId = SupabaseService().client.auth.currentUser?.id;
      if (userId == null) {
        _snack('خطأ في تحميل المستخدم');
        setState(() => _isLoading = false);
        return;
      }

      await SupabaseService().client.from('provider_profiles').update({
        'provider_type': _selectedType,
      }).eq('id', userId);

      if (!mounted) return;
      _snack('تم حفظ نوع مقدم الخدمة بنجاح', success: true);
      Navigator.pushReplacementNamed(context, '/provider');
    } catch (e) {
      _snack('حدث خطأ: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _snack(String msg, {bool success = false}) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        content: Text(msg),
        actions: [
          TextButton(
            isDefaultAction: true,
            child: const Text('حسنا'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(backgroundColor: AppTheme.backgroundColor, body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: DesignTokens.space16),
              Text(
                'ما هو نوعك؟',
                style: TextStyle(
                  fontSize: DesignTokens.textTitleLarge,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: DesignTokens.space8),
              Text(
                'اختر نوع مقدم الخدمة المناسب لك',
                style: TextStyle(
                  fontSize: DesignTokens.textLabelMedium,
                  color: AppTheme.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: DesignTokens.space32),
              Expanded(
                child: ListView.builder(
                  itemCount: _providerTypes.length,
                  itemBuilder: (context, index) {
                    final type = _providerTypes[index];
                    final isSelected = _selectedType == type['type'];
                    final color = type['color'] as Color;

                    return GestureDetector(
                      onTap: () {
                        setState(() => _selectedType = type['type']);
                      },
                      child: Container(
                        margin: EdgeInsets.only(bottom: DesignTokens.space16),
                        padding: EdgeInsets.all(DesignTokens.space16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: DesignTokens.brXl,
                          border: Border.all(
                            color: isSelected ? color : AppTheme.borderColor,
                            width: isSelected ? 2 : 1,
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
                            Container(
                              padding: EdgeInsets.all(DesignTokens.space12),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                type['icon'] as IconData,
                                size: 32.sp,
                                color: color,
                              ),
                            ),
                            SizedBox(width: DesignTokens.space16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    type['title'] as String,
                                    style: TextStyle(
                                      fontSize: DesignTokens.textTitleMedium,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                  SizedBox(height: DesignTokens.space4),
                                  Text(
                                    type['subtitle'] as String,
                                    style: TextStyle(
                                      fontSize: DesignTokens.textLabelSmall,
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                  SizedBox(height: DesignTokens.space8),
                                  Wrap(
                                    spacing: DesignTokens.space8,
                                    runSpacing: DesignTokens.space4,
                                    children: (type['examples'] as List<String>)
                                        .map((example) => Container(
                                              padding: EdgeInsets.symmetric(
                                                horizontal: DesignTokens.space8,
                                                vertical: DesignTokens.space4,
                                              ),
                                              decoration: BoxDecoration(
                                                color: color.withValues(alpha: 0.1),
                                                borderRadius: DesignTokens.brSm,
                                              ),
                                              child: Text(
                                                example,
                                                style: TextStyle(
                                                  fontSize: DesignTokens.textLabelSmall,
                                                  color: color,
                                                ),
                                              ),
                                            ))
                                        .toList(),
                                  ),
                                ],
                              ),
                            ),
                            if (isSelected)
                              Container(
                                padding: EdgeInsets.all(DesignTokens.space8),
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.check_rounded,
                                  color: Colors.white,
                                  size: 20.sp,
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              SizedBox(height: DesignTokens.space16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveProviderType,
                  padding: EdgeInsets.symmetric(vertical: DesignTokens.space16),
                  borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          'متابعة',
                          style: TextStyle(
                            fontSize: DesignTokens.textLabelLarge,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
