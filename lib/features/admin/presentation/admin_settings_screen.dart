import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/services/supabase_service.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/presentation/login_screen.dart';
import 'admin_maintenance_screen.dart';
import 'admin_bank_accounts_screen.dart';

class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});
  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  final _currencyCtrl = TextEditingController();
  final _adminEmailCtrl = TextEditingController();
  final _whatsappNumberCtrl = TextEditingController();
  final _whatsappMsgCtrl = TextEditingController();
  final _instapayNameCtrl = TextEditingController();
  final _instapayNumCtrl = TextEditingController();

  String _currency = 'جنيه';
  String _adminEmail = 'admin@faster.com';
  String _whatsappNumber = '201000000000';
  String _whatsappMsg = 'مرحباً، أحتاج مساعدة';
  String _instapayName = '';
  String _instapayNum = '';
  bool _isLoading = true;
  List<Map<String, dynamic>> _categories = [];

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final settings = await SupabaseService.db.from('app_settings').select();
      for (final setting in settings) {
        final key = setting['key'];
        final value = setting['value'];
        if (key == 'currency') { _currency = value.toString(); _currencyCtrl.text = _currency; }
        else if (key == 'admin_email') { _adminEmail = value.toString(); _adminEmailCtrl.text = _adminEmail; }
        else if (key == 'instapay_name') { _instapayName = value.toString(); _instapayNameCtrl.text = _instapayName; }
        else if (key == 'instapay_number') { _instapayNum = value.toString(); _instapayNumCtrl.text = _instapayNum; }
        else if (key == 'whatsapp_customer_service') {
          if (value is Map) { _whatsappNumber = value['number']?.toString() ?? '201000000000'; _whatsappMsg = value['message']?.toString() ?? 'مرحباً، أحتاج مساعدة'; }
          else if (value != null) {
            try { final parsed = jsonDecode(value.toString()); _whatsappNumber = parsed['number']?.toString() ?? '201000000000'; _whatsappMsg = parsed['message']?.toString() ?? 'مرحباً، أحتاج مساعدة'; } catch (_) {}
          }
          _whatsappNumberCtrl.text = _whatsappNumber; _whatsappMsgCtrl.text = _whatsappMsg;
        }
      }
      final categories = await SupabaseService.db.from('categories').select().order('name_ar');
      if (mounted) setState(() { _categories = List<Map<String, dynamic>>.from(categories); _isLoading = false; });
    } catch (e) {
      _currencyCtrl.text = 'جنيه'; _adminEmailCtrl.text = 'admin@faster.com';
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveCurrency() async {
    final currency = _currencyCtrl.text.trim();
    if (currency.isEmpty) { _snack('الرجاء إدخال العملة'); return; }
    try { await _upsertSetting('currency', currency); _snack('تم حفظ العملة'); setState(() => _currency = currency); }
    catch (e) { _snack('خطأ في الحفظ'); }
  }

  Future<void> _saveAdminEmail() async {
    final email = _adminEmailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) { _snack('الرجاء إدخال بريد صحيح'); return; }
    try { await _upsertSetting('admin_email', email); _snack('تم حفظ البريد'); setState(() => _adminEmail = email); }
    catch (e) { _snack('خطأ في الحفظ'); }
  }

  Future<void> _saveWhatsAppSettings() async {
    final number = _whatsappNumberCtrl.text.trim();
    final message = _whatsappMsgCtrl.text.trim();
    if (number.isEmpty) { _snack('الرجاء إدخال رقم الواتساب'); return; }
    try {
      final value = {'number': number, 'message': message};
      final existing = await SupabaseService.db.from('app_settings').select().eq('key', 'whatsapp_customer_service').maybeSingle();
      if (existing != null) { await SupabaseService.db.from('app_settings').update({'value': value}).eq('key', 'whatsapp_customer_service'); }
      else { await SupabaseService.db.from('app_settings').insert({'key': 'whatsapp_customer_service', 'value': value}); }
      _snack('تم حفظ إعدادات الدعم الفني');
      setState(() { _whatsappNumber = number; _whatsappMsg = message; });
    } catch (e) { _snack('خطأ في حفظ الدعم الفني: $e'); }
  }

  Future<void> _saveInstaPaySettings() async {
    try {
      await _upsertSetting('instapay_name', _instapayNameCtrl.text.trim());
      await _upsertSetting('instapay_number', _instapayNumCtrl.text.trim());
      _snack('تم حفظ بيانات التحويل');
      setState(() { _instapayName = _instapayNameCtrl.text.trim(); _instapayNum = _instapayNumCtrl.text.trim(); });
    } catch (e) { _snack('خطأ في الحفظ'); }
  }

  Future<void> _saveCategoryCommission(String categoryId, double rate) async {
    try {
      await _upsertSetting('category_commission_$categoryId', rate.toString());
      await _upsertSetting('category_default_commission_$categoryId', (rate / 100).toString());
      _snack('تم حفظ عمولة القسم');
      _load();
    } catch (e) { _snack('خطأ في الحفظ'); }
  }

  Future<void> _upsertSetting(String key, dynamic value) async {
    final existing = await SupabaseService.db.from('app_settings').select().eq('key', key).maybeSingle();
    if (existing != null) { await SupabaseService.db.from('app_settings').update({'value': value}).eq('key', key); }
    else { await SupabaseService.db.from('app_settings').insert({'key': key, 'value': value}); }
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg, textAlign: TextAlign.center), backgroundColor: AppTheme.primaryColor, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: DesignTokens.brMd)),
  );

  @override
  void dispose() {
    _currencyCtrl.dispose(); _adminEmailCtrl.dispose(); _whatsappNumberCtrl.dispose(); _whatsappMsgCtrl.dispose();
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
        title: Text('الإعدادات', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: DesignTokens.textTitleMedium)),
        leading: IconButton(icon: Icon(Icons.arrow_back_ios_rounded, color: AppTheme.textPrimary), tooltip: 'العودة', onPressed: () => Navigator.pop(context)),
      ),
      body: _isLoading
        ? Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
        : SingleChildScrollView(
            padding: EdgeInsets.all(DesignTokens.space24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildGeneralSettings(),
                SizedBox(height: DesignTokens.space12),
                _buildPaymentSettings(),
                SizedBox(height: DesignTokens.space12),
                _buildWhatsAppSettings(),
                SizedBox(height: DesignTokens.space12),
                _buildCommissionSettings(),
                SizedBox(height: DesignTokens.space12),
                _buildCategoryCommissions(),
                SizedBox(height: DesignTokens.space12),
                _buildAboutSection(),
                SizedBox(height: DesignTokens.space16),
              ],
            ),
          ),
    );
  }

  Widget _buildSection({required IconData icon, required String title, required List<Widget> children}) {
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
                  Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: DesignTokens.textTitleSmall, color: AppTheme.textPrimary)),
                ],
              ),
              SizedBox(height: DesignTokens.space16),
              ...children,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGeneralSettings() {
    return _buildSection(
      icon: Icons.settings_rounded,
      title: 'الإعدادات العامة',
      children: [
        _buildSettingRow('العملة', _currency, Icons.monetization_on_rounded, _currencyCtrl, _saveCurrency, hint: 'مثال: جنيه'),
        SizedBox(height: DesignTokens.space16),
        _buildSettingRow('بريد الإدارة', _adminEmail, Icons.email_rounded, _adminEmailCtrl, _saveAdminEmail, hint: 'admin@example.com', isEmail: true),
        SizedBox(height: DesignTokens.space12),
        Divider(height: 1, color: AppTheme.textPrimary.withValues(alpha: 0.06)),
        _buildNavTile(Icons.construction_rounded, 'وضع الصيانة للمستخدمين', 'التحكم في تفعيل/تعطيل تطبيق العميل والمزود', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminMaintenanceScreen()))),
        Divider(height: 1, color: AppTheme.textPrimary.withValues(alpha: 0.06)),
        _buildNavTile(Icons.account_balance_rounded, 'الحسابات البنكية للإدارة', 'إدارة الحسابات التي يحول إليها الفنيون العمولة', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminBankAccountsScreen()))),
      ],
    );
  }

  Widget _buildPaymentSettings() {
    return _buildSection(
      icon: Icons.account_balance_wallet_rounded,
      title: 'بيانات استلام العمولة (InstaPay)',
      children: [
        _buildSettingRow('اسم الحساب (InstaPay)', _instapayName, Icons.person_rounded, _instapayNameCtrl, _saveInstaPaySettings, hint: 'مثال: Mohamed Ali'),
        SizedBox(height: DesignTokens.space16),
        _buildSettingRow('رقم الهاتف المرتبط', _instapayNum, Icons.phone_rounded, _instapayNumCtrl, _saveInstaPaySettings, hint: 'مثال: 010xxxxxxxx', isPhone: true),
      ],
    );
  }

  Widget _buildWhatsAppSettings() {
    return _buildSection(
      icon: Icons.support_agent_rounded,
      title: 'الدعم الفني والواتساب',
      children: [
        _buildSettingRow('رقم الواتساب للدعم الفني', _whatsappNumber, Icons.phone_rounded, _whatsappNumberCtrl, _saveWhatsAppSettings, hint: 'مثال: 201128966996', isPhone: true),
        SizedBox(height: DesignTokens.space16),
        _buildSettingRow('الرسالة التلقائية الافتراضية', _whatsappMsg, Icons.message_rounded, _whatsappMsgCtrl, _saveWhatsAppSettings, hint: 'الرسالة الافتراضية للعميل'),
      ],
    );
  }

  Widget _buildCommissionSettings() {
    return _buildSection(
      icon: Icons.percent_rounded,
      title: 'إعدادات العمولة',
      children: [
        Container(
          padding: EdgeInsets.all(DesignTokens.space6),
          decoration: BoxDecoration(
            color: AppTheme.tertiaryColor.withValues(alpha: 0.1),
            borderRadius: DesignTokens.brMd,
            border: Border.all(color: AppTheme.tertiaryColor.withValues(alpha: 0.2)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, color: AppTheme.tertiaryColor, size: DesignTokens.iconMd),
              SizedBox(width: DesignTokens.space4),
              Expanded(
                child: Text(
                  'العمولة تُطبق على مستوى القسم. كل قسم له نسبة عمولة خاصة به.',
                  style: TextStyle(fontSize: DesignTokens.textBodySmall, color: AppTheme.tertiaryColor, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryCommissions() {
    return _buildSection(
      icon: Icons.category_rounded,
      title: 'عمولة الأقسام',
      children: [
        if (_categories.isEmpty)
          Padding(
            padding: EdgeInsets.all(DesignTokens.space6),
            child: Center(child: Text('لا توجد أقسام', style: TextStyle(color: AppTheme.textSecondary, fontSize: DesignTokens.textBodyMedium))),
          )
        else
          ...List.generate(_categories.length, (index) {
            final cat = _categories[index];
            return Padding(
              padding: EdgeInsets.only(bottom: index < _categories.length - 1 ? DesignTokens.space4 : 0),
              child: _CategoryCommissionItem(
                categoryName: cat['name_ar'] ?? 'قسم',
                categoryId: cat['id'].toString(),
                onSave: _saveCategoryCommission,
              ),
            );
          }),
      ],
    );
  }

  Widget _buildAboutSection() {
    return _buildSection(
      icon: Icons.info_outline_rounded,
      title: 'عن التطبيق',
      children: [
        _buildInfoTile(Icons.flash_on_rounded, 'Faster', 'تطبيق الخدمات المنزلية'),
        Divider(height: 1, color: AppTheme.textPrimary.withValues(alpha: 0.06)),
        _buildInfoTile(Icons.code_rounded, 'الإصدار', '1.0.0'),
        Divider(height: 1, color: AppTheme.textPrimary.withValues(alpha: 0.06)),
        _buildLogoutTile(),
      ],
    );
  }

  Widget _buildSettingRow(String label, String currentValue, IconData icon, TextEditingController ctrl, VoidCallback onSave, {String? hint, bool isEmail = false, bool isPhone = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: DesignTokens.iconXs + 2, color: AppTheme.primaryColor),
            SizedBox(width: DesignTokens.space2),
            Text(label, style: TextStyle(fontSize: DesignTokens.textBodySmall, color: AppTheme.textSecondary, fontWeight: FontWeight.w500)),
          ],
        ),
        SizedBox(height: DesignTokens.space2),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: ctrl,
                keyboardType: isEmail ? TextInputType.emailAddress : (isPhone ? TextInputType.phone : null),
                textAlign: TextAlign.right,
                style: TextStyle(fontSize: DesignTokens.textBodyMedium, color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  hintText: hint ?? label,
                  hintStyle: TextStyle(color: AppTheme.textTertiary, fontSize: DesignTokens.textBodyMedium),
                  filled: true,
                  fillColor: AppTheme.backgroundColor,
                  border: OutlineInputBorder(borderRadius: DesignTokens.brMd, borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: DesignTokens.brMd,
                    borderSide: BorderSide(color: AppTheme.primaryColor.withValues(alpha: 0.3), width: 1.5),
                  ),
                  contentPadding: EdgeInsets.symmetric(horizontal: DesignTokens.space16, vertical: DesignTokens.space14),
                ),
              ),
            ),
            SizedBox(width: DesignTokens.space3),
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: DesignTokens.brMd,
                gradient: AppTheme.primaryGradient,
                boxShadow: DesignTokens.shadow1(AppTheme.primaryColor),
              ),
              child: ElevatedButton(
                onPressed: onSave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: EdgeInsets.symmetric(horizontal: DesignTokens.space20, vertical: DesignTokens.space7),
                  shape: RoundedRectangleBorder(borderRadius: DesignTokens.brMd),
                  elevation: 0,
                ),
                child: Text('حفظ', style: TextStyle(color: AppTheme.surfaceColor, fontWeight: FontWeight.bold, fontSize: DesignTokens.textBodyMedium)),
              ),
            ),
          ],
        ),
        if (currentValue.isNotEmpty && currentValue != ctrl.text.trim()) ...[
          SizedBox(height: DesignTokens.space1),
          Text('القيمة الحالية: $currentValue', style: TextStyle(fontSize: DesignTokens.textLabelSmall, color: AppTheme.textTertiary)),
        ],
      ],
    );
  }

  Widget _buildNavTile(IconData icon, String title, String subtitle, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: DesignTokens.brMd,
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: DesignTokens.space7, horizontal: DesignTokens.space2),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(DesignTokens.space2),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.08),
                  borderRadius: DesignTokens.brSm,
                ),
                child: Icon(icon, color: AppTheme.primaryColor, size: DesignTokens.iconMd),
              ),
              SizedBox(width: DesignTokens.space4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(fontWeight: FontWeight.w600, fontSize: DesignTokens.textBodyMedium, color: AppTheme.textPrimary)),
                    if (subtitle.isNotEmpty) Text(subtitle, style: TextStyle(fontSize: DesignTokens.textBodySmall, color: AppTheme.textTertiary)),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded, size: DesignTokens.iconXs, color: AppTheme.textTertiary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoTile(IconData icon, String title, String subtitle) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: DesignTokens.space7, horizontal: DesignTokens.space2),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(DesignTokens.space2),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.08),
              borderRadius: DesignTokens.brSm,
            ),
            child: Icon(icon, color: AppTheme.primaryColor, size: DesignTokens.iconMd),
          ),
          SizedBox(width: DesignTokens.space4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.w600, fontSize: DesignTokens.textBodyMedium, color: AppTheme.textPrimary)),
                Text(subtitle, style: TextStyle(fontSize: DesignTokens.textBodySmall, color: AppTheme.textTertiary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoutTile() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: DesignTokens.brMd,
        onTap: () async {
          await AuthRepository().signOut();
          if (!mounted) return;
          Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
        },
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: DesignTokens.space7, horizontal: DesignTokens.space2),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(DesignTokens.space2),
                decoration: BoxDecoration(
                  color: AppTheme.errorColor.withValues(alpha: 0.1),
                  borderRadius: DesignTokens.brSm,
                ),
                child: Icon(Icons.logout_rounded, color: AppTheme.errorColor, size: DesignTokens.iconMd),
              ),
              SizedBox(width: DesignTokens.space4),
              Expanded(
                child: Text('تسجيل الخروج', style: TextStyle(fontWeight: FontWeight.w600, fontSize: DesignTokens.textBodyMedium, color: AppTheme.errorColor)),
              ),
              Icon(Icons.arrow_forward_ios_rounded, size: DesignTokens.iconXs, color: AppTheme.errorColor),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryCommissionItem extends StatefulWidget {
  final String categoryName;
  final String categoryId;
  final Function(String, double) onSave;

  const _CategoryCommissionItem({
    required this.categoryName,
    required this.categoryId,
    required this.onSave,
  });

  @override
  State<_CategoryCommissionItem> createState() => _CategoryCommissionItemState();
}

class _CategoryCommissionItemState extends State<_CategoryCommissionItem> {
  final _rateCtrl = TextEditingController(text: '10');
  bool _isLoading = true;

  @override
  void initState() { super.initState(); _loadRate(); }

  Future<void> _loadRate() async {
    try {
      final setting = await SupabaseService.db.from('app_settings').select('value').eq('key', 'category_commission_${widget.categoryId}').maybeSingle();
      if (setting != null) { _rateCtrl.text = setting['value'].toString(); }
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return SizedBox.shrink();
    return Container(
      padding: EdgeInsets.symmetric(horizontal: DesignTokens.space6, vertical: DesignTokens.space4),
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: DesignTokens.brLg,
        border: Border.all(color: AppTheme.textPrimary.withValues(alpha: 0.04)),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(DesignTokens.space2),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.08),
              borderRadius: DesignTokens.brSm,
            ),
            child: Icon(Icons.category_outlined, size: DesignTokens.iconSm, color: AppTheme.primaryColor),
          ),
          SizedBox(width: DesignTokens.space4),
          Expanded(
            flex: 2,
            child: Text(
              widget.categoryName,
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: DesignTokens.textBodyMedium, color: AppTheme.textPrimary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(width: DesignTokens.space4),
          SizedBox(
            width: DesignTokens.space40.w,
            child: TextField(
              controller: _rateCtrl,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: DesignTokens.textBodyMedium, color: AppTheme.textPrimary, fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                hintText: '10',
                suffixText: '%',
                suffixStyle: TextStyle(color: AppTheme.textSecondary, fontSize: DesignTokens.textBodySmall, fontWeight: FontWeight.w600),
                filled: true,
                fillColor: AppTheme.surfaceColor,
                border: OutlineInputBorder(borderRadius: DesignTokens.brSm, borderSide: BorderSide(color: AppTheme.textPrimary.withValues(alpha: 0.08))),
                focusedBorder: OutlineInputBorder(
                  borderRadius: DesignTokens.brSm,
                  borderSide: BorderSide(color: AppTheme.primaryColor.withValues(alpha: 0.3), width: 1.5),
                ),
                contentPadding: EdgeInsets.symmetric(horizontal: DesignTokens.space4, vertical: DesignTokens.space14),
              ),
            ),
          ),
          SizedBox(width: DesignTokens.space3),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: DesignTokens.brSm,
              boxShadow: DesignTokens.shadow1(AppTheme.primaryColor),
            ),
            child: GestureDetector(
              onTap: () {
                final rate = double.tryParse(_rateCtrl.text) ?? 10;
                widget.onSave(widget.categoryId, rate);
              },
              child: Container(
                padding: EdgeInsets.all(DesignTokens.space10),
                child: Icon(Icons.check, color: AppTheme.surfaceColor, size: DesignTokens.iconSm),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() { _rateCtrl.dispose(); super.dispose(); }
}