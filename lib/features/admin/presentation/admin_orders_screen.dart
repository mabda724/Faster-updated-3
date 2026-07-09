import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/services/supabase_service.dart';

class AdminOrdersScreen extends StatefulWidget {
  const AdminOrdersScreen({super.key});
  @override
  State<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends State<AdminOrdersScreen>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _bookings = [];
  bool _isLoading = true;
  String _filter = 'all';
  bool _isMapView = false;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: DesignTokens.durationModal,
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: DesignTokens.curveEaseInOut,
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: DesignTokens.curveEaseInOut,
    ));
    _load();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      var query = SupabaseService.db.from('bookings').select('''
        *,
        services(title, description, price),
        profiles!bookings_client_id_fkey(full_name, phone, avatar_url),
        provider_profiles!bookings_provider_id_fkey(
          *,
          profiles(full_name, phone, avatar_url)
        )
      ''');
      if (_filter != 'all') query = query.eq('status', _filter);
      final data = await query.order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _bookings = data.cast<Map<String, dynamic>>();
          _isLoading = false;
        });
        _animController.reset();
        _animController.forward();
      }
    } catch (e) {
      debugPrint('Error loading orders: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  double _getCommissionAmount(Map<String, dynamic> booking) {
    final total = double.tryParse(
            booking['total_price']?.toString() ?? booking['price']?.toString() ?? '0') ??
        0;
    double commissionAmount =
        double.tryParse(booking['commission_amount']?.toString() ?? '0') ?? 0;
    if (commissionAmount == 0) {
      final commissionRate =
          double.tryParse(booking['commission_rate']?.toString() ?? '0.10') ??
              0.10;
      commissionAmount = total * (commissionRate > 1 ? commissionRate / 100 : commissionRate);
    }
    return commissionAmount;
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'pending':
        return AppTheme.tertiaryColor;
      case 'accepted':
        return AppTheme.secondaryColor;
      case 'on_the_way':
        return AppTheme.primaryColor;
      case 'in_progress':
        return AppTheme.primaryColor;
      case 'completed':
        return AppTheme.successColor;
      case 'rejected':
      case 'cancelled':
        return AppTheme.errorColor;
      default:
        return AppTheme.textSecondary;
    }
  }

  LinearGradient _statusGradient(String s) {
    final c = _statusColor(s);
    return LinearGradient(
      colors: [c.withValues(alpha: 0.9), c],
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    );
  }

  String _statusText(String s) {
    switch (s) {
      case 'pending':
        return 'قيد الانتظار';
      case 'accepted':
        return 'مقبول';
      case 'completed':
        return 'مكتمل';
      case 'rejected':
        return 'مرفوض';
      case 'cancelled':
        return 'ملغي';
      case 'on_the_way':
        return 'في الطريق';
      case 'in_progress':
        return 'جاري العمل';
      default:
        return s;
    }
  }

  String _paymentMethodText(String? method) {
    switch (method) {
      case 'cash':
        return 'كاش';
      case 'card':
        return 'فيزا';
      case 'wallet':
        return 'محفظة';
      case 'unpaid':
        return 'غير مدفوع';
      default:
        return method ?? '-';
    }
  }

  LatLng _getMapCenter() {
    for (var b in _bookings) {
      final lat = double.tryParse(b['client_lat']?.toString() ?? '');
      final lng = double.tryParse(b['client_lng']?.toString() ?? '');
      if (lat != null && lng != null) {
        return LatLng(lat, lng);
      }
    }
    return const LatLng(30.0444, 31.2357);
  }

  List<Marker> _buildMarkers() {
    final markers = <Marker>[];
    for (var b in _bookings) {
      final lat = double.tryParse(b['client_lat']?.toString() ?? '');
      final lng = double.tryParse(b['client_lng']?.toString() ?? '');
      if (lat == null || lng == null) continue;

      final status = b['status'] ?? 'pending';
      final client = b['profiles'];
      final clientName = client?['full_name'] ?? 'عميل';
      final provider = b['provider_profiles'];
      final providerProfile = provider != null ? provider['profiles'] : null;
      final providerName = providerProfile?['full_name'];
      final serviceName = b['services']?['title'];

      markers.add(
        Marker(
          point: LatLng(lat, lng),
          width: 56.w,
          height: 56.h,
          child: GestureDetector(
            onTap: () => _showOrderDetailsBottomSheet(b),
            child: Container(
              decoration: BoxDecoration(
                gradient: _statusGradient(status),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _statusColor(status).withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
                border: Border.all(color: AppTheme.surfaceColor, width: 1.5),
              ),
              child: Icon(
                _getStatusIcon(status),
                color: AppTheme.surfaceColor,
                size: DesignTokens.iconMd,
              ),
            ),
          ),
        ),
      );
    }
    return markers;
  }

  void _showOrderDetailsBottomSheet(Map<String, dynamic> b) {
    final client = b['profiles'];
    final provider = b['provider_profiles'];
    final providerProfile = provider != null ? provider['profiles'] : null;
    final service = b['services'];
    final status = b['status'] ?? 'pending';
    final total = double.tryParse(
            b['total_price']?.toString() ?? b['price']?.toString() ?? '0') ??
        0;
    final commission = _getCommissionAmount(b);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          height: MediaQuery.of(context).size.height * 0.88,
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(DesignTokens.radius2xl)),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.only(top: DesignTokens.space6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _statusColor(status).withValues(alpha: 0.06),
                      AppTheme.surfaceColor,
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      width: DesignTokens.space20,
                      height: DesignTokens.space2,
                      decoration: BoxDecoration(
                        color: AppTheme.textTertiary.withValues(alpha: 0.3),
                        borderRadius: DesignTokens.brFull,
                      ),
                    ),
                    const SizedBox(height: DesignTokens.space4),
                    Padding(
                      padding: DesignTokens.hPadding24,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  gradient: _statusGradient(status),
                                  borderRadius: DesignTokens.brSm,
                                ),
                                child: Icon(
                                  _getStatusIcon(status),
                                  color: AppTheme.surfaceColor,
                                  size: DesignTokens.iconSm,
                                ),
                              ),
                              const SizedBox(width: DesignTokens.space3),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'تفاصيل الطلب',
                                    style: TextStyle(
                                      fontSize: DesignTokens.textTitleMedium,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    '#${b['id'].toString().substring(0, 8)}',
                                    style: TextStyle(
                                      fontSize: DesignTokens.textLabelSmall,
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          IconButton(
                            icon: Icon(Icons.close, color: AppTheme.textSecondary),
                            tooltip: 'إغلاق',
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: DesignTokens.pagePadding,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: DesignTokens.space6,
                          vertical: DesignTokens.space3,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              _statusColor(status).withValues(alpha: 0.08),
                              _statusColor(status).withValues(alpha: 0.03),
                            ],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          borderRadius: DesignTokens.brMd,
                          border: Border.all(
                            color: _statusColor(status).withValues(alpha: 0.15),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(DesignTokens.space2),
                              decoration: BoxDecoration(
                                color: _statusColor(status).withValues(alpha: 0.12),
                                borderRadius: DesignTokens.brSm,
                              ),
                              child: Icon(
                                _getStatusIcon(status),
                                color: _statusColor(status),
                                size: DesignTokens.iconSm,
                              ),
                            ),
                            const SizedBox(width: DesignTokens.space3),
                            Text(
                              _statusText(status),
                              style: TextStyle(
                                fontSize: DesignTokens.textBodyMedium,
                                fontWeight: FontWeight.bold,
                                color: _statusColor(status),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: DesignTokens.space8),

                      _buildSectionTitle(Icons.person_outline_rounded, 'بيانات العميل'),
                      _buildInfoCard([
                        _buildInfoRow('الاسم', client?['full_name'] ?? 'غير معروف'),
                        _buildInfoRow('رقم الهاتف', client?['phone'] ?? 'غير متوفر'),
                        if (b['address'] != null) _buildInfoRow('العنوان', b['address']),
                        if (b['client_lat'] != null && b['client_lng'] != null)
                          _buildInfoRow('الموقع', '${b['client_lat']}, ${b['client_lng']}'),
                      ]),
                      const SizedBox(height: DesignTokens.space8),

                      if (provider != null) ...[
                        _buildSectionTitle(Icons.engineering_rounded, 'بيانات مقدم الخدمة'),
                        _buildInfoCard([
                          _buildInfoRow('الاسم', providerProfile?['full_name'] ?? 'غير معروف'),
                          _buildInfoRow('رقم الهاتف', providerProfile?['phone'] ?? 'غير متوفر'),
                          _buildInfoRow(
                            'التقييم',
                            '${provider['rating']?.toStringAsFixed(1) ?? '0.0'} (${provider['total_reviews'] ?? 0} تقييم)',
                          ),
                          _buildInfoRow(
                            'حالة الصناعي',
                            provider['is_online'] == true ? 'متصل' : 'غير متصل',
                          ),
                        ]),
                      ] else if (status == 'pending') ...[
                        _buildSectionTitle(Icons.engineering_rounded, 'بيانات مقدم الخدمة'),
                        _buildInfoCard([
                          _buildInfoRow('الحالة', 'لم يتم تحديد مقدم خدمة بعد'),
                        ]),
                      ],
                      const SizedBox(height: DesignTokens.space8),

                      if (service != null) ...[
                        _buildSectionTitle(Icons.build_outlined, 'بيانات الخدمة'),
                        _buildInfoCard([
                          _buildInfoRow('اسم الخدمة', service['title']),
                          if (service['description'] != null)
                            _buildInfoRow('الوصف', service['description']),
                          _buildInfoRow('السعر الأساسي', '${service['price']} ج/س'),
                        ]),
                      ],
                      const SizedBox(height: DesignTokens.space8),

                      _buildSectionTitle(Icons.account_balance_wallet_outlined, 'المعلومات المالية'),
                      _buildInfoCard([
                        _buildInfoRow('السعر النهائي', '$total جنيه', bold: true),
                        _buildInfoRow('عمولة التطبيق', '$commission جنيه',
                            color: AppTheme.tertiaryColor),
                        _buildInfoRow('صافي ربح الصناعي', '${total - commission} جنيه',
                            color: AppTheme.successColor),
                        _buildInfoRow('طريقة الدفع', _paymentMethodText(b['payment_method'])),
                        _buildInfoRow('خدمة مجانية؟', b['is_free_service'] == true ? 'نعم' : 'لا'),
                      ]),
                      const SizedBox(height: DesignTokens.space8),

                      _buildSectionTitle(Icons.schedule_rounded, 'التواريخ والأوقات'),
                      _buildInfoCard([
                        _buildInfoRow('تاريخ الطلب', _formatDate(b['created_at'])),
                        if (b['accepted_at'] != null)
                          _buildInfoRow('تاريخ القبول', _formatDate(b['accepted_at'])),
                        if (b['started_at'] != null)
                          _buildInfoRow('تاريخ البدء', _formatDate(b['started_at'])),
                        if (b['completed_at'] != null)
                          _buildInfoRow('تاريخ الإتمام', _formatDate(b['completed_at'])),
                        if (b['cancelled_at'] != null)
                          _buildInfoRow('تاريخ الإلغاء', _formatDate(b['cancelled_at'])),
                      ]),
                      const SizedBox(height: DesignTokens.space8),

                      if (status == 'cancelled' && b['cancel_reason'] != null) ...[
                        _buildSectionTitle(Icons.info_outline_rounded, 'سبب الإلغاء'),
                        _buildInfoCard([
                          _buildInfoRow('السبب', b['cancel_reason']),
                          if (b['cancellation_reason'] != null)
                            _buildInfoRow('تفاصيل إضافية', b['cancellation_reason']),
                          _buildInfoRow(
                            'ألغى بواسطة',
                            b['cancelled_by'] == b['client_id'] ? 'العميل' : 'مقدم الخدمة',
                          ),
                        ]),
                      ],
                      const SizedBox(height: DesignTokens.space8),

                      _buildSectionTitle(Icons.admin_panel_settings_rounded, 'إجراءات الأدمن'),
                      _buildAdminActions(b, status, setSheetState),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(IconData icon, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: DesignTokens.space3),
      child: Row(
        children: [
          Container(
            width: DesignTokens.space9,
            height: DesignTokens.space9,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: DesignTokens.brSm,
            ),
            child: Icon(icon, color: AppTheme.surfaceColor, size: DesignTokens.iconXs),
          ),
          const SizedBox(width: DesignTokens.space3),
          Text(
            title,
            style: TextStyle(
              fontSize: DesignTokens.textTitleSmall,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(DesignTokens.space6),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: DesignTokens.brMd,
        border: Border.all(
          color: AppTheme.adaptiveBorder(context),
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildInfoRow(String label, String value,
      {bool bold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DesignTokens.space2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 110,
            padding: const EdgeInsets.symmetric(
              horizontal: DesignTokens.space2,
              vertical: DesignTokens.space1,
            ),
            decoration: BoxDecoration(
              color: AppTheme.backgroundColor.withValues(alpha: 0.5),
              borderRadius: DesignTokens.brXs,
            ),
            child: Text(
              label,
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: DesignTokens.textLabelMedium,
              ),
            ),
          ),
          const SizedBox(width: DesignTokens.space3),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: color ?? AppTheme.textPrimary,
                fontSize: DesignTokens.textBodyMedium,
                fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminActions(
      Map<String, dynamic> booking, String status, StateSetter setSheetState) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(DesignTokens.space6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor.withValues(alpha: 0.04),
            AppTheme.primaryColor.withValues(alpha: 0.01),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: DesignTokens.brMd,
        border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (status != 'completed' && status != 'cancelled') ...[
            Row(
              children: [
                Container(
                  width: DesignTokens.space14,
                  height: DesignTokens.space14,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: DesignTokens.brXs,
                  ),
                  child: Icon(
                    Icons.swap_horiz_rounded,
                    size: DesignTokens.iconXs,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(width: DesignTokens.space2),
                Text(
                  'تغيير الحالة:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: DesignTokens.textBodyMedium,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: DesignTokens.space4),
            Wrap(
              spacing: DesignTokens.space3,
              runSpacing: DesignTokens.space3,
              children: [
                if (status == 'pending')
                  _actionChip('قبول', AppTheme.successColor,
                      () => _changeStatus(booking, 'accepted', setSheetState)),
                if (status == 'accepted')
                  _actionChip('في الطريق', AppTheme.primaryColor,
                      () => _changeStatus(booking, 'on_the_way', setSheetState)),
                if (status == 'on_the_way')
                  _actionChip('وصل', AppTheme.primaryColor,
                      () => _changeStatus(booking, 'arrived', setSheetState)),
                if (status == 'arrived')
                  _actionChip('بدء العمل', AppTheme.whatsappColor,
                      () => _changeStatus(booking, 'in_progress', setSheetState)),
                if (status == 'in_progress')
                  _actionChip('إتمام', AppTheme.successColor,
                      () => _changeStatus(booking, 'completed', setSheetState)),
                _actionChip('إلغاء', AppTheme.errorColor,
                    () => _cancelOrder(booking, setSheetState)),
              ],
            ),
            const SizedBox(height: DesignTokens.space6),
          ],

          Container(
            padding: const EdgeInsets.all(DesignTokens.space4),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor.withValues(alpha: 0.6),
              borderRadius: DesignTokens.brSm,
              border: Border.all(
                color: AppTheme.adaptiveBorder(context),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: DesignTokens.space14,
                  height: DesignTokens.space14,
                  decoration: BoxDecoration(
                    color: AppTheme.tertiaryColor.withValues(alpha: 0.1),
                    borderRadius: DesignTokens.brXs,
                  ),
                  child: Icon(
                    Icons.card_giftcard_rounded,
                    size: DesignTokens.iconXs,
                    color: AppTheme.tertiaryColor,
                  ),
                ),
                const SizedBox(width: DesignTokens.space3),
                Text(
                  'خدمة مجانية:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: DesignTokens.textBodyMedium,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const Spacer(),
                Switch(
                  value: booking['is_free_service'] == true,
                  onChanged: (value) =>
                      _toggleFreeService(booking, value, setSheetState),
                ),
              ],
            ),
          ),

          if (status == 'pending') ...[
            const SizedBox(height: DesignTokens.space6),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: Icon(Icons.person_add_alt_rounded, size: DesignTokens.iconSm),
                label: const Text('تعيين صناعي يدوياً'),
                onPressed: () => _assignProvider(booking, setSheetState),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: AppTheme.surfaceColor,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: DesignTokens.space8,
                    vertical: DesignTokens.space4,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: DesignTokens.brSm,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _actionChip(String label, Color color, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: DesignTokens.brFull,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: DesignTokens.space6,
            vertical: DesignTokens.space3,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                color.withValues(alpha: 0.08),
                color.withValues(alpha: 0.04),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: DesignTokens.brFull,
            border: Border.all(color: color.withValues(alpha: 0.15)),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: DesignTokens.textLabelMedium,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _changeStatus(
      Map<String, dynamic> booking, String newStatus, StateSetter setSheetState) async {
    try {
      await SupabaseService.db.from('bookings').update({
        'status': newStatus,
        'provider_status': newStatus,
      }).eq('id', booking['id']);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: AppTheme.surfaceColor, size: DesignTokens.iconSm),
                const SizedBox(width: DesignTokens.space3),
                Text('تم تغيير الحالة إلى ${_statusText(newStatus)}'),
              ],
            ),
            backgroundColor: AppTheme.successColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: DesignTokens.brSm),
          ),
        );
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) Navigator.pop(context);
        });
        _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ: $e'),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _cancelOrder(
      Map<String, dynamic> booking, StateSetter setSheetState) async {
    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Container(
              width: DesignTokens.space16,
              height: DesignTokens.space16,
              decoration: BoxDecoration(
                color: AppTheme.errorColor.withValues(alpha: 0.1),
                borderRadius: DesignTokens.brSm,
              ),
              child: Icon(Icons.cancel_rounded,
                  color: AppTheme.errorColor, size: DesignTokens.iconSm),
            ),
            const SizedBox(width: DesignTokens.space3),
            Text('إلغاء الطلب',
                style: TextStyle(
                    fontSize: DesignTokens.textTitleSmall,
                    fontWeight: FontWeight.bold)),
          ],
        ),
        content: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: TextField(
            controller: reasonCtrl,
            decoration: InputDecoration(
              hintText: 'سبب الإلغاء',
              filled: true,
              fillColor: Colors.grey.shade200,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('تراجع'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('إلغاء'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await SupabaseService.db.from('bookings').update({
        'status': 'cancelled',
        'provider_status': 'cancelled',
        'cancel_reason':
            reasonCtrl.text.trim().isEmpty ? null : reasonCtrl.text.trim(),
        'cancelled_by': SupabaseService.currentUserId,
        'cancelled_at': DateTime.now().toIso8601String(),
      }).eq('id', booking['id']);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.cancel, color: AppTheme.surfaceColor, size: DesignTokens.iconSm),
                const SizedBox(width: DesignTokens.space3),
                Text('تم إلغاء الطلب'),
              ],
            ),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: DesignTokens.brSm),
          ),
        );
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) Navigator.pop(context);
        });
        _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ: $e'),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _toggleFreeService(
      Map<String, dynamic> booking, bool isFree, StateSetter setSheetState) async {
    try {
      await SupabaseService.db
          .from('bookings')
          .update({'is_free_service': isFree})
          .eq('id', booking['id']);

      setSheetState(() {
        booking['is_free_service'] = isFree;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  isFree ? Icons.check_circle : Icons.info_outline,
                  color: AppTheme.surfaceColor,
                  size: DesignTokens.iconSm,
                ),
                const SizedBox(width: DesignTokens.space3),
                Text(isFree ? 'تم تفعيل الخدمة المجانية' : 'تم إلغاء الخدمة المجانية'),
              ],
            ),
            backgroundColor: AppTheme.successColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: DesignTokens.brSm),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ: $e'),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _assignProvider(
      Map<String, dynamic> booking, StateSetter setSheetState) async {
    List<Map<String, dynamic>> providers = [];
    try {
      final data = await SupabaseService.db
          .from('profiles')
          .select('id, full_name, phone_number, provider_profiles!inner(profession, rating, is_online, category_id)')
          .eq('role', 'provider')
          .eq('provider_profiles.document_verification_status', 'approved')
          .order('full_name');
      providers = List<Map<String, dynamic>>.from(data);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ في تحميل قائمة مقدمي الخدمة: $e')));
      return;
    }

    if (providers.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('لا يوجد مقدمي خدمة موثقين متاحين'),
        backgroundColor: AppTheme.tertiaryColor,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    final selected = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.75),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(DesignTokens.radius2xl)),
        ),
        child: Column(
          children: [
            Container(
              width: DesignTokens.space20, height: DesignTokens.space2, margin: const EdgeInsets.only(top: DesignTokens.space4, bottom: DesignTokens.space2),
              decoration: BoxDecoration(
                color: AppTheme.textTertiary.withValues(alpha: 0.3),
                borderRadius: DesignTokens.brFull,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: DesignTokens.space8, vertical: DesignTokens.space4),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(DesignTokens.space3),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: DesignTokens.brSm,
                    ),
                    child: const Icon(Icons.person_add_alt_rounded, color: AppTheme.primaryColor, size: DesignTokens.iconSm),
                  ),
                  const SizedBox(width: DesignTokens.space4),
                  const Text('اختيار مقدم خدمة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: DesignTokens.textTitleSmall, color: AppTheme.textPrimary)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppTheme.textSecondary),
                    tooltip: 'إغلاق',
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(DesignTokens.space4),
                itemCount: providers.length,
                itemBuilder: (_, i) {
                  final p = providers[i];
                  final pp = p['provider_profiles'] is List ? (p['provider_profiles'] as List).firstOrNull as Map<String, dynamic>? : p['provider_profiles'] as Map<String, dynamic>?;
                  final isOnline = pp?['is_online'] == true;
                  final rating = double.tryParse(pp?['rating']?.toString() ?? '0') ?? 0;
                  return Card(
                    margin: const EdgeInsets.only(bottom: DesignTokens.space3),
                    shape: RoundedRectangleBorder(borderRadius: DesignTokens.brMd),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isOnline ? AppTheme.successColor.withValues(alpha: 0.15) : AppTheme.textSecondary.withValues(alpha: 0.1),
                        child: Icon(Icons.person_rounded, color: isOnline ? AppTheme.successColor : AppTheme.textSecondary),
                      ),
                      title: Text(p['full_name'] ?? 'بدون اسم', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: DesignTokens.textBodyMedium)),
                      subtitle: Row(
                        children: [
                          if (pp?['profession'] != null)
                            Text(pp!['profession'], style: TextStyle(fontSize: DesignTokens.textLabelSmall, color: AppTheme.textSecondary)),
                          if (pp?['profession'] != null) const SizedBox(width: DesignTokens.space4),
                          Icon(Icons.star_rounded, size: DesignTokens.iconXs, color: AppTheme.tertiaryColor),
                          Text(rating.toStringAsFixed(1), style: TextStyle(fontSize: DesignTokens.textLabelSmall, color: AppTheme.tertiaryColor)),
                        ],
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: DesignTokens.space4, vertical: DesignTokens.space2),
                        decoration: BoxDecoration(
                          color: isOnline ? AppTheme.successColor.withValues(alpha: 0.1) : AppTheme.textSecondary.withValues(alpha: 0.1),
                          borderRadius: DesignTokens.brSm,
                        ),
                        child: Text(isOnline ? 'متاح' : 'غير متصل', style: TextStyle(fontSize: DesignTokens.textLabelSmall, color: isOnline ? AppTheme.successColor : AppTheme.textSecondary, fontWeight: FontWeight.bold)),
                      ),
                      onTap: () => Navigator.pop(ctx, p),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );

    if (selected == null || !mounted) return;

    try {
      setSheetState(() {});
      await SupabaseService.db.from('bookings').update({
        'provider_id': selected['id'],
        'status': 'accepted',
        'provider_status': 'accepted',
        'accepted_at': DateTime.now().toIso8601String(),
      }).eq('id', booking['id']);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: AppTheme.surfaceColor, size: DesignTokens.iconSm),
              const SizedBox(width: DesignTokens.space4),
              Text('تم تعيين ${selected['full_name'] ?? 'مقدم الخدمة'} بنجاح'),
            ],
          ),
          backgroundColor: AppTheme.successColor,
          behavior: SnackBarBehavior.floating,
        ));
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) Navigator.pop(context);
        });
        _load();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('خطأ في التعيين: $e'),
        backgroundColor: AppTheme.errorColor,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'pending':
        return Icons.hourglass_empty_rounded;
      case 'accepted':
        return Icons.check_circle_outline_rounded;
      case 'on_the_way':
        return Icons.directions_car_rounded;
      case 'arrived':
        return Icons.location_on_rounded;
      case 'in_progress':
        return Icons.build_rounded;
      case 'completed':
        return Icons.check_circle_rounded;
      case 'cancelled':
        return Icons.cancel_rounded;
      default:
        return Icons.help_outline_rounded;
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '-';
    try {
      final date = DateTime.parse(dateStr).toLocal();
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '-';
    }
  }

  Widget _buildMapView() {
    final markers = _buildMarkers();
    if (markers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.06),
                borderRadius: DesignTokens.brFull,
              ),
              child: Icon(
                Icons.map_outlined,
                size: DesignTokens.iconLg,
                color: AppTheme.primaryColor.withValues(alpha: 0.3),
              ),
            ),
            const SizedBox(height: DesignTokens.space8),
            Text(
              'لا توجد طلبات بمواقع محددة للعرض على الخريطة',
              style: TextStyle(
                fontSize: DesignTokens.textBodyMedium,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return FlutterMap(
      options: MapOptions(
        initialCenter: _getMapCenter(),
        initialZoom: 12,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.faster.app',
        ),
        MarkerLayer(markers: markers),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: DesignTokens.space8,
                vertical: DesignTokens.space6,
              ),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryColor.withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  AppTheme.primaryColor,
                                  AppTheme.secondaryColor,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: DesignTokens.brSm,
                            ),
                            child: Icon(
                              Icons.receipt_long_rounded,
                              color: AppTheme.surfaceColor,
                              size: DesignTokens.iconSm,
                            ),
                          ),
                          const SizedBox(width: DesignTokens.space3),
                          Text(
                            'إدارة الطلبات',
                            style: TextStyle(
                              fontSize: DesignTokens.textTitleMedium,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.06),
                          borderRadius: DesignTokens.brSm,
                          border: Border.all(
                            color: AppTheme.primaryColor.withValues(alpha: 0.12),
                          ),
                        ),
                        child: IconButton(
                          icon: Icon(
                            _isMapView
                                ? Icons.list_alt_rounded
                                : Icons.map_rounded,
                            color: AppTheme.primaryColor,
                            size: DesignTokens.iconSm,
                          ),
                          onPressed: () =>
                              setState(() => _isMapView = !_isMapView),
                          tooltip: _isMapView ? 'عرض كقائمة' : 'عرض على الخريطة',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: DesignTokens.space6),
                  SizedBox(
                    height: DesignTokens.space16 + 8.h,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _filterChip('الكل', 'all'),
                        _filterChip('قيد الانتظار', 'pending'),
                        _filterChip('مقبول', 'accepted'),
                        _filterChip('في الطريق', 'on_the_way'),
                        _filterChip('جاري العمل', 'in_progress'),
                        _filterChip('مكتمل', 'completed'),
                        _filterChip('مرفوض', 'rejected'),
                        _filterChip('ملغي', 'cancelled'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: DesignTokens.durationNormal,
                switchInCurve: DesignTokens.curveEaseInOut,
                switchOutCurve: DesignTokens.curveEaseInOut,
                child: _isLoading
                    ? _buildShimmerLoading()
                    : _bookings.isEmpty
                        ? _buildEmptyState()
                        : _isMapView
                            ? _buildMapView()
                            : _buildOrdersList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmerLoading() {
    return ListView.builder(
      key: const ValueKey('shimmer'),
      padding: DesignTokens.pagePadding,
      itemCount: 6,
      itemBuilder: (_, i) => Container(
        margin: const EdgeInsets.only(bottom: DesignTokens.space6),
        padding: const EdgeInsets.all(DesignTokens.space6),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: DesignTokens.brMd,
          border: Border.all(
            color: AppTheme.adaptiveBorder(context),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: DesignTokens.space40,
                  height: DesignTokens.space6,
                  decoration: BoxDecoration(
                    color: AppTheme.adaptiveBorder(context),
                    borderRadius: DesignTokens.brFull,
                  ),
                ),
                Container(
                  width: 50,
                  height: DesignTokens.space10,
                  decoration: BoxDecoration(
                    color: AppTheme.adaptiveBorder(context),
                    borderRadius: DesignTokens.brFull,
                  ),
                ),
              ],
            ),
            const SizedBox(height: DesignTokens.space4),
            Container(
              width: double.infinity,
              height: DesignTokens.space5,
              decoration: BoxDecoration(
                color: AppTheme.backgroundColor,
                borderRadius: DesignTokens.brFull,
              ),
            ),
            const SizedBox(height: DesignTokens.space2),
            Container(
              width: 150,
              height: DesignTokens.space5,
              decoration: BoxDecoration(
                color: AppTheme.backgroundColor,
                borderRadius: DesignTokens.brFull,
              ),
            ),
            const SizedBox(height: DesignTokens.space4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: DesignTokens.space40,
                  height: DesignTokens.space7,
                  decoration: BoxDecoration(
                    color: AppTheme.adaptiveBorder(context),
                    borderRadius: DesignTokens.brFull,
                  ),
                ),
                Container(
                  width: DesignTokens.space20,
                  height: DesignTokens.space10,
                  decoration: BoxDecoration(
                    color: AppTheme.adaptiveBorder(context),
                    borderRadius: DesignTokens.brFull,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      key: const ValueKey('empty'),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: DesignTokens.space40,
            height: DesignTokens.space40,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.06),
              borderRadius: DesignTokens.brFull,
            ),
            child: Icon(
              Icons.receipt_long_outlined,
              size: DesignTokens.iconLg,
              color: AppTheme.primaryColor.withValues(alpha: 0.25),
            ),
          ),
          const SizedBox(height: DesignTokens.space8),
          Text(
            'لا توجد طلبات',
            style: TextStyle(
              fontSize: DesignTokens.textBodyMedium,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: DesignTokens.space2),
          Text(
            _filter == 'all'
                ? 'لم يتم إنشاء أي طلبات بعد'
                : 'لا توجد طلبات بهذه الحالة',
            style: TextStyle(
              fontSize: DesignTokens.textLabelMedium,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrdersList() {
    return FadeTransition(
      key: const ValueKey('orders_list'),
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: RefreshIndicator(
          onRefresh: _load,
          color: AppTheme.primaryColor,
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(
              DesignTokens.space8,
              DesignTokens.space4,
              DesignTokens.space8,
              DesignTokens.space16,
            ),
            itemCount: _bookings.length,
            itemBuilder: (_, i) {
              final b = _bookings[i];
              final status = b['status'] ?? 'pending';
              final client = b['profiles'];
              final clientName = client?['full_name'] ?? 'عميل';
              final provider = b['provider_profiles'];
              final providerProfile =
                  provider != null ? provider['profiles'] : null;
              final providerName = providerProfile?['full_name'];
              final serviceName = b['services']?['title'];
              final total = double.tryParse(b['total_price']?.toString() ??
                      b['price']?.toString() ??
                      '0') ??
                  0;
              final commission = _getCommissionAmount(b);
              final statusC = _statusColor(status);

              return Padding(
                padding: const EdgeInsets.only(bottom: DesignTokens.space3),
                child: GestureDetector(
                  onTap: () => _showOrderDetailsBottomSheet(b),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceColor,
                      borderRadius: DesignTokens.brMd,
                      border: Border.all(
                        color: AppTheme.adaptiveBorder(context),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryColor.withValues(alpha: 0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                        BoxShadow(
                          color: AppTheme.primaryColor.withValues(alpha: 0.02),
                          blurRadius: 2,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.fromLTRB(
                            DesignTokens.space6,
                            DesignTokens.space4,
                            DesignTokens.space6,
                            DesignTokens.space2,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                statusC.withValues(alpha: 0.03),
                                Colors.transparent,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(DesignTokens.radiusMd),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: DesignTokens.space9,
                                    height: DesignTokens.space9,
                                    decoration: BoxDecoration(
                                      gradient: _statusGradient(status),
                                      borderRadius: DesignTokens.brXs,
                                    ),
                                    child: Icon(
                                      _getStatusIcon(status),
                                      color: AppTheme.surfaceColor,
                                      size: DesignTokens.iconXs,
                                    ),
                                  ),
                                  const SizedBox(width: DesignTokens.space2),
                                  Text(
                                    '#${b['id'].toString().substring(0, 8)}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: DesignTokens.textLabelMedium,
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                              AnimatedContainer(
                                duration: DesignTokens.durationFast,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: DesignTokens.space4,
                                  vertical: DesignTokens.space1,
                                ),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      statusC.withValues(alpha: 0.1),
                                      statusC.withValues(alpha: 0.05),
                                    ],
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                  ),
                                  borderRadius: DesignTokens.brFull,
                                  border: Border.all(
                                    color: statusC.withValues(alpha: 0.2),
                                  ),
                                ),
                                child: Text(
                                  _statusText(status),
                                  style: TextStyle(
                                    fontSize: DesignTokens.textLabelSmall,
                                    fontWeight: FontWeight.bold,
                                    color: statusC,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: DesignTokens.space6,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  _buildInfoIconLabel(
                                    Icons.person_outline_rounded,
                                    'العميل: $clientName',
                                  ),
                                ],
                              ),
                              if (serviceName != null) ...[
                                const SizedBox(height: DesignTokens.space1),
                                Row(
                                  children: [
                                    _buildInfoIconLabel(
                                      Icons.build_outlined,
                                      'الخدمة: $serviceName',
                                    ),
                                  ],
                                ),
                              ],
                              if (providerName != null) ...[
                                const SizedBox(height: DesignTokens.space1),
                                Row(
                                  children: [
                                    _buildInfoIconLabel(
                                      Icons.engineering_rounded,
                                      'المقدم: $providerName',
                                    ),
                                  ],
                                ),
                              ] else if (status == 'pending') ...[
                                const SizedBox(height: DesignTokens.space1),
                                Row(
                                  children: [
                                    _buildInfoIconLabel(
                                      Icons.flash_on_rounded,
                                      'طلب عام - لم يحدد مقدم',
                                      color: AppTheme.tertiaryColor,
                                    ),
                                  ],
                                ),
                              ],
                              if (b['address'] != null) ...[
                                const SizedBox(height: DesignTokens.space1),
                                _buildInfoIconLabel(
                                  Icons.location_on_outlined,
                                  b['address'],
                                  isExpanded: true,
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: DesignTokens.space2),
                        Container(
                          padding: const EdgeInsets.fromLTRB(
                            DesignTokens.space6,
                            DesignTokens.space3,
                            DesignTokens.space6,
                            DesignTokens.space3,
                          ),
                          decoration: BoxDecoration(
                            border: Border(
                              top: BorderSide(
                                color: AppTheme.adaptiveBorder(context),
                                width: 1,
                              ),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${total.toStringAsFixed(0)} جنيه',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.primaryColor,
                                      fontSize: DesignTokens.textBodyMedium,
                                    ),
                                  ),
                                  Text(
                                    'عمولة: ${commission.toStringAsFixed(0)} ج',
                                    style: TextStyle(
                                      fontSize: DesignTokens.textLabelSmall,
                                      color: AppTheme.tertiaryColor,
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: DesignTokens.space4,
                                  vertical: DesignTokens.space2,
                                ),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: b['payment_method'] == 'cash'
                                        ? [
                                            AppTheme.successColor.withValues(alpha: 0.1),
                                            AppTheme.successColor.withValues(alpha: 0.05),
                                          ]
                                        : [
                                            AppTheme.primaryColor.withValues(alpha: 0.1),
                                            AppTheme.primaryColor.withValues(alpha: 0.05),
                                          ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: DesignTokens.brSm,
                                  border: Border.all(
                                    color: b['payment_method'] == 'cash'
                                        ? AppTheme.successColor.withValues(alpha: 0.15)
                                        : AppTheme.primaryColor.withValues(alpha: 0.15),
                                  ),
                                ),
                                child: Text(
                                  _paymentMethodText(b['payment_method']),
                                  style: TextStyle(
                                    fontSize: DesignTokens.textLabelSmall,
                                    fontWeight: FontWeight.bold,
                                    color: b['payment_method'] == 'cash'
                                        ? AppTheme.successColor
                                        : AppTheme.primaryColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildInfoIconLabel(IconData icon, String text,
      {Color? color, bool isExpanded = false}) {
    final textColor = color ?? AppTheme.textSecondary;
    return Row(
      children: [
        Icon(icon, size: DesignTokens.iconXs, color: textColor),
        const SizedBox(width: DesignTokens.space1),
        if (isExpanded)
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: DesignTokens.textLabelMedium,
                color: textColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          )
        else
          Text(
            text,
            style: TextStyle(
              fontSize: DesignTokens.textLabelMedium,
              color: textColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
      ],
    );
  }

  Widget _filterChip(String label, String value) {
    final sel = _filter == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _filter = value;
          _isLoading = true;
        });
        _load();
      },
      child: AnimatedContainer(
        duration: DesignTokens.durationFast,
        curve: DesignTokens.curveEaseInOut,
        margin: const EdgeInsets.only(left: DesignTokens.space2),
        padding: const EdgeInsets.symmetric(
          horizontal: DesignTokens.space6,
          vertical: DesignTokens.space4,
        ),
        decoration: BoxDecoration(
          gradient: sel
              ? const LinearGradient(
                  colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                )
              : null,
          color: sel ? null : AppTheme.surfaceColor,
          borderRadius: DesignTokens.brFull,
          border: Border.all(
            color: sel
                ? AppTheme.primaryColor
                : AppTheme.textPrimary.withValues(alpha: 0.08),
          ),
          boxShadow: sel
              ? [
                  BoxShadow(
                    color: AppTheme.primaryColor.withValues(alpha: 0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: sel ? AppTheme.surfaceColor : AppTheme.textSecondary,
            fontWeight: FontWeight.bold,
            fontSize: DesignTokens.textLabelMedium,
          ),
        ),
      ),
    );
  }
}