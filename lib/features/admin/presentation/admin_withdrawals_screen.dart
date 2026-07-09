import '../../../core/theme/app_theme.dart';
import '../../../core/theme/design_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/services/supabase_service.dart';

class AdminWithdrawalsScreen extends StatefulWidget {
  const AdminWithdrawalsScreen({super.key});
  @override
  State<AdminWithdrawalsScreen> createState() => _AdminWithdrawalsScreenState();
}

class _AdminWithdrawalsScreenState extends State<AdminWithdrawalsScreen> {
  List<Map<String, dynamic>> _requests = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await SupabaseService.db
          .from('withdrawal_requests')
          .select('*, profiles!withdrawal_requests_provider_id_fkey(full_name)')
          .order('created_at', ascending: false);
      if (mounted) {
        setState(() {
          _requests = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _approve(String id) async {
    try {
      await SupabaseService.db
          .from('withdrawal_requests')
          .update({'status': 'approved'})
          .eq('id', id);
      _load();
    } catch (e) {
      debugPrint('Error approving: $e');
    }
  }

  Future<void> _reject(String id) async {
    try {
      await SupabaseService.db
          .from('withdrawal_requests')
          .update({'status': 'rejected'})
          .eq('id', id);
      _load();
    } catch (e) {
      debugPrint('Error rejecting: $e');
    }
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'approved':
        return AppTheme.successColor;
      case 'rejected':
        return AppTheme.errorColor;
      default:
        return AppTheme.tertiaryColor;
    }
  }

  String _statusText(String s) {
    switch (s) {
      case 'approved':
        return 'تمت الموافقة';
      case 'rejected':
        return 'مرفوض';
      default:
        return 'بانتظار المراجعة';
    }
  }

  IconData _statusIcon(String s) {
    switch (s) {
      case 'approved':
        return Icons.check_circle_rounded;
      case 'rejected':
        return Icons.cancel_rounded;
      default:
        return Icons.access_time_rounded;
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
        title: Text(
          'طلبات السحب',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: DesignTokens.textTitleMedium,
          ),
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppTheme.textPrimary,
            size: DesignTokens.iconSm,
          ),
          tooltip: 'العودة',
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor),
            )
          : _requests.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: EdgeInsets.all(DesignTokens.space8),
                    itemCount: _requests.length,
                    itemBuilder: (_, i) {
                      return _buildWithdrawalCard(_requests[i], i);
                    },
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: DesignTokens.iconXl * 2.5,
            height: DesignTokens.iconXl * 2.5,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.account_balance_wallet_outlined,
              size: DesignTokens.iconXl,
              color: AppTheme.primaryColor.withValues(alpha: 0.4),
            ),
          ),
          SizedBox(height: DesignTokens.space8),
          Text(
            'لا توجد طلبات سحب',
            style: TextStyle(
              fontSize: DesignTokens.textTitleSmall,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          SizedBox(height: DesignTokens.space3),
          Text(
            'سيتم عرض طلبات السحب من مقدمي الخدمات هنا',
            style: TextStyle(
              fontSize: DesignTokens.textBodyMedium,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWithdrawalCard(Map<String, dynamic> r, int index) {
    final status = r['status'] ?? 'pending';
    final profile = r['profiles'];
    final statusColor = _statusColor(status);

    return AnimatedSwitcher(
      duration: DesignTokens.durationModal,
      switchInCurve: DesignTokens.curveEmphasized,
      switchOutCurve: DesignTokens.curveFastOut,
      transitionBuilder: (Widget child, Animation<double> animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: Offset(0, 0.05 * (index + 1)),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: DesignTokens.curveEaseInOut,
            )),
            child: child,
          ),
        );
      },
      child: Container(
        key: ValueKey('${r['id']}_${r['status']}'),
        margin: EdgeInsets.only(bottom: DesignTokens.space8),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: DesignTokens.brMd,
          border: Border.all(
            color: statusColor.withValues(alpha: 0.2),
          ),
          boxShadow: DesignTokens.shadow2(statusColor.withValues(alpha: 0.05)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.all(DesignTokens.space8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: DesignTokens.iconAvatar,
                        height: DesignTokens.iconAvatar,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppTheme.primaryColor,
                              AppTheme.primaryColor.withValues(alpha: 0.7),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: DesignTokens.brSm,
                        ),
                        child: Icon(
                          Icons.person_rounded,
                          color: AppTheme.surfaceColor,
                          size: DesignTokens.iconMd,
                        ),
                      ),
                      SizedBox(width: DesignTokens.space6),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              profile?['full_name'] ?? 'مقدم خدمة',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: DesignTokens.textTitleSmall,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            SizedBox(height: DesignTokens.space1),
                            Row(
                              children: [
                                Icon(
                                  _statusIcon(status),
                                  size: DesignTokens.iconXs,
                                  color: statusColor,
                                ),
                                SizedBox(width: DesignTokens.space2),
                                Text(
                                  _statusText(status),
                                  style: TextStyle(
                                    fontSize: DesignTokens.textBodySmall,
                                    color: statusColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Text(
                        r['method'] == 'weekly' ? 'أسبوعي' : 'شهري',
                        style: TextStyle(
                          fontSize: DesignTokens.textLabelSmall,
                          color: AppTheme.textTertiary,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: DesignTokens.space6),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(DesignTokens.space6),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.primaryColor.withValues(alpha: 0.06),
                          AppTheme.backgroundColor,
                        ],
                        begin: Alignment.centerRight,
                        end: Alignment.centerLeft,
                      ),
                      borderRadius: DesignTokens.brSm,
                      border: Border.all(
                        color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'المبلغ المطلوب',
                          style: TextStyle(
                            fontSize: DesignTokens.textBodySmall,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        SizedBox(height: DesignTokens.space2),
                        Row(
                          children: [
                            Text(
                              '${r['amount'] ?? 0}',
                              style: TextStyle(
                                fontSize: DesignTokens.textDisplayMedium,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                            SizedBox(width: DesignTokens.space2),
                            Text(
                              'جنيه',
                              style: TextStyle(
                                fontSize: DesignTokens.textTitleSmall,
                                fontWeight: FontWeight.w500,
                                color: AppTheme.primaryColor
                                    .withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: DesignTokens.space3),
                  Row(
                    children: [
                      Icon(
                        Icons.payments_outlined,
                        size: DesignTokens.iconSm - 2,
                        color: AppTheme.textTertiary,
                      ),
                      SizedBox(width: DesignTokens.space2),
                      Text(
                        'طريقة السحب: ${r['method'] == 'weekly' ? 'أسبوعي (خميس)' : 'شهري'}',
                        style: TextStyle(
                          fontSize: DesignTokens.textBodySmall,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  if (r['account_number'] != null) ...[
                    SizedBox(height: DesignTokens.space2),
                    Row(
                      children: [
                        Icon(
                          Icons.account_balance_rounded,
                          size: DesignTokens.iconSm - 2,
                          color: AppTheme.textTertiary,
                        ),
                        SizedBox(width: DesignTokens.space2),
                        Text(
                          'رقم الحساب: ${r['account_number']}',
                          style: TextStyle(
                            fontSize: DesignTokens.textBodySmall,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (status == 'pending')
              Padding(
                padding: EdgeInsets.fromLTRB(
                  DesignTokens.space8,
                  0,
                  DesignTokens.space8,
                  DesignTokens.space8,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppTheme.successColor,
                              AppTheme.successColor.withValues(alpha: 0.85),
                            ],
                          ),
                          borderRadius: DesignTokens.brSm,
                          boxShadow: [
                            BoxShadow(
                              color:
                                  AppTheme.successColor.withValues(alpha: 0.25),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ElevatedButton.icon(
                          onPressed: () =>
                              _approve(r['id'].toString()),
                          icon: Icon(
                            Icons.check_rounded,
                            size: DesignTokens.iconSm - 2,
                          ),
                          label: const Text('موافقة'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            foregroundColor: AppTheme.surfaceColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: DesignTokens.brSm,
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: DesignTokens.space8),
                    Expanded(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppTheme.errorColor,
                              AppTheme.errorColor.withValues(alpha: 0.85),
                            ],
                          ),
                          borderRadius: DesignTokens.brSm,
                          boxShadow: [
                            BoxShadow(
                              color:
                                  AppTheme.errorColor.withValues(alpha: 0.25),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ElevatedButton.icon(
                          onPressed: () =>
                              _reject(r['id'].toString()),
                          icon: Icon(
                            Icons.close_rounded,
                            size: DesignTokens.iconSm - 2,
                          ),
                          label: const Text('رفض'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            foregroundColor: AppTheme.surfaceColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: DesignTokens.brSm,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              Padding(
                padding: EdgeInsets.fromLTRB(
                  DesignTokens.space8,
                  0,
                  DesignTokens.space8,
                  DesignTokens.space8,
                ),
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(DesignTokens.space4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.06),
                    borderRadius: DesignTokens.brSm,
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.15),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        status == 'approved'
                            ? Icons.check_circle_outline_rounded
                            : Icons.cancel_rounded,
                        size: DesignTokens.iconSm - 2,
                        color: statusColor,
                      ),
                      SizedBox(width: DesignTokens.space3),
                      Text(
                        status == 'approved'
                            ? 'تمت الموافقة على طلب السحب'
                            : 'تم رفض طلب السحب',
                        style: TextStyle(
                          fontSize: DesignTokens.textBodyMedium,
                          fontWeight: FontWeight.w600,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}