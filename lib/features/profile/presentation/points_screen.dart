import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/services/supabase_service.dart';

class PointsScreen extends StatefulWidget {
  const PointsScreen({Key? key}) : super(key: key);

  @override
  State<PointsScreen> createState() => _PointsScreenState();
}

class _PointsScreenState extends State<PointsScreen> {
  Map<String, dynamic>? _pointsData;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPoints();
  }

  Future<void> _loadPoints() async {
    try {
      final data = await SupabaseService.getUserPoints();
      setState(() {
        _pointsData = data;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Error loading points: $e');
      setState(() => _loading = false);
    }
  }

  Future<void> _redeemPoints() async {
    final TextEditingController amountCtrl = TextEditingController();
    bool isRedeeming = false;
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: const Text('استبدال النقاط'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('أدخل عدد النقاط التي تريد استبدالها:'),
              const SizedBox(height: 12),
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'عدد النقاط'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: isRedeeming
                  ? null
                  : () async {
                      setStateDialog(() => isRedeeming = true);
                      final amount = int.tryParse(amountCtrl.text.trim());
                      if (amount == null || amount <= 0) {
                        ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('الرجاء إدخال عدد صحيح صالح'), backgroundColor: Colors.red));
                        setStateDialog(() => isRedeeming = false);
                        return;
                      }
                      try {
                        final result = await SupabaseService.redeemPoints(amount);
                        if (result['success'] == true) {
                          ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('تم استبدال ${amount} نقاط بنجاح. رصيدك الجديد: ${result['new_balance']}'), backgroundColor: Colors.green));
                          await _loadPoints();
                          Navigator.pop(ctx);
                        } else {
                          ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('نقاط غير كافية. الرصيد الحالي: ${result['new_balance']}'), backgroundColor: Colors.red));
                        }
                      } catch (e) {
                        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red));
                      } finally {
                        setStateDialog(() => isRedeeming = false);
                      }
                    },
              child: const Text('استبدال'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('نقاط الولاء')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: EdgeInsets.all(DesignTokens.space20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Current points card
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: DesignTokens.brLg),
                    elevation: 2,
                    child: Padding(
                      padding: EdgeInsets.all(DesignTokens.space20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('الرصيد الحالي', style: TextStyle(fontSize: 16, color: AppTheme.textSecondary)),
                          const SizedBox(height: 8),
                          Text('${_pointsData?['points'] ?? 0} نقطة', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                          const SizedBox(height: 8),
                          Text('إجمالي النقاط المكتسبة: ${_pointsData?['lifetime_points'] ?? 0}', style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
                          Text('النقاط المستبدلة: ${_pointsData?['redeemed_points'] ?? 0}', style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: DesignTokens.space20),
                  // Redeem button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _redeemPoints,
                      icon: const Icon(Icons.card_giftcard_rounded),
                      label: const Text('استبدال النقاط'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        padding: EdgeInsets.symmetric(vertical: DesignTokens.space12),
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
