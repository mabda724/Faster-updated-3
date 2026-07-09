import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/document_deadline_service.dart';
import 'seller_dashboard_screen.dart';
import 'seller_orders_screen.dart';
import 'seller_products_screen.dart';
import '../../provider/presentation/provider_wallet_screen.dart';
import '../../provider/presentation/partner_profile_screen.dart';
import '../../provider/presentation/partner_document_upload_screen.dart';

class _NavItem {
  final IconData icon;
  final String label;
  final int index;

  _NavItem(this.icon, this.label, this.index);
}

class SellerNavScreen extends StatefulWidget {
  const SellerNavScreen({super.key});
  @override
  State<SellerNavScreen> createState() => _SellerNavScreenState();
}

class _SellerNavScreenState extends State<SellerNavScreen> {
  int _idx = 0;

  // Document deadline state
  bool _showDeadlineBanner = false;
  int _daysRemaining = 0;
  bool _isExpired = false;
  bool _isBanned = false;

  final List<Widget> _screens = const [
    SellerDashboardScreen(),
    SellerOrdersScreen(),
    SellerProductsScreen(),
    ProviderWalletScreen(),
    PartnerProfileScreen(),
  ];

  final List<_NavItem> _navItems = [
    _NavItem(Icons.home_rounded, 'الرئيسية', 0),
    _NavItem(Icons.receipt_long_rounded, 'الطلبات', 1),
    _NavItem(Icons.inventory_2_rounded, 'المنتجات', 2),
    _NavItem(Icons.account_balance_wallet_rounded, 'المحفظة', 3),
    _NavItem(Icons.person_rounded, 'حسابي', 4),
  ];

  @override
  void initState() {
    super.initState();
    _checkDocumentDeadline();
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
    final bottom = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      body: Column(
        children: [
          if (_showDeadlineBanner) _buildDeadlineBanner(),
          Expanded(child: _screens[_idx]),
        ],
      ),
      bottomNavigationBar: Container(
        height: 60.h + (bottom > 0 ? bottom : 0),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppTheme.darkBackgroundColor,
              AppTheme.darkSurfaceColor,
              AppTheme.primaryColor,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(DesignTokens.radius2xl),
            topRight: Radius.circular(DesignTokens.radius2xl),
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryColor,
              blurRadius: 16,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.only(bottom: bottom > 0 ? bottom : 8.h),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: _navItems
                .map((item) => _buildNavItem(item))
                .toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(_NavItem item) {
    final selected = _idx == item.index;
    return GestureDetector(
      onTap: () => setState(() => _idx = item.index),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            item.icon,
            color: selected
                ? Colors.white
                : Colors.white.withValues(alpha: 0.6),
            size: 20.w,
          ),
          SizedBox(height: 2.h),
          Text(
            item.label,
            style: TextStyle(
              color: selected
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.6),
              fontSize: 9.sp,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
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
      message =
          'يرجى رفع الوثائق خلال $_daysRemaining يوم لإكمال تفعيل الحساب.';
    }

    return GestureDetector(
      onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
                 builder: (_) => const PartnerDocumentUploadScreen())),
      child: Container(
        width: double.infinity,
        padding:
            EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        margin:
            EdgeInsets.only(top: MediaQuery.of(context).padding.top),
        decoration: BoxDecoration(
          color: bgColor,
          border: Border(
              bottom:
                  BorderSide(color: textColor.withValues(alpha: 0.2))),
        ),
        child: Row(
          children: [
            Icon(icon, color: textColor, size: 20),
            SizedBox(width: 8.w),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: textColor,
                  fontSize: DesignTokens.textBodySmall,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Icon(Icons.arrow_forward_ios,
                color: textColor, size: DesignTokens.iconSm),
          ],
        ),
      ),
    );
  }
}
