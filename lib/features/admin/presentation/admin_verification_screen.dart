
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/notification_service.dart';

class AdminVerificationScreen extends StatefulWidget {
  const AdminVerificationScreen({super.key});
  @override
  State<AdminVerificationScreen> createState() => _AdminVerificationScreenState();
}

class _AdminVerificationScreenState extends State<AdminVerificationScreen> {
  List<Map<String, dynamic>> _pending = [];
  bool _isLoading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final data = await SupabaseService.db.from('pending_face_verification').select();
      _pending = List<Map<String, dynamic>>.from(data);
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _verify(String id, {required bool approved}) async {
    String? rejectionReason;
    if (!approved) {
      final reasonCtrl = TextEditingController();
      final confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
        title: Row(
            children: [
              Icon(Icons.gpp_bad_rounded, color: AppTheme.errorColor, size: DesignTokens.iconMd),
              SizedBox(width: DesignTokens.space4),
              Text('سبب الرفض', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: DesignTokens.textTitleSmall)),
            ],
          ),
          content: TextField(
            controller: reasonCtrl,
            textAlign: TextAlign.right,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'اكتب سبب رفض المستندات...',
              hintStyle: TextStyle(color: AppTheme.textTertiary),
              filled: true,
              fillColor: AppTheme.backgroundColor,
              border: OutlineInputBorder(borderRadius: DesignTokens.brMd, borderSide: BorderSide.none),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('إلغاء', style: TextStyle(color: AppTheme.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              ),
              child: Text('رفض', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      rejectionReason = reasonCtrl.text.trim().isNotEmpty ? reasonCtrl.text.trim() : 'مستندات غير صحيحة';
    }

    try {
      await SupabaseService.client.rpc('verify_provider_documents', params: {
        'p_provider_id': id,
        'p_approved': approved,
        'p_rejection_reason': rejectionReason,
      });

      try {
        await NotificationService.sendPushNotification(
          userId: id,
          title: approved ? 'تم توثيق المستندات' : 'تم رفض المستندات',
          body: approved
            ? 'تمت الموافقة على مستنداتك بنجاح. يمكنك الآن تقديم الخدمات.'
            : 'لم تتم الموافقة على مستنداتك. ${rejectionReason ?? 'يرجى إعادة رفع المستندات الصحيحة.'}',
          type: approved ? 'document_verified' : 'document_rejected',
        );
      } catch (_) {}

      if (mounted) {
        _snack(
          approved ? 'تم توثيق مقدم الخدمة بنجاح' : 'تم رفض المستندات مع إرسال سبب الرفض',
          color: approved ? AppTheme.successColor : AppTheme.errorColor,
        );
      }
    } catch (e) {
      debugPrint('Verification error: $e');
      if (mounted) _snack('خطأ في التحقق: $e', color: AppTheme.errorColor);
    }
    _load();
  }

  void _snack(String msg, {Color? color}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg, textAlign: TextAlign.center), backgroundColor: color ?? AppTheme.primaryColor, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: DesignTokens.brMd)),
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
            Icon(Icons.verified_user_rounded, color: AppTheme.primaryColor, size: DesignTokens.iconMd),
            SizedBox(width: DesignTokens.space4),
            Text('التحقق من الهوية', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: DesignTokens.textTitleMedium)),
          ],
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.textPrimary),
          tooltip: 'العودة',
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
          : _pending.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: EdgeInsets.all(DesignTokens.space24),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceColor,
                          shape: BoxShape.circle,
                          boxShadow: DesignTokens.shadow2(AppTheme.textPrimary),
                        ),
                        child: Icon(Icons.verified_rounded, size: DesignTokens.iconDoctorAvatar, color: AppTheme.successColor.withValues(alpha: 0.5)),
                      ),
                      SizedBox(height: DesignTokens.space20),
                      Text('لا يوجد طلبات تحقق', style: TextStyle(color: AppTheme.textSecondary, fontSize: DesignTokens.textTitleSmall)),
                      SizedBox(height: DesignTokens.space8),
                      Text('جميع مقدمي الخدمة موثقين', style: TextStyle(color: AppTheme.textTertiary, fontSize: DesignTokens.textBodyMedium)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppTheme.primaryColor,
                  child: ListView.builder(
                    padding: EdgeInsets.all(DesignTokens.space20),
                    itemCount: _pending.length,
                    itemBuilder: (_, i) {
                      final p = _pending[i];
                      return _buildVerificationCard(p);
                    },
                  ),
                ),
    );
  }

  Widget _buildVerificationCard(Map<String, dynamic> p) {
    final status = p['document_verification_status'] as String? ?? 'pending';
    final isRejected = status == 'rejected';
    return Container(
      margin: EdgeInsets.only(bottom: DesignTokens.space20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: DesignTokens.brXl,
        border: Border.all(
          color: isRejected
            ? AppTheme.errorColor.withValues(alpha: 0.15)
            : AppTheme.textPrimary.withValues(alpha: 0.05),
        ),
        boxShadow: DesignTokens.shadow2(AppTheme.textPrimary),
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(DesignTokens.space16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.vertical(top: DesignTokens.brXl),
              gradient: LinearGradient(
                colors: [
                  if (isRejected)
                    AppTheme.errorColor.withValues(alpha: 0.05)
                  else
                    AppTheme.primaryColor.withValues(alpha: 0.03),
                  AppTheme.surfaceColor,
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: DesignTokens.iconDoctorAvatar,
                  height: DesignTokens.iconDoctorAvatar,
                  decoration: BoxDecoration(
                    gradient: isRejected
                      ? LinearGradient(colors: [AppTheme.errorColor, AppTheme.errorColor.withValues(alpha: 0.7)])
                      : AppTheme.primaryGradient,
                    shape: BoxShape.circle,
                    boxShadow: DesignTokens.shadow2(AppTheme.primaryColor),
                  ),
                  child: Center(
                    child: Text(
                      (p['full_name'] as String?)?[0].toUpperCase() ?? '?',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: DesignTokens.textTitleLarge),
                    ),
                  ),
                ),
                SizedBox(width: DesignTokens.space12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p['full_name'] ?? '',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: DesignTokens.textTitleSmall, color: AppTheme.textPrimary),
                      ),
                      SizedBox(height: DesignTokens.space4),
                      Text(
                        p['profession'] ?? '',
                        style: TextStyle(fontSize: DesignTokens.textBodySmall, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
                _buildStatusBadge(status),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: DesignTokens.space16),
            child: Row(
              children: [
                Expanded(child: _photoCard(p['id_document_url'], 'صورة الهوية')),
                SizedBox(width: DesignTokens.space12),
                Expanded(child: _photoCard(p['profile_document_url'], 'صورة شخصية (سيلفي)')),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.all(DesignTokens.space16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _verify(p['id'], approved: false),
                    icon: Icon(Icons.close_rounded, color: AppTheme.errorColor, size: DesignTokens.iconSm),
                    label: Text('رفض', style: TextStyle(color: AppTheme.errorColor, fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AppTheme.errorColor, width: 1.5),
                      padding: EdgeInsets.symmetric(vertical: DesignTokens.space12),
                      shape: RoundedRectangleBorder(borderRadius: DesignTokens.brLg),
                    ),
                  ),
                ),
                SizedBox(width: DesignTokens.space12),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: DesignTokens.brLg,
                      boxShadow: DesignTokens.shadow1(AppTheme.primaryColor),
                    ),
                    child: ElevatedButton.icon(
                      onPressed: () => _verify(p['id'], approved: true),
                      icon: Icon(Icons.check_rounded, color: Colors.white, size: DesignTokens.iconSm),
                      label: Text(isRejected ? 'توثيق (إعادة)' : 'توثيق', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      shape: RoundedRectangleBorder(borderRadius: DesignTokens.brLg),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (isRejected)
            Container(
              width: double.infinity,
              margin: EdgeInsets.fromLTRB(DesignTokens.space16, 0, DesignTokens.space16, DesignTokens.space16),
              padding: EdgeInsets.all(DesignTokens.space6),
              decoration: BoxDecoration(
                color: AppTheme.errorColor.withValues(alpha: 0.05),
                borderRadius: DesignTokens.brSm,
                border: Border.all(color: AppTheme.errorColor.withValues(alpha: 0.15)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, size: DesignTokens.iconSm, color: AppTheme.errorColor),
                  SizedBox(width: DesignTokens.space4),
                  Text('مرفوض مسبقاً - يمكن إعادة التوثيق بعد رفع مستندات جديدة',
                    style: TextStyle(fontSize: DesignTokens.textLabelSmall, color: AppTheme.errorColor),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final isApproved = status == 'approved';
    final isRejected = status == 'rejected';
    Color badgeColor;
    String badgeText;
    IconData badgeIcon;
    if (isApproved) {
      badgeColor = AppTheme.successColor;
      badgeText = 'موثق';
      badgeIcon = Icons.verified_rounded;
    } else if (isRejected) {
      badgeColor = AppTheme.errorColor;
      badgeText = 'مرفوض';
      badgeIcon = Icons.gpp_bad_rounded;
    } else {
      badgeColor = AppTheme.tertiaryColor;
      badgeText = 'قيد المراجعة';
      badgeIcon = Icons.hourglass_empty_rounded;
    }
    return Container(
      padding: EdgeInsets.symmetric(horizontal: DesignTokens.space10, vertical: DesignTokens.space4),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.1),
        borderRadius: DesignTokens.brSm,
        border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(badgeIcon, size: DesignTokens.iconXs, color: badgeColor),
          SizedBox(width: DesignTokens.space4),
          Text(
            badgeText,
            style: TextStyle(fontSize: DesignTokens.textLabelSmall, color: badgeColor, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _photoCard(String? url, String label) {
    return Column(
      children: [
        Container(
          height: 180,
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppTheme.backgroundColor,
            borderRadius: DesignTokens.brMd,
            border: Border.all(color: AppTheme.textPrimary.withValues(alpha: 0.08)),
            boxShadow: url != null && url.isNotEmpty ? DesignTokens.shadow1(AppTheme.textPrimary) : null,
          ),
          child: url != null && url.isNotEmpty
              ? ClipRRect(
                  borderRadius: DesignTokens.brMd,
                  child: Image.network(
                    url,
                    fit: BoxFit.cover,
                    semanticLabel: 'صورة التحقق',
                    errorBuilder: (_, __, ___) => _emptyPhoto(),
                    loadingBuilder: (_, child, progress) {
                      if (progress == null) return child;
                      return Center(
                        child: CircularProgressIndicator(
                          color: AppTheme.primaryColor,
                          strokeWidth: 2,
                          value: progress.expectedTotalBytes != null ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes! : null,
                        ),
                      );
                    },
                  ),
                )
              : _emptyPhoto(),
        ),
        SizedBox(height: DesignTokens.space6),
        Container(
          padding: EdgeInsets.symmetric(horizontal: DesignTokens.space8, vertical: DesignTokens.space2),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.06),
            borderRadius: DesignTokens.brSm,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.image_outlined, size: DesignTokens.iconXs, color: AppTheme.primaryColor),
              SizedBox(width: DesignTokens.space4),
              Text(label, style: TextStyle(fontSize: DesignTokens.textLabelSmall, color: AppTheme.primaryColor, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _emptyPhoto() => Container(
    decoration: BoxDecoration(
      color: AppTheme.textSecondary.withValues(alpha: 0.04),
      borderRadius: DesignTokens.brMd,
    ),
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.image_outlined, size: DesignTokens.iconLg, color: AppTheme.textSecondary.withValues(alpha: DesignTokens.opacityMuted)),
          SizedBox(height: DesignTokens.space4),
          Text('لا توجد صورة', style: TextStyle(fontSize: DesignTokens.textLabelSmall, color: AppTheme.textSecondary.withValues(alpha: DesignTokens.opacityMuted))),
        ],
      ),
    ),
  );
}