import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/paymob_service.dart';

class ProviderSubscriptionScreen extends StatefulWidget {
  const ProviderSubscriptionScreen({super.key});

  @override
  State<ProviderSubscriptionScreen> createState() =>
      _ProviderSubscriptionScreenState();
}

class _ProviderSubscriptionScreenState
    extends State<ProviderSubscriptionScreen> {
  bool _isLoading = false;
  String _selectedPlan = 'premium'; // monthly, yearly, premium

  final List<Map<String, dynamic>> _plans = [
    {
      'id': 'standard',
      'name': 'الباقة العادية',
      'price': 0,
      'features': [
        'الظهور العادي في البحث',
        'استقبال طلبات محدودة',
        'دعم فني عبر البريد',
      ],
      'color': AppTheme.textSecondary,
    },
    {
      'id': 'premium',
      'name': 'الباقة المميزة (الأكثر طلباً)',
      'price': 150,
      'features': [
        'الظهور في مقدمة البحث',
        'شارات "موثق مميز"',
        'استقبال طلبات غير محدودة',
        'دعم فني سريع 24/7',
      ],
      'color': AppTheme.primaryColor,
      'isBest': true,
    },
    {
      'id': 'featured',
      'name': 'باقة النجوم',
      'price': 400,
      'features': [
        'ظهور كإعلان ممول',
        'خصومات على العمولات',
        'لوحة تحكم متقدمة',
        'أولوية في ترشيح المهام',
      ],
      'color': AppTheme.tertiaryColor,
    },
  ];

  void _showMessage(String msg, {bool isError = false}) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        content: Text(msg),
        actions: [
          TextButton(
            isDefaultAction: true,
            isDestructiveAction: isError,
            child: const Text('حسنا'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Future<void> _processSubscription() async {
    final plan = _plans.firstWhere((p) => p['id'] == _selectedPlan);
    if (plan['price'] == 0) {
      _showMessage('أنت مشترك بالفعل في الباقة العادية');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final uid = SupabaseService.currentUserId;
      if (uid == null) throw Exception('يجب تسجيل الدخول');

      // 1. Get profile data
      final profile = await SupabaseService.db
          .from('profiles')
          .select()
          .eq('id', uid)
          .single();

      // 2. Start Paymob Payment via Wrapper (Standard Secure Mode)
      final result = await PaymobServiceWrapper.pay(
        amount: plan['price'],
        userId: uid,
        fullName: profile['full_name'] ?? 'Faster Provider',
        email: SupabaseService.auth.currentUser?.email ?? 'test@faster.com',
        phone: profile['phone_number'] ?? profile['phone'] ?? '01010101010',
        buttonColor: plan['color'],
      );

      if (result.isSuccessful) {
        final now = DateTime.now().toUtc();
        final expiry = now.add(const Duration(days: 30));
        final priorityBoost = _selectedPlan == 'featured'
            ? 50
            : _selectedPlan == 'premium'
                ? 20
                : 0;

        // 3. Update Provider Status in DB
        await SupabaseService.db
            .from('provider_profiles')
            .update({
              'is_online': true,
              'subscription_plan': _selectedPlan,
              'subscription_expiry': expiry.toIso8601String(),
              'priority_boost': priorityBoost,
            })
            .eq('id', uid);

        await SupabaseService.db.from('provider_subscriptions').insert({
          'provider_id': uid,
          'plan_id': _selectedPlan,
          'amount_paid': plan['price'],
          'payment_method': 'card',
          'payment_status': 'paid',
          'starts_at': now.toIso8601String(),
          'expires_at': expiry.toIso8601String(),
        });

        if (mounted) {
          _showSuccessDialog(plan['name']);
        }
      } else {
        if (mounted) {
          _showMessage(
            result.isRejected ? 'تم رفض عملية الدفع' : 'فشلت عملية الاشتراك',
            isError: true,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        _showMessage('خطأ: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSuccessDialog(String planName) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        content: Padding(
          padding: const EdgeInsets.only(top: DesignTokens.space8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.star_rounded,
                color: AppTheme.tertiaryColor,
                size: DesignTokens.iconDoctorAvatar,
              ),
              const SizedBox(height: DesignTokens.space16),
              Text(
                'تهانينا!',
                style: TextStyle(
                  fontSize: DesignTokens.textTitleLarge,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: DesignTokens.space8),
              Text(
                'لقد أصبحت الآن مشتركاً في $planName',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: DesignTokens.space4),
              Text(
                'سيتم تمييز حسابك في نتائج البحث فوراً.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: DesignTokens.textBodySmall, color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            isDefaultAction: true,
            child: const Text('ابدأ الآن'),
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context); // Back to profile
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(backgroundColor: AppTheme.backgroundColor, body: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'زد من أرباحك وضاعف فرصك',
                    style: TextStyle(
                      fontSize: DesignTokens.textDisplayMedium,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: DesignTokens.space8),
                  Text(
                    'اختر الباقة المناسبة لك للظهور بشكل أفضل للعملاء',
                    style: TextStyle(color: AppTheme.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),

                  ..._plans.map((plan) => _buildPlanCard(plan)),
                ],
              ),
            ),

            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(DesignTokens.space20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withValues(alpha: 0.5),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _processSubscription,
                    padding: const EdgeInsets.symmetric(vertical: DesignTokens.space12),
                    borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                            'اشترك الآن',
                            style: TextStyle(
                              fontSize: DesignTokens.textTitleMedium,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanCard(Map<String, dynamic> plan) {
    final isSelected = _selectedPlan == plan['id'];
    final isBest = plan['isBest'] ?? false;
    final color = plan['color'] as Color;

    return GestureDetector(
      onTap: () => setState(() => _selectedPlan = plan['id']),
      child: Container(
        margin: const EdgeInsets.only(bottom: DesignTokens.space20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: DesignTokens.brXl,
          border: Border.all(
            color: isSelected ? color : Colors.transparent,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.1),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Stack(
          children: [
            if (isBest)
              Positioned(
                top: 0,
                left: 20,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: DesignTokens.space12,
                    vertical: DesignTokens.space4,
                  ),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(DesignTokens.radiusMd),
                      bottomRight: Radius.circular(DesignTokens.radiusMd),
                    ),
                  ),
                  child: Text(
                    'الأفضل قيمة',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: DesignTokens.textLabelSmall,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(DesignTokens.space24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          plan['name'] as String,
                          style: TextStyle(
                            fontSize: DesignTokens.textTitleMedium,
                            fontWeight: FontWeight.w600,
                            color: color,
                          ),
                        ),
                      ),
                      Container(
                        width: DesignTokens.space24,
                        height: DesignTokens.space24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? color : AppTheme.textSecondary.withValues(alpha: 0.3),
                            width: 2,
                          ),
                        ),
                        child: isSelected
                            ? Center(
                                child: Container(
                                  width: DesignTokens.space12,
                                  height: DesignTokens.space12,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: color,
                                  ),
                                ),
                              )
                            : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${plan['price']}',
                        style: TextStyle(
                          fontSize: DesignTokens.textDisplayMedium,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: DesignTokens.space4),
                      Text(
                        'ج.م / شهر',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: DesignTokens.textBodyMedium),
                      ),
                    ],
                  ),
                  const SizedBox(height: DesignTokens.space16),
                  Container(height: 1, color: AppTheme.borderColor),
                  const SizedBox(height: DesignTokens.space16),
                  ...(plan['features'] as List<dynamic>).map<Widget>(
                    (f) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Icon(
                            Icons.check_circle_rounded,
                            color: color,
                            size: DesignTokens.iconMd,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              f.toString(),
                              style: TextStyle(
                                fontSize: DesignTokens.textBodySmall,
                                color: AppTheme.textPrimary.withValues(alpha: 0.87),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
