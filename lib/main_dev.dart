import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'core/stubs/stub_service_registry.dart';
import 'core/services/supabase_service.dart';
import 'features/onboarding/presentation/splash_screen.dart';
import 'features/home/presentation/main_nav_screen.dart';
import 'features/auth/presentation/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SupabaseService.enableBypassMode();
  await StubServiceRegistry.initialize();

  runApp(const ProviderScope(child: FasterApp()));
}

class FasterApp extends StatelessWidget {
  const FasterApp({super.key});

  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(390, 844),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return MaterialApp(
          title: 'Faster',
          debugShowCheckedModeBanner: false,
          debugShowMaterialGrid: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeMode.light,
          home: const SplashScreen(),
          navigatorKey: navigatorKey,
        );
      },
    );
  }
}
