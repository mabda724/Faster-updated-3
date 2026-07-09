import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/design_tokens.dart';

/// Booking status types supported by the app.
enum StatusType {
  pending,
  accepted,
  onTheWay,
  arrived,
  inProgress,
  completed,
  cancelled,
  rejected,
}

class _BadgeStyle {
  final IconData icon;
  final Color color;
  final Color bgColor;

  const _BadgeStyle(this.icon, this.color, this.bgColor);
}

/// Unified status badge component that follows the design system.
/// Automatically maps status to correct icon + color + background.
class AppStatusBadge extends StatelessWidget {
  final StatusType status;
  final String? label;
  final bool showIcon;
  final bool isSmall;

  const AppStatusBadge({
    super.key,
    required this.status,
    this.label,
    this.showIcon = true,
    this.isSmall = false,
  });

  static final Map<StatusType, _BadgeStyle> _styles = {
    StatusType.pending: _BadgeStyle(
      Icons.hourglass_top_rounded,
      AppTheme.warningColor,
      const Color(0xFFFFFBEB),
    ),
    StatusType.accepted: _BadgeStyle(
      Icons.check_circle_outline_rounded,
      AppTheme.primaryColor,
      const Color(0xFFF5F3FF),
    ),
    StatusType.onTheWay: _BadgeStyle(
      Icons.directions_car_rounded,
      const Color(0xFF8B5CF6),
      const Color(0xFFF5F3FF),
    ),
    StatusType.arrived: _BadgeStyle(
      Icons.location_on_rounded,
      const Color(0xFF14B8A6),
      const Color(0xFFF0FDFA),
    ),
    StatusType.inProgress: _BadgeStyle(
      Icons.build_rounded,
      const Color(0xFFF97316),
      const Color(0xFFFFF7ED),
    ),
    StatusType.completed: _BadgeStyle(
      Icons.check_circle_rounded,
      AppTheme.successColor,
      const Color(0xFFF0FDF4),
    ),
    StatusType.cancelled: _BadgeStyle(
      Icons.cancel_rounded,
      AppTheme.errorColor,
      const Color(0xFFFEF2F2),
    ),
    StatusType.rejected: _BadgeStyle(
      Icons.block_rounded,
      AppTheme.errorColor,
      const Color(0xFFFEF2F2),
    ),
  };

  static String _statusLabel(StatusType s) {
    return const {
      StatusType.pending: 'قيد الانتظار',
      StatusType.accepted: 'تم القبول',
      StatusType.onTheWay: 'في الطريق',
      StatusType.arrived: 'وصل',
      StatusType.inProgress: 'جاري التنفيذ',
      StatusType.completed: 'مكتمل',
      StatusType.cancelled: 'ملغي',
      StatusType.rejected: 'مرفوض',
    }[s]!;
  }

  @override
  Widget build(BuildContext context) {
    final style = _styles[status]!;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmall ? 8.0 : 12.0,
        vertical: isSmall ? 4.0 : 6.0,
      ),
      decoration: BoxDecoration(
        color: style.bgColor,
        borderRadius: DesignTokens.brSm,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showIcon)
            Icon(
              style.icon,
              color: style.color,
              size: isSmall ? 14.0 : 16.0,
            ),
          if (showIcon) const SizedBox(width: 4),
          Text(
            label ?? _statusLabel(status),
            style: TextStyle(
              color: style.color,
              fontSize: isSmall ? 10.0 : 12.0,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
