import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/services/supabase_service.dart';
import '../../auth/presentation/login_screen.dart';
import 'admin_dashboard_screen.dart';
import 'admin_orders_screen.dart';
import 'admin_categories_screen.dart';
import 'admin_pricing_screen.dart';
import 'admin_quality_dashboard_screen.dart';
import 'admin_notifications_screen.dart';
import 'admin_settings_screen.dart';

class AdminNavScreen extends StatefulWidget {
  const AdminNavScreen({super.key});
  @override
  State<AdminNavScreen> createState() => _AdminNavScreenState();
}

class _AdminNavScreenState extends State<AdminNavScreen> with TickerProviderStateMixin {
  int _idx = 0;
  bool _isCheckingAccess = true;
  bool _hasAccess = false;
  late AnimationController _animController;
  late AnimationController _pageAnimController;

List<Widget> get _screens {
return <Widget>[
const AdminDashboardScreen(),
AdminOrdersScreen(),
AdminCategoriesScreen(),
const AdminPricingScreen(),
const AdminQualityDashboardScreen(),
const AdminNotificationsScreen(),
AdminSettingsScreen(),
];
}

List<Map<String, dynamic>> get _navItems {
return <Map<String, dynamic>>[
{'icon': Icons.dashboard_rounded, 'label': 'الرئيسية'},
{'icon': Icons.receipt_long_rounded, 'label': 'الطلبات'},
{'icon': Icons.category_rounded, 'label': 'الأقسام'},
{'icon': Icons.attach_money_rounded, 'label': 'الأسعار'},
{'icon': Icons.assessment_rounded, 'label': 'الجودة'},
{'icon': Icons.notifications_rounded, 'label': 'الإشعارات'},
{'icon': Icons.settings_rounded, 'label': 'الإعدادات'},
];
}

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: DesignTokens.durationNormal);
    _pageAnimController = AnimationController(vsync: this, duration: DesignTokens.durationPage);
    _checkAccess();
  }

  @override
  void dispose() {
    _animController.dispose();
    _pageAnimController.dispose();
    super.dispose();
  }

  Future<void> _checkAccess() async {
    try {
      final uid = SupabaseService.currentUserId;
      if (uid == null) {
        if (!mounted) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
        });
        return;
      }

      final profile = await SupabaseService.db.from('profiles').select('role').eq('id', uid).maybeSingle();

      if (!mounted) return;
      final hasAccess = profile?['role'] == 'admin';
      if (!hasAccess) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
        });
        return;
      }

      setState(() {
        _hasAccess = true;
        _isCheckingAccess = false;
      });
    } catch (_) {
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
    }
  }

  void _navigateTo(int idx) {
    if (_idx == idx) return;
    _pageAnimController.forward(from: 0);
    setState(() => _idx = idx);
  }

  String _currentTime() {
    final now = DateTime.now();
    return '${now.hour}:${now.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingAccess) {
      return Scaffold(
        backgroundColor: AppTheme.darkBackgroundColor,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(DesignTokens.space6),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: DesignTokens.brFull,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryColor.withValues(alpha: 0.4),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(Icons.flash_on_rounded, color: AppTheme.surfaceColor, size: DesignTokens.iconLg),
              ),
              SizedBox(height: DesignTokens.space8),
              SizedBox(
                width: DesignTokens.space14.w,
                height: DesignTokens.space14.w,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: AppTheme.accentColor.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (!_hasAccess) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 600;

        return Scaffold(
          backgroundColor: AppTheme.darkBackgroundColor,
          body: Row(
            children: [
              if (isWide) _buildSidebar(),
              Expanded(
                child: AnimatedSwitcher(
                  duration: DesignTokens.durationNormal,
                  switchInCurve: DesignTokens.curveEaseInOut,
                  switchOutCurve: DesignTokens.curveEaseInOut.flipped,
                  transitionBuilder: (child, animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0.03, 0),
                          end: Offset.zero,
                        ).animate(CurvedAnimation(
                          parent: animation,
                          curve: DesignTokens.curveEaseInOut,
                        )),
                        child: child,
                      ),
                    );
                  },
                  child: KeyedSubtree(
                    key: ValueKey(_idx),
                    child: _screens[_idx],
                  ),
                ),
              ),
            ],
          ),
          bottomNavigationBar: isWide ? null : _buildBottomNav(),
        );
      },
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 140.w,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor,
            AppTheme.primaryColor.withValues(alpha: 0.92),
            AppTheme.darkSurfaceColor,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(4, 0),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          children: [
            SizedBox(height: DesignTokens.space6),
            _buildSidebarHeader(),
            SizedBox(height: DesignTokens.space6),
            _buildSidebarDivider(),
            SizedBox(height: DesignTokens.space8),
_sidebarItem(Icons.dashboard_rounded, 'لوحة التحكم', 0),
_sidebarItem(Icons.receipt_long_rounded, 'الطلبات', 1),
_sidebarItem(Icons.category_rounded, 'الأقسام', 2),
_sidebarItem(Icons.attach_money_rounded, 'الأسعار', 3),
_sidebarItem(Icons.assessment_rounded, 'الجودة', 4),
_sidebarItem(Icons.notifications_rounded, 'الإشعارات', 5),
_sidebarItem(Icons.settings_rounded, 'الإعدادات', 6),
            const Spacer(),
            _buildSidebarStatusCard(),
            SizedBox(height: DesignTokens.space6),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebarHeader() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: DesignTokens.space8, vertical: DesignTokens.space6),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(DesignTokens.space4),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.surfaceColor.withValues(alpha: 0.25),
                  AppTheme.surfaceColor.withValues(alpha: 0.08),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: DesignTokens.brLg,
              border: Border.all(color: AppTheme.surfaceColor.withValues(alpha: 0.15), width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Container(
              padding: EdgeInsets.all(DesignTokens.space3),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.surfaceColor.withValues(alpha: 0.08),
                    Colors.transparent,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: DesignTokens.brMd,
              ),
              child: const Icon(Icons.flash_on_rounded, color: AppTheme.surfaceColor, size: DesignTokens.iconLg),
            ),
          ),
          SizedBox(width: DesignTokens.space6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ShaderMask(
                shaderCallback: (bounds) => LinearGradient(
                  colors: [AppTheme.surfaceColor, AppTheme.accentColor.withValues(alpha: 0.9)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ).createShader(bounds),
                child: const Text(
                  'FASTER',
                  style: TextStyle(
                    color: AppTheme.surfaceColor,
                    fontSize: DesignTokens.textDisplayMedium,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 3,
                  ),
                ),
              ),
              Text(
                'لوحة التحكم',
                style: TextStyle(
                  color: AppTheme.surfaceColor.withValues(alpha: 0.55),
                  fontSize: DesignTokens.textLabelMedium,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarDivider() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: DesignTokens.space8),
      child: Row(
        children: List.generate(60, (index) {
          final isActive = index % 4 == 0;
          return Expanded(
            child: Container(
              height: 1,
              margin: EdgeInsets.symmetric(horizontal: 0.5),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isActive
                      ? [AppTheme.surfaceColor.withValues(alpha: 0.2), Colors.transparent]
                      : [AppTheme.surfaceColor.withValues(alpha: 0.05), Colors.transparent],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildSidebarStatusCard() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: DesignTokens.space8),
      padding: EdgeInsets.all(DesignTokens.space6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.surfaceColor.withValues(alpha: 0.08),
            AppTheme.surfaceColor.withValues(alpha: 0.02),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: DesignTokens.brLg,
        border: Border.all(color: AppTheme.surfaceColor.withValues(alpha: 0.08), width: 1),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: DesignTokens.space4, height: DesignTokens.space4,
                decoration: BoxDecoration(
                  color: AppTheme.successColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.successColor.withValues(alpha: 0.6),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
              SizedBox(width: DesignTokens.space4),
              Text(
                'النظام نشط',
                style: TextStyle(
                  color: AppTheme.surfaceColor.withValues(alpha: 0.7),
                  fontSize: DesignTokens.textLabelMedium,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Container(
                padding: EdgeInsets.symmetric(horizontal: DesignTokens.space3, vertical: DesignTokens.space1),
                decoration: BoxDecoration(
                  color: AppTheme.successColor.withValues(alpha: 0.15),
                  borderRadius: DesignTokens.brFull,
                ),
                child: Text(
                  'مباشر',
                  style: TextStyle(
                    color: AppTheme.successColor,
                    fontSize: DesignTokens.textLabelSmall,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: DesignTokens.space6),
          Row(
            children: [
              Icon(Icons.access_time_rounded, color: AppTheme.surfaceColor.withValues(alpha: 0.25), size: DesignTokens.iconSm),
              SizedBox(width: DesignTokens.space3),
              Text(
                _currentTime(),
                style: TextStyle(
                  color: AppTheme.surfaceColor.withValues(alpha: 0.4),
                  fontSize: DesignTokens.textLabelMedium,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const Spacer(),
              Icon(Icons.security_rounded, color: AppTheme.surfaceColor.withValues(alpha: 0.2), size: DesignTokens.iconSm),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sidebarItem(IconData icon, String label, int idx) {
    final sel = _idx == idx;
    return GestureDetector(
      onTap: () => _navigateTo(idx),
      child: AnimatedContainer(
        duration: DesignTokens.durationNormal,
        curve: DesignTokens.curveEaseInOut,
        margin: EdgeInsets.symmetric(horizontal: DesignTokens.space4, vertical: 3.h),
        padding: EdgeInsets.symmetric(horizontal: DesignTokens.space6, vertical: DesignTokens.space5),
        decoration: BoxDecoration(
          gradient: sel
              ? LinearGradient(
                  colors: [
                    AppTheme.surfaceColor.withValues(alpha: 0.15),
                    AppTheme.surfaceColor.withValues(alpha: 0.04),
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                )
              : null,
          borderRadius: DesignTokens.brLg,
          border: sel
              ? Border.all(color: AppTheme.surfaceColor.withValues(alpha: 0.12), width: 1)
              : null,
          boxShadow: sel
              ? [
                  BoxShadow(
                    color: AppTheme.surfaceColor.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: DesignTokens.durationNormal,
              curve: DesignTokens.curveEaseInOut,
              padding: EdgeInsets.all(DesignTokens.space2),
              decoration: BoxDecoration(
                gradient: sel
                    ? LinearGradient(
                        colors: [
                          AppTheme.accentColor.withValues(alpha: 0.25),
                          AppTheme.surfaceColor.withValues(alpha: 0.05),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                borderRadius: DesignTokens.brSm,
                color: sel ? null : Colors.transparent,
              ),
              child: Icon(
                icon,
                color: sel ? AppTheme.surfaceColor : AppTheme.surfaceColor.withValues(alpha: 0.4),
                size: DesignTokens.iconMd,
              ),
            ),
            SizedBox(width: DesignTokens.space6),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: sel ? AppTheme.surfaceColor : AppTheme.surfaceColor.withValues(alpha: 0.4),
                  fontWeight: sel ? FontWeight.w700 : FontWeight.w400,
                  fontSize: DesignTokens.textBodyMedium,
                  letterSpacing: 0.3,
                ),
              ),
            ),
            if (sel)
              Container(
                width: DesignTokens.space2,
                height: DesignTokens.space10,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.accentColor,
                      AppTheme.accentColor.withValues(alpha: 0.3),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: DesignTokens.brFull,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.accentColor.withValues(alpha: 0.4),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      height: 34.h + MediaQuery.of(context).padding.bottom,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.darkBackgroundColor,
            AppTheme.darkSurfaceColor.withValues(alpha: 0.95),
            AppTheme.darkBackgroundColor,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        border: Border(
          top: BorderSide(
            color: AppTheme.surfaceColor.withValues(alpha: 0.05),
            width: 0.5,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: (MediaQuery.of(context).padding.bottom - 2.h).clamp(0, double.infinity)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(_navItems.length, (index) {
            final item = _navItems[index];
            final isSelected = _idx == index;

            return GestureDetector(
              onTap: () => _navigateTo(index),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: DesignTokens.durationFast,
                curve: DesignTokens.curveEaseInOut,
                padding: EdgeInsets.symmetric(horizontal: DesignTokens.space4, vertical: DesignTokens.space3),
                decoration: BoxDecoration(
                  borderRadius: DesignTokens.brLg,
                  gradient: isSelected
                      ? LinearGradient(
                          colors: [
                            AppTheme.primaryColor.withValues(alpha: 0.12),
                            AppTheme.secondaryColor.withValues(alpha: 0.05),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        )
                      : null,
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        if (isSelected)
                          AnimatedContainer(
                            duration: DesignTokens.durationFast,
                            curve: DesignTokens.curveEaseInOut,
                            width: DesignTokens.space16.w,
                            height: DesignTokens.space16.w,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [
                                  AppTheme.primaryColor.withValues(alpha: 0.2),
                                  AppTheme.primaryColor.withValues(alpha: 0.05),
                                ],
                              ),
                            ),
                          ),
                        ShaderMask(
                          shaderCallback: (bounds) {
                            if (!isSelected) {
                              return LinearGradient(
                                colors: [AppTheme.surfaceColor, AppTheme.surfaceColor],
                              ).createShader(bounds);
                            }
                            return LinearGradient(
                              colors: [
                                AppTheme.accentColor,
                                AppTheme.surfaceColor,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ).createShader(bounds);
                          },
                          child: Icon(
                            item['icon'] as IconData,
                            color: AppTheme.surfaceColor,
                            size: 22.w,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: DesignTokens.space1),
                    ShaderMask(
                      shaderCallback: (bounds) {
                        if (!isSelected) {
                          return LinearGradient(
                            colors: [AppTheme.surfaceColor, AppTheme.surfaceColor],
                          ).createShader(bounds);
                        }
                        return LinearGradient(
                          colors: [
                            AppTheme.accentColor,
                            AppTheme.surfaceColor,
                          ],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ).createShader(bounds);
                      },
                      child: Text(
                        item['label'] as String,
                        style: TextStyle(
                          color: AppTheme.surfaceColor,
                          fontSize: DesignTokens.textLabelSmall.sp,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                    AnimatedContainer(
                      duration: DesignTokens.durationFast,
                      curve: DesignTokens.curveEaseInOut,
                      width: isSelected ? 20.w : 0,
                      height: 1.5,
                      margin: EdgeInsets.only(top: DesignTokens.space1),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.accentColor,
                            AppTheme.accentColor.withValues(alpha: 0.3),
                          ],
                        ),
                        borderRadius: DesignTokens.brFull,
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: AppTheme.accentColor.withValues(alpha: 0.5),
                                  blurRadius: 4,
                                ),
                              ]
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
                }),
        ),
      ),
    );
  }
}
