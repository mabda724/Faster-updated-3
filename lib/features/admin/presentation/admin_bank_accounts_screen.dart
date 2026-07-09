import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/services/supabase_service.dart';

class AdminBankAccountsScreen extends StatefulWidget {
  const AdminBankAccountsScreen({super.key});

  @override
  State<AdminBankAccountsScreen> createState() => _AdminBankAccountsScreenState();
}

class _AdminBankAccountsScreenState extends State<AdminBankAccountsScreen> {
  List<Map<String, dynamic>> _accounts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await SupabaseService.db
          .from('admin_bank_accounts')
          .select()
          .order('created_at', ascending: false);
      if (mounted) setState(() { _accounts = List<Map<String, dynamic>>.from(data); _isLoading = false; });
    } catch (e) { if (mounted) setState(() => _isLoading = false); }
  }

  Future<void> _showAddDialog({Map<String, dynamic>? existing}) async {
    final bankCtrl = TextEditingController(text: existing?['bank_name'] ?? '');
    final nameCtrl = TextEditingController(text: existing?['account_name'] ?? '');
    final numCtrl = TextEditingController(text: existing?['account_number'] ?? '');
    bool isActive = existing?['is_active'] ?? true;
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.fromLTRB(DesignTokens.space24, DesignTokens.space20, DesignTokens.space24, MediaQuery.of(ctx).viewInsets.bottom + DesignTokens.space24),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(DesignTokens.radius2xl)),
            boxShadow: DesignTokens.shadow4(AppTheme.textPrimary),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: DesignTokens.space40,
                height: DesignTokens.space4,
                decoration: BoxDecoration(
                  color: AppTheme.textSecondary.withValues(alpha: 0.15),
                  borderRadius: DesignTokens.brSm,
                ),
              ),
              SizedBox(height: DesignTokens.space20),
              Container(
                padding: const EdgeInsets.all(DesignTokens.space10),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  existing != null ? Icons.edit_rounded : Icons.add_card_rounded,
                  color: AppTheme.primaryColor,
                  size: DesignTokens.iconLg,
                ),
              ),
              SizedBox(height: DesignTokens.space12),
              Text(
                existing != null ? 'تعديل حساب بنكي' : 'إضافة حساب بنكي جديد',
                style: const TextStyle(fontSize: DesignTokens.textTitleLarge, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
              ),
              SizedBox(height: DesignTokens.space20),
              _field(bankCtrl, 'اسم البنك', Icons.account_balance_rounded),
              SizedBox(height: DesignTokens.space12),
              _field(nameCtrl, 'اسم صاحب الحساب', Icons.person_rounded),
              SizedBox(height: DesignTokens.space12),
              _field(numCtrl, 'رقم الحساب / IBAN', Icons.numbers_rounded),
              SizedBox(height: DesignTokens.space12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: DesignTokens.space16, vertical: DesignTokens.space4),
                decoration: BoxDecoration(
                  color: AppTheme.backgroundColor,
                  borderRadius: DesignTokens.brMd,
                ),
                child: SwitchListTile(
                  title: Row(
                    children: [
                      Icon(Icons.toggle_on_outlined, size: DesignTokens.iconSm, color: isActive ? AppTheme.successColor : AppTheme.textSecondary),
                      SizedBox(width: DesignTokens.space6),
                      const Text('نشط', style: TextStyle(fontWeight: FontWeight.w600, fontSize: DesignTokens.textBodyMedium, color: AppTheme.textPrimary)),
                    ],
                  ),
                  value: isActive,
                  activeColor: AppTheme.successColor,
                  onChanged: (v) => setModalState(() => isActive = v),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              SizedBox(height: DesignTokens.space24),
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: DesignTokens.brLg,
                  boxShadow: DesignTokens.shadow1(AppTheme.primaryColor),
                ),
                child: ElevatedButton(
                  onPressed: isSaving ? null : () async {
                    if (bankCtrl.text.isEmpty || nameCtrl.text.isEmpty || numCtrl.text.isEmpty) return;
                    setModalState(() => isSaving = true);
                    final data = {
                      'bank_name': bankCtrl.text,
                      'account_name': nameCtrl.text,
                      'account_number': numCtrl.text,
                      'is_active': isActive,
                    };
                    try {
                      if (existing != null) {
                        await SupabaseService.db.from('admin_bank_accounts').update(data).eq('id', existing['id']);
                      } else {
                        await SupabaseService.db.from('admin_bank_accounts').insert(data);
                      }
                      if (ctx.mounted) Navigator.pop(ctx);
                      _load();
                    } catch (e) {
                      setModalState(() => isSaving = false);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(vertical: DesignTokens.space14),
                    shape: RoundedRectangleBorder(borderRadius: DesignTokens.brLg),
                  ),
                  child: isSaving
                      ? const SizedBox(width: DesignTokens.space20, height: DesignTokens.space20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.save_rounded, color: Colors.white, size: DesignTokens.iconSm),
                            SizedBox(width: DesignTokens.space6),
                            const Text('حفظ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: DesignTokens.textTitleSmall)),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _delete(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد الحذف', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
        content: const Text('هل أنت متأكد من حذف هذا الحساب البنكي؟', style: TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [AppTheme.errorColor, AppTheme.errorColor.withValues(alpha: 0.8)]),
              borderRadius: DesignTokens.brSm,
            ),
            child: ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(horizontal: DesignTokens.space16),
              ),
              child: const Text('حذف', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await SupabaseService.db.from('admin_bank_accounts').delete().eq('id', id);
      _load();
    }
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
            Icon(Icons.account_balance_rounded, color: AppTheme.primaryColor, size: DesignTokens.iconMd),
            SizedBox(width: DesignTokens.space4),
            const Text('الحسابات البنكية للإدارة', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: DesignTokens.textTitleMedium)),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.textPrimary),
          tooltip: 'العودة',
          onPressed: () => Navigator.pop(context),
        ),
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.primaryGradient,
          shape: BoxShape.circle,
          boxShadow: DesignTokens.shadow3(AppTheme.primaryColor),
        ),
        child: FloatingActionButton(
          onPressed: () => _showAddDialog(),
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: const Icon(Icons.add_rounded, color: Colors.white),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
          : _accounts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(DesignTokens.space24),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceColor,
                          shape: BoxShape.circle,
                          boxShadow: DesignTokens.shadow2(AppTheme.textPrimary),
                        ),
                        child: Icon(Icons.account_balance_outlined, size: DesignTokens.iconDoctorAvatar, color: AppTheme.textSecondary.withValues(alpha: DesignTokens.opacityMuted)),
                      ),
                      SizedBox(height: DesignTokens.space20),
                      const Text('لا توجد حسابات مضافة', style: TextStyle(color: AppTheme.textSecondary, fontSize: DesignTokens.textTitleSmall)),
                      SizedBox(height: DesignTokens.space8),
                      const Text('اضغط على علامة + لإضافة حساب جديد', style: TextStyle(color: AppTheme.textTertiary, fontSize: DesignTokens.textBodyMedium)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.all(DesignTokens.space20),
                  itemCount: _accounts.length,
                  itemBuilder: (_, i) => _buildAccountCard(_accounts[i]),
                ),
    );
  }

  Widget _buildAccountCard(Map<String, dynamic> acc) {
    final isActive = acc['is_active'] == true;
    return Container(
      margin: EdgeInsets.only(bottom: DesignTokens.space16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: DesignTokens.brXl,
        border: Border.all(
          color: isActive ? AppTheme.successColor.withValues(alpha: 0.15) : AppTheme.textPrimary.withValues(alpha: 0.05),
        ),
        boxShadow: DesignTokens.shadow2(AppTheme.textPrimary),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: DesignTokens.brXl,
        child: Padding(
          padding: const EdgeInsets.all(DesignTokens.space16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(DesignTokens.space12),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  shape: BoxShape.circle,
                  boxShadow: DesignTokens.shadow1(AppTheme.primaryColor),
                ),
                child: const Icon(Icons.account_balance_rounded, color: Colors.white, size: DesignTokens.iconMd),
              ),
              SizedBox(width: DesignTokens.space16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            acc['bank_name'] ?? '',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: DesignTokens.textTitleSmall, color: AppTheme.textPrimary),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: DesignTokens.space6, vertical: DesignTokens.space2),
                          decoration: BoxDecoration(
                            color: isActive ? AppTheme.successColor.withValues(alpha: 0.1) : AppTheme.textSecondary.withValues(alpha: 0.1),
                            borderRadius: DesignTokens.brSm,
                          ),
                          child: Text(
                            isActive ? 'نشط' : 'غير نشط',
                            style: TextStyle(
                              fontSize: DesignTokens.textLabelSmall,
                              color: isActive ? AppTheme.successColor : AppTheme.textSecondary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: DesignTokens.space6),
                    Row(
                      children: [
                        Icon(Icons.person_outline_rounded, size: DesignTokens.iconXs, color: AppTheme.textSecondary),
                        SizedBox(width: DesignTokens.space4),
                        Text(
                          acc['account_name'] ?? '',
                          style: TextStyle(fontSize: DesignTokens.textBodySmall, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                    SizedBox(height: DesignTokens.space2),
                    Row(
                      children: [
                        Icon(Icons.numbers_rounded, size: DesignTokens.iconXs, color: AppTheme.textSecondary),
                        SizedBox(width: DesignTokens.space4),
                        Text(
                          acc['account_number'] ?? '',
                          style: TextStyle(fontSize: DesignTokens.textBodySmall, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.08),
                      borderRadius: DesignTokens.brSm,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.edit_rounded, color: AppTheme.primaryColor, size: DesignTokens.iconSm),
                      tooltip: 'تعديل',
                      onPressed: () => _showAddDialog(existing: acc),
                      constraints: const BoxConstraints(minWidth: DesignTokens.touchTargetMin, minHeight: DesignTokens.touchTargetMin),
                    ),
                  ),
                  SizedBox(height: DesignTokens.space4),
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.errorColor.withValues(alpha: 0.08),
                      borderRadius: DesignTokens.brSm,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.errorColor, size: DesignTokens.iconSm),
                      tooltip: 'حذف',
                      onPressed: () => _delete(acc['id']),
                      constraints: const BoxConstraints(minWidth: DesignTokens.touchTargetMin, minHeight: DesignTokens.touchTargetMin),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String h, IconData ic) => Container(
    decoration: BoxDecoration(
      color: AppTheme.backgroundColor,
      borderRadius: DesignTokens.brMd,
      border: Border.all(color: AppTheme.textPrimary.withValues(alpha: 0.06)),
    ),
    child: TextField(
      controller: c,
      textAlign: TextAlign.right,
      decoration: InputDecoration(
        hintText: h,
        hintStyle: TextStyle(color: AppTheme.textTertiary, fontSize: DesignTokens.textBodyMedium),
        prefixIcon: Icon(ic, color: AppTheme.primaryColor, size: DesignTokens.iconSm),
        filled: true,
        fillColor: AppTheme.backgroundColor,
        border: OutlineInputBorder(borderRadius: DesignTokens.brMd, borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: DesignTokens.brMd,
          borderSide: const BorderSide(color: AppTheme.primaryColor, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: DesignTokens.space16, vertical: DesignTokens.space12),
      ),
    ),
  );
}