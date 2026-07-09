import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/services/supabase_service.dart';
import 'package:url_launcher/url_launcher.dart';

class AdminSettlementsScreen extends StatefulWidget {
  const AdminSettlementsScreen({super.key});

  @override
  State<AdminSettlementsScreen> createState() => _AdminSettlementsScreenState();
}

class _AdminSettlementsScreenState extends State<AdminSettlementsScreen> {
  List<Map<String, dynamic>> _settlements = [];
  bool _isLoading = true;
  String _filter = 'pending';
  String? _expandedImageUrl;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      setState(() => _isLoading = true);
      final data = await SupabaseService.db
          .from('commission_settlements')
          .select(
              '*, profiles!commission_settlements_provider_id_fkey(full_name, phone_number)')
          .order('created_at', ascending: false);

      if (_filter != 'all') {
        _settlements = data.where((s) => s['status'] == _filter).toList();
      } else {
        _settlements = data;
      }

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateStatus(String id, String status,
      {String? reason}) async {
    try {
      await SupabaseService.db.from('commission_settlements').update({
        'status': status,
        'verified_by': SupabaseService.currentUserId,
        'verified_at': DateTime.now().toIso8601String(),
        if (reason != null) 'rejection_reason': reason,
      }).eq('id', id);

      _snack(status == 'verified'
          ? 'تم تأكيد التوريد وتصفير المبلغ'
          : 'تم رفض الطلب');
      _load();
    } catch (e) {
      _snack('خطأ: $e');
    }
  }

  void _showRejectDialog(String id) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('سبب الرفض'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(hintText: 'مثلاً: الصورة غير واضحة'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _updateStatus(id, 'rejected', reason: ctrl.text.trim());
            },
            child:
                const Text('رفض وإرسال', style: TextStyle(color: AppTheme.surfaceColor)),
          ),
        ],
      ),
    );
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(m),
        backgroundColor: AppTheme.primaryColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: DesignTokens.brSm),
      ));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(
          'مراجعة التوريدات',
          style: TextStyle(
            fontSize: DesignTokens.textTitleMedium,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.support_agent_rounded, size: DesignTokens.iconSm),
            tooltip: 'الدعم الفني',
            onPressed: () async {
              try {
                final setting = await SupabaseService.db
                    .from('app_settings')
                    .select('value')
                    .eq('key', 'whatsapp_customer_service')
                    .maybeSingle();
                String number = '201000000000';
                String msg = 'مرحباً، أحتاج помощи في صفحة مراجعة التوريدات';
                if (setting != null && setting['value'] != null) {
                  final value = setting['value'];
                  if (value is Map) {
                    number = value['number']?.toString() ?? '201000000000';
                    msg = value['message']?.toString() ?? 'مرحباً، أحتاج مساعدة';
                  } else {
                    try {
                      final parsed = jsonDecode(value.toString());
                      number = parsed['number']?.toString() ?? '201000000000';
                      msg =
                          parsed['message']?.toString() ?? 'مرحباً، أحتاج مساعدة';
                    } catch (_) {}
                  }
                }
                await launchUrl(Uri.parse(
                    'https://wa.me/$number?text=${Uri.encodeComponent(msg)}'));
              } catch (_) {
                await launchUrl(Uri.parse('https://wa.me/201000000000'));
              }
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(44),
          child: Padding(
            padding: EdgeInsets.symmetric(
                horizontal: DesignTokens.space4, vertical: DesignTokens.space2),
            child: Row(
              children: [
                _filterBtn('قيد المراجعة', 'pending'),
                SizedBox(width: DesignTokens.space3),
                _filterBtn('تم التأكيد', 'verified'),
                SizedBox(width: DesignTokens.space3),
                _filterBtn('مرفوض', 'rejected'),
                SizedBox(width: DesignTokens.space3),
                _filterBtn('الكل', 'all'),
              ],
            ),
          ),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: AppTheme.primaryColor),
      );
    }

    if (_settlements.isEmpty) {
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
                Icons.account_balance_rounded,
                size: DesignTokens.iconXl,
                color: AppTheme.primaryColor.withValues(alpha: 0.4),
              ),
            ),
            SizedBox(height: DesignTokens.space8),
            Text(
              'لا توجد طلبات توريد',
              style: TextStyle(
                fontSize: DesignTokens.textTitleSmall,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            SizedBox(height: DesignTokens.space3),
            Text(
              'سيتم عرض طلبات توريد العمولة هنا',
              style: TextStyle(
                fontSize: DesignTokens.textBodyMedium,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: EdgeInsets.all(DesignTokens.space8),
        itemCount: _settlements.length,
        itemBuilder: (_, i) {
          final s = _settlements[i];
          final provider = s['profiles'];
          final status = s['status'] ?? 'pending';
          return _buildSettlementCard(s, provider, status);
        },
      ),
    );
  }

  Widget _buildSettlementCard(
      Map<String, dynamic> s, dynamic provider, String status) {
    final statusColor = status == 'verified'
        ? AppTheme.successColor
        : status == 'rejected'
            ? AppTheme.errorColor
            : AppTheme.tertiaryColor;

    return AnimatedContainer(
      duration: DesignTokens.durationNormal,
      curve: DesignTokens.curveEaseInOut,
      margin: EdgeInsets.only(bottom: DesignTokens.space8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: DesignTokens.brMd,
        border: Border.all(
          color: statusColor.withValues(alpha: 0.25),
          width: 1.2,
        ),
        boxShadow: DesignTokens.shadow2(statusColor.withValues(alpha: 0.06)),
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
                        gradient: status == 'verified'
                            ? LinearGradient(colors: [
                                AppTheme.successColor,
                                AppTheme.successColor.withValues(alpha: 0.7)
                              ])
                            : status == 'rejected'
                                ? LinearGradient(colors: [
                                    AppTheme.errorColor,
                                    AppTheme.errorColor.withValues(alpha: 0.7)
                                  ])
                                : LinearGradient(colors: [
                                    AppTheme.tertiaryColor,
                                    AppTheme.primaryColor
                                  ]),
                        borderRadius: DesignTokens.brSm,
                      ),
                      child: Icon(
                        status == 'verified'
                            ? Icons.check_circle_outline_rounded
                            : status == 'rejected'
                                ? Icons.cancel_rounded
                                : Icons.hourglass_top_rounded,
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
                            provider?['full_name'] ?? 'فني',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: DesignTokens.textTitleSmall,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          SizedBox(height: DesignTokens.space1),
                          Text(
                            'الوسيلة: ${s['method']}',
                            style: TextStyle(
                              fontSize: DesignTokens.textBodySmall,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _formatDate(s['created_at']),
                          style: TextStyle(
                            fontSize: DesignTokens.textLabelSmall,
                            color: AppTheme.textTertiary,
                          ),
                        ),
                        SizedBox(height: DesignTokens.space2),
                        _buildStatusBadge(status),
                      ],
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
                        statusColor.withValues(alpha: 0.06),
                        AppTheme.backgroundColor,
                      ],
                      begin: Alignment.centerRight,
                      end: Alignment.centerLeft,
                    ),
                    borderRadius: DesignTokens.brSm,
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'المبلغ',
                        style: TextStyle(
                          fontSize: DesignTokens.textBodySmall,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      Text(
                        '${s['amount']} ج.م',
                        style: TextStyle(
                          fontSize: DesignTokens.textTitleLarge,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          if (s['proof_url'] != null)
            Column(
              children: [
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _expandedImageUrl = _expandedImageUrl == s['proof_url']
                          ? null
                          : s['proof_url'];
                    });
                  },
                  child: AnimatedContainer(
                    duration: DesignTokens.durationSlow,
                    curve: DesignTokens.curveEaseInOut,
                    height: _expandedImageUrl == s['proof_url'] ? 200.h : 48,
                    width: double.infinity,
                    margin: EdgeInsets.symmetric(horizontal: DesignTokens.space8),
                    decoration: BoxDecoration(
                      color: _expandedImageUrl == s['proof_url']
                          ? Colors.transparent
                          : AppTheme.primaryColor.withValues(alpha: 0.06),
                      borderRadius: DesignTokens.brSm,
                      image: _expandedImageUrl == s['proof_url']
                          ? DecorationImage(
                              image: NetworkImage(s['proof_url']),
                              fit: BoxFit.contain,
                            )
                          : null,
                      border: Border.all(
                        color: AppTheme.primaryColor.withValues(alpha: 0.15),
                      ),
                    ),
                    child: _expandedImageUrl == s['proof_url']
                        ? Align(
                            alignment: Alignment.topRight,
                            child: Padding(
                              padding: EdgeInsets.all(DesignTokens.space2),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.5),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.close_rounded,
                                  color: AppTheme.surfaceColor,
                                  size: DesignTokens.iconSm,
                                ),
                              ),
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.image_rounded,
                                size: DesignTokens.iconSm,
                                color: AppTheme.primaryColor,
                              ),
                              SizedBox(width: DesignTokens.space3),
                              Text(
                                'اضغط لعرض صورة الإثبات',
                                style: TextStyle(
                                  fontSize: DesignTokens.textBodySmall,
                                  color: AppTheme.primaryColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(width: DesignTokens.space3),
                              Icon(
                                Icons.expand_rounded,
                                size: DesignTokens.iconSm - 4,
                                color: AppTheme.primaryColor,
                              ),
                            ],
                          ),
                  ),
                ),
                SizedBox(height: DesignTokens.space4),
              ],
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
                            color: AppTheme.successColor.withValues(alpha: 0.25),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ElevatedButton.icon(
                        onPressed: () => _updateStatus(s['id'], 'verified'),
                        icon: Icon(Icons.check_rounded, size: DesignTokens.iconSm - 2),
                        label: const Text('تأكيد وقبض'),
                        ),
                      ),
                    ),
                  SizedBox(width: DesignTokens.space8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showRejectDialog(s['id']),
                      icon: Icon(Icons.close_rounded, size: DesignTokens.iconSm - 2),
                      label: const Text('رفض الطلب'),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: AppTheme.errorColor, width: 1.2),
                        foregroundColor: AppTheme.errorColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: DesignTokens.brSm,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            )
          else if (status == 'rejected' && s['rejection_reason'] != null)
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
                  color: AppTheme.errorColor.withValues(alpha: 0.06),
                  borderRadius: DesignTokens.brSm,
                  border: Border.all(
                    color: AppTheme.errorColor.withValues(alpha: 0.15),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: DesignTokens.iconSm - 2,
                      color: AppTheme.errorColor,
                    ),
                    SizedBox(width: DesignTokens.space3),
                    Expanded(
                      child: Text(
                        'سبب الرفض: ${s['rejection_reason']}',
                        style: TextStyle(
                          fontSize: DesignTokens.textBodySmall,
                          color: AppTheme.errorColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final color = status == 'verified'
        ? AppTheme.successColor
        : status == 'rejected'
            ? AppTheme.errorColor
            : AppTheme.tertiaryColor;
    final label = status == 'verified'
        ? 'مؤكد'
        : status == 'rejected'
            ? 'مرفوض'
            : 'قيد المراجعة';
    final icon = status == 'verified'
        ? Icons.check_circle_rounded
        : status == 'rejected'
            ? Icons.cancel_rounded
            : Icons.access_time_rounded;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: DesignTokens.space3,
        vertical: DesignTokens.space1,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.12), color.withValues(alpha: 0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: DesignTokens.brFull,
        border: Border.all(
          color: color.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: DesignTokens.iconXs, color: color),
          SizedBox(width: DesignTokens.space1),
          Text(
            label,
            style: TextStyle(
              fontSize: DesignTokens.textLabelSmall,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterBtn(String label, String val) {
    bool sel = _filter == val;
    final color = val == 'verified'
        ? AppTheme.successColor
        : val == 'rejected'
            ? AppTheme.errorColor
            : AppTheme.primaryColor;

    return GestureDetector(
      onTap: () {
        setState(() => _filter = val);
        _load();
      },
      child: AnimatedContainer(
        duration: DesignTokens.durationNormal,
        curve: DesignTokens.curveEmphasized,
        padding: EdgeInsets.symmetric(
          horizontal: DesignTokens.space5,
          vertical: DesignTokens.space3,
        ),
        decoration: BoxDecoration(
          gradient: sel
              ? LinearGradient(
                  colors: [color, color.withValues(alpha: 0.85)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: sel ? null : AppTheme.surfaceColor,
          borderRadius: DesignTokens.brXl,
          border: Border.all(
            color: sel
                ? color
                : AppTheme.textTertiary.withValues(alpha: 0.2),
            width: sel ? 0 : 1,
          ),
          boxShadow: sel
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (sel)
              Padding(
                padding: EdgeInsets.only(left: DesignTokens.space2),
                child: Icon(
                  Icons.check_rounded,
                  size: DesignTokens.iconSm - 6,
                  color: AppTheme.surfaceColor,
                ),
              ),
            Text(
              label,
              style: TextStyle(
                color: sel ? AppTheme.surfaceColor : AppTheme.textSecondary,
                fontWeight: FontWeight.w600,
                fontSize: DesignTokens.textLabelLarge,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showImage(String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: DesignTokens.brMd,
              child: Image.network(url, semanticLabel: 'صورة'),
            ),
            SizedBox(height: DesignTokens.space6),
            Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                tooltip: 'إغلاق',
                onPressed: () => Navigator.pop(context),
                icon: Icon(
                  Icons.close_rounded,
                  color: AppTheme.surfaceColor,
                  size: DesignTokens.iconMd,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(String? s) {
    if (s == null) return '';
    try {
      final d = DateTime.parse(s);
      return '${d.day}/${d.month} ${d.hour}:${d.minute}';
    } catch (_) {
      return '';
    }
  }
}