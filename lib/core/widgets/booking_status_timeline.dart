// ============================================================
// Faster App - جميع الحقوق محفوظة
// All Rights Reserved © 2024-2026
// المالك: محمد ابراهيم عبدالله | 01128966996
// ============================================================
// ============================================================
// Faster App - ???? ?????? ??????
// ??????: ???? ??????? ??????? | 01128966996
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../theme/app_theme.dart';
import '../theme/design_tokens.dart';
import '../utils/booking_status_utils.dart';

/// A professional vertical timeline widget that visualises the booking journey.
///
/// Supports:
/// - completed steps (filled primary circle + primary line)
/// - current step (filled primary circle with pulse + primary line)
/// - upcoming steps (grey outline circle + grey line)
/// - cancelled / rejected (red line branching from current position)
class BookingStatusTimeline extends StatelessWidget {
  final String currentStatus;
  final String? cancelledAt;
  final String? completedAt;
  final bool showDescriptions;
  final bool isCompact;

  const BookingStatusTimeline({
    super.key,
    required this.currentStatus,
    this.cancelledAt,
    this.completedAt,
    this.showDescriptions = true,
    this.isCompact = false,
  });

  bool get _isCancelled => currentStatus == 'cancelled' || currentStatus == 'rejected';

  @override
  Widget build(BuildContext context) {
    final steps = _buildSteps();
    return Container(
      padding: EdgeInsets.all(isCompact ? DesignTokens.space16 : DesignTokens.space20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: DesignTokens.brXl,
        border: Border.all(color: AppTheme.textPrimary.withValues(alpha: 0.05)),
        boxShadow: DesignTokens.shadow3(Colors.black),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isCompact) ...[
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(DesignTokens.space12),
                  decoration: BoxDecoration(
                    color: (_isCancelled ? AppTheme.errorColor : AppTheme.primaryColor).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isCancelled ? Icons.warning_rounded : Icons.route_rounded,
                    color: _isCancelled ? AppTheme.errorColor : AppTheme.primaryColor,
                    size: DesignTokens.space20,
                  ),
                ),
                SizedBox(width: DesignTokens.space12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'حالة الطلب',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: DesignTokens.textTitleSmall,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      getBookingStatusConfig(currentStatus).label,
                      style: TextStyle(
                        fontSize: DesignTokens.textBodySmall,
                        fontWeight: FontWeight.w600,
                        color: getBookingStatusColor(currentStatus),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: DesignTokens.space20),
          ],
          ...List.generate(steps.length, (index) {
            final step = steps[index];
            final isLast = index == steps.length - 1;
            return _StepRow(
              step: step,
              isLast: isLast,
              isCompact: isCompact,
              showDescription: showDescriptions,
            );
          }),
        ],
      ),
    );
  }

  List<_StepData> _buildSteps() {
    if (_isCancelled) {
      // For UI purposes we show: pending was attempted, then cancelled.
      return [
        _StepData(
          status: 'pending',
          label: getBookingStatusConfig('pending').label,
          description: getBookingStatusConfig('pending').description,
          icon: getBookingStatusConfig('pending').icon,
          state: _StepState.completed,
        ),
        _StepData(
          status: currentStatus,
          label: getBookingStatusConfig(currentStatus).label,
          description: getBookingStatusConfig(currentStatus).description,
          icon: getBookingStatusConfig(currentStatus).icon,
          state: _StepState.cancelled,
        ),
      ];
    }

    final currentIdx = getBookingStatusIndex(currentStatus);
    final result = <_StepData>[];

    for (int i = 0; i < bookingStatusFlow.length; i++) {
      final s = bookingStatusFlow[i];
      final config = getBookingStatusConfig(s);
      _StepState state;
      if (i < currentIdx) {
        state = _StepState.completed;
      } else if (i == currentIdx) {
        state = _StepState.current;
      } else {
        state = _StepState.upcoming;
      }
      result.add(_StepData(
        status: s,
        label: config.label,
        description: config.description,
        icon: config.icon,
        state: state,
      ));
    }
    return result;
  }
}

enum _StepState { completed, current, upcoming, cancelled }

class _StepData {
  final String status;
  final String label;
  final String description;
  final IconData icon;
  final _StepState state;

  _StepData({
    required this.status,
    required this.label,
    required this.description,
    required this.icon,
    required this.state,
  });
}

class _StepRow extends StatelessWidget {
  final _StepData step;
  final bool isLast;
  final bool isCompact;
  final bool showDescription;

  const _StepRow({
    required this.step,
    required this.isLast,
    this.isCompact = false,
    this.showDescription = true,
  });

  @override
  Widget build(BuildContext context) {
    final circleSize = isCompact ? 28.0 : 34.0;
    final iconSize = isCompact ? 14.0 : 16.0;

    Color circleColor;
    Color lineColor;
    Color iconColor;
    Widget circleContent;

    switch (step.state) {
      case _StepState.completed:
        circleColor = AppTheme.primaryColor;
        lineColor = AppTheme.primaryColor;
        iconColor = Colors.white;
        circleContent = Icon(Icons.check_rounded, color: iconColor, size: iconSize);
        break;
      case _StepState.current:
        circleColor = AppTheme.primaryColor;
        lineColor = AppTheme.primaryColor.withValues(alpha: 0.3);
        iconColor = Colors.white;
        circleContent = Icon(step.icon, color: iconColor, size: iconSize);
        break;
      case _StepState.cancelled:
        circleColor = AppTheme.errorColor;
        lineColor = AppTheme.errorColor.withValues(alpha: 0.3);
        iconColor = Colors.white;
        circleContent = Icon(step.icon, color: iconColor, size: iconSize);
        break;
      case _StepState.upcoming:
        circleColor = AppTheme.textSecondary.withValues(alpha: 0.1);
        lineColor = AppTheme.textSecondary.withValues(alpha: 0.2);
        iconColor = AppTheme.textTertiary;
        circleContent = Icon(step.icon, color: iconColor, size: iconSize);
        break;
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline column
          Column(
            children: [
              Container(
                width: circleSize,
                height: circleSize,
                decoration: BoxDecoration(
                  color: circleColor,
                  shape: BoxShape.circle,
                  border: step.state == _StepState.upcoming
                      ? Border.all(color: AppTheme.textSecondary.withValues(alpha: 0.2), width: 2)
                      : null,
                  boxShadow: step.state == _StepState.current
                      ? [
                          BoxShadow(
                            color: AppTheme.primaryColor.withValues(alpha: 0.3),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ]
                      : null,
                ),
                child: Center(child: circleContent),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    color: lineColor,
                  ),
                ),
            ],
          ),
          SizedBox(width: isCompact ? 10.w : 14.w),
          // Content
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : (isCompact ? 12.h : 18.h)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step.label,
                    style: TextStyle(
                      fontWeight: step.state == _StepState.current || step.state == _StepState.completed
                          ? FontWeight.bold
                          : FontWeight.w500,
                      fontSize: isCompact ? 12 : 14,
                      color: step.state == _StepState.upcoming ? AppTheme.textTertiary : AppTheme.textPrimary,
                    ),
                  ),
                  if (showDescription && step.description.isNotEmpty) ...[
                    SizedBox(height: 2.h),
                    Text(
                      step.description,
                      style: TextStyle(
                        fontSize: isCompact ? 10 : 12,
                        color: step.state == _StepState.upcoming ? AppTheme.textTertiary : AppTheme.textSecondary,
                      ),
                    ),
                  ],
                  if (step.state == _StepState.current && (step.status == 'on_the_way' || step.status == 'arrived')) ...[
                    SizedBox(height: 6.h),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.schedule_rounded, size: 12, color: AppTheme.primaryColor),
                          SizedBox(width: 4.w),
                          const Text(
                            'قيد التحديث المباشر',
                            style: TextStyle(fontSize: 10, color: AppTheme.primaryColor, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
