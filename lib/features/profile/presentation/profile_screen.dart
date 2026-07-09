import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/services/supabase_service.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/presentation/login_screen.dart';
import '../../booking/presentation/my_bookings_screen.dart';
import 'addresses_screen.dart';
import 'favorites_screen.dart';
import 'points_screen.dart';
import 'user_settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _profile;
  bool _isLoading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final p = await AuthRepository().getCurrentProfile();
    if (mounted) setState(() { _profile = p; _isLoading = false; });
  }

   Future<void> _showReferralDialog() async {
    String? code; int points = 0; int referralsCount = 0; String referredBy = '';
    bool isGenerating = false;
    bool isApplying = false;
    final applyCodeCtrl = TextEditingController();
    
    try {
      final uid = SupabaseService.currentUserId;
      if (uid == null) return;
      final profile = await SupabaseService.db.from('profiles').select('referral_code, referral_points, referrals_count, referred_by').eq('id', uid).maybeSingle();
      code = profile?['referral_code'] as String?;
      points = int.tryParse(profile?['referral_points']?.toString() ?? '0') ?? 0;
      referralsCount = int.tryParse(profile?['referrals_count']?.toString() ?? '0') ?? 0;
      referredBy = profile?['referred_by'] as String? ?? '';
    } catch (_) {}
    if (!mounted) return;
    showDialog(context: context, builder: (ctx) => StatefulBuilder(
      builder: (ctx, setStateModal) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: DesignTokens.br2xl),
      title: const Text('دعوة الأصدقاء', textAlign: TextAlign.center),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(padding: DesignTokens.padding16, decoration: BoxDecoration(color: AppTheme.primaryColor.withValues(alpha: 0.08), borderRadius: DesignTokens.brLg),
          child: Column(children: [
            const Text('كود الدعوة الخاص بك', style: TextStyle(color: AppTheme.textSecondary, fontSize: DesignTokens.textLabelMedium)),
            SizedBox(height: DesignTokens.space8),
            if (code != null && code!.isNotEmpty)
              Text(code!, style: TextStyle(fontSize: DesignTokens.textDisplayMedium, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: AppTheme.primaryColor))
            else
              Column(children: [
                Text('اضغط Generate لإنشاء كود الدعوة', style: TextStyle(color: AppTheme.textSecondary, fontSize: DesignTokens.textLabelMedium)),
                SizedBox(height: DesignTokens.space8),
                ElevatedButton.icon(
                  onPressed: isGenerating ? null : () async {
                    setStateModal(() => isGenerating = true);
                    try {
                      final uid = SupabaseService.currentUserId;
                      if (uid == null) return;
                      final newCode = await AuthRepository().generateReferralCode(uid);
                      if (newCode != null) {
                        setStateModal(() => code = newCode);
                      }
                    } catch (e) {
                      debugPrint('Error generating referral code: $e');
                    } finally {
                      setStateModal(() => isGenerating = false);
                    }
                  },
                  icon: isGenerating ? const SizedBox(width: DesignTokens.space16, height: DesignTokens.space16, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.surfaceColor)) : const Icon(Icons.add_rounded, color: AppTheme.surfaceColor, size: DesignTokens.iconSm),
                  label: const Text('Generate', style: TextStyle(color: AppTheme.surfaceColor, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, shape: RoundedRectangleBorder(borderRadius: DesignTokens.brMd)),
                ),
              ]),
          ])),
        SizedBox(height: DesignTokens.space16),
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          _pointBadge(Icons.people_outline, '$referralsCount', 'تمت الدعوة'),
          _pointBadge(Icons.star_rounded, '$points', 'نقاطي'),
          _pointBadge(Icons.card_giftcard_rounded, '50', 'لكل دعوة'),
        ]),
        SizedBox(height: DesignTokens.space16),
        const Text('شارك الكود مع أصدقائك، كل صديق يسجل تحصل على 50 نقطة وهو 25 نقطة!', textAlign: TextAlign.center, style: TextStyle(fontSize: DesignTokens.textBodySmall, color: AppTheme.textSecondary)),
        
        // Apply referral code section (only if not already used)
        if (referredBy == null || referredBy.isEmpty) ...[
          SizedBox(height: DesignTokens.space16),
          const Divider(),
          SizedBox(height: DesignTokens.space8),
          const Text('لديك كود دعوة؟', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
          SizedBox(height: DesignTokens.space8),
          TextField(
            controller: applyCodeCtrl,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              hintText: 'أدخل كود الدعوة (6 أحرف)',
              prefixIcon: const Icon(Icons.card_giftcard),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          SizedBox(height: DesignTokens.space8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: isApplying ? null : () async {
                final inputCode = applyCodeCtrl.text.trim().toUpperCase();
                if (inputCode.length != 6) {
                  ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('كود الدعوة يجب أن يكون 6 أحرف'), backgroundColor: Colors.red));
                  return;
                }
                setStateModal(() => isApplying = true);
                try {
                  final uid = SupabaseService.currentUserId;
                  if (uid == null) return;
                  final result = await AuthRepository().applyReferralCode(uid, inputCode);
                  if (result['success'] == true) {
                    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                      content: Text(result['message'] ?? 'تم تطبيق كود الدعوة بنجاح'),
                      backgroundColor: Colors.green,
                    ));
                    Navigator.pop(ctx);
                    _load(); // Reload profile
                  } else {
                    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                      content: Text(result['error'] ?? 'فشل تطبيق كود الدعوة'),
                      backgroundColor: Colors.red,
                    ));
                  }
                } catch (e) {
                  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red));
                } finally {
                  setStateModal(() => isApplying = false);
                }
              },
              icon: isApplying ? const SizedBox(width: DesignTokens.space16, height: DesignTokens.space16, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.surfaceColor)) : const Icon(Icons.check_rounded, color: AppTheme.surfaceColor),
              label: const Text('تطبيق الكود', style: TextStyle(color: AppTheme.surfaceColor, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, shape: RoundedRectangleBorder(borderRadius: DesignTokens.brMd)),
            ),
          ),
        ],
      ]),
      actions: [
        SizedBox(width: double.infinity, child: ElevatedButton.icon(
          onPressed: code == null || code!.isEmpty ? null : () { Navigator.pop(ctx); _shareReferral(code!); },
          icon: const Icon(Icons.share_rounded, color: AppTheme.surfaceColor, size: DesignTokens.iconSm),
          label: const Text('مشاركة الكود', style: TextStyle(color: AppTheme.surfaceColor, fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(backgroundColor: (code != null && code!.isNotEmpty) ? AppTheme.primaryColor : AppTheme.textSecondary, shape: RoundedRectangleBorder(borderRadius: DesignTokens.brMd)),
        )),
      ],
    )));
  }

  void _shareReferral(String code) async {
    final name = _profile?['full_name'] ?? 'صديق';
    await Share.share('مرحباً! استخدم كود الدعوة الخاص بي $code للتسجيل في تطبيق Faster واحصل على 25 نقطة!', subject: 'دعوة من $name لتطبيق Faster');
  }

  Future<void> _showAddPhoneDialog() async {
    final phoneCtrl = TextEditingController();
    bool isLoading = false;
    
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateModal) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: DesignTokens.br2xl),
          title: const Text('إضافة رقم الهاتف', textAlign: TextAlign.center),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'أدخل رقم هاتفك لتأمين حسابك وتسجيل الدخول بالرقم في النسخة القادمة',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: DesignTokens.space16),
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                textDirection: TextDirection.ltr,
                decoration: InputDecoration(
                  hintText: 'مثال: 201234567890',
                  prefixIcon: const Icon(Icons.phone_android_rounded),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: isLoading ? null : () async {
                final phone = phoneCtrl.text.trim();
                if (phone.isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('الرجاء إدخال رقم الهاتف'), backgroundColor: Colors.red),
                  );
                  return;
                }
                
                setStateModal(() => isLoading = true);
                
                try {
                  final result = await AuthRepository().updatePhone(phone);
                  if (!mounted) return;
                  
                  if (result['success'] == true) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('تم إضافة رقم الهاتف بنجاح'), backgroundColor: Colors.green),
                    );
                    _load(); // Reload profile
                  } else {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text(result['error'] ?? 'فشل إضافة رقم الهاتف'), backgroundColor: Colors.red),
                    );
                  }
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
                  );
                } finally {
                  setStateModal(() => isLoading = false);
                }
              },
              child: isLoading
                  ? const SizedBox(width: DesignTokens.space16, height: DesignTokens.space16, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.surfaceColor))
                  : const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pointBadge(IconData icon, String value, String label) {
    return Column(children: [
      Icon(icon, color: AppTheme.primaryColor, size: DesignTokens.iconMd), SizedBox(height: DesignTokens.space4),
      Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: DesignTokens.textBodyLarge, color: AppTheme.textPrimary)),
      Text(label, style: TextStyle(fontSize: DesignTokens.textLabelSmall, color: AppTheme.textSecondary)),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final name = _profile?['full_name'] ?? 'المستخدم';
    final email = SupabaseService.auth.currentUser?.email ?? '';
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
          : SingleChildScrollView(
              child: Column(
                children: [
                  // Header with gradient
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                   Container(
                     height: 220,
                     width: double.infinity,
                     decoration: const BoxDecoration(
                       gradient: AppTheme.primaryGradient,
                       borderRadius: BorderRadius.only(bottomLeft: Radius.circular(DesignTokens.radiusXl), bottomRight: Radius.circular(DesignTokens.radiusXl)),
                     ),
                        child: SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: DesignTokens.space24, vertical: DesignTokens.space16),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const SizedBox(width: DesignTokens.space24),
                                    const Text('الملف الشخصي', style: TextStyle(color: AppTheme.surfaceColor, fontSize: 18, fontWeight: FontWeight.bold)),
                                    IconButton(
                                      icon: const Icon(Icons.arrow_forward_ios_rounded, color: AppTheme.surfaceColor, size: 20),
                                      tooltip: 'العودة',
                                      onPressed: () => Navigator.pop(context),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: DesignTokens.space16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text('مرحباً', style: TextStyle(color: AppTheme.surfaceColor.withValues(alpha: 0.7), fontSize: 14)),
                                        Text(name, style: const TextStyle(color: AppTheme.surfaceColor, fontSize: 20, fontWeight: FontWeight.bold)),
                                        Text(email, style: TextStyle(color: AppTheme.surfaceColor.withValues(alpha: 0.54), fontSize: 12)),
                                      ],
                                    ),
                                    const SizedBox(width: DesignTokens.space16),
                                    CircleAvatar(
                                      radius: 36,
                                      backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.3),
                                      child: Text(name.isNotEmpty ? name.substring(0, 1) : '?', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppTheme.surfaceColor)),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      // Phone card overlay
                      Positioned(
                        bottom: -40,
                        left: 24,
                        right: 24,
                        child: Container(
                          height: 80,
                          padding: const EdgeInsets.symmetric(horizontal: DesignTokens.space20),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceColor,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 5))],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(DesignTokens.space8),
                                decoration: BoxDecoration(color: AppTheme.primaryColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                                child: const Icon(Icons.phone_android_rounded, color: AppTheme.primaryColor),
                              ),
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text('رقم الهاتف', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                                  Text(_profile?['phone_number'] ?? 'غير محدد', style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 60),
                  
                  // Phone migration warning for users without phone number
                  if (_profile?['phone_number'] == null || _profile?['phone_number'].toString().trim().isEmpty == true)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: DesignTokens.space24),
                      child: Container(
                        padding: const EdgeInsets.all(DesignTokens.space16),
                        decoration: BoxDecoration(
                          color: AppTheme.warningColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.warningColor.withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.warning_rounded, color: AppTheme.warningColor, size: 20),
                                const SizedBox(width: DesignTokens.space8),
                                Expanded(
                                  child: Text(
                                    'تنبيه هام',
                                    style: TextStyle(
                                      color: AppTheme.warningColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: DesignTokens.space8),
                            Text(
                              'حسابك لا يحتوي على رقم هاتف. في النسخة القادمة، سيكون تسجيل الدخول بالرقم فقط. ننصحك بإضافة رقم الهاتف الآن لتأمين حسابك.',
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: DesignTokens.space12),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _showAddPhoneDialog,
                                icon: const Icon(Icons.add_circle_rounded, color: AppTheme.surfaceColor, size: 18),
                                label: const Text('إضافة رقم الهاتف', style: TextStyle(color: AppTheme.surfaceColor, fontWeight: FontWeight.bold)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.warningColor,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  minimumSize: const Size(double.infinity, 40),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  
                  const SizedBox(height: DesignTokens.space16),
                  
                  // Menu items
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: DesignTokens.space24),
                    child: Column(
                      children: [
                        _buildMenuItem(Icons.receipt_long_rounded, 'طلباتي', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyBookingsScreen()))),
                        _buildMenuItem(Icons.location_on_outlined, 'عناويني', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddressesScreen()))),
                        _buildMenuItem(Icons.favorite_border_rounded, 'المفضلة', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FavoritesScreen()))),
                        _buildMenuItem(Icons.card_giftcard_rounded, 'دعوة صديق ونقاط', _showReferralDialog),
                        _buildMenuItem(Icons.star_rounded, 'نقاط الولاء', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PointsScreen()))),
                        _buildMenuItem(Icons.settings_outlined, 'الإعدادات', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UserSettingsScreen()))),
                         _buildMenuItem(Icons.chat_rounded, 'المساعدة والدعم', () async {
                           try {
                             final setting = await SupabaseService.db.from('app_settings').select('value').eq('key', 'whatsapp_customer_service').maybeSingle();
                             String number = '201000000000';
                             String msg = 'مرحباً، أحتاج مساعدة';
                             if (setting != null && setting['value'] != null) {
                               final value = setting['value'];
                               if (value is Map) {
                                 number = value['number']?.toString() ?? '201000000000';
                                 msg = value['message']?.toString() ?? 'مرحباً، أحتاج مساعدة';
                               } else {
                                 try {
                                   final parsed = jsonDecode(value.toString());
                                   number = parsed['number']?.toString() ?? '201000000000';
                                   msg = parsed['message']?.toString() ?? 'مرحباً، أحتاج مساعدة';
                                 } catch (_) {
                                   // If JSON parsing fails, use defaults
                                 }
                               }
                             }
                             await launchUrl(Uri.parse('https://wa.me/$number?text=${Uri.encodeComponent(msg)}'));
                           } catch (_) {
                             await launchUrl(Uri.parse('https://wa.me/201000000000'));
                           }
                         }),
                        const SizedBox(height: DesignTokens.space16),
                        InkWell(
                          onTap: () async {
                            await AuthRepository().signOut();
                            if (!context.mounted) return;
                            Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: DesignTokens.space20),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                const Text('تسجيل الخروج', style: TextStyle(color: Colors.red, fontSize: 16, fontWeight: FontWeight.bold)),
                                const SizedBox(width: DesignTokens.space16),
                                const Icon(Icons.logout_rounded, color: Colors.red),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: DesignTokens.space32),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildMenuItem(IconData icon, String title, VoidCallback onTap) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: DesignTokens.space16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: AppTheme.textSecondary),
                Row(
                  children: [
                    Text(title, style: const TextStyle(fontSize: 16, color: AppTheme.textPrimary, fontWeight: FontWeight.w500)),
                    const SizedBox(width: DesignTokens.space16),
                    Icon(icon, color: AppTheme.textSecondary),
                  ],
                ),
              ],
            ),
          ),
        ),
        Divider(color: AppTheme.textPrimary.withValues(alpha: 0.05), height: 1),
      ],
    );
  }
}
