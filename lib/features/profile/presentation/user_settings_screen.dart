import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/theme/app_theme.dart';

class UserSettingsScreen extends StatelessWidget {
  const UserSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('الإعدادات'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          tooltip: 'العودة',
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(24.w),
        child: Column(
          children: [
            _buildSection('عام', [
              _buildItem(Icons.notifications_none_rounded, 'التنبيهات', true),
              _buildItem(Icons.language_rounded, 'اللغة', true, trailing: 'العربية'),
              _buildItem(Icons.dark_mode_outlined, 'الوضع الليلي', false),
            ]),
            SizedBox(height: 24.h),
            _buildSection('الحساب والأمان', [
              _buildItem(Icons.lock_outline_rounded, 'تغيير كلمة المرور', true),
              _buildItem(Icons.security_rounded, 'خصوصية البيانات', true),
              _buildItem(Icons.delete_forever_outlined, 'حذف الحساب', true, color: Colors.red),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(right: 8.w, bottom: 12.h),
          child: Text(title, style: TextStyle(fontSize: 14.sp, color: AppTheme.textSecondary, fontWeight: FontWeight.bold)),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildItem(IconData icon, String title, bool hasArrow, {String? trailing, Color? color}) {
    return ListTile(
      leading: Icon(icon, color: color ?? AppTheme.textPrimary),
      title: Text(title, style: TextStyle(color: color ?? AppTheme.textPrimary, fontSize: 16.sp, fontWeight: FontWeight.w500)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trailing != null) Text(trailing, style: TextStyle(color: AppTheme.textSecondary, fontSize: 14.sp)),
          if (hasArrow) Icon(Icons.arrow_forward_ios_rounded, size: 16, color: AppTheme.textSecondary),
        ],
      ),
      onTap: () {},
    );
  }
}
