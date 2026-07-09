import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/design_tokens.dart';

void test() {
  String method = 'weekly';
  void setS(void Function() fn) => fn();
  
  Row(children: [
    Expanded(child: Semantics(label: 'سحب أسبوعي', child: GestureDetector(onTap: () => setS(() => method = 'weekly'), child: Container(padding: const EdgeInsets.all(DesignTokens.space7), decoration: BoxDecoration(color: method == 'weekly' ? AppTheme.primaryColor.withValues(alpha: 0.1) : AppTheme.surfaceColor, borderRadius: DesignTokens.brMd, border: Border.all(color: method == 'weekly' ? AppTheme.primaryColor : AppTheme.textPrimary.withValues(alpha: 0.1)), child: Column(children: [Icon(Icons.calendar_today, color: method == 'weekly' ? AppTheme.primaryColor : AppTheme.textSecondary, size: 20), const SizedBox(height: DesignTokens.space2), Text('كل خميس', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: method == 'weekly' ? AppTheme.primaryColor : AppTheme.textSecondary))]))),
    SizedBox(width: DesignTokens.space6.w),
    Expanded(child: Semantics(label: 'سحب شهري', child: GestureDetector(onTap: () => setS(() => method = 'monthly'), child: Container(padding: const EdgeInsets.all(DesignTokens.space7), decoration: BoxDecoration(color: method == 'monthly' ? AppTheme.primaryColor.withValues(alpha: 0.1) : AppTheme.surfaceColor, borderRadius: DesignTokens.brMd, border: Border.all(color: method == 'monthly' ? AppTheme.primaryColor : AppTheme.textPrimary.withValues(alpha: 0.1)), child: Column(children: [Icon(Icons.date_range, color: method == 'monthly' ? AppTheme.primaryColor : AppTheme.textSecondary, size: 20), const SizedBox(height: DesignTokens.space2), Text('آخر الشهر', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: method == 'monthly' ? AppTheme.primaryColor : AppTheme.textSecondary))]))),
  ]);
}
