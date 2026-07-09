import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/services/supabase_service.dart';

class DeveloperScreen extends StatefulWidget {
  const DeveloperScreen({super.key});

  @override
  State<DeveloperScreen> createState() => _DeveloperScreenState();
}

class _DeveloperScreenState extends State<DeveloperScreen> {
  bool _clientDown = false;
  bool _providerDown = false;
  bool _adminDown = false;
  String _message = '';
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final rows = await SupabaseService.db
          .from('app_settings')
          .select('key, value')
          .inFilter('key', [
        'maintenance_client',
        'maintenance_provider',
        'maintenance_admin',
        'maintenance_message'
      ]);

      for (final r in rows) {
        final k = r['key']?.toString();
        final v = r['value']?.toString() ?? 'false';
        if (k == 'maintenance_client') {
          _clientDown = v == 'true';
        } else if (k == 'maintenance_provider') {
          _providerDown = v == 'true';
        } else if (k == 'maintenance_admin') {
          _adminDown = v == 'true';
        } else if (k == 'maintenance_message') {
          _message = v;
        }
      }
      if (_message.isEmpty) {
        _message = 'نحن نقوم بتحديث التطبيق لتقديم تجربة أفضل لك.';
      }
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Error loading maintenance settings: $e');
    }
  }

  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);
    try {
      final settings = [
        {'key': 'maintenance_client', 'value': _clientDown.toString()},
        {'key': 'maintenance_provider', 'value': _providerDown.toString()},
        {'key': 'maintenance_admin', 'value': _adminDown.toString()},
        {'key': 'maintenance_message', 'value': _message},
      ];

      for (final s in settings) {
        await SupabaseService.db
            .from('app_settings')
            .upsert(s, onConflict: 'key');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حفظ الإعدادات بنجاح'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error saving settings: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ: $e'),
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
        title: const Text('Developer Panel'),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: _isSaving
                ? const SizedBox(
                    width: DesignTokens.space20,
                    height: DesignTokens.space20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.save_rounded),
            onPressed: _isSaving ? null : _saveSettings,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(DesignTokens.space24),
        children: [
          // App Lock Section
          Container(
            padding: const EdgeInsets.all(DesignTokens.space20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: DesignTokens.brXl,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(DesignTokens.space8),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.lock_rounded,
                          color: Colors.red, size: 20),
                    ),
                    const SizedBox(width: DesignTokens.space12),
                    const Text(
                      'قفل التطبيق (Maintenance Mode)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: DesignTokens.space8),
                Text(
                  'تحكم في وصول كل دور للتطبيق أثناء التحديثات',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: DesignTokens.space20),
                _buildToggle('العملاء (Clients)', _clientDown,
                    Icons.people_rounded, AppTheme.primaryColor, (v) {
                  setState(() => _clientDown = v ?? !_clientDown);
                }),
                const SizedBox(height: DesignTokens.space12),
                _buildToggle('مقدمو الخدمات (Providers)', _providerDown,
                    Icons.handyman_rounded, AppTheme.primaryColor, (v) {
                  setState(() => _providerDown = v ?? !_providerDown);
                }),
                const SizedBox(height: DesignTokens.space12),
                _buildToggle(
                    'المشرفون (Admins)',
                    _adminDown,
                    Icons.admin_panel_settings_rounded,
                    AppTheme.primaryColor, (v) {
                  setState(() => _adminDown = v ?? !_adminDown);
                }),
              ],
            ),
          ),
          const SizedBox(height: DesignTokens.space16),

          // Message Section
          Container(
            padding: const EdgeInsets.all(DesignTokens.space20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: DesignTokens.brXl,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'رسالة الصيانة',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: DesignTokens.space12),
                TextField(
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'أدخل رسالة الصيانة...',
                    border: OutlineInputBorder(
                      borderRadius: DesignTokens.brMd,
                    ),
                    filled: true,
                    fillColor: AppTheme.backgroundColor,
                  ),
                  controller: TextEditingController(text: _message),
                  onChanged: (v) => _message = v,
                ),
              ],
            ),
          ),
          const SizedBox(height: DesignTokens.space16),

          // Save Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : _saveSettings,
              icon: const Icon(Icons.save_rounded),
              label: Text(_isSaving ? 'جاري الحفظ...' : 'حفظ الإعدادات'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: DesignTokens.brLg,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggle(String title, bool value, IconData icon, Color color,
      ValueChanged<bool?> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: DesignTokens.space12, vertical: DesignTokens.space8),
      decoration: BoxDecoration(
        color: value
            ? Colors.red.withValues(alpha: 0.05)
            : Colors.green.withValues(alpha: 0.05),
        borderRadius: DesignTokens.brMd,
        border: Border.all(
          color: value
              ? Colors.red.withValues(alpha: 0.2)
              : Colors.green.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: value ? Colors.red : Colors.green),
          const SizedBox(width: DesignTokens.space12),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 13,
                color: value ? Colors.red : Colors.green,
              ),
            ),
          ),
          Switch.adaptive(
            value: value,
            activeColor: Colors.red,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
