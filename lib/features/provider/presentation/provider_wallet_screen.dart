import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/services/supabase_service.dart';
import '../../../core/services/paymob_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/design_tokens.dart';

class ProviderWalletScreen extends StatefulWidget {
  const ProviderWalletScreen({super.key});
  @override
  State<ProviderWalletScreen> createState() => _ProviderWalletScreenState();
}

class _ProviderWalletScreenState extends State<ProviderWalletScreen> {
  // Preserved from existing — all backend logic

  double _balance = 0;
  double _debtAmount = 0;
  double _totalNetProfit = 0;
  double _totalCommissionCalculated = 0;
  double _settledAmount = 0;
  List<Map<String, dynamic>> _transactions = [];
  List<Map<String, dynamic>> _withdrawals = [];
  List<Map<String, dynamic>> _settlements = [];
  bool _isLoading = true;
  XFile? _proofImage;
  bool _isSettling = false;
  String _instapayPhone = '';
  String _instapayName = '';
  String _walletNumber = '';
  String _walletName = '';
  double _thisWeekEarnings = 0;
  double _todayEarnings = 0;
  int _todayRidesCount = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = SupabaseService.currentUserId;
    if (uid == null) return;
    try {
      final balanceRes = await SupabaseService.db
          .from('provider_profiles')
          .select('wallet_balance, debt_amount, settled_amount')
          .eq('id', uid)
          .maybeSingle();
      _balance =
          double.tryParse(balanceRes?['wallet_balance']?.toString() ?? '0') ??
              0;
      _debtAmount =
          double.tryParse(balanceRes?['debt_amount']?.toString() ?? '0') ?? 0;
      _settledAmount =
          double.tryParse(balanceRes?['settled_amount']?.toString() ?? '0') ??
              0;

      try {
        final transRes = await SupabaseService.db
            .from('transactions')
            .select('*')
            .eq('provider_id', uid)
            .order('created_at', ascending: false)
            .limit(50);
        _transactions = List<Map<String, dynamic>>.from(transRes);
      } catch (e) {
        debugPrint('Transactions load error: $e');
        _transactions = [];
      }

      try {
        final withdrawRes = await SupabaseService.db
            .from('withdrawal_requests')
            .select('*')
            .eq('provider_id', uid)
            .order('created_at', ascending: false);
        _withdrawals = List<Map<String, dynamic>>.from(withdrawRes);
      } catch (e) {
        debugPrint('Withdrawals load error: $e');
        _withdrawals = [];
      }

      try {
        final settlementRes = await SupabaseService.db
            .from('commission_settlements')
            .select('*')
            .eq('provider_id', uid)
            .order('created_at', ascending: false);
        _settlements = List<Map<String, dynamic>>.from(settlementRes);
      } catch (e) {
        debugPrint('Settlements load error: $e');
        _settlements = [];
      }

      try {
        final bookingsRes = await SupabaseService.db
            .from('bookings')
            .select('total_price, commission_amount, offered_price, created_at')
            .eq('provider_id', uid)
            .eq('status', 'completed');

        double totalNet = 0;
        double totalComm = 0;
        double weekEarnings = 0;
        double todayEarnings = 0;
        int todayCount = 0;
        final now = DateTime.now();
        final weekStart = now.subtract(Duration(days: now.weekday));
        final todayStart = DateTime(now.year, now.month, now.day);

        for (var b in (bookingsRes as List)) {
          final price = double.tryParse(
                  (b['offered_price'] ?? b['total_price'])?.toString() ??
                      '0') ??
              0;
          final comm =
              double.tryParse(b['commission_amount']?.toString() ?? '0') ?? 0;
          totalNet += (price - comm);
          totalComm += comm;

          final createdAt = b['created_at']?.toString();
          if (createdAt != null) {
            try {
              final bDate = DateTime.parse(createdAt);
              if (bDate.isAfter(weekStart)) {
                weekEarnings += (price - comm);
              }
              if (bDate.isAfter(todayStart)) {
                todayEarnings += (price - comm);
                todayCount++;
              }
            } catch (_) {}
          }
        }
        _totalNetProfit = totalNet;
        _totalCommissionCalculated = totalComm;
        _thisWeekEarnings = weekEarnings;
        _todayEarnings = todayEarnings;
        _todayRidesCount = todayCount;
      } catch (e) {
        debugPrint('Profit stats error: $e');
      }

      try {
        final settings = await SupabaseService.db
            .from('app_settings')
            .select('key, value')
            .inFilter('key', [
          'instapay_number',
          'instapay_name',
          'settlement_wallet_number',
          'settlement_wallet_name'
        ]);
        for (var s in settings) {
          final key = s['key'] as String?;
          final val = s['value']?.toString() ?? '';
          if (key == 'instapay_number') _instapayPhone = val;
          if (key == 'instapay_name') _instapayName = val;
          if (key == 'settlement_wallet_number') _walletNumber = val;
          if (key == 'settlement_wallet_name') _walletName = val;
        }
      } catch (e) {
        debugPrint('Settlement settings error: $e');
      }

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Wallet load error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ───── Withdraw Dialog (preserved) ─────

  void _showWithdrawDialog() {
    final amountCtrl = TextEditingController();
    String method = 'instant';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Container(
          padding: EdgeInsets.fromLTRB(24.w, 20, 24.w,
              MediaQuery.of(ctx).viewInsets.bottom + 24),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(24))),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
                width: 20, height: 2,
                decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(10))),
            SizedBox(height: 10.h),
            const Text('طلب سحب أرباح',
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 4.h),
            Text('الرصيد المتاح: ${_balance.toStringAsFixed(0)} جنيه',
                style: const TextStyle(color: AppTheme.textSecondary)),
            SizedBox(height: 10.h),
            TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                textDirection: TextDirection.ltr,
                decoration: InputDecoration(
                    hintText: 'المبلغ المطلوب',
                    prefixIcon: const Icon(Icons.attach_money_rounded,
                        color: AppTheme.primaryColor),
                    suffixText: 'جنيه',
                    filled: true,
                    fillColor: AppTheme.surfaceColor70,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none))),
            SizedBox(height: 8.h),
            Row(children: [
              _buildMethodOption(
                currentValue: method,
                label: 'سحب أسبوعي',
                icon: Icons.calendar_today_rounded,
                text: 'كل خميس',
                currentMethod: 'weekly',
                onTap: () => setS(() => method = 'weekly'),
              ),
              SizedBox(width: 6.w),
              _buildMethodOption(
                currentValue: method,
                label: 'سحب شهري',
                icon: Icons.edit_calendar_rounded,
                text: 'آخر الشهر',
                currentMethod: 'monthly',
                onTap: () => setS(() => method = 'monthly'),
              ),
            ]),
            SizedBox(height: 14.h),
            SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () async {
                    final amount = double.tryParse(amountCtrl.text);
                    if (amount == null ||
                        amount <= 0 ||
                        amount > _balance) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(
                          content: const Text('المبلغ غير صحيح، يرجى إدخال مبلغ صحيح'),
                          backgroundColor: AppTheme.errorColor,
                          duration: const Duration(seconds: 5),
                        ),
                      );
                      return;
                    }
                    if (amount < 500) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(
                          content: const Text('الحد الأدنى للسحب هو 500 جنيه'),
                          backgroundColor: AppTheme.warningColor,
                          duration: const Duration(seconds: 3),
                        ),
                      );
                      return;
                    }

                    final scaffoldMessenger = ScaffoldMessenger.of(context);
                    final navigator = Navigator.of(ctx);

                    final uid = SupabaseService.currentUserId!;
                    await SupabaseService.db
                        .from('withdrawal_requests')
                        .insert({
                      'provider_id': uid,
                      'amount': amount,
                      'method': method,
                      'status': 'pending',
                    });

                    if (!ctx.mounted || !context.mounted) return;
                    navigator.pop();
                    scaffoldMessenger.showSnackBar(SnackBar(
                        content: const Text('تم إرسال طلب السحب بنجاح'),
                        backgroundColor: AppTheme.successColor,
                        duration: const Duration(seconds: 2)));
                    _load();
                  },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16))),
                  child: FittedBox(
                      child: Text('تأكيد طلب السحب',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14))),
                )),
          ]),
        ),
      ),
    );
  }

  Widget _buildMethodOption({
    required String currentValue,
    required String label,
    required IconData icon,
    required String text,
    required String currentMethod,
    required VoidCallback onTap,
  }) {
    final isSelected = currentValue == currentMethod;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.primaryColor.withValues(alpha: 0.1)
                : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? AppTheme.primaryColor
                  : Colors.black.withValues(alpha: 0.1),
            ),
          ),
          child: Column(
            children: [
              Icon(icon,
                  color: isSelected
                      ? AppTheme.primaryColor
                      : AppTheme.textSecondary,
                  size: 20),
              const SizedBox(height: 4),
              Text(text,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isSelected
                          ? AppTheme.primaryColor
                          : AppTheme.textSecondary)),
            ],
          ),
        ),
      ),
    );
  }

  // ───── Settle Dialog (preserved) ─────

  void _showSettleDialog() {
    final commissionRemaining = _totalCommissionCalculated - _settledAmount;
    final refCtrl = TextEditingController();
    String method = 'instapay';
    _proofImage = null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Container(
          padding: EdgeInsets.fromLTRB(24.w, 24, 24.w,
              MediaQuery.of(ctx).viewInsets.bottom + 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                    width: 20, height: 2,
                    decoration: BoxDecoration(
                        color: Colors.grey.shade400,
                        borderRadius: BorderRadius.circular(10))),
                const SizedBox(height: 14),
                const Text('توريد العمولة',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                    'العمولة المتبقية للتوريد: ${commissionRemaining.toStringAsFixed(2)} ج.م',
                    style: const TextStyle(
                        color: AppTheme.warningColor,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: AppTheme.primaryColor.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.info_rounded,
                              color: AppTheme.primaryColor, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            method == 'instapay'
                                ? 'حوّل على حساب InstaPay'
                                : method == 'wallet'
                                    ? 'حوّل على المحفظة الإلكترونية'
                                    : 'ادفع عبر البوابة الإلكترونية',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryColor,
                                fontSize: 13),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (method == 'instapay') ...[
                        if (_instapayName.isNotEmpty) ...[
                          const Text('اسم الحساب:',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary)),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Expanded(
                                  child: Text(_instapayName,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15),
                                      textDirection:
                                          TextDirection.ltr)),
                              IconButton(
                                icon: const Icon(
                                    Icons.description_rounded,
                                    size: 18,
                                    color: AppTheme.primaryColor),
                                tooltip: 'نسخ',
                                onPressed: () {
                                  Clipboard.setData(ClipboardData(
                                      text: _instapayName));
                                  ScaffoldMessenger.of(ctx)
                                      .showSnackBar(const SnackBar(
                                          content: Text(
                                              'تم نسخ اسم الحساب'),
                                          duration:
                                              Duration(seconds: 1)));
                                },
                                visualDensity: VisualDensity.compact,
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                        ],
                        if (_instapayPhone.isNotEmpty) ...[
                          const Text('رقم InstaPay:',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary)),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Expanded(
                                  child: Text(_instapayPhone,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          letterSpacing: 1),
                                      textDirection:
                                          TextDirection.ltr)),
                              IconButton(
                                icon: const Icon(
                                    Icons.description_rounded,
                                    size: 18,
                                    color: AppTheme.primaryColor),
                                tooltip: 'نسخ',
                                onPressed: () {
                                  Clipboard.setData(ClipboardData(
                                      text: _instapayPhone));
                                  ScaffoldMessenger.of(ctx)
                                      .showSnackBar(const SnackBar(
                                          content: Text(
                                              'تم نسخ رقم InstaPay'),
                                          duration:
                                              Duration(seconds: 1)));
                                },
                                visualDensity: VisualDensity.compact,
                              ),
                              IconButton(
                                icon: const Icon(
                                    Icons.open_in_new_rounded,
                                    size: 18,
                                    color: AppTheme.primaryColor),
                                tooltip: 'فتح InstaPay',
                                onPressed: () async {
                                  final uri = Uri.parse(
                                      'instapay://pay?phone=$_instapayPhone&amount=${commissionRemaining.toStringAsFixed(0)}');
                                  if (await canLaunchUrl(uri)) {
                                    await launchUrl(uri);
                                  } else {
                                    if (!ctx.mounted) return;
                                    ScaffoldMessenger.of(ctx)
                                        .showSnackBar(const SnackBar(
                                            content: Text(
                                                'InstaPay غير مثبت. يمكنك التحويل من تطبيق البنك')));
                                  }
                                },
                                visualDensity: VisualDensity.compact,
                              ),
                            ],
                          ),
                        ],
                        if (_instapayPhone.isEmpty &&
                            _instapayName.isEmpty)
                          const Text(
                              'لم يتم تحديد بيانات InstaPay بعد. تواصل مع الإدارة.',
                              style: TextStyle(
                                  color: AppTheme.warningColor,
                                  fontSize: 13)),
                      ] else if (method == 'wallet') ...[
                        if (_walletName.isNotEmpty) ...[
                          const Text('اسم المحفظة:',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary)),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Expanded(
                                  child: Text(_walletName,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15),
                                      textDirection:
                                          TextDirection.ltr)),
                              IconButton(
                                icon: const Icon(
                                    Icons.description_rounded,
                                    size: 18,
                                    color: AppTheme.primaryColor),
                                tooltip: 'نسخ',
                                onPressed: () {
                                  Clipboard.setData(ClipboardData(
                                      text: _walletName));
                                  ScaffoldMessenger.of(ctx)
                                      .showSnackBar(const SnackBar(
                                          content: Text(
                                              'تم نسخ اسم المحفظة'),
                                          duration:
                                              Duration(seconds: 1)));
                                },
                                visualDensity: VisualDensity.compact,
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                        ],
                        if (_walletNumber.isNotEmpty) ...[
                          const Text('رقم المحفظة:',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary)),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Expanded(
                                  child: Text(_walletNumber,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          letterSpacing: 1),
                                      textDirection:
                                          TextDirection.ltr)),
                              IconButton(
                                icon: const Icon(
                                    Icons.description_rounded,
                                    size: 18,
                                    color: AppTheme.primaryColor),
                                tooltip: 'نسخ',
                                onPressed: () {
                                  Clipboard.setData(ClipboardData(
                                      text: _walletNumber));
                                  ScaffoldMessenger.of(ctx)
                                      .showSnackBar(const SnackBar(
                                          content: Text(
                                              'تم نسخ رقم المحفظة'),
                                          duration:
                                              Duration(seconds: 1)));
                                },
                                visualDensity: VisualDensity.compact,
                              ),
                            ],
                          ),
                        ],
                        if (_walletNumber.isEmpty &&
                            _walletName.isEmpty)
                          const Text(
                              'لم يتم تحديد بيانات المحفظة بعد. تواصل مع الإدارة.',
                              style: TextStyle(
                                  color: AppTheme.warningColor,
                                  fontSize: 13)),
                      ] else ...[
                        const Text('سيتم فتح بوابة الدفع الإلكترونية PayMob',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        const Text(
                            'يمكنك الدفع ببطاقة Visa أو محفظة إلكترونية',
                            style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary)),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceColor70,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: Colors.black.withValues(alpha: 0.08)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('المبلغ المراد توريده',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary)),
                          const SizedBox(height: 4),
                          Text(
                              '${commissionRemaining.toStringAsFixed(2)} ج.م',
                              style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.warningColor)),
                        ],
                      ),
                      const Icon(Icons.lock_rounded,
                          color: AppTheme.textTertiary),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: refCtrl,
                  textDirection: TextDirection.ltr,
                  decoration: InputDecoration(
                    labelText: 'رقم العملية المرجعي (اختياري)',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setS(() => method = 'instapay'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: 10),
                          decoration: BoxDecoration(
                            color: method == 'instapay'
                                ? AppTheme.primaryColor.withValues(alpha: 0.1)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: method == 'instapay'
                                    ? AppTheme.primaryColor
                                    : Colors.black.withValues(alpha: 0.08)),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.business_rounded,
                                  color: method == 'instapay'
                                      ? AppTheme.primaryColor
                                      : AppTheme.textSecondary,
                                  size: 20),
                              const SizedBox(height: 4),
                              const Text('InstaPay',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setS(() => method = 'wallet'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: 10),
                          decoration: BoxDecoration(
                            color: method == 'wallet'
                                ? AppTheme.primaryColor.withValues(alpha: 0.1)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: method == 'wallet'
                                    ? AppTheme.primaryColor
                                    : Colors.black.withValues(alpha: 0.08)),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.phone_android_rounded,
                                  color: method == 'wallet'
                                      ? AppTheme.primaryColor
                                      : AppTheme.textSecondary,
                                  size: 20),
                              const SizedBox(height: 4),
                              const Text('محفظة',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setS(() => method = 'card'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: 10),
                          decoration: BoxDecoration(
                            color: method == 'card'
                                ? AppTheme.primaryColor.withValues(alpha: 0.1)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: method == 'card'
                                    ? AppTheme.primaryColor
                                    : Colors.black.withValues(alpha: 0.08)),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.credit_card_rounded,
                                  color: method == 'card'
                                      ? AppTheme.primaryColor
                                      : AppTheme.textSecondary,
                                  size: 20),
                              const SizedBox(height: 4),
                              const Text('Visa/بطاقة',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (method != 'card')
                  GestureDetector(
                    onTap: () async {
                      final picker = ImagePicker();
                      final img = await picker.pickImage(
                          source: ImageSource.gallery);
                      if (img != null) {
                        setS(() => _proofImage = img);
                      }
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          vertical: 16, horizontal: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceColor70,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: _proofImage != null
                                ? AppTheme.successColor
                                : Colors.black.withValues(alpha: 0.08),
                            style: BorderStyle.solid),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            _proofImage != null
                                ? Icons.check_circle_outline_rounded
                                : Icons.cloud_upload_rounded,
                            color: _proofImage != null
                                ? AppTheme.successColor
                                : AppTheme.primaryColor,
                            size: 32,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _proofImage != null
                                ? 'تم اختيار صورة الإيصال بنجاح'
                                : 'اضغط لرفع لقطة شاشة لإيصال التحويل (مطلوب)',
                            style: TextStyle(
                              color: _proofImage != null
                                  ? AppTheme.successColor
                                  : AppTheme.textSecondary,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          if (_proofImage != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              _proofImage!.name,
                              style: const TextStyle(
                                  fontSize: 10,
                                  color: AppTheme.textSecondary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(
                              vertical: 14),
                        ),
                        child: const Text('إلغاء',
                            style: TextStyle(
                                color: AppTheme.textSecondary)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _isSettling
                            ? null
                            : () async {
                                if (method == 'card') {
                                  try {
                                    setS(() => _isSettling = true);
                                    final user = SupabaseService
                                        .client.auth.currentUser;
                                    if (user == null) return;
                                    final meta =
                                        user.userMetadata ?? {};
                                    final result =
                                        await PaymobServiceWrapper
                                            .pay(
                                      amount:
                                          commissionRemaining.toInt(),
                                      userId: user.id,
                                      fullName: meta[
                                                  'full_name'] ??
                                              'Provider',
                                      email: meta['email'] ??
                                          'provider@faster.app',
                                      phone: meta[
                                                  'phone_number'] ??
                                          '',
                                      paymentMethod: 'card',
                                    );
                                    if (result.isSuccessful) {
                                      final settlementData =
                                          await SupabaseService.db
                                              .from(
                                                  'commission_settlements')
                                              .insert({
                                        'provider_id': user.id,
                                        'amount':
                                            commissionRemaining,
                                        'method': 'card',
                                        'reference_number': result
                                                .transactionDetails?[
                                                    'id']
                                                ?.toString() ??
                                            '',
                                        'status': 'pending',
                                      }).select().single();

                                      try {
                                        await NotificationService
                                            .sendPushNotification(
                                          userId: 'admin',
                                          title:
                                              'توريد عمولة جديد',
                                          body:
                                              'قام مقدم خدمة بتوريد عمولة ${commissionRemaining.toStringAsFixed(0)} ج.م',
                                          type: 'settlement',
                                          data: {
                                            'settlement_id':
                                                settlementData['id']
                                                    .toString(),
                                            'amount':
                                                commissionRemaining
                                                    .toString(),
                                            'status': 'pending',
                                          },
                                        );
                                      } catch (e) {
                                        debugPrint(
                                            'FCM settlement notification error: $e');
                                      }

                                      if (!mounted) return;
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                            content: Text(
                                                'تم الدفع بنجاح وجاري المراجعة'),
                                            backgroundColor:
                                                AppTheme
                                                    .successColor),
                                      );
                                      if (!ctx.mounted) return;
                                      Navigator.pop(ctx);
                                      _load();
                                    } else {
                                      if (!mounted) return;
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                            content: Text(
                                                'فشل الدفع: ${result.errorMessage ?? "خطأ غير معروف"}'),
                                            backgroundColor:
                                                AppTheme.errorColor),
                                      );
                                    }
                                  } catch (e) {
                                    if (mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                            content:
                                                Text('خطأ في البوابة: $e'),
                                            backgroundColor:
                                                AppTheme.errorColor),
                                      );
                                    }
                                  } finally {
                                    setS(() => _isSettling = false);
                                  }
                                  return;
                                }

                                if (_proofImage == null) {
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(const SnackBar(
                                          content: Text(
                                              'لقطة شاشة إيصال التحويل مطلوبة')));
                                  return;
                                }

                                setS(() => _isSettling = true);
                                final scaffoldMessenger =
                                    ScaffoldMessenger.of(context);
                                final navigator =
                                    Navigator.of(ctx);

                                try {
                                  final uid =
                                      SupabaseService.currentUserId;
                                  if (uid == null) return;

                                  final bytes =
                                      await _proofImage!.readAsBytes();
                                  final fileExt =
                                      _proofImage!.path.split('.').last;
                                  final fileName =
                                      '${uid}_${DateTime.now().millisecondsSinceEpoch}.$fileExt';
                                  final storagePath =
                                      'proofs/$fileName';

                                  await SupabaseService.db.storage
                                      .from('settlement-proofs')
                                      .uploadBinary(
                                          storagePath, bytes);

                                  final proofUrl =
                                      SupabaseService.db.storage
                                          .from(
                                              'settlement-proofs')
                                          .getPublicUrl(storagePath);

                                  await SupabaseService.db
                                      .from(
                                          'commission_settlements')
                                      .insert({
                                    'provider_id': uid,
                                    'amount': commissionRemaining,
                                    'method': method,
                                    'proof_url': proofUrl,
                                    'reference_number': refCtrl
                                            .text.isNotEmpty
                                        ? refCtrl.text
                                        : null,
                                    'status': 'pending',
                                  });

                                  scaffoldMessenger.showSnackBar(
                                      const SnackBar(
                                          content: Text(
                                              'تم إرسال إثبات التوريد بنجاح'),
                                          backgroundColor:
                                              AppTheme.successColor));
                                  navigator.pop();
                                  _load();
                                } catch (e) {
                                  scaffoldMessenger.showSnackBar(
                                      SnackBar(
                                          content: Text(
                                              'خطأ أثناء التوريد: $e'),
                                          backgroundColor:
                                              AppTheme.errorColor));
                                } finally {
                                  setS(() => _isSettling = false);
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(
                              vertical: 14),
                        ),
                        child: _isSettling
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2))
                            : FittedBox(
                                child: Text(
                                  method == 'card'
                                      ? 'ادفع عبر البوابة'
                                      : 'تأكيد وإرسال التوريد',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13),
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ───── Helpers (preserved) ─────

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}/${date.month}';
    } catch (_) {
      return '';
    }
  }

  String _typeLabel(String? type) {
    switch (type) {
      case 'earning':
        return 'إيداع أرباح';
      case 'commission':
        return 'عمولة التطبيق';
      case 'withdrawal':
        return 'سحب';
      case 'refund':
        return 'استرداد';
      case 'cancel_commission':
        return 'عمولة إلغاء';
      default:
        return type ?? 'معاملة';
    }
  }

  // ───── Build ─────

  @override
  Widget build(BuildContext context) {
    final commissionRemaining = _totalCommissionCalculated - _settledAmount;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        body: Center(
          child: CircularProgressIndicator(color: AppTheme.primaryColor),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppTheme.primaryColor,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              // ── Header ──
              _buildHeader(),

              // ── Content ──
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildQuickActions(),
                    const SizedBox(height: 16),
                    _buildEarningsCards(commissionRemaining),
                    const SizedBox(height: 20),
                    _buildTransactionSection(),
                    const SizedBox(height: 16),
                    _buildWithdrawalsSection(),
                    const SizedBox(height: 16),
                    _buildSettlementsSection(),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ──── New UI: Header ────

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppTheme.darkBackgroundColor,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        left: 20,
        right: 20,
        bottom: 24,
      ),
      child: Column(
        children: [
          // Top bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: () => Navigator.maybePop(context),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.arrow_back_rounded,
                      size: 16, color: Colors.white),
                ),
              ),
              const Text(
                'محفظة كابتن Faster',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              GestureDetector(
                onTap: _load,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.refresh_rounded,
                      size: 16, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Balance card
          const Text(
            'إجمالي رصيدك الصافي المتاح',
            style: TextStyle(
              fontSize: 11,
              color: AppTheme.accentColor,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${_balance.toStringAsFixed(2)} ',
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Text(
            'جنيه',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: AppTheme.successColor,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(
              color: AppTheme.successColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.trending_up_rounded,
                    size: 12, color: AppTheme.textTertiary),
                const SizedBox(width: 4),
                const Text(
                  '+15% زيادة هذا الأسبوع',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppTheme.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ──── Quick Actions ────

  Widget _buildQuickActions() {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: _showWithdrawDialog,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: AppTheme.darkBackgroundColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.darkBackgroundColor.withValues(alpha: 0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Icon(Icons.money_rounded,
                      size: 24, color: AppTheme.successColor),
                  const SizedBox(height: 6),
                  const Text(
                    'سحب الأرباح كاش',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            onTap: _showSettleDialog,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.dividerColor),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Icon(Icons.credit_card_rounded,
                      size: 24, color: AppTheme.primaryColor),
                  const SizedBox(height: 6),
                  const Text(
                    'شحن / سداد العهدة',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ──── Earnings Cards ────

  Widget _buildEarningsCards(double commissionRemaining) {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.dividerColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'أرباح اليوم ($_todayRidesCount رحلات)',
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppTheme.textTertiary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_todayEarnings.toStringAsFixed(2)} ج.م',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.dividerColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        size: 10, color: AppTheme.errorColor),
                    const SizedBox(width: 4),
                    const Text(
                      'مستحقات المنصة كاش',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppTheme.warningColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${commissionRemaining.toStringAsFixed(2)} ج.م',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.darkSurfaceColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ──── Transaction Section ────

  Widget _buildTransactionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'سجل المعاملات الأخير',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            if (_transactions.isNotEmpty)
              GestureDetector(
                onTap: () => _showAllTransactions(),
                child: const Text(
                  'عرض الكل',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (_transactions.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Column(children: [
                Icon(Icons.article_outlined,
                    size: 40,
                    color: AppTheme.textSecondary.withValues(alpha: 0.3)),
                const SizedBox(height: 8),
                const Text('لا توجد معاملات بعد',
                    style: TextStyle(
                        color: AppTheme.textSecondary, fontSize: 12)),
              ]),
            ),
          )
        else
          ...(_transactions.take(5).map(_buildTransactionItem)),
      ],
    );
  }

  Widget _buildTransactionItem(Map<String, dynamic> t) {
    final isPositive =
        t['type'] == 'earning' || t['type'] == 'refund';
    final amount =
        double.tryParse(t['amount']?.toString() ?? '0') ?? 0;

    IconData icon;
    Color iconBg;
    Color iconColor;

    if (isPositive) {
      icon = Icons.motorcycle_rounded;
      iconBg = AppTheme.backgroundColor;
      iconColor = AppTheme.primaryColor;
    } else if (t['type'] == 'withdrawal') {
      icon = Icons.money_rounded;
      iconBg = AppTheme.backgroundColor;
      iconColor = AppTheme.errorColor;
    } else {
      icon = Icons.card_giftcard_rounded;
      iconBg = AppTheme.surfaceColor;
      iconColor = AppTheme.warningColor;
    }

    final description = t['description']?.toString() ?? _typeLabel(t['type']);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.dividerColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 16, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  t['created_at'] != null
                      ? _formatDateWithContext(t['created_at'])
                      : '',
                  style: const TextStyle(
                    fontSize: 9,
                    color: AppTheme.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${isPositive ? '+' : '-'}${amount.toStringAsFixed(2)} ج.م',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isPositive
                  ? AppTheme.successColor
                  : AppTheme.errorColor,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateWithContext(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final diff = now.difference(date);
      if (diff.inHours < 24) {
        return 'اليوم، ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
      } else if (diff.inHours < 48) {
        return 'أمس، ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
      }
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }

  void _showAllTransactions() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(ctx).size.height * 0.75,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('كل المعاملات',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.bold)),
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: const Icon(Icons.close_rounded, size: 20),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _transactions.isEmpty
                  ? const Center(child: Text('لا توجد معاملات'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _transactions.length,
                      itemBuilder: (_, i) =>
                          _buildTransactionItem(_transactions[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ──── Withdrawals Section (preserved logic) ────

  Widget _buildWithdrawalsSection() {
    if (_withdrawals.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('طلبات السحب',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary)),
            Text('${_withdrawals.length} طلب',
                style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textSecondary)),
          ],
        ),
        const SizedBox(height: 12),
        ..._withdrawals.take(5).map((w) {
          final wStatus = w['status'] ?? 'pending';
          final statusColor = wStatus == 'approved'
              ? AppTheme.successColor
              : wStatus == 'rejected'
                  ? AppTheme.errorColor
                  : AppTheme.warningColor;
          final statusIcon = wStatus == 'approved'
              ? Icons.check_circle_rounded
              : wStatus == 'rejected'
                  ? Icons.cancel_rounded
                  : Icons.hourglass_empty_rounded;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: statusColor.withValues(alpha: 0.15)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10)),
                  child: Icon(statusIcon,
                      color: statusColor, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${w['amount']} جنيه',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13)),
                      Text(
                          w['method'] == 'weekly'
                              ? 'سحب أسبوعي'
                              : 'سحب شهري',
                          style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.textSecondary)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20)),
                  child: Text(
                    wStatus == 'approved'
                        ? 'تمت الموافقة'
                        : wStatus == 'rejected'
                            ? 'مرفوض'
                            : 'قيد المراجعة',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: statusColor),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  // ──── Settlements Section (preserved logic) ────

  Widget _buildSettlementsSection() {
    if (_settlements.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('سجل التوريدات',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary)),
            Text('${_settlements.length} توريد',
                style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textSecondary)),
          ],
        ),
        const SizedBox(height: 12),
        ..._settlements.take(5).map((s) {
          final sStatus = s['status'] ?? 'pending';
          final statusColor = sStatus == 'verified'
              ? AppTheme.successColor
              : sStatus == 'rejected'
                  ? AppTheme.errorColor
                  : AppTheme.warningColor;
          final statusIcon = sStatus == 'verified'
              ? Icons.check_circle_rounded
              : sStatus == 'rejected'
                  ? Icons.cancel_rounded
                  : Icons.hourglass_empty_rounded;
          final statusText = sStatus == 'verified'
              ? 'تم التأكيد'
              : sStatus == 'rejected'
                  ? 'مرفوض'
                  : 'قيد المراجعة';
          final amount =
              double.tryParse(s['amount']?.toString() ?? '0') ??
                  0;
          final method = s['method'] ?? 'instapay';
          final methodText = method == 'instapay'
              ? 'InstaPay'
              : method == 'wallet'
                  ? 'محفظة'
                  : 'بطاقة';
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: statusColor.withValues(alpha: 0.15)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                          color: statusColor
                              .withValues(alpha: 0.1),
                          borderRadius:
                              BorderRadius.circular(10)),
                      child: Icon(statusIcon,
                          color: statusColor, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                              '${amount.toStringAsFixed(0)} جنيه',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13)),
                          Text(methodText,
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.textSecondary)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                          color: statusColor
                              .withValues(alpha: 0.1),
                          borderRadius:
                              BorderRadius.circular(20)),
                      child: Text(
                        statusText,
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: statusColor),
                      ),
                    ),
                  ],
                ),
                if (s['reference_number'] != null) ...[
                  const SizedBox(height: 8),
                  Text(
                      'رقم المرجعي: ${s['reference_number']}',
                      style: const TextStyle(
                          fontSize: 10,
                          color: AppTheme.textSecondary)),
                ],
                if (s['created_at'] != null) ...[
                  const SizedBox(height: 4),
                  Text(
                      'التاريخ: ${_formatDate(s['created_at'])}',
                      style: const TextStyle(
                          fontSize: 10,
                          color: AppTheme.textSecondary)),
                ],
              ],
            ),
          );
        }),
      ],
    );
  }
}
