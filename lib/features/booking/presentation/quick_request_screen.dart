import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/location_service.dart';
import 'tracking_screen.dart';

class QuickRequestScreen extends StatefulWidget {
  final int serviceId;
  final String serviceTitle;

  const QuickRequestScreen({
    super.key,
    required this.serviceId,
    required this.serviceTitle,
  });

  @override
  State<QuickRequestScreen> createState() => _QuickRequestScreenState();
}

class _QuickRequestScreenState extends State<QuickRequestScreen> with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();
  LatLng? _userLocation;
  bool _isLoadingLocation = true;
  bool _isSearching = false;
  String? _requestId;
  RealtimeChannel? _realtimeChannel;
  Timer? _requestTimeoutTimer;

  // Radar Animation
  late AnimationController _radarController;

  @override
  void initState() {
    super.initState();
    _getUserLocation();
    _radarController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
  }

  @override
  void dispose() {
    _radarController.dispose();
    _requestTimeoutTimer?.cancel();
    _cancelRequest(silent: true);
    super.dispose();
  }

  Future<void> _getUserLocation() async {
    try {
      final pos = await LocationService.getCurrentPosition();
      if (!mounted) return;
      if (pos != null) {
        setState(() {
          _userLocation = LatLng(pos.latitude, pos.longitude);
          _isLoadingLocation = false;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            try {
              _mapController.move(_userLocation!, 15);
            } catch (_) {}
          }
        });
      } else {
        setState(() {
          _userLocation = const LatLng(30.0444, 31.2357); // Cairo
          _isLoadingLocation = false;
        });
      }
    } catch (e) {
      debugPrint('Error getting location: $e');
      if (!mounted) return;
      setState(() {
        _userLocation = const LatLng(30.0444, 31.2357);
        _isLoadingLocation = false;
      });
    }
  }

  Future<void> _startRequest() async {
    if (_userLocation == null) return;
    final userId = SupabaseService.currentUserId;
    if (userId == null) {
      if (mounted) _showCupertinoAlert('يجب تسجيل الدخول أولاً');
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      // Resolve address in background or fetch it first
      String requestAddress = 'طلب فوري مباشر';
      try {
        requestAddress = await LocationService.getAddressFromLatLng(_userLocation!);
      } catch (_) {}

      // Create request in DB
      final response = await SupabaseService.db.from('service_requests').insert({
        'client_id': userId,
        'service_id': widget.serviceId,
        'lat': _userLocation!.latitude,
        'lng': _userLocation!.longitude,
        'address': requestAddress,
        'status': 'pending',
      }).select().single();

      _requestId = response['id'];
      _requestTimeoutTimer?.cancel();
      _requestTimeoutTimer = Timer(const Duration(seconds: 90), () async {
        if (!mounted || !_isSearching || _requestId == null) return;
        await _cancelRequest(silent: true);
        if (!mounted) return;
        setState(() {
          _isSearching = false;
          _requestId = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لا يوجد مقدم خدمة قريب متاح الآن، حاول مرة أخرى.')),
        );
      });

      // Listen for acceptance
      _realtimeChannel = SupabaseService.client
          .channel('public:service_requests:id=eq.$_requestId')
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'service_requests',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'id',
              value: _requestId!,
            ),
            callback: (payload) {
              final newRecord = payload.newRecord;
              if (newRecord['status'] == 'accepted' && newRecord['accepted_provider_id'] != null) {
                _onProviderAccepted(newRecord['accepted_provider_id']);
              }
            },
          )
          .subscribe();

    } catch (e) {
      debugPrint('Request Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('حدث خطأ أثناء إرسال الطلب')));
      }
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  Future<void> _onProviderAccepted(String providerId) async {
    // The provider creates the formal booking before updating the request status.
    // We just need to fetch it to get the bookingId.
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) return;
      
      // Add a small delay to ensure the provider's booking insert is fully committed
      await Future.delayed(const Duration(milliseconds: 500));

      final bookingRes = await SupabaseService.db
          .from('bookings')
          .select()
          .eq('client_id', userId)
          .eq('provider_id', providerId)
          .eq('status', 'accepted')
          .order('created_at', ascending: false)
          .limit(1)
          .single();

      // Cancel the realtime listener
      _requestTimeoutTimer?.cancel();
      await _realtimeChannel?.unsubscribe();
      
      if (!mounted) return;
      
      // Navigate to tracking
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => TrackingScreen(bookingId: bookingRes['id']),
        ),
      );
    } catch (e) {
      debugPrint('Error fetching booking: $e');
      // Retry once if not found
      await Future.delayed(const Duration(seconds: 1));
      try {
        final userId = SupabaseService.currentUserId;
        final bookingRes = await SupabaseService.db
            .from('bookings')
            .select()
            .eq('client_id', userId!)
            .eq('provider_id', providerId)
            .eq('status', 'accepted')
            .order('created_at', ascending: false)
            .limit(1)
            .single();
            
        await _realtimeChannel?.unsubscribe();
        _requestTimeoutTimer?.cancel();
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => TrackingScreen(bookingId: bookingRes['id']),
            ),
          );
        }
      } catch (retryError) {
        debugPrint('Retry failed: $retryError');
      }
    }
  }

  void _showCupertinoAlert(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(message),
        actions: [
          TextButton(
            child: const Text('حسناً'),
            onPressed: () => Navigator.pop(ctx),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelRequest({bool silent = false}) async {
    if (_requestId != null) {
      try {
        _requestTimeoutTimer?.cancel();
        await SupabaseService.client.channel('public:service_requests:id=eq.$_requestId').unsubscribe();
        await SupabaseService.db.from('service_requests').update({'status': 'cancelled'}).eq('id', _requestId!);
      } catch (e) {
        debugPrint('Cancel error: $e');
      }
    }
    if (!silent && mounted) {
      setState(() {
        _isSearching = false;
        _requestId = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(backgroundColor: AppTheme.backgroundColor, body: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!_isSearching) ...[
                        Text(
                          'حدد موقعك بدقة على الخريطة',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: DesignTokens.textTitleSmall,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        SizedBox(height: DesignTokens.space8),
                        Text(
                          'سيتم إرسال طلبك لأقرب مزودي الخدمة المتاحين حالياً وسيتم إخبارك فور قبول أحدهم للطلب.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppTheme.textPrimary.withOpacity(0.7),
                            fontSize: DesignTokens.textBodySmall,
                          ),
                        ),
                        SizedBox(height: DesignTokens.space24),
                        SizedBox(
                          width: double.infinity,
                          height: 56.h,
                          child: ElevatedButton(
                            onPressed: _startRequest,
                            borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
                            color: AppTheme.primaryColor,
                            child: const Text(
                              'اطلب الآن',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ] else ...[
                        const CircularProgressIndicator(),
                        SizedBox(height: DesignTokens.space16),
                        Text(
                          'جاري البحث عن أقرب الفنيين...',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: DesignTokens.textTitleMedium,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        SizedBox(height: DesignTokens.space8),
                        Text(
                          'الرجاء الانتظار، سيتم تأكيد طلبك قريباً',
                          style: TextStyle(
                            color: AppTheme.textPrimary.withOpacity(0.7),
                          ),
                        ),
                        SizedBox(height: DesignTokens.space24),
                        ElevatedButton(
                          onPressed: () => _cancelRequest(),
                          borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
                          color: Colors.white,
                          child: Text(
                            'إلغاء الطلب',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.errorColor,
                              fontSize: DesignTokens.textBodyLarge,
                            ),
                          ),
                        ),
                      ]
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRadarAnimation() {
    return AnimatedBuilder(
      animation: _radarController,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 150 * _radarController.value,
              height: 150 * _radarController.value,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primaryColor.withOpacity(0.3 * (1 - _radarController.value)),
                border: Border.all(
                  color: AppTheme.primaryColor.withOpacity(0.5 * (1 - _radarController.value)),
                  width: 2,
                ),
              ),
            ),
            Icon(Icons.location_on_rounded, color: AppTheme.primaryColor, size: 40),
          ],
        );
      },
    );
  }
}
