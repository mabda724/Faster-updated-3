import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/services/supabase_service.dart';

class AdminPricingScreen extends StatefulWidget {
  const AdminPricingScreen({super.key});

  @override
  State<AdminPricingScreen> createState() => _AdminPricingScreenState();
}

class _AdminPricingScreenState extends State<AdminPricingScreen> {
  final _carPerKmCtrl = TextEditingController();
  final _scooterPerKmCtrl = TextEditingController();
  final _deliveryPerKmCtrl = TextEditingController();
  final _deliveryMinFeeCtrl = TextEditingController();
  final _deliveryMaxRatioCtrl = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  String? _saveError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _saveError = null;
    });

    try {
      final result = await SupabaseService.db.from('app_settings').select();

      String carPerKm = '3.5';
      String scooterPerKm = '2.0';
      String deliveryPerKm = '2.5';
      String deliveryMinFee = '15';
      String deliveryMaxRatio = '0.8';

      for (final row in result) {
        final key = row['key'] as String?;
        final value = row['value']?.toString() ?? '';

        switch (key) {
          case 'driver_car_price_per_km':
            carPerKm = value;
            break;
          case 'driver_scooter_price_per_km':
            scooterPerKm = value;
            break;
          case 'delivery_price_per_km':
            deliveryPerKm = value;
            break;
          case 'delivery_min_fee':
            deliveryMinFee = value;
            break;
          case 'delivery_max_fee_ratio':
            deliveryMaxRatio = value;
            break;
        }
      }

      if (!mounted) return;
      setState(() {
        _carPerKmCtrl.text = carPerKm;
        _scooterPerKmCtrl.text = scooterPerKm;
        _deliveryPerKmCtrl.text = deliveryPerKm;
        _deliveryMinFeeCtrl.text = deliveryMinFee;
        _deliveryMaxRatioCtrl.text = deliveryMaxRatio;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saveError = 'فشل تحميل الأسعار: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _save() async {
    final carRaw = _carPerKmCtrl.text.trim();
    final scooterRaw = _scooterPerKmCtrl.text.trim();
    final deliveryPerKmRaw = _deliveryPerKmCtrl.text.trim();
    final minFeeRaw = _deliveryMinFeeCtrl.text.trim();
    final maxRatioRaw = _deliveryMaxRatioCtrl.text.trim();

    final carPerKm = double.tryParse(carRaw);
    final scooterPerKm = double.tryParse(scooterRaw);
    final deliveryPerKm = double.tryParse(deliveryPerKmRaw);
    final minFee = double.tryParse(minFeeRaw);
    final maxRatio = double.tryParse(maxRatioRaw);

    if (carPerKm == null || carPerKm <= 0) {
      _showError('أدخل سعر صحيح للسيارة (أكبر من صفر)');
      return;
    }
    if (scooterPerKm == null || scooterPerKm <= 0) {
      _showError('أدخل سعر صحيح للسكوتر (أكبر من صفر)');
      return;
    }
    if (deliveryPerKm == null || deliveryPerKm <= 0) {
      _showError('أدخل سعر صحيح للتوصيل (أكبر من صفر)');
      return;
    }
    if (minFee == null || minFee < 0) {
      _showError('أدخل حد أدنى صحيح للتوصيل');
      return;
    }
    if (maxRatio == null || maxRatio <= 0 || maxRatio > 1) {
      _showError('أدخل نسبة قصوى صحيحة بين 0 و 1');
      return;
    }

    setState(() {
      _isSaving = true;
      _saveError = null;
    });

    try {
      final updates = {
        'driver_car_price_per_km': carPerKm.toString(),
        'driver_scooter_price_per_km': scooterPerKm.toString(),
        'delivery_price_per_km': deliveryPerKm.toString(),
        'delivery_min_fee': minFee.toString(),
        'delivery_max_fee_ratio': maxRatio.toString(),
      };

      // Upsert each key individually using the existing _upsert pattern.
      for (final entry in updates.entries) {
        final existing = await SupabaseService.db
            .from('app_settings')
            .select()
            .eq('key', entry.key)
            .maybeSingle();

        if (existing != null) {
          await SupabaseService.db
              .from('app_settings')
              .update({'value': entry.value})
              .eq('key', entry.key);
        } else {
          await SupabaseService.db
              .from('app_settings')
              .insert({'key': entry.key, 'value': entry.value});
        }
      }

      if (!mounted) return;
      _snack('تم حفظ أسعار الرحلات والتوصيل بنجاح');
    } catch (e) {
      _showError('خطأ في الحفظ: $e');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, textAlign: TextAlign.center),
        backgroundColor: AppTheme.errorColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: DesignTokens.brMd),
      ),
    );
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, textAlign: TextAlign.center),
        backgroundColor: AppTheme.primaryColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: DesignTokens.brMd),
      ),
    );
  }

  @override
  void dispose() {
    _carPerKmCtrl.dispose();
    _scooterPerKmCtrl.dispose();
    _deliveryPerKmCtrl.dispose();
    _deliveryMinFeeCtrl.dispose();
    _deliveryMaxRatioCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceColor,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'الأسعار',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: DesignTokens.textTitleMedium,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded, color: AppTheme.textPrimary),
          tooltip: 'العودة',
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor),
            )
          : SingleChildScrollView(
              padding: EdgeInsets.all(DesignTokens.space24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoBanner(),
                  SizedBox(height: DesignTokens.space24),
                  _buildSection(
                    icon: Icons.directions_car_rounded,
                    title: 'أسعار الرحلات (بالكيلومتر)',
                    description: 'تُستخدم لحساب سعر رحلة السائق بناءً على المسافة ونوع المركبة.',
                    children: [
                      _buildPriceField(
                        label: 'سعر الكيلومتر - سيارة',
                        hint: 'مثال: 3.5',
                        suffix: 'جنيه/كم',
                        controller: _carPerKmCtrl,
                        icon: Icons.directions_car_rounded,
                        info: 'يُطبق على السائقين بسيارة. يُضرب في عدد الكيلومترات لحساب السعر.',
                      ),
                      SizedBox(height: DesignTokens.space16),
                      _buildPriceField(
                        label: 'سعر الكيلومتر - سكوتر',
                        hint: 'مثال: 2.0',
                        suffix: 'جنيه/كم',
                        controller: _scooterPerKmCtrl,
                        icon: Icons.two_wheeler_rounded,
                        info: 'يُطبق على السائقين بسكوتر.',
                      ),
                    ],
                  ),
                  SizedBox(height: DesignTokens.space24),
                  _buildSection(
                    icon: Icons.delivery_dining_rounded,
                    title: 'أسعار التوصيل',
                    description: 'تُستخدم لحساب رسوم توصيل الطلبات مع منطق ذكي لمنع إلغاء الطلب.',
                    children: [
                      _buildPriceField(
                        label: 'سعر الكيلومتر - توصيل',
                        hint: 'مثال: 2.5',
                        suffix: 'جنيه/كم',
                        controller: _deliveryPerKmCtrl,
                        icon: Icons.two_wheeler_rounded,
                        info: 'يُستخدم لحساب رسوم التوصيل الأساسية بناءً على المسافة.',
                      ),
                      SizedBox(height: DesignTokens.space16),
                      _buildPriceField(
                        label: 'الحد الأدنى لرسوم التوصيل',
                        hint: 'مثال: 15',
                        suffix: 'جنيه',
                        controller: _deliveryMinFeeCtrl,
                        icon: Icons.money_rounded,
                        info: 'أقل مبلغ يمكن تحصيله لتوصيل طلب، حتى لو كانت المسافة قصيرة.',
                      ),
                      SizedBox(height: DesignTokens.space16),
                      _buildPriceField(
                        label: 'نسبة قصوى لرسوم التوصيل',
                        hint: 'مثال: 0.8',
                        suffix: '',
                        controller: _deliveryMaxRatioCtrl,
                        icon: Icons.speed_rounded,
                        info: 'الحد الأقصى لرسوم التوصيل كنسبة من إجمالي الطلب (0.8 = 80%). إذا تجاوزت الرسوم هذه النسبة يتم خفضها تلقائياً لمنع إلغاء العميل.',
                      ),
                    ],
                  ),
                  SizedBox(height: DesignTokens.space24),
                  if (_saveError != null) ...[
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(DesignTokens.space16),
                      decoration: BoxDecoration(
                        color: AppTheme.errorColor.withValues(alpha: 0.08),
                        borderRadius: DesignTokens.brMd,
                        border: Border.all(color: AppTheme.errorColor.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline_rounded, color: AppTheme.errorColor, size: DesignTokens.iconMd),
                          SizedBox(width: DesignTokens.space4),
                          Expanded(
                            child: Text(
                              _saveError!,
                              style: TextStyle(
                                color: AppTheme.errorColor,
                                fontSize: DesignTokens.textBodySmall,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: DesignTokens.space16),
                  ],
                  _buildSaveButton(),
                  SizedBox(height: DesignTokens.space32),
                ],
              ),
            ),
    );
  }

  Widget _buildInfoBanner() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(DesignTokens.space16),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.06),
        borderRadius: DesignTokens.brMd,
        border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(DesignTokens.space2),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              borderRadius: DesignTokens.brSm,
            ),
            child: Icon(
              Icons.info_outline_rounded,
              color: AppTheme.primaryColor,
              size: DesignTokens.iconMd,
            ),
          ),
          SizedBox(width: DesignTokens.space4),
          Expanded(
            child: Text(
              'التغييرات هنا تُطبق فوراً على حسابات الرحلات والتوصيل داخل التطبيق. يتم حساب السعر تلقائياً عند إنشاء الرحلة أو التوصيل.',
              style: TextStyle(
                fontSize: DesignTokens.textBodySmall,
                color: AppTheme.textSecondary,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required IconData icon,
    required String title,
    required String description,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: DesignTokens.br2xl,
        boxShadow: DesignTokens.shadow2(AppTheme.textPrimary),
      ),
      child: ClipRRect(
        borderRadius: DesignTokens.br2xl,
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor.withValues(alpha: 0.92),
            border: Border.all(color: AppTheme.textPrimary.withValues(alpha: 0.05)),
          ),
          padding: EdgeInsets.all(DesignTokens.space24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(DesignTokens.space3),
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: DesignTokens.brMd,
                      boxShadow: DesignTokens.shadow1(AppTheme.primaryColor),
                    ),
                    child: Icon(icon, color: AppTheme.surfaceColor, size: DesignTokens.iconMd),
                  ),
                  SizedBox(width: DesignTokens.space6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: DesignTokens.textTitleSmall,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        SizedBox(height: DesignTokens.space1),
                        Text(
                          description,
                          style: TextStyle(
                            fontSize: DesignTokens.textBodySmall,
                            color: AppTheme.textSecondary,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: DesignTokens.space20),
              ...children,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPriceField({
    required String label,
    required String hint,
    required String suffix,
    required TextEditingController controller,
    required IconData icon,
    required String info,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: DesignTokens.iconSm, color: AppTheme.primaryColor),
            SizedBox(width: DesignTokens.space2),
            Text(
              label,
              style: TextStyle(
                fontSize: DesignTokens.textBodySmall,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        SizedBox(height: DesignTokens.space2),
        Container(
          padding: EdgeInsets.all(DesignTokens.space6),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.03),
            borderRadius: DesignTokens.brSm,
            border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.08)),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: DesignTokens.textBodyMedium,
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: TextStyle(
                      color: AppTheme.textTertiary,
                      fontSize: DesignTokens.textBodyMedium,
                    ),
                    filled: true,
                    fillColor: AppTheme.surfaceColor,
                    border: OutlineInputBorder(
                      borderRadius: DesignTokens.brMd,
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: DesignTokens.brMd,
                      borderSide: BorderSide(
                        color: AppTheme.primaryColor.withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: DesignTokens.space16,
                      vertical: DesignTokens.space14,
                    ),
                    suffixText: suffix.isNotEmpty ? suffix : null,
                    suffixStyle: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: DesignTokens.textBodySmall,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              SizedBox(width: DesignTokens.space3),
              Container(
                padding: EdgeInsets.all(DesignTokens.space10),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.06),
                  borderRadius: DesignTokens.brSm,
                ),
                child: Icon(Icons.edit_rounded, color: AppTheme.primaryColor, size: DesignTokens.iconMd),
              ),
            ],
          ),
        ),
        SizedBox(height: DesignTokens.space2),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: DesignTokens.space2),
          child: Text(
            info,
            style: TextStyle(
              fontSize: DesignTokens.textLabelSmall,
              color: AppTheme.textTertiary,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: DesignTokens.buttonHeight,
      child: ElevatedButton(
        onPressed: _isSaving ? null : _save,
        style: ElevatedButton.styleFrom(
          backgroundColor: _isSaving ? AppTheme.textTertiary : null,
          shadowColor: AppTheme.primaryColor.withValues(alpha: 0.25),
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: DesignTokens.brLg),
        ),
        child: _isSaving
            ? SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppTheme.surfaceColor,
                ),
              )
            : Text(
                'حفظ الأسعار',
                style: TextStyle(
                  color: AppTheme.surfaceColor,
                  fontWeight: FontWeight.bold,
                  fontSize: DesignTokens.textBodyMedium,
                  letterSpacing: 0.3,
                ),
              ),
      ),
    );
  }
}
