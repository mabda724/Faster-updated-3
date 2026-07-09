// ============================================================
// Faster App - جميع الحقوق محفوظة
// All Rights Reserved © 2024-2026
// المالك: محمد ابراهيم عبدالله | 01128966996
// ============================================================
// ============================================================
// Faster App - ???? ?????? ??????
// ??????: ???? ??????? ??????? | 01128966996
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Unified booking status configuration used across the entire app.
class BookingStatusConfig {
  final String label;
  final String description;
  final Color color;
  final IconData icon;
  final bool isTerminal;

  const BookingStatusConfig({
    required this.label,
    required this.description,
    required this.color,
    required this.icon,
    this.isTerminal = false,
  });
}

const Map<String, BookingStatusConfig> _statusMap = {
  'pending': BookingStatusConfig(
    label: 'بانتظار القبول',
    description: 'الطلب مرسل وجاري البحث عن مقدم خدمة مناسب',
    color: AppTheme.warningColor,
    icon: Icons.access_time_rounded,
  ),
  'accepted': BookingStatusConfig(
    label: 'تم القبول',
    description: 'قام مقدم الخدمة بقبول طلبك وهو يستعد للتحرك',
    color: AppTheme.infoColor,
    icon: Icons.thumb_up_alt_rounded,
  ),
  'on_the_way': BookingStatusConfig(
    label: 'في الطريق',
    description: 'مقدم الخدمة في الطريق إليك الآن',
    color: Color(0xFF8B5CF6), // custom purple
    icon: Icons.local_shipping_rounded,
  ),
  'arrived': BookingStatusConfig(
    label: 'وصل للموقع',
    description: 'مقدم الخدمة وصل إلى موقعك',
    color: Color(0xFF14B8A6), // custom teal
    icon: Icons.location_on_rounded,
  ),
  'in_progress': BookingStatusConfig(
    label: 'جاري التنفيذ',
    description: 'مقدم الخدمة بدأ في تنفيذ الخدمة',
    color: Color(0xFFF97316), // custom orange
    icon: Icons.build_rounded,
  ),
  'completed': BookingStatusConfig(
    label: 'تم التنفيذ',
    description: 'تم إتمام الخدمة بنجاح',
    color: AppTheme.successColor,
    icon: Icons.check_circle_rounded,
    isTerminal: true,
  ),
  'cancelled': BookingStatusConfig(
    label: 'تم الإلغاء',
    description: 'تم إلغاء الطلب',
    color: AppTheme.errorColor,
    icon: Icons.cancel_rounded,
    isTerminal: true,
  ),
  'rejected': BookingStatusConfig(
    label: 'تم الرفض',
    description: 'تم رفض الطلب من مقدم الخدمة',
    color: AppTheme.errorColor,
    icon: Icons.block_rounded,
    isTerminal: true,
  ),
};

/// Returns the config for a given raw status string.
BookingStatusConfig getBookingStatusConfig(String? status) {
  return _statusMap[status] ??
      const BookingStatusConfig(
        label: 'غير معروف',
        description: '',
        color: Colors.grey,
        icon: Icons.help_outline_rounded,
      );
}

/// Color only helper.
Color getBookingStatusColor(String? status) => getBookingStatusConfig(status).color;

/// Label only helper.
String getBookingStatusLabel(String? status) => getBookingStatusConfig(status).label;

/// Icon only helper.
IconData getBookingStatusIcon(String? status) => getBookingStatusConfig(status).icon;

/// Terminal = completed, cancelled, rejected.
bool isTerminalStatus(String? status) => getBookingStatusConfig(status).isTerminal;

/// Active statuses = not terminal.
bool isActiveStatus(String? status) {
  final s = status ?? '';
  return s != 'completed' && s != 'cancelled' && s != 'rejected';
}

/// The canonical flow for the booking journey.
const List<String> bookingStatusFlow = [
  'pending',
  'accepted',
  'on_the_way',
  'arrived',
  'in_progress',
  'completed',
];

/// Returns the index of a status in the canonical flow, or -1.
int getBookingStatusIndex(String? status) {
  if (status == null) return -1;
  return bookingStatusFlow.indexOf(status);
}

/// Returns the next logical status in the flow.
String? getNextBookingStatus(String? currentStatus) {
  final idx = getBookingStatusIndex(currentStatus);
  if (idx < 0 || idx >= bookingStatusFlow.length - 1) return null;
  return bookingStatusFlow[idx + 1];
}

/// Returns the action button label for a provider to advance the status.
String getProviderActionLabel(String? status) {
  switch (status) {
    case 'pending':
      return 'قبول الطلب';
    case 'accepted':
      return 'بدأت التحرك';
    case 'on_the_way':
      return 'وصلت للموقع';
    case 'arrived':
      return 'بدأت الشغل';
    case 'in_progress':
      return 'إنهاء الطلب';
    default:
      return 'تحديث الحالة';
  }
}

/// Returns the icon for the provider action button.
IconData getProviderActionIcon(String? status) {
  switch (status) {
    case 'pending':
      return Icons.check_circle_rounded;
    case 'accepted':
      return Icons.local_shipping_rounded;
    case 'on_the_way':
      return Icons.location_on_rounded;
    case 'arrived':
      return Icons.build_rounded;
    case 'in_progress':
      return Icons.done_all_rounded;
    default:
      return Icons.arrow_forward_rounded;
  }
}

/// Returns a localized status change message for snackbars / notifications.
String getStatusChangeMessage(String newStatus) {
  final config = getBookingStatusConfig(newStatus);
  return 'تم تحديث الحالة: ${config.label}';
}
