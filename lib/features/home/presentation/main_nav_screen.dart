import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/services/supabase_service.dart';
import 'home_screen.dart';
import '../../booking/presentation/my_bookings_screen.dart';
import '../../profile/presentation/profile_screen.dart';
import 'categories_screen.dart';

class MainNavScreen extends StatefulWidget {
  const MainNavScreen({super.key});

  @override
  State<MainNavScreen> createState() => _MainNavScreenState();
}

class _MainNavScreenState extends State<MainNavScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    HomeScreen(),
    CategoriesScreen(),
    MyBookingsScreen(),
    ProfileScreen(),
  ];

  void _onNavTap(int index) {
    if (index != 0 && !SupabaseService.isLoggedIn) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: DesignTokens.brXl,
          ),
          title: const Text(
            'تسجيل الدخول مطلوب',
            textAlign: TextAlign.center,
          ),
          content: const Text(
            'يرجى تسجيل الدخول للوصول إلى هذه الصفحة',
            textAlign: TextAlign.center,
          ),
          actions: [
            TextButton(
              child: const Text('إلغاء'),
              onPressed: () => Navigator.pop(ctx),
            ),
            ElevatedButton(
              child: const Text('تسجيل الدخول'),
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pushNamed(context, '/login');
              },
            ),
          ],
        ),
      );
      return;
    }
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceColor,
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(
              color: AppTheme.dividerColor,
              width: 1,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(
              vertical: DesignTokens.space2.h,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(0, Icons.home_rounded, 'الرئيسية'),
                _buildNavItem(1, Icons.volunteer_activism_rounded, 'طلب خدمة'),
                _buildNavItem(2, Icons.list_alt_rounded, 'الطلبات'),
                _buildNavItem(3, Icons.person_rounded, 'حسابي'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isActive = _currentIndex == index;
    return GestureDetector(
      onTap: () => _onNavTap(index),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: DesignTokens.space4.w,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20.toDouble().sp,
              color: isActive
                  ? AppTheme.primaryColor
                  : AppTheme.textTertiary,
            ),
            SizedBox(height: DesignTokens.space1.h),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.toDouble().sp,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                color: isActive
                    ? AppTheme.primaryColor
                    : AppTheme.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
