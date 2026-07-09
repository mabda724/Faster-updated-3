import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/services/document_deadline_service.dart';
import '../../../core/services/compass_service.dart';
import '../../../core/services/supabase_service.dart';
import 'driver_dashboard_screen.dart';
import 'driver_history_screen.dart';
import 'driver_ride_requests_screen.dart';
import '../../provider/presentation/provider_orders_screen.dart';
import '../../provider/presentation/provider_wallet_screen.dart';
import '../../provider/presentation/partner_profile_screen.dart';
import '../../provider/presentation/provider_map_screen.dart';
import '../../provider/presentation/partner_document_upload_screen.dart';

class _NavItem {
  final IconData icon;
  final String label;
  final int index;
  const _NavItem(this.icon, this.label, this.index);
}

class DriverNavScreen extends StatefulWidget {
  const DriverNavScreen({super.key});
  @override
  State<DriverNavScreen> createState() => _DriverNavScreenState();
}

class _DriverNavScreenState extends State<DriverNavScreen> {
  int _idx = 0;

  // Document deadline state
  bool _showDeadlineBanner = false;
  int _daysRemaining = 0;
  bool _isExpired = false;
  bool _isBanned = false;

  final List<_NavItem> _navItems = const [
    _NavItem(Icons.dashboard_rounded, 'الرئيسية', 0),
    _NavItem(Icons.receipt_long_rounded, 'الطلبات', 1),
    _NavItem(Icons.local_taxi_rounded, 'المشاوير', 2),
    _NavItem(Icons.map_rounded, 'الخريطة', 3),
    _NavItem(Icons.account_balance_wallet_rounded, 'المحفظة', 4),
    _NavItem(Icons.person_rounded, 'حسابي', 5),
  ];

  List<Widget> get _screens => const [
        DriverDashboardScreen(),
        ProviderOrdersScreen(),
        DriverRideRequestsScreen(),
        ProviderMapScreen(),
        ProviderWalletScreen(),
        PartnerProfileScreen(),
      ];

  @override
  void initState() {
    super.initState();
    _checkDocumentDeadline();
    _startLocationTrackingIfNeeded();
  }

  Future<void> _startLocationTrackingIfNeeded() async {
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) return;
      final providerData = await SupabaseService.db
          .from('provider_profiles')
          .select('is_online')
          .eq('id', userId)
          .maybeSingle();
      if (providerData != null && providerData['is_online'] == true) {
        final activeOrders = await SupabaseService.db
            .from('bookings')
            .select('id')
            .eq('provider_id', userId)
            .inFilter('status', ['accepted', 'on_the_way', 'arrived', 'in_progress'])
            .limit(1);
        if (activeOrders.isNotEmpty) {
          CompassService.startTracking();
        }
      }
    } catch (e) {
      debugPrint('Error checking driver status: $e');
    }
  }

  Future<void> _checkDocumentDeadline() async {
    final result = await DocumentDeadlineService.checkDeadline();
    if (mounted) {
      setState(() {
        _showDeadlineBanner = result['needsUpload'] == true;
        _daysRemaining = result['daysRemaining'] as int? ?? 0;
        _isExpired = result['isExpired'] == true;
        _isBanned = _isExpired && result['isDocumentComplete'] != true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          if (_showDeadlineBanner) _buildDeadlineBanner(),
          Expanded(child: _screens[_idx]),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildDeadlineBanner() {
    final Color bgColor;
    final Color textColor;
    final IconData icon;
    final String message;

    if (_isBanned) {
      bgColor = AppTheme.errorColor.withValues(alpha: 0.08);
      textColor = AppTheme.errorColor;
      icon = Icons.block;
      message = 'تم حظر حسابك بسبب عدم رفع الوثائق المطلوبة. تواصل مع الدعم.';
    } else if (_isExpired) {
      bgColor = AppTheme.errorColor.withValues(alpha: 0.08);
      textColor = AppTheme.errorColor;
      icon = Icons.warning_amber_rounded;
      message = 'انتهت المهلة! يرجى رفع الوثائق فوراً لتجنب حظر الحساب.';
    } else if (_daysRemaining <= 3) {
      bgColor = AppTheme.tertiaryColor.withValues(alpha: 0.08);
      textColor = AppTheme.tertiaryColor;
      icon = Icons.timer;
      message = 'تبقى $_daysRemaining أيام فقط لرفع الوثائق المطلوبة!';
    } else {
      bgColor = AppTheme.primaryColor.withValues(alpha: 0.05);
      textColor = AppTheme.primaryColor;
      icon = Icons.info_outline;
      message = 'يرجى رفع الوثائق خلال $_daysRemaining يوم لإكمال تفعيل الحساب.';
    }

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => PartnerDocumentUploadScreen()),
      ),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        margin: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
        decoration: BoxDecoration(
          color: bgColor,
          border: Border(bottom: BorderSide(color: textColor.withValues(alpha: 0.2))),
        ),
        child: Row(children: [
          Icon(icon, color: textColor, size: 20),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(message,
                style: TextStyle(
                  color: textColor,
                  fontSize: DesignTokens.textBodySmall,
                  fontWeight: FontWeight.bold,
                )),
          ),
          Icon(Icons.arrow_forward_ios, color: textColor, size: DesignTokens.iconSm),
        ]),
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      height: 70.h + MediaQuery.of(context).padding.bottom,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.darkBackgroundColor, AppTheme.darkSurfaceColor, AppTheme.primaryColor],
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
        ),
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(DesignTokens.radius2xl),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: _navItems
              .map((item) => _buildNavItem(item.icon, item.label, item.index))
              .toList(),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int idx) {
    final isSelected = _idx == idx;
    return GestureDetector(
      onTap: () => setState(() => _idx = idx),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 4.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.5),
              size: 22.w,
            ),
            SizedBox(height: 2.h),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.5),
                  fontSize: 10.sp,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w400,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    CompassService.stopTracking();
    super.dispose();
  }
}
