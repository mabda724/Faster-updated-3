import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/widgets/app_report_bottom_sheet.dart';
import '../../../core/utils/snackbar_utils.dart';
import 'tracking_screen.dart';
import 'reviews_screen.dart';
import '../../chat/presentation/chat_screen.dart';

class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen> {
  int _selectedTab = 0;
  List<Map<String, dynamic>> _currentOrders = [];
  List<Map<String, dynamic>> _pastOrders = [];
  bool _isLoading = true;
  String _selectedStatus = 'all';
  String _selectedDateRange = 'all';
  int? _selectedCategoryId;
  List<Map<String, dynamic>> _categories = [];

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _loadBookings();
  }

  Future<void> _loadCategories() async {
    try {
      final res = await SupabaseService.db
          .from('categories')
          .select('id, name_ar')
          .order('name_ar');
      setState(() => _categories = List<Map<String, dynamic>>.from(res));
    } catch (_) {}
  }

  Future<void> _loadBookings() async {
    setState(() => _isLoading = true);
    try {
      final uid = SupabaseService.currentUserId;
      if (uid == null) throw Exception('Not logged in');

      var query = SupabaseService.db
          .from('bookings')
          .select(
              '*, services(title, price, description, image_url, category_id)')
          .eq('client_id', uid);

      if (_selectedStatus != 'all') {
        query = query.eq('status', _selectedStatus);
      }
      if (_selectedDateRange != 'all') {
        final now = DateTime.now();
        DateTime startDate;
        if (_selectedDateRange == 'last_7') {
          startDate = now.subtract(const Duration(days: 7));
        } else if (_selectedDateRange == 'last_30') {
          startDate = now.subtract(const Duration(days: 30));
        } else {
          startDate = DateTime(2000);
        }
        query = query.gte('created_at', startDate.toIso8601String());
      }

      final bookings = await query.order('created_at', ascending: false);

      final List<Map<String, dynamic>> current = [];
      final List<Map<String, dynamic>> past = [];

      for (var b in bookings) {
        final status = b['status'] as String;

        if (_selectedCategoryId != null &&
            b['services']?['category_id'] != _selectedCategoryId) {
          continue;
        }

        String providerName = 'مقدم خدمة';
        String? providerProfileId;
        if (b['provider_id'] != null) {
          try {
            final prov = await SupabaseService.db
                .from('profiles')
                .select('full_name')
                .eq('id', b['provider_id'])
                .maybeSingle();
            providerName = prov?['full_name'] ?? 'مقدم خدمة';
            providerProfileId = b['provider_id'];
          } catch (_) {}
        }

        bool hasReview = false;
        if (status == 'completed' && b['id'] != null) {
          try {
            final review = await SupabaseService.db
                .from('reviews')
                .select('id')
                .eq('booking_id', b['id'])
                .maybeSingle();
            hasReview = review != null;
          } catch (_) {}
        }

        final bookingMap = {
          'id': b['id'],
          'title': b['services']?['title'] ?? 'خدمة',
          'price': '${b['total_price'] ?? b['price'] ?? 0} جنيه',
          'offeredPrice':
              b['offered_price'] != null ? '${b['offered_price']} جنيه' : null,
          'rawStatus': status,
          'status': _statusText(status),
          'statusColor': _statusColor(status),
          'statusIcon': _statusIcon(status),
          'company': providerName,
          'providerId': providerProfileId ?? '',
          'hasReview': hasReview,
          'image': b['services']?['image_url'] ??
              'https://images.unsplash.com/photo-1581578731548-c64695cc6952?w=200&q=80',
          'createdAt': b['created_at'],
        };

        if (status == 'pending' ||
            status == 'accepted' ||
            status == 'on_the_way' ||
            status == 'arrived' ||
            status == 'in_progress') {
          current.add(bookingMap);
        } else {
          past.add(bookingMap);
        }
      }

      if (!mounted) return;
      setState(() {
        _currentOrders = current;
        _pastOrders = past;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading bookings: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'pending':
        return Icons.hourglass_empty_rounded;
      case 'accepted':
        return Icons.check_circle_rounded;
      case 'on_the_way':
        return Icons.directions_car_rounded;
      case 'arrived':
        return Icons.location_on_rounded;
      case 'in_progress':
        return Icons.build_rounded;
      case 'completed':
        return Icons.check_rounded;
      case 'cancelled':
        return Icons.cancel_rounded;
      case 'rejected':
        return Icons.block_rounded;
      default:
        return Icons.article_outlined;
    }
  }

  void _showPicker(String type) {
    final items = type == 'status'
        ? const ['الكل', 'معلق', 'مقبول', 'في الطريق', 'وصل', 'جاري العمل', 'مكتمل', 'ملغي', 'مرفوض']
        : type == 'date'
            ? const ['الكل', 'آخر 7 أيام', 'آخر 30 يوم']
            : ['الكل', ..._categories.map((c) => c['name_ar'] as String).toList()];

    final currentValue = type == 'status'
        ? _selectedStatus == 'all'
            ? 'الكل'
            : _statusText(_selectedStatus)
        : type == 'date'
            ? _selectedDateRange == 'all'
                ? 'الكل'
                : _selectedDateRange == 'last_7'
                    ? 'آخر 7 أيام'
                    : 'آخر 30 يوم'
            : _selectedCategoryId == null
                ? 'الكل'
                : _categories
                        .firstWhere(
                          (c) => c['id'] == _selectedCategoryId,
                          orElse: () => {'name_ar': 'الكل'},
                        )['name_ar'];

    int initialIndex = items.indexOf(currentValue);
    if (initialIndex == -1) initialIndex = 0;

    showModalBottomSheet(
      context: context,
      builder: (_) => Container(
        height: 250.h,
        padding: EdgeInsets.only(top: DesignTokens.space4.h),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(DesignTokens.radiusXl),
            topRight: Radius.circular(DesignTokens.radiusXl),
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: DesignTokens.space16.w, vertical: DesignTokens.space8.h),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: Padding(
                      padding: EdgeInsets.zero,
                      child: Text('إلغاء', style: TextStyle(color: AppTheme.primaryColor)),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: Padding(
                      padding: EdgeInsets.zero,
                      child: Text('حفظ', style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListWheelScrollView(
                itemExtent: 36,
                physics: const FixedExtentScrollPhysics(),
                diameterRatio: 1.5,
                children: List.generate(items.length, (i) {
                  final value = items[i];
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        if (type == 'status') {
                          _selectedStatus = value == 'الكل'
                              ? 'all'
                              : value == 'معلق'
                                  ? 'pending'
                                  : value == 'مقبول'
                                      ? 'accepted'
                                      : value == 'في الطريق'
                                          ? 'on_the_way'
                                          : value == 'وصل'
                                              ? 'arrived'
                                              : value == 'جاري العمل'
                                                  ? 'in_progress'
                                                  : value == 'مكتمل'
                                                      ? 'completed'
                                                      : value == 'ملغي'
                                                          ? 'cancelled'
                                                          : 'rejected';
                        } else if (type == 'date') {
                          _selectedDateRange = value == 'الكل'
                              ? 'all'
                              : value == 'آخر 7 أيام'
                                  ? 'last_7'
                                  : 'last_30';
                        } else {
                          final catId = value == 'الكل'
                              ? null
                              : _categories
                                      .firstWhere(
                                        (c) => c['name_ar'] == value,
                                        orElse: () => {},
                                      )['id'];
                          _selectedCategoryId = catId as int?;
                        }
                      });
                    },
                    child: Center(
                      child: Text(
                        value,
                        style: TextStyle(
                          fontSize: DesignTokens.textBodyLarge,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                  );
                }),
              ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            SizedBox(height: DesignTokens.space16),
            _buildFilters(),
            SizedBox(height: DesignTokens.space12),
            _buildTabs(),
            SizedBox(height: DesignTokens.space12),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : IndexedStack(
                      index: _selectedTab,
                      children: [
                        _buildOrdersList(_currentOrders, isCurrent: true),
                        _buildOrdersList(_pastOrders, isCurrent: false),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        DesignTokens.space20,
        DesignTokens.space16,
        DesignTokens.space20,
        0,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'طلباتي',
            style: TextStyle(
              fontSize: DesignTokens.textDisplayMedium.sp,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          if (!_isLoading)
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: DesignTokens.space12,
                vertical: DesignTokens.space4.h,
              ),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: DesignTokens.brXl,
              ),
              child: Text(
                '${_currentOrders.length + _pastOrders.length} طلب',
                style: TextStyle(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.bold,
                  fontSize: DesignTokens.textLabelSmall.sp,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: DesignTokens.space20),
      child: Row(
        children: [
          Expanded(
            child: _buildFilterButton(
              label: 'الحالة',
              value: _selectedStatus == 'all'
                  ? 'الكل'
                  : _statusText(_selectedStatus),
              onTap: () => _showPicker('status'),
            ),
          ),
          SizedBox(width: DesignTokens.space8.w),
          Expanded(
            child: _buildFilterButton(
              label: 'التاريخ',
              value: _selectedDateRange == 'all'
                  ? 'الكل'
                  : _selectedDateRange == 'last_7'
                      ? 'آخر 7 أيام'
                      : 'آخر 30 يوم',
              onTap: () => _showPicker('date'),
            ),
          ),
          SizedBox(width: DesignTokens.space8.w),
          Expanded(
            child: _buildFilterButton(
              label: 'الخدمة',
              value: _selectedCategoryId == null
                  ? 'الكل'
                  : _categories
                          .firstWhere(
                            (c) => c['id'] == _selectedCategoryId,
                            orElse: () => {'name_ar': 'الكل'},
                          )['name_ar'],
              onTap: () => _showPicker('category'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterButton({
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: DesignTokens.space12.w, vertical: DesignTokens.space10.h),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: DesignTokens.brMd,
          border: Border.all(color: AppTheme.textPrimary.withValues(alpha: 0.1)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                value,
                style: TextStyle(
                  fontSize: DesignTokens.textBodyMedium.sp,
                  color: AppTheme.textPrimary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: AppTheme.textSecondary),
          ],
        ),
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: DesignTokens.space20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: DesignTokens.brXl,
        border: Border.all(color: AppTheme.textPrimary.withValues(alpha: 0.06)),
      ),
      child: SegmentedButton<int>(
        segments: [
          ButtonSegment(
            value: 0,
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('الحالية', style: TextStyle(fontSize: DesignTokens.textBodyMedium.sp)),
                if (_currentOrders.isNotEmpty) ...[
                  SizedBox(width: DesignTokens.space4.w),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: DesignTokens.space6.w, vertical: DesignTokens.space2.h),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.2),
                      borderRadius: DesignTokens.brXl,
                    ),
                    child: Text(
                      '${_currentOrders.length}',
                      style: TextStyle(
                        fontSize: DesignTokens.textLabelSmall.sp,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            icon: Icon(Icons.schedule_rounded, size: DesignTokens.iconSm),
          ),
          ButtonSegment(
            value: 1,
            label: Text('السابقة', style: TextStyle(fontSize: DesignTokens.textBodyMedium.sp)),
            icon: Icon(Icons.schedule_rounded, size: DesignTokens.iconSm),
          ),
        ],
        selected: {_selectedTab},
        onSelectionChanged: (selected) {
          setState(() => _selectedTab = selected.first);
        },
      ),
    );
  }

  Widget _buildOrdersList(List<Map<String, dynamic>> orders, {required bool isCurrent}) {
    if (orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isCurrent ? Icons.inbox_rounded : Icons.schedule_rounded,
              size: 64,
              color: AppTheme.textSecondary.withValues(alpha: 0.3),
            ),
            SizedBox(height: DesignTokens.space16),
            Text(
              isCurrent ? 'مفيش طلبات حالية' : 'مفيش طلبات سابقة',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: DesignTokens.textBodyLarge.sp,
              ),
            ),
            SizedBox(height: DesignTokens.space8),
            Text(
              isCurrent
                  ? 'اطلب خدمة وهتلاقي طلباتك هنا'
                  : 'لما تخلص طلباتك هتظهر هنا',
              style: TextStyle(
                color: AppTheme.textTertiary,
                fontSize: DesignTokens.textLabelMedium.sp,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadBookings,
      color: AppTheme.primaryColor,
      child: ListView.builder(
        padding: EdgeInsets.fromLTRB(
          DesignTokens.space20,
          0,
          DesignTokens.space20,
          100.h,
        ),
        itemCount: orders.length,
        itemBuilder: (context, index) =>
            _buildOrderCard(orders[index], context, isCurrent),
      ),
    );
  }

  Widget _buildOrderCard(
      Map<String, dynamic> order, BuildContext context, bool isCurrent) {
    final rawStatus = order['rawStatus'] as String;
    final statusColor = order['statusColor'] as Color;
    final isCompleted = rawStatus == 'completed';
    final hasReview = order['hasReview'] == true;

    return Semantics(
      label: 'تفاصيل الطلب',
      child: GestureDetector(
        onTap: () async {
          if (isCompleted && !hasReview) {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ReviewsScreen(
                  providerId: order['providerId'],
                  bookingId: order['id']?.toString(),
                ),
              ),
            );
            if (result == true) _loadBookings();
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => TrackingScreen(bookingId: order['id']),
              ),
            );
          }
        },
        child: Container(
          margin: EdgeInsets.only(bottom: DesignTokens.space14.h),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: DesignTokens.brLg,
            border: Border.all(
              color: isCurrent
                  ? statusColor.withValues(alpha: 0.15)
                  : AppTheme.textPrimary.withValues(alpha: 0.06),
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.textPrimary.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.all(DesignTokens.space16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: DesignTokens.space5.w,
                        vertical: DesignTokens.space3.h,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: DesignTokens.brXl,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            order['statusIcon'] as IconData,
                            size: 14,
                            color: statusColor,
                          ),
                          SizedBox(width: DesignTokens.space3.w),
                          Text(
                            order['status'] as String,
                            style: TextStyle(
                              fontSize: DesignTokens.textLabelMedium.sp,
                              fontWeight: FontWeight.bold,
                              color: statusColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      _formatDate(order['createdAt']),
                      style: TextStyle(
                        fontSize: DesignTokens.textLabelMedium.sp,
                        color: AppTheme.textTertiary,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: DesignTokens.space12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: DesignTokens.brLg,
                      child: SizedBox(
                        width: 72.w,
                        height: 72.w,
                        child: Image.network(
                          order['image'] as String,
                          fit: BoxFit.cover,
                          semanticLabel: 'صورة الخدمة',
                          errorBuilder: (_, __, ___) => Container(
                            color: AppTheme.primaryColor.withValues(alpha: 0.1),
                            child: Icon(
                              Icons.photo_rounded,
                              color: AppTheme.primaryColor,
                              size: 28,
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: DesignTokens.space14.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            order['title'] as String,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: DesignTokens.textBodyLarge.sp,
                              color: AppTheme.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: DesignTokens.space4),
                          Row(
                            children: [
                              Icon(
                                Icons.person_rounded,
                                size: 14,
                                color: AppTheme.textSecondary.withValues(alpha: 0.7),
                              ),
                              SizedBox(width: DesignTokens.space4),
                              Expanded(
                                child: Text(
                                  order['company'] as String,
                                  style: TextStyle(
                                    fontSize: DesignTokens.textLabelMedium.sp,
                                    color: AppTheme.textSecondary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: DesignTokens.space8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                order['price'] as String,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: DesignTokens.textBodyMedium.sp,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (order['providerId'] != null &&
                                      order['providerId'].toString().isNotEmpty &&
                                      isCurrent)
                                    _buildMiniButton(
                                      icon: Icons.chat_rounded,
                                      onTap: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => ChatScreen(
                                            partnerName: order['company'],
                                            partnerId: order['providerId'],
                                          ),
                                        ),
                                      ),
                                      semanticsLabel: 'فتح المحادثة',
                                    ),
                                  if (isCompleted && !hasReview)
                                    _buildMiniButton(
                                      icon: Icons.star_rounded,
                                      color: AppTheme.tertiaryColor,
                                      onTap: () async {
                                        final result = await Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => ReviewsScreen(
                                              providerId: order['providerId'],
                                              bookingId: order['id']?.toString(),
                                            ),
                                          ),
                                        );
                                        if (result == true) _loadBookings();
                                      },
                                      semanticsLabel: 'تقييم',
                                    ),
                                  if (isCompleted)
                                    _buildMiniButton(
                                      icon: Icons.flag_rounded,
                                      color: AppTheme.errorColor.withValues(alpha: 0.7),
                                      onTap: () => _showReportDialog(order),
                                      semanticsLabel: 'الإبلاغ',
                                    ),
                                ],
                              ),
                            ],
                          ),
                          if (order['offeredPrice'] != null) ...[
                            SizedBox(height: DesignTokens.space8),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: DesignTokens.space12.w,
                                vertical: DesignTokens.space8.h,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.tertiaryColor.withValues(alpha: 0.1),
                                borderRadius: DesignTokens.brMd,
                                border: Border.all(
                                  color: AppTheme.tertiaryColor.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.local_offer_rounded,
                                    color: AppTheme.tertiaryColor,
                                    size: 16,
                                  ),
                                  SizedBox(width: DesignTokens.space6.w),
                                  Expanded(
                                    child: Text(
                                      'عرض سعر: ${order['offeredPrice']} ج',
                                      style: TextStyle(
                                        color: AppTheme.tertiaryColor,
                                        fontSize: DesignTokens.textLabelMedium.sp,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                if (isCompleted && !hasReview)
                  Container(
                    margin: EdgeInsets.only(top: DesignTokens.space12),
                    padding: EdgeInsets.symmetric(
                      horizontal: DesignTokens.space12,
                      vertical: DesignTokens.space8,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.tertiaryColor.withValues(alpha: 0.08),
                      borderRadius: DesignTokens.brMd,
                      border: Border.all(
                        color: AppTheme.tertiaryColor.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.star_rounded,
                          color: AppTheme.tertiaryColor,
                          size: 18,
                        ),
                        SizedBox(width: DesignTokens.space8),
                        Expanded(
                          child: Text(
                            'قيّم تجربتك مع مقدم الخدمة',
                            style: TextStyle(
                              fontSize: DesignTokens.textLabelMedium.sp,
                              color: AppTheme.tertiaryColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () async {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ReviewsScreen(
                                  providerId: order['providerId'],
                                  bookingId: order['id']?.toString(),
                                ),
                              ),
                            );
                            if (result == true) _loadBookings();
                          },
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: DesignTokens.space12.w,
                              vertical: DesignTokens.space4.h,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.tertiaryColor,
                              borderRadius: DesignTokens.brMd,
                            ),
                            child: Text(
                              'تقييم',
                              style: TextStyle(
                                color: AppTheme.surfaceColor,
                                fontSize: DesignTokens.textLabelSmall.sp,
                                fontWeight: FontWeight.bold,
                              ),
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
      ),
    );
  }

  Widget _buildMiniButton({
    required IconData icon,
    required VoidCallback onTap,
    Color? color,
    String? semanticsLabel,
  }) {
    final btn = GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(DesignTokens.space8),
        margin: EdgeInsets.only(left: DesignTokens.space6.w),
        decoration: BoxDecoration(
          color: (color ?? AppTheme.primaryColor).withValues(alpha: 0.1),
          borderRadius: DesignTokens.brMd,
        ),
        child: Icon(
          icon,
          size: 18,
          color: color ?? AppTheme.primaryColor,
        ),
      ),
    );
    if (semanticsLabel != null) {
      return Semantics(label: semanticsLabel, child: btn);
    }
    return btn;
  }

  void _showReportDialog(Map<String, dynamic> order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(DesignTokens.radiusXl),
            topRight: Radius.circular(DesignTokens.radiusXl),
          ),
        ),
        child: AppReportBottomSheet(
          bookingId: order['id']?.toString(),
          providerId: order['providerId']?.toString(),
          reportedById: SupabaseService.currentUserId,
        ),
      ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr).toLocal();
      final now = DateTime.now();
      final diff = now.difference(date);
      if (diff.inDays == 0) return 'اليوم';
      if (diff.inDays == 1) return 'أمس';
      if (diff.inDays < 7) return 'منذ ${diff.inDays} أيام';
      return '${date.day}/${date.month}/${date.year}';
    } catch (_) {
      return '';
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'pending':
        return AppTheme.warningColor;
      case 'accepted':
        return AppTheme.infoColor;
      case 'on_the_way':
        return AppTheme.primaryColor;
      case 'arrived':
        return AppTheme.successColor;
      case 'in_progress':
        return AppTheme.tertiaryColor;
      case 'completed':
        return AppTheme.successColor;
      case 'cancelled':
        return AppTheme.errorColor;
      case 'rejected':
        return AppTheme.errorColor;
      default:
        return AppTheme.textSecondary;
    }
  }

  String _statusText(String status) {
    switch (status) {
      case 'pending':
        return 'منتظر القبول';
      case 'accepted':
        return 'تم القبول';
      case 'on_the_way':
        return 'في الطريق';
      case 'arrived':
        return 'وصل عندك';
      case 'in_progress':
        return 'جاري التنفيذ';
      case 'completed':
        return 'مكتمل';
      case 'cancelled':
        return 'ملغي';
      case 'rejected':
        return 'مرفوض';
      default:
        return status;
    }
  }
}
