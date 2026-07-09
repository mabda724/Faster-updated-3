
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/services/supabase_service.dart';

class AdminCashRemittanceScreen extends StatefulWidget {
  const AdminCashRemittanceScreen({super.key});

  @override
  State<AdminCashRemittanceScreen> createState() => _AdminCashRemittanceScreenState();
}

class _AdminCashRemittanceScreenState extends State<AdminCashRemittanceScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _providerDebts = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final res = await SupabaseService.db
          .from('bookings')
          .select('*, profiles:client_id(full_name), provider:provider_id(id, profiles(full_name))')
          .eq('payment_method', 'cash')
          .eq('status', 'completed')
          .eq('payment_status', 'unpaid');

      final Map<String, Map<String, dynamic>> debts = {};
      for (var b in (res as List)) {
        final pid = b['provider_id'];
        final pName = b['provider']?['profiles']?['full_name'] ?? 'مقدم خدمة';
        final commission = double.tryParse(b['commission_amount']?.toString() ?? '0') ?? 0;

        if (debts.containsKey(pid)) {
          debts[pid]!['amount'] += commission;
          debts[pid]!['booking_ids'].add(b['id']);
        } else {
          debts[pid] = {
            'id': pid,
            'name': pName,
            'amount': commission,
            'booking_ids': [b['id']],
          };
        }
      }

      if (mounted) setState(() {
        _providerDebts = debts.values.toList();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading remittance data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _settleDebt(Map<String, dynamic> debt) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: DesignTokens.brXl),
        title: Row(
          children: [
            Icon(Icons.handshake_rounded, color: AppTheme.successColor, size: DesignTokens.iconMd),
            SizedBox(width: DesignTokens.space8),
            const Text('تأكيد التحصيل', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Container(
          padding: const EdgeInsets.all(DesignTokens.space16),
          decoration: BoxDecoration(
            color: AppTheme.backgroundColor,
            borderRadius: DesignTokens.brMd,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.person_rounded, size: DesignTokens.iconSm, color: AppTheme.textSecondary),
                  SizedBox(width: DesignTokens.space6),
                  Expanded(child: Text(debt['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: DesignTokens.textBodyMedium, color: AppTheme.textPrimary))),
                ],
              ),
              SizedBox(height: DesignTokens.space10),
              Row(
                children: [
                  Icon(Icons.receipt_long_rounded, size: DesignTokens.iconSm, color: AppTheme.textSecondary),
                  SizedBox(width: DesignTokens.space6),
                  Text('عدد الطلبات: ${debt['booking_ids'].length}', style: TextStyle(fontSize: DesignTokens.textBodyMedium, color: AppTheme.textSecondary)),
                ],
              ),
              SizedBox(height: DesignTokens.space10),
              Container(
                padding: const EdgeInsets.all(DesignTokens.space10),
                decoration: BoxDecoration(
                  color: AppTheme.tertiaryColor.withValues(alpha: 0.08),
                  borderRadius: DesignTokens.brSm,
                ),
                child: Row(
                  children: [
                    Icon(Icons.monetization_on_rounded, size: DesignTokens.iconSm, color: AppTheme.tertiaryColor),
                    SizedBox(width: DesignTokens.space6),
                    Text('هل تم استلام مبلغ', style: TextStyle(fontSize: DesignTokens.textBodyMedium, color: AppTheme.textSecondary)),
                    SizedBox(width: DesignTokens.space4),
                    Text('${debt['amount']} ج.م', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: DesignTokens.textTitleSmall, color: AppTheme.tertiaryColor)),
                    SizedBox(width: DesignTokens.space4),
                    Text('من المقدم؟', style: TextStyle(fontSize: DesignTokens.textBodyMedium, color: AppTheme.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء', style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [AppTheme.successColor, AppTheme.successColor.withValues(alpha: 0.8)]),
              borderRadius: DesignTokens.brSm,
              boxShadow: DesignTokens.shadow1(AppTheme.successColor),
            ),
            child: ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              shape: RoundedRectangleBorder(borderRadius: DesignTokens.brSm),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_rounded, color: Colors.white, size: DesignTokens.iconSm),
                  SizedBox(width: DesignTokens.space4),
                  const Text('تم التحصيل', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        setState(() => _isLoading = true);
        for (var bid in debt['booking_ids']) {
          await SupabaseService.db.from('bookings').update({'payment_status': 'paid'}).eq('id', bid);
        }

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: DesignTokens.iconSm),
                SizedBox(width: DesignTokens.space6),
                const Expanded(child: Text('تم تسجيل التحصيل بنجاح', style: TextStyle(color: Colors.white))),
              ],
            ),
            backgroundColor: AppTheme.successColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: DesignTokens.brMd),
          ),
        );
        _loadData();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline_rounded, color: Colors.white, size: DesignTokens.iconSm),
                SizedBox(width: DesignTokens.space6),
                Expanded(child: Text('خطأ: $e', style: const TextStyle(color: Colors.white))),
              ],
            ),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: DesignTokens.brMd),
          ),
        );
        setState(() => _isLoading = false);
      }
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
            Icon(Icons.payments_rounded, color: AppTheme.primaryColor, size: DesignTokens.iconMd),
            SizedBox(width: DesignTokens.space4),
            const Text('تحصيل العمولات (كاش)', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: DesignTokens.textTitleMedium)),
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
          : _providerDebts.isEmpty
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
                        child: Icon(Icons.money_off_rounded, size: DesignTokens.iconDoctorAvatar, color: AppTheme.successColor.withValues(alpha: 0.5)),
                      ),
                      SizedBox(height: DesignTokens.space20),
                      const Text('لا توجد مبالغ مستحقة للتحصيل حالياً', style: TextStyle(color: AppTheme.textSecondary, fontSize: DesignTokens.textTitleSmall)),
                      SizedBox(height: DesignTokens.space8),
                      const Text('جميع العمولات تم تسويتها', style: TextStyle(color: AppTheme.textTertiary, fontSize: DesignTokens.textBodyMedium)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.all(DesignTokens.space20),
                  itemCount: _providerDebts.length,
                  itemBuilder: (context, index) => _buildDebtCard(_providerDebts[index]),
                ),
    );
  }

  Widget _buildDebtCard(Map<String, dynamic> debt) {
    final bookingCount = (debt['booking_ids'] as List).length;
    return Container(
      margin: EdgeInsets.only(bottom: DesignTokens.space16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: DesignTokens.brXl,
        border: Border(
          top: BorderSide(color: AppTheme.tertiaryColor, width: 3),
          left: BorderSide(color: AppTheme.textPrimary.withValues(alpha: 0.05)),
          right: BorderSide(color: AppTheme.textPrimary.withValues(alpha: 0.05)),
          bottom: BorderSide(color: AppTheme.textPrimary.withValues(alpha: 0.05)),
        ),
        boxShadow: DesignTokens.shadow2(AppTheme.textPrimary),
      ),
      child: Padding(
        padding: const EdgeInsets.all(DesignTokens.space20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(DesignTokens.space12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppTheme.tertiaryColor, AppTheme.tertiaryColor.withValues(alpha: 0.7)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: DesignTokens.shadow1(AppTheme.tertiaryColor),
                  ),
                  child: const Icon(Icons.monetization_on_rounded, color: Colors.white, size: DesignTokens.iconMd),
                ),
                SizedBox(width: DesignTokens.space16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        debt['name'],
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: DesignTokens.textTitleSmall, color: AppTheme.textPrimary),
                      ),
                      SizedBox(height: DesignTokens.space4),
                      Row(
                        children: [
                          Icon(Icons.receipt_long_rounded, size: DesignTokens.iconXs, color: AppTheme.textSecondary),
                          SizedBox(width: DesignTokens.space4),
                          Text(
                            '$bookingCount طلب',
                            style: TextStyle(fontSize: DesignTokens.textBodySmall, color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(DesignTokens.space12),
                  decoration: BoxDecoration(
                    color: AppTheme.tertiaryColor.withValues(alpha: 0.08),
                    borderRadius: DesignTokens.brMd,
                  ),
                  child: Column(
                    children: [
                      Text(
                        '${debt['amount']} ج.م',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: DesignTokens.textTitleSmall, color: AppTheme.tertiaryColor),
                      ),
                      Text(
                        'مستحق',
                        style: TextStyle(fontSize: DesignTokens.textLabelSmall, color: AppTheme.tertiaryColor),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: DesignTokens.space16),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.primaryColor, AppTheme.primaryColor.withValues(alpha: 0.8)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: DesignTokens.brMd,
                boxShadow: DesignTokens.shadow1(AppTheme.primaryColor),
              ),
              child: ElevatedButton.icon(
                onPressed: () => _settleDebt(debt),
                icon: const Icon(Icons.handshake_rounded, color: Colors.white, size: DesignTokens.iconSm),
                label: const Text('تحصيل العمولة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: DesignTokens.textBodyMedium)),
                shape: RoundedRectangleBorder(borderRadius: DesignTokens.brMd),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}