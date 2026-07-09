import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/location_service.dart';
import 'delivery_active_screen.dart';

/// Delivery Orders Screen
/// Shows nearby restaurant/shop orders ready for pickup.
/// Calculates delivery fee based on distance and applies smart pricing rules.
class DeliveryOrdersScreen extends StatefulWidget {
  const DeliveryOrdersScreen({super.key});

  @override
  State<DeliveryOrdersScreen> createState() => _DeliveryOrdersScreenState();
}

class _DeliveryOrdersScreenState extends State<DeliveryOrdersScreen> {
  List<Map<String, dynamic>> _orders = [];
  bool _isLoading = true;
  LatLng? _currentLocation;
  String? _error;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _captureLocation();
    _refreshTimer = Timer.periodic(const Duration(seconds: 20), (_) => _loadOrders());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _captureLocation() async {
    try {
      final pos = await LocationService.getPreciseLatLng();
      if (pos != null && mounted) {
        setState(() => _currentLocation = LatLng(pos.latitude, pos.longitude));
        _loadOrders();
      }
    } catch (e) {
      debugPrint('Error capturing location: $e');
    }
  }

  Future<void> _loadOrders() async {
    if (_currentLocation == null) return;
    try {
      final result = await SupabaseService.db.rpc(
        'find_nearby_delivery_orders',
        params: {
          'p_delivery_lat': _currentLocation!.latitude,
          'p_delivery_lng': _currentLocation!.longitude,
          'p_max_distance_km': 8.0,
        },
      );
      if (!mounted) return;
      setState(() {
        _orders = List<Map<String, dynamic>>.from(result ?? []);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading delivery orders: $e');
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _acceptOrder(String orderId) async {
    final uid = SupabaseService.currentUserId;
    if (uid == null) return;
    try {
      final result = await SupabaseService.db
          .from('bookings')
          .update({
            'delivery_provider_id': uid,
            'status': 'accepted',
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', orderId)
          .eq('status', 'ready')
          .select()
          .singleOrNull();

      if (result != null && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => DeliveryActiveScreen(orderId: orderId)),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('الطلب تم قبوله من مندوب آخر'),
            backgroundColor: AppTheme.warningColor,
          ),
        );
        _loadOrders();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: AppTheme.errorColor),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('طلبات التوصيل'),
        backgroundColor: AppTheme.backgroundColor,
        elevation: 0,
        centerTitle: true,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadOrders,
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? _buildErrorWidget()
                  : _orders.isEmpty
                      ? _buildEmptyWidget()
                      : _buildOrdersList(),
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: AppTheme.errorColor),
          SizedBox(height: 16.h),
          Text(_error!),
          SizedBox(height: 16.h),
          ElevatedButton(onPressed: _loadOrders, child: const Text('إعادة المحاولة')),
        ],
      ),
    );
  }

  Widget _buildEmptyWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.delivery_dining_outlined, size: 64, color: AppTheme.textTertiary.withValues(alpha: 0.4)),
          SizedBox(height: 16.h),
          Text(
            'لا توجد طلبات توصيل حالياً',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
          ),
          SizedBox(height: 8.h),
          Text(
            'سنخبرك عند توفر طلبات قريبة منك',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildOrdersList() {
    return ListView.builder(
      padding: EdgeInsets.all(DesignTokens.space16.w),
      itemCount: _orders.length,
      itemBuilder: (context, index) => _buildOrderCard(_orders[index]),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final seller = order['seller'] as Map<String, dynamic>?;
    final sellerName = seller?['full_name'] ?? 'متجر';
    final sellerAddress = seller?['address'] ?? 'عنوان غير معروف';
    final customerAddress = order['customer_address'] ?? 'عنوان العميل';
    final distance = double.tryParse(order['distance_km']?.toString() ?? '0') ?? 0;
    final itemsTotal = double.tryParse(order['items_total']?.toString() ??NU) ?? 0;
    final deliveryFee = double.tryParse(order['delivery_fee']?.toString() ?? '0') ?? 0;
    final total = double.tryParse(order['total_price']?.toString() ?? '0') ?? 0;
    final feeType = order['fee_type'] ?? 'normal';
    final feeNotes = order['fee_notes'] ?? '';

    return Card(
      margin: EdgeInsets.only(bottom: DesignTokens.space12.h),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: DesignTokens.brLg),
      child: Padding(
        padding: EdgeInsets.all(DesignTokens.space16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    sellerName,
                    style: TextStyle(
                      fontSize: DesignTokens.textTitleMedium.sp,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: AppTheme.successColor.withValues(alpha: 0.1),
                    borderRadius: DesignTokens.brSm,
                  ),
                  child: Text(
                    '${distance.toStringAsFixed(1)} كم',
                    style: TextStyle(fontSize: DesignTokens.textBodySmall.sp, color: AppTheme.successColor, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            SizedBox(height: DesignTokens.space6.h),
            Text('📍 $sellerAddress', style: TextStyle(color: AppTheme.textSecondary, fontSize: DesignTokens.textBodySmall.sp)),
            SizedBox(height: DesignTokens.space2.h),
            Text('🏠 $customerAddress', style: TextStyle(color: AppTheme.textSecondary, fontSize: DesignTokens.textBodySmall.sp)),
            SizedBox(height: DesignTokens.space8.h),

            // Smart fee info
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(DesignTokens.space10.w),
              decoration: BoxDecoration(
                color: feeType == 'free_delivery' ? AppTheme.successColor.withValues(alpha: 0.08) : AppTheme.backgroundColor,
                borderRadius: DesignTokens.brMd,
                border: Border.all(color: feeType == 'free_delivery' ? AppTheme.successColor.withValues(alpha: 0.3) : Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('المبلغ',
                        style: TextStyle(fontSize: DesignTokens.textBodySmall.sp, color: AppTheme.textSecondary),
                      ),
                      Text(
                        '${itemsTotal.toStringAsFixed(0)} ج.م',
                        style: TextStyle(fontSize: DesignTokens.textBodyMedium.sp, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  SizedBox(height: DesignTokens.space2.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('رسوم التوصيل', style: TextStyle(fontSize: DesignTokens.textBodySmall.sp, color: AppTheme.textSecondary)),
                      Text(
                        feeType == 'free_delivery' ? 'مجاني 🎉' : '${deliveryFee.toStringAsFixed(0)} ج.م',
                        style: TextStyle(
                          fontSize: DesignTokens.textBodyMedium.sp,
                          fontWeight: FontWeight.bold,
                          color: feeType == 'free_delivery' ? AppTheme.successColor : AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  if (feeNotes.isNotEmpty) ...[
                    SizedBox(height: DesignTokens.space2.h),
                    Text(
                      feeNotes,
                      style: TextStyle(fontSize: DesignTokens.textLabelSmall.sp, color: AppTheme.textSecondary, fontStyle: FontStyle.italic),
                    ),
                  ],
                  Divider(height: 8.h, thickness: 1, color: AppTheme.textTertiary.withValues(alpha: 0.1)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('الإجمالي', style: TextStyle(fontSize: DesignTokens.textBodyMedium.sp, fontWeight: FontWeight.bold)),
                      Text('${total.toStringAsFixed(0)} ج.م', style: TextStyle(fontSize: DesignTokens.textTitleSmall.sp, fontWeight: FontWeight.bold, color: AppTheme.successColor)),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: DesignTokens.space8.h),
            SizedBox(
              width: double.infinity,
              height: DesignTokens.buttonHeight + 4,
              child: ElevatedButton.icon(
                onPressed: () => _acceptOrder(order['id'].toString()),
                icon: const Icon(Icons.check_circle_outline_rounded, color: Colors.white),
                label: const Text('قبول الطلب', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.successColor, shape: RoundedRectangleBorder(borderRadius: DesignTokens.brLg)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
