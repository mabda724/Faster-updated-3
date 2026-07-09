import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/services/supabase_service.dart';
import 'ride_request_screen.dart';
import 'ride_tracking_screen.dart';

class RideWaitingScreen extends StatefulWidget {
  final String bookingId;
  final double totalPrice;
  final double distanceKm;
  final String vehicleType;
  final String pickupAddress;
  final String destinationAddress;

  const RideWaitingScreen({
    super.key,
    required this.bookingId,
    required this.totalPrice,
    required this.distanceKm,
    required this.vehicleType,
    required this.pickupAddress,
    required this.destinationAddress,
  });

  @override
  State<RideWaitingScreen> createState() => _RideWaitingScreenState();
}

class _RideWaitingScreenState extends State<RideWaitingScreen> {
  bool _isSearching = true;
  bool _driverFound = false;
  Map<String, dynamic>? _driverData;
  Map<String, dynamic>? _lastBooking;
  String? _error;

  @override
  void initState() {
    super.initState();
    _listenForDriver();
    _loadBooking();
  }

  Future<void> _loadBooking() async {
    try {
      final data = await SupabaseService.db
          .from('bookings')
          .select()
          .eq('id', widget.bookingId)
          .single();
      if (mounted) setState(() => _lastBooking = data);
    } catch (_) {}
  }

  void _listenForDriver() {
    _sub = SupabaseService.db
        .from('bookings')
        .stream(primaryKey: ['id'])
        .eq('id', widget.bookingId)
        .listen((data) {
      if (data.isEmpty || !mounted) return;
      final booking = data.first;
      setState(() {
        _lastBooking = booking;
        _isSearching = booking['status'] == 'pending' || booking['status'] == null;
        final driverId = booking['provider_id'];
        if (driverId != null && !_driverFound) {
          _driverFound = true;
          _isSearching = false;
          _loadDriverInfo(driverId);
        }
        if (booking['status'] == 'cancelled') {
          _error = 'تم إلغاء الطلب. لا يوجد سائق متاح في الوقت الحالي.';
          _isSearching = false;
        }
      });
    });
  }

  Future<void> _loadDriverInfo(String driverId) async {
    try {
      final profile = await SupabaseService.db
          .from('profiles')
          .select('full_name, phone')
          .eq('id', driverId)
          .maybeSingle();
      if (mounted) setState(() => _driverData = profile);
    } catch (_) {}
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }

  late final StreamSubscription<List<Map<String, dynamic>>> _sub;

  Future<void> _callDriver() async {
    if (_driverData == null) return;
    final phone = _driverData!['phone']?.toString();
    if (phone == null || phone.isEmpty) return;
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWaiting = _isSearching && !_driverFound;
    final isDriverFound = _driverFound;
    final isCancelled = _lastBooking?['status'] == 'cancelled';

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceColor,
        elevation: 0,
        centerTitle: true,
        title: Text(
          isWaiting ? 'جاري البحث عن سائق...' : isCancelled ? 'تم الإلغاء' : 'تم العثور على سائق',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: DesignTokens.textTitleSmall,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.close_rounded, color: AppTheme.textPrimary),
          tooltip: 'إغلاق',
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(DesignTokens.space24),
          child: Column(
            children: [
              SizedBox(height: 20.h),
              // Animated icon
              if (isWaiting)
                _PulsingIcon(
                  icon: Icons.search_rounded,
                  color: AppTheme.primaryColor,
                  size: 72,
                ),
              if (isDriverFound)
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.primaryColor.withValues(alpha: 0.12),
                        AppTheme.primaryColor.withValues(alpha: 0.03),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: DesignTokens.brFull,
                    border: Border.all(
                      color: AppTheme.primaryColor.withValues(alpha: 0.18),
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    Icons.person_rounded,
                    size: 56,
                    color: AppTheme.primaryColor,
                  ),
                ),
              if (isCancelled)
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: AppTheme.errorColor.withValues(alpha: 0.08),
                    borderRadius: DesignTokens.brFull,
                    border: Border.all(
                      color: AppTheme.errorColor.withValues(alpha: 0.15),
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    Icons.cancel_rounded,
                    size: 56,
                    color: AppTheme.errorColor,
                  ),
                ),
              SizedBox(height: DesignTokens.space24),
              if (isWaiting)
                Text(
                  'نبحث عن أقرب سائق إليك...',
                  style: TextStyle(
                    fontSize: DesignTokens.textTitleSmall,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
              if (isDriverFound && _driverData != null)
                Text(
                  _driverData!['full_name'] ?? 'سائق',
                  style: TextStyle(
                    fontSize: DesignTokens.textTitleMedium,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
              if (isCancelled)
                Text(
                  'تم إلغاء الطلب',
                  style: TextStyle(
                    fontSize: DesignTokens.textTitleMedium,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.errorColor,
                  ),
                ),
              SizedBox(height: DesignTokens.space8),
              if (isWaiting)
                Text(
                  'سيتم إشعارك فور العثور على سائق',
                  style: TextStyle(
                    fontSize: DesignTokens.textBodySmall,
                    color: AppTheme.textSecondary,
                  ),
                ),
              if (isDriverFound && _driverData != null)
                Text(
                  'السائق في الطريق إليك',
                  style: TextStyle(
                    fontSize: DesignTokens.textBodySmall,
                    color: AppTheme.successColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              if (isCancelled && _error != null)
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: DesignTokens.space8),
                  child: Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: DesignTokens.textBodySmall,
                      color: AppTheme.errorColor,
                    ),
                  ),
                ),
              SizedBox(height: DesignTokens.space24),

              // Price summary
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(DesignTokens.space16),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceColor.withValues(alpha: 0.92),
                  borderRadius: DesignTokens.brLg,
                  border: Border.all(
                    color: AppTheme.textPrimary.withValues(alpha: 0.06),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'سعر الرحلة',
                          style: TextStyle(
                            fontSize: DesignTokens.textBodySmall,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        Text(
                          '${widget.totalPrice.toStringAsFixed(0)} جنيه',
                          style: TextStyle(
                            fontSize: DesignTokens.textTitleSmall,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: DesignTokens.space4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'المسافة',
                          style: TextStyle(
                            fontSize: DesignTokens.textBodySmall,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        Text(
                          '${widget.distanceKm.toStringAsFixed(1)} كم',
                          style: TextStyle(
                            fontSize: DesignTokens.textBodyMedium,
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    if (widget.vehicleType == 'car')
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'النوع',
                            style: TextStyle(
                              fontSize: DesignTokens.textBodySmall,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: DesignTokens.space4,
                              vertical: DesignTokens.space1,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor
                                  .withValues(alpha: 0.08),
                              borderRadius: DesignTokens.brSm,
                            ),
                            child: Text(
                              'سيارة',
                              style: TextStyle(
                                fontSize: DesignTokens.textLabelSmall,
                                color: AppTheme.primaryColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              SizedBox(height: DesignTokens.space24),
              if (isDriverFound && _driverData != null) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _callDriver,
                    icon: Icon(Icons.phone_rounded,
                        color: AppTheme.surfaceColor),
                    label: Text(
                      'اتصل بالسائق',
                      style: TextStyle(
                        color: AppTheme.surfaceColor,
                        fontWeight: FontWeight.bold,
                        fontSize: DesignTokens.textBodyMedium,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      shadowColor:
                          AppTheme.primaryColor.withValues(alpha: 0.25),
                      elevation: 2,
                      padding: EdgeInsets.symmetric(
                        vertical: DesignTokens.space14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: DesignTokens.brLg,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: DesignTokens.space12),
                TextButton(
                  onPressed: () {
                    if (_lastBooking == null) return;
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RideTrackingScreen(
                          bookingId: widget.bookingId,
                          totalPrice: widget.totalPrice,
                          distanceKm: widget.distanceKm,
                          vehicleType: widget.vehicleType,
                          pickupAddress: widget.pickupAddress,
                          destinationAddress: widget.destinationAddress,
                        ),
                      ),
                    );
                  },
                  child: Text(
                    'عرض التتبع',
                    style: TextStyle(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
              if (isWaiting) ...[
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.errorColor,
                      side: BorderSide(
                        color: AppTheme.errorColor.withValues(alpha: 0.3),
                      ),
                      padding: EdgeInsets.symmetric(
                        vertical: DesignTokens.space14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: DesignTokens.brLg,
                      ),
                    ),
                    child: Text(
                      'إلغاء البحث',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: DesignTokens.textBodyMedium,
                      ),
                    ),
                  ),
                ),
              ],
              if (isCancelled) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      shadowColor:
                          AppTheme.primaryColor.withValues(alpha: 0.25),
                      elevation: 2,
                      padding: EdgeInsets.symmetric(
                        vertical: DesignTokens.space14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: DesignTokens.brLg,
                      ),
                    ),
                    child: Text(
                      'العودة',
                      style: TextStyle(
                        color: AppTheme.surfaceColor,
                        fontWeight: FontWeight.bold,
                        fontSize: DesignTokens.textBodyMedium,
                      ),
                    ),
                  ),
                ),
              ],
              SizedBox(height: DesignTokens.space32),
            ],
          ),
        ),
      ),
    );
  }
}

// -------------------------------------------------------------------
// Pulsing search icon
// -------------------------------------------------------------------

class _PulsingIcon extends StatefulWidget {
  final IconData icon;
  final Color color;
  final double size;

  const _PulsingIcon({
    required this.icon,
    required this.color,
    required this.size,
  });

  @override
  State<_PulsingIcon> createState() => _PulsingIconState();
}

class _PulsingIconState extends State<_PulsingIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _scale = Tween<double>(begin: 0.95, end: 1.08).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _opacity = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scale.value,
          child: Opacity(
            opacity: _opacity.value,
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    widget.color.withValues(alpha: 0.15),
                    widget.color.withValues(alpha: 0.03),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(widget.size / 2),
              ),
              child: Icon(widget.icon, size: widget.size * 0.55, color: widget.color),
            ),
          ),
        );
      },
    );
  }
}
