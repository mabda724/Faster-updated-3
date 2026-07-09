import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/services/supabase_service.dart';

class AdminMaintenanceScreen extends StatefulWidget {
  const AdminMaintenanceScreen({super.key});

  @override
  State<AdminMaintenanceScreen> createState() => _AdminMaintenanceScreenState();
}

class _AdminMaintenanceScreenState extends State<AdminMaintenanceScreen> {
  bool _clientMaintenance = false;
  bool _providerMaintenance = false;
  String _message = 'سنعود قريباً... نحن نقوم بتحديث التطبيق لتقديم تجربة أفضل لك.';
  bool _isLoading = true;
  bool _isSaving = false;

  final _msgCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final rows = await SupabaseService.db
          .from('app_settings')
          .select('key, value')
          .inFilter('key', ['maintenance_client', 'maintenance_provider', 'maintenance_message']);
      for (final r in rows) {
        switch (r['key']) {
          case 'maintenance_client':
            _clientMaintenance = r['value'] == 'true' || r['value'] == '1';
            break;
          case 'maintenance_provider':
            _providerMaintenance = r['value'] == 'true' || r['value'] == '1';
            break;
          case 'maintenance_message':
            _message = r['value']?.toString() ?? _message;
            break;
        }
      }
      _msgCtrl.text = _message;
      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Maintenance load error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      final values = [
        {'key': 'maintenance_client', 'value': _clientMaintenance ? 'true' : 'false'},
        {'key': 'maintenance_provider', 'value': _providerMaintenance ? 'true' : 'false'},
        {'key': 'maintenance_message', 'value': _msgCtrl.text.trim().isEmpty ? _message : _msgCtrl.text.trim()},
      ];

      for (final v in values) {
        final exists = await SupabaseService.db
            .from('app_settings')
            .select('id')
            .eq('key', v['key']!)
            .maybeSingle();
        if (exists != null) {
          await SupabaseService.db.from('app_settings').update(v).eq('key', v['key']!);
        } else {
          await SupabaseService.db.from('app_settings').insert(v);
        }
      }

      _snack('تم حفظ الإعدادات بنجاح', color: AppTheme.successColor);
    } catch (e) {
      _snack('حدث خطأ: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _snack(String msg, {Color? color}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, textAlign: TextAlign.center),
        backgroundColor: color ?? AppTheme.primaryColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: DesignTokens.brMd),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceColor,
        elevation: 0,
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.construction_rounded, color: AppTheme.tertiaryColor, size: DesignTokens.iconMd),
            SizedBox(width: DesignTokens.space4),
            const Text('وضع الصيانة', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: DesignTokens.textTitleMedium)),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.textPrimary),
          tooltip: 'العودة',
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
          : SafeArea(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: DesignTokens.space24, vertical: DesignTokens.space20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSettingsCard(),
                    SizedBox(height: DesignTokens.space24),
                    _buildPreviewCard(),
                    SizedBox(height: DesignTokens.space24),
                    _buildSaveButton(),
                    const SizedBox(height: DesignTokens.space32),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSettingsCard() {
    return Container(
      padding: const EdgeInsets.all(DesignTokens.space20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: DesignTokens.brXl,
        border: Border.all(color: AppTheme.textPrimary.withValues(alpha: 0.05)),
        boxShadow: DesignTokens.shadow2(AppTheme.textPrimary),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(DesignTokens.space10),
                decoration: BoxDecoration(
                  color: AppTheme.tertiaryColor.withValues(alpha: 0.1),
                  borderRadius: DesignTokens.brMd,
                ),
                child: const Icon(Icons.tune_rounded, color: AppTheme.tertiaryColor, size: DesignTokens.iconMd),
              ),
              SizedBox(width: DesignTokens.space12),
              const Expanded(
                child: Text(
                  'إعدادات وضع الصيانة',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: DesignTokens.textTitleSmall, color: AppTheme.textPrimary),
                ),
              ),
            ],
          ),
          SizedBox(height: DesignTokens.space20),
          _toggleRow(
            'تعطيل تطبيق العميل',
            'يظهر شاشة "سنعود قريباً" للعملاء',
            Icons.person_off_rounded,
            _clientMaintenance,
            (v) => setState(() => _clientMaintenance = v),
          ),
          SizedBox(height: DesignTokens.space16),
          _toggleRow(
            'تعطيل تطبيق المقدم',
            'يظهر شاشة "سنعود قريباً" لمقدمي الخدمة',
            Icons.engineering_outlined,
            _providerMaintenance,
            (v) => setState(() => _providerMaintenance = v),
          ),
          SizedBox(height: DesignTokens.space20),
          Container(
            padding: const EdgeInsets.all(DesignTokens.space16),
            decoration: BoxDecoration(
              color: AppTheme.backgroundColor,
              borderRadius: DesignTokens.brLg,
              border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.08)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.message_outlined, size: DesignTokens.iconSm, color: AppTheme.primaryColor),
                    SizedBox(width: DesignTokens.space6),
                    const Text('رسالة الصيانة:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: DesignTokens.textBodyMedium, color: AppTheme.textPrimary)),
                  ],
                ),
                SizedBox(height: DesignTokens.space10),
                TextField(
                  controller: _msgCtrl,
                  maxLines: 3,
                  textAlign: TextAlign.right,
                  decoration: InputDecoration(
                    hintText: 'الرسالة التي تظهر للمستخدمين...',
                    filled: true,
                    fillColor: AppTheme.surfaceColor,
                    border: OutlineInputBorder(borderRadius: DesignTokens.brLg, borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: DesignTokens.brLg,
                      borderSide: const BorderSide(color: AppTheme.primaryColor, width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: DesignTokens.space16, vertical: DesignTokens.space12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewCard() {
    final isAnyActive = _clientMaintenance || _providerMaintenance;
    return Container(
      padding: const EdgeInsets.all(DesignTokens.space20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: DesignTokens.brXl,
        border: Border.all(color: AppTheme.textPrimary.withValues(alpha: 0.05)),
        boxShadow: DesignTokens.shadow2(AppTheme.textPrimary),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(DesignTokens.space6),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.08),
                  borderRadius: DesignTokens.brSm,
                ),
                child: const Icon(Icons.preview_rounded, color: AppTheme.primaryColor, size: DesignTokens.iconSm),
              ),
              SizedBox(width: DesignTokens.space8),
              const Text('معاينة الشاشة:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: DesignTokens.textBodyMedium, color: AppTheme.textPrimary)),
              const Spacer(),
              if (isAnyActive)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: DesignTokens.space8, vertical: DesignTokens.space2),
                  decoration: BoxDecoration(
                    color: AppTheme.errorColor.withValues(alpha: 0.1),
                    borderRadius: DesignTokens.brSm,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.warning_amber_rounded, size: DesignTokens.iconXs, color: AppTheme.errorColor),
                      SizedBox(width: DesignTokens.space4),
                      Text('نشط', style: TextStyle(fontSize: DesignTokens.textLabelSmall, color: AppTheme.errorColor, fontWeight: FontWeight.bold)),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: DesignTokens.space8, vertical: DesignTokens.space2),
                  decoration: BoxDecoration(
                    color: AppTheme.successColor.withValues(alpha: 0.1),
                    borderRadius: DesignTokens.brSm,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_rounded, size: DesignTokens.iconXs, color: AppTheme.successColor),
                      SizedBox(width: DesignTokens.space4),
                      Text('غير نشط', style: TextStyle(fontSize: DesignTokens.textLabelSmall, color: AppTheme.successColor, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
            ],
          ),
          SizedBox(height: DesignTokens.space12),
          AnimatedContainer(
            duration: DesignTokens.durationNormal,
            curve: DesignTokens.curveEaseInOut,
            padding: const EdgeInsets.all(DesignTokens.space20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.darkSurfaceColor, AppTheme.darkBackgroundColor],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: DesignTokens.brXl,
              border: Border.all(color: AppTheme.darkBorder.withValues(alpha: 0.5)),
              boxShadow: DesignTokens.shadow3(AppTheme.textPrimary),
            ),
            child: Column(
              children: [
                AnimatedContainer(
                  duration: DesignTokens.durationNormal,
                  padding: const EdgeInsets.all(DesignTokens.space12),
                  decoration: BoxDecoration(
                    color: isAnyActive ? AppTheme.tertiaryColor.withValues(alpha: 0.15) : AppTheme.textSecondary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isAnyActive ? Icons.construction_rounded : Icons.check_circle_outline_rounded,
                    color: isAnyActive ? AppTheme.tertiaryColor : AppTheme.successColor,
                    size: DesignTokens.iconAvatar,
                  ),
                ),
                const SizedBox(height: DesignTokens.space16),
                AnimatedDefaultTextStyle(
                  duration: DesignTokens.durationNormal,
                  style: TextStyle(
                    color: isAnyActive ? Colors.white : AppTheme.darkTextPrimary,
                    fontSize: DesignTokens.textTitleLarge,
                    fontWeight: FontWeight.bold,
                  ),
                  child: const Text('سنعود قريباً', textAlign: TextAlign.center),
                ),
                const SizedBox(height: DesignTokens.space8),
                AnimatedDefaultTextStyle(
                  duration: DesignTokens.durationNormal,
                  style: TextStyle(
                    color: isAnyActive ? Colors.white70 : AppTheme.darkTextSecondary,
                    fontSize: DesignTokens.textBodyMedium,
                  ),
                  child: Text(
                    _msgCtrl.text.trim().isEmpty ? _message : _msgCtrl.text.trim(),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: DesignTokens.brLg,
        boxShadow: DesignTokens.shadow2(AppTheme.primaryColor),
      ),
      child: ElevatedButton.icon(
        onPressed: _isSaving ? null : _save,
        icon: _isSaving
            ? const SizedBox(width: DesignTokens.space20, height: DesignTokens.space20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : const Icon(Icons.save_rounded, color: Colors.white),
        label: Text(
          _isSaving ? 'جاري الحفظ...' : 'حفظ الإعدادات',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: DesignTokens.textTitleSmall),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: DesignTokens.space14),
          shape: RoundedRectangleBorder(borderRadius: DesignTokens.brLg),
        ),
      ),
    );
  }

  Widget _toggleRow(String title, String subtitle, IconData icon, bool value, ValueChanged<bool> onChanged) {
    return AnimatedContainer(
      duration: DesignTokens.durationNormal,
      curve: DesignTokens.curveEaseInOut,
      padding: const EdgeInsets.all(DesignTokens.space12),
      decoration: BoxDecoration(
        color: value ? AppTheme.errorColor.withValues(alpha: 0.04) : AppTheme.backgroundColor,
        borderRadius: DesignTokens.brLg,
        border: Border.all(
          color: value ? AppTheme.errorColor.withValues(alpha: 0.2) : AppTheme.textPrimary.withValues(alpha: 0.06),
        ),
      ),
      child: Row(
        children: [
          AnimatedContainer(
            duration: DesignTokens.durationNormal,
            padding: const EdgeInsets.all(DesignTokens.space8),
            decoration: BoxDecoration(
              color: value ? AppTheme.errorColor.withValues(alpha: 0.1) : AppTheme.primaryColor.withValues(alpha: 0.08),
              borderRadius: DesignTokens.brMd,
            ),
            child: Icon(icon, size: DesignTokens.iconMd, color: value ? AppTheme.errorColor : AppTheme.primaryColor),
          ),
          SizedBox(width: DesignTokens.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedDefaultTextStyle(
                  duration: DesignTokens.durationNormal,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: DesignTokens.textBodyMedium,
                    color: value ? AppTheme.errorColor : AppTheme.textPrimary,
                  ),
                  child: Text(title),
                ),
                Text(subtitle, style: TextStyle(fontSize: DesignTokens.textBodySmall, color: AppTheme.textSecondary)),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            activeColor: AppTheme.errorColor,
            activeTrackColor: AppTheme.errorColor.withValues(alpha: 0.3),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}