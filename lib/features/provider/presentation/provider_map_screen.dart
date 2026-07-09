import 'package:flutter/material.dart';
import 'package:flutter/material.dart' show MaterialPageRoute;
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/services/supabase_service.dart';
import 'provider_order_detail_screen.dart';

class ProviderMapScreen extends StatefulWidget {
  const ProviderMapScreen({super.key});

  @override
  State<ProviderMapScreen> createState() => _ProviderMapScreenState();
}

class _ProviderMapScreenState extends State<ProviderMapScreen> {
  List<Map<String, dynamic>> _requests = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() => _isLoading = true);
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) return;

      // Load nearby delivery requests
      final requests = await SupabaseService.db
          .from('bookings')
          .select('*, services(*), profiles(full_name, phone)')
          .eq('provider_id', userId)
          .inFilter('status', ['accepted', 'on_the_way', 'arrived']).order(
              'created_at',
              ascending: false);

      if (mounted) {
        setState(() {
          _requests = List<Map<String, dynamic>>.from(requests);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading requests: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(backgroundColor: AppTheme.backgroundColor, body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _requests.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.map_rounded,
                        size: 80.sp,
                        color: AppTheme.textSecondary,
                      ),
                      SizedBox(height: DesignTokens.space16),
                      Text(
                        'لا توجد طلبات نشطة',
                        style: TextStyle(
                          fontSize: DesignTokens.textTitleMedium,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      SizedBox(height: DesignTokens.space8),
                      Text(
                        'ستظهر الطلبات النشطة هنا',
                        style: TextStyle(
                          fontSize: DesignTokens.textLabelMedium,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                )
              : FlutterMap(
                  options: MapOptions(
                    initialCenter: const LatLng(30.0444, 31.2357), // Cairo center
                    initialZoom: 13.0,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.faster',
                    ),
                    MarkerLayer(
                      markers: _buildMarkers(),
                    ),
                  ],
                ),
    );
  }

  List<Marker> _buildMarkers() {
    final markers = <Marker>[];

    for (final request in _requests) {
      final lat = request['client_lat'] as double?;
      final lng = request['client_lng'] as double?;

      if (lat != null && lng != null) {
        markers.add(
          Marker(
            point: LatLng(lat, lng),
            width: 40.w,
            height: 40.h,
            child: GestureDetector(
              onTap: () => _showRequestDetails(request),
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withValues(alpha: 0.5),
                      blurRadius: 5,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.location_on_rounded,
                  color: Colors.white,
                  size: 24.sp,
                ),
              ),
            ),
          ),
        );
      }
    }

    return markers;
  }

  void _showRequestDetails(Map<String, dynamic> request) {
    final service = request['services'] as Map<String, dynamic>?;
    final client = request['profiles'] as Map<String, dynamic>?;
    final status = request['status'] as String?;
    final address = request['address'] as String? ?? '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.85,
        expand: false,
        builder: (_, controller) => Container(
          padding: const EdgeInsets.all(DesignTokens.space24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'تفاصيل الطلب',
                    style: TextStyle(
                      fontSize: DesignTokens.textTitleLarge,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(10, 10),
                    ),
                    child: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              SizedBox(height: DesignTokens.space16),
              _buildDetailRow('الخدمة', service?['name'] ?? ''),
              SizedBox(height: DesignTokens.space8),
              _buildDetailRow('العميل', client?['full_name'] ?? ''),
              SizedBox(height: DesignTokens.space8),
              _buildDetailRow('العنوان', address),
              SizedBox(height: DesignTokens.space8),
              _buildDetailRow('الحالة', _getStatusText(status ?? '')),
              SizedBox(height: DesignTokens.space24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProviderOrderDetailScreen(booking: request),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: DesignTokens.space12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DesignTokens.radiusLg)),
                  ),
                  child: const Text('عرض التفاصيل الكاملة'),
                ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100.w,
          child: Text(
            label,
            style: TextStyle(
              fontSize: DesignTokens.textLabelMedium,
              color: AppTheme.textSecondary,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: DesignTokens.textLabelMedium,
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'accepted':
        return 'مقبول';
      case 'on_the_way':
        return 'في الطريق';
      case 'arrived':
        return 'وصل';
      case 'in_progress':
        return 'جاري التنفيذ';
      default:
        return status;
    }
  }
}
