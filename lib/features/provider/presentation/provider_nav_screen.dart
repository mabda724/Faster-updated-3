import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/services/document_deadline_service.dart';
import '../../../core/services/compass_service.dart';
import '../../../core/services/supabase_service.dart';
import 'provider_dashboard_screen.dart';
import 'provider_orders_screen.dart';
import 'provider_wallet_screen.dart';
import 'provider_profile_screen.dart';
import 'partner_document_upload_screen.dart';
import 'provider_products_screen.dart';
import 'provider_map_screen.dart';
import 'provider_schedule_screen.dart';

class _NavItem {
  final IconData icon;
  final String label;
  final int index;

  _NavItem(this.icon, this.label, this.index);
}

class ProviderNavScreen extends StatefulWidget {
  const ProviderNavScreen({super.key});
  @override
  State<ProviderNavScreen> createState() => _ProviderNavScreenState();
}

class _ProviderNavScreenState extends State<ProviderNavScreen> {
  int _idx = 0;
  String? _providerType;
  List<Widget> _screens = [];
  List<_NavItem> _navItems = [];

  // Document deadline state
  bool _showDeadlineBanner = false;
  int _daysRemaining = 0;
  bool _isExpired = false;
  bool _isBanned = false;

  @override
  void initState() {
    super.initState();
    _initializeDefaultScreens();
    _loadProviderType();
    _checkDocumentDeadline();
    // Start location tracking if provider is online
    _startLocationTrackingIfNeeded();
  }

  Future<void> _loadProviderType() async {
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) return;

      final providerData = await SupabaseService.db
          .from('provider_profiles')
          .select('provider_type')
          .eq('id', userId)
          .maybeSingle();

      if (providerData != null && mounted) {
        setState(() {
          _providerType = providerData['provider_type'] as String?;
          _setupScreensAndNav();
        });
      }
    } catch (e) {
      debugPrint('Error loading provider type: $e');
    }
  }

  void _setupScreensAndNav() {
    switch (_providerType) {
      case 'merchant':
        // تاجر: يرى شاشة المنتجات والطلبات والمحفظة والحساب
      _screens = const [
        ProviderProductsScreen(),
        ProviderOrdersScreen(),
        ProviderWalletScreen(),
        ProviderScheduleScreen(),
        ProviderProfileScreen()
      ];
          _navItems = [
            _NavItem(Icons.inventory_rounded, 'المنتجات', 0),
            _NavItem(Icons.article_rounded, 'الطلبات', 1),
            _NavItem(Icons.account_balance_wallet_rounded, 'المحفظة', 2),
            _NavItem(Icons.schedule_rounded, 'المواعيد', 3),
            _NavItem(Icons.person_rounded, 'حسابي', 4),
          ];
        break;
      case 'driver':
        // سواق: يرى شاشة الطلبات والخريطة والمحفظة والحساب
      _screens = const [
        ProviderOrdersScreen(),
        ProviderMapScreen(),
        ProviderWalletScreen(),
        ProviderScheduleScreen(),
        ProviderProfileScreen()
      ];
          _navItems = [
            _NavItem(Icons.article_rounded, 'الطلبات', 0),
            _NavItem(Icons.map_rounded, 'الخريطة', 1),
            _NavItem(Icons.account_balance_wallet_rounded, 'المحفظة', 2),
            _NavItem(Icons.schedule_rounded, 'المواعيد', 3),
            _NavItem(Icons.person_rounded, 'حسابي', 4),
          ];
        break;
      case 'handyman':
        // صنايعي: يرى الرئيسية والطلبات والمحفظة والحساب + مركز بولت
        _screens = const [
          ProviderDashboardScreen(),
          ProviderOrdersScreen(),
          ProviderWalletScreen(),
          ProviderProfileScreen()
        ];
        _navItems = [
          _NavItem(Icons.house_rounded, 'الرئيسية', 0),
          _NavItem(Icons.article_rounded, 'الطلبات', 1),
          _NavItem(Icons.bolt_rounded, '', 2),
          _NavItem(Icons.account_balance_wallet_rounded, 'المحفظة', 3),
          _NavItem(Icons.person_rounded, 'المزيد', 4),
        ];
        break;
      default:
        // كلاهما أو غير محدد: يرى كل الشاشات
        _screens = const [
          ProviderDashboardScreen(),
          ProviderOrdersScreen(),
          ProviderWalletScreen(),
          ProviderProfileScreen()
        ];
        _navItems = [
          _NavItem(Icons.house_rounded, 'الرئيسية', 0),
          _NavItem(Icons.article_rounded, 'الطلبات', 1),
          _NavItem(Icons.bolt_rounded, '', 2),
          _NavItem(Icons.account_balance_wallet_rounded, 'المحفظة', 3),
          _NavItem(Icons.person_rounded, 'المزيد', 4),
        ];
    }
  }

  // Initialize with default screens to prevent RangeError
  void _initializeDefaultScreens() {
    _screens = const [
      ProviderDashboardScreen(),
      ProviderOrdersScreen(),
      ProviderWalletScreen(),
      ProviderProfileScreen()
    ];
    _navItems = [
      _NavItem(Icons.house_rounded, 'الرئيسية', 0),
      _NavItem(Icons.article_rounded, 'الطلبات', 1),
      _NavItem(Icons.bolt_rounded, '', 2),
      _NavItem(Icons.account_balance_wallet_rounded, 'المحفظة', 3),
      _NavItem(Icons.person_rounded, 'المزيد', 4),
    ];
  }

  Future<void> _startLocationTrackingIfNeeded() async {
    try {
      // Check if provider is online
      final userId = SupabaseService.currentUserId;
      if (userId == null) return;

      final providerData = await SupabaseService.db
          .from('provider_profiles')
          .select('is_online')
          .eq('id', userId)
          .maybeSingle();

      if (providerData != null && providerData['is_online'] == true) {
        // Check if provider has active orders
        final activeOrders = await SupabaseService.db
            .from('bookings')
            .select('id')
            .eq('provider_id', userId)
            .inFilter('status',
                ['accepted', 'on_the_way', 'arrived', 'in_progress']).limit(1);

        if (activeOrders.isNotEmpty) {
          CompassService.startTracking();
        }
      }
    } catch (e) {
      debugPrint('Error checking provider status: $e');
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
      backgroundColor: AppTheme.surfaceColor,
      body: Column(
        children: [
          // Document deadline warning banner
          if (_showDeadlineBanner) _buildDeadlineBanner(),
          // Main content
          Expanded(child: _screens[_idx.clamp(0, _screens.length - 1)]),
          _buildBottomNav(),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      height: 70.h + MediaQuery.of(context).padding.bottom,
      clipBehavior: Clip.none,
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        border: Border(
            top: BorderSide(
                color: AppTheme.dividerColor, width: 0.5)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, -2)),
        ],
      ),
      child: Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: _navItems
              .map((item) => item.index == 2
                  ? _buildCenterNav()
                  : _nav(item.icon, item.label, item.index))
              .toList(),
        ),
      ),
    );
  }

  Widget _buildCenterNav() {
    return Transform.translate(
      offset: Offset(0, -16.h),
      child: GestureDetector(
        onTap: () => setState(() => _idx = 0),
        child: Container(
          width: 48.sp,
          height: 48.sp,
          decoration: BoxDecoration(
            color: AppTheme.primaryColor,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 4),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryColor.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(
            Icons.bolt_rounded,
            color: AppTheme.warningColor,
            size: 22.sp,
          ),
        ),
      ),
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
      icon = Icons.block_rounded;
      message = 'تم حظر حسابك بسبب عدم رفع الوثائق المطلوبة. تواصل مع الدعم.';
    } else if (_isExpired) {
      bgColor = AppTheme.errorColor.withValues(alpha: 0.08);
      textColor = AppTheme.errorColor;
      icon = Icons.warning_rounded;
      message = 'انتهت المهلة! يرجى رفع الوثائق فوراً لتجنب حظر الحساب.';
    } else if (_daysRemaining <= 3) {
      bgColor = AppTheme.tertiaryColor.withValues(alpha: 0.08);
      textColor = AppTheme.tertiaryColor;
      icon = Icons.timer_rounded;
      message = 'تبقى $_daysRemaining أيام فقط لرفع الوثائق المطلوبة!';
    } else {
      bgColor = AppTheme.primaryColor.withValues(alpha: 0.05);
      textColor = AppTheme.primaryColor;
      icon = Icons.info_rounded;
      message =
          'يرجى رفع الوثائق خلال $_daysRemaining يوم لإكمال تفعيل الحساب.';
    }

    return Semantics(
      label: 'رفع الوثائق',
      child: GestureDetector(
        onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => const PartnerDocumentUploadScreen())),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
          margin: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
          decoration: BoxDecoration(
              color: bgColor,
              border: Border(
                  bottom: BorderSide(color: textColor.withValues(alpha: 0.2)))),
          child: Row(children: [
            Icon(icon, color: textColor, size: 20),
            SizedBox(width: 8.w),
            Expanded(
                child: Text(message,
                    style: TextStyle(
                        color: textColor,
                        fontSize: DesignTokens.textBodySmall,
                        fontWeight: FontWeight.bold))),
            Icon(Icons.chevron_left_rounded,
                color: textColor, size: DesignTokens.iconSm),
          ]),
        ),
      ),
    );
  }

  static const Color _providerPrimary = AppTheme.primaryColor;

  Widget _nav(IconData icon, String label, int idx) {
    final sel = _idx == idx;
    return Semantics(
      label: 'تبويب $label',
      child: GestureDetector(
        onTap: () => setState(() => _idx = idx),
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 4.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  color: sel ? _providerPrimary : AppTheme.textSecondary,
                  size: 20.w),
              SizedBox(height: 2.h),
              Flexible(
                child: Text(label,
                    style: TextStyle(
                      color:
                          sel ? _providerPrimary : AppTheme.textSecondary,
                      fontSize: 10.sp,
                      fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1),
              ),
            ],
          ),
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