import 'dart:io' show HttpOverrides, Platform;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'features/auth/presentation/register_screen.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';

import 'core/services/supabase_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/notification_badge_service.dart';
import 'core/services/maintenance_service.dart';
import 'core/widgets/connectivity_wrapper.dart';
import 'config/app_config.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/onboarding/presentation/splash_screen.dart';
import 'features/home/presentation/main_nav_screen.dart';
import 'features/admin/presentation/admin_nav_screen.dart';
import 'features/provider/presentation/provider_nav_screen.dart';
import 'features/seller/presentation/seller_nav_screen.dart';
import 'features/driver/presentation/driver_nav_screen.dart';
import 'features/delivery/presentation/delivery_nav_screen.dart';
import 'features/developer/presentation/developer_screen.dart';
import 'features/booking/presentation/waiting_for_provider_screen.dart';
import 'features/booking/presentation/reviews_screen.dart';
import 'features/provider/presentation/provider_analytics_screen.dart';
import 'features/notifications/presentation/notifications_screen.dart';
import 'core/services/location_service.dart';
import 'core/services/chat_cleanup_service.dart';
import 'core/security/security_service.dart';
import 'core/security/ssl_pinning_interceptor.dart';
import 'core/security/app_sec_config.dart';
import 'core/security/encrypted_cache_service.dart';
import 'core/security/honeypot_database_service.dart';
import 'core/security/security_incident_service.dart';

final themeProvider = ThemeProvider();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('Flutter Error: ${details.exception}');
  };

  await _initializeSecurity();

  runApp(const ProviderScope(child: FasterApp()));

  NotificationService.onForegroundMessage.listen((message) {
    _handleForegroundNotification(message);
  });
}

Future<void> _initializeSecurity() async {
  if (!kIsWeb) {
    try {
      HttpOverrides.global = PinningHttpOverrides(AppSecConfig.sslPinnedHosts);
    } catch (_) {}

    try {
      await EncryptedCacheService.initialize();
    } catch (e) {
      debugPrint('Cache init: $e');
    }
  }

  if (!kIsWeb) {
    try {
      await SecurityService.checkIntegrity();
      if (SecurityService.isCompromised) {
        debugPrint('Compromised device detected: ${SecurityService.status}');
      }
    } catch (e) {
      debugPrint('Security init: $e');
    }
  }

  try {
    await SecurityIncidentService.arm();
  } catch (e) {
    debugPrint('SecurityIncidentService arm: $e');
  }

  if (!kIsWeb) {
    try {
      await HoneypotDatabaseService.initialize();
    } catch (e) {
      debugPrint('HoneypotDatabaseService init: $e');
    }
  }
}

void _handleForegroundNotification(RemoteMessage message) {
  final navigator = FasterApp.navigatorKey.currentState;
  if (navigator == null) return;
  final context = navigator.context;

  final title = message.notification?.title ?? 'تنبيه جديد';
  final body = message.notification?.body ?? '';

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      duration: const Duration(seconds: 5),
      margin: const EdgeInsets.all(16),
      behavior: SnackBarBehavior.floating,
      padding: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [Color(0xFF0F2B6E), Color(0xFF1E40AF)]),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  shape: BoxShape.circle),
              child: const Icon(Icons.notifications_active_rounded,
                  color: AppTheme.surfaceColor, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: AppTheme.surfaceColor)),
                  Text(body,
                      style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.surfaceColor.withValues(alpha: 0.7)),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.arrow_forward_ios_rounded,
                  color: AppTheme.surfaceColor, size: 16),
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                _handleNotificationNavigation(message);
              },
            ),
          ],
        ),
      ),
    ),
  );
}

void _handleNotificationNavigation(RemoteMessage message) {
  final data = message.data;
  final type = data['type'];
  final navigator = FasterApp.navigatorKey.currentState;
  if (navigator == null) return;

  switch (type) {
    case 'order_status':
    case 'new_booking':
      // Navigate to provider or client home based on user role
      final orderId = data['order_id'];
      if (orderId != null) {
        // For now, navigate to the appropriate home screen
        // The user can then navigate to the specific order
        _navigateToHomeByRole(navigator);
      }
      break;
    case 'withdrawal_request':
    case 'withdrawal_update':
      navigator.push(
        MaterialPageRoute(
          builder: (_) => const ConnectivityWrapper(child: ProviderNavScreen()),
        ),
      );
      break;
    case 'chat_message':
      // Navigate to home - user can access chat from there
      _navigateToHomeByRole(navigator);
      break;
    case 'settlement':
      final role = data['role'];
      if (role == 'admin') {
        navigator.push(
          MaterialPageRoute(
            builder: (_) => const ConnectivityWrapper(child: AdminNavScreen()),
          ),
        );
      } else {
        navigator.push(
          MaterialPageRoute(
            builder: (_) =>
                const ConnectivityWrapper(child: ProviderNavScreen()),
          ),
        );
      }
      break;
    default:
      _navigateToHomeByRole(navigator);
  }
}

void _navigateToHomeByRole(NavigatorState navigator) async {
  try {
    final role = await AuthRepository().getCurrentRole();
    Widget destination;
    switch (role) {
      case 'admin':
        destination = const AdminNavScreen();
      case 'provider':
      case 'seller':
      case 'driver':
        destination = const ProviderNavScreen();
      case 'delivery':
        destination = const DeliveryNavScreen();
      case 'developer':
        destination = const DeveloperScreen();
      default:
        destination = const MainNavScreen();
    }
    navigator.push(
      MaterialPageRoute(
        builder: (_) => ConnectivityWrapper(child: destination),
      ),
    );
  } catch (_) {
    navigator.push(
      MaterialPageRoute(
        builder: (_) => const ConnectivityWrapper(child: MainNavScreen()),
      ),
    );
  }
}

class FasterApp extends StatelessWidget {
  const FasterApp({super.key});

  // Global navigator key for navigation from notifications
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(390, 844),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return ListenableBuilder(
          listenable: themeProvider,
          builder: (context, _) {
            return MaterialApp(
              title: 'Faster',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.lightTheme,
              darkTheme: AppTheme.darkTheme,
              themeMode: themeProvider.themeMode,
              home: const SplashScreenWrapper(),
              navigatorKey: navigatorKey,
              builder: (context, child) {
                // Allow text scaling up to 1.15x for accessibility (Design System §3.3)
                final mediaQuery = MediaQuery.of(context);
                final constrainedScale =
                    mediaQuery.textScaler.clamp(maxScaleFactor: 1.15);
                return MediaQuery(
                  data: mediaQuery.copyWith(textScaler: constrainedScale),
                  child: child!,
                );
              },
              routes: {
                '/login': (context) => const LoginScreen(),
                '/home': (context) =>
                    const ConnectivityWrapper(child: MainNavScreen()),
                '/admin': (context) =>
                    const ConnectivityWrapper(child: AdminNavScreen()),
                '/provider': (context) =>
                    const ConnectivityWrapper(child: ProviderNavScreen()),
                '/seller': (context) =>
                    const ConnectivityWrapper(child: SellerNavScreen()),
                '/driver': (context) =>
                    const ConnectivityWrapper(child: DriverNavScreen()),
                '/delivery': (context) =>
                    const ConnectivityWrapper(child: DeliveryNavScreen()),
                '/notifications': (context) => const NotificationsScreen(),
                '/waiting-provider': (context) {
                  final args = ModalRoute.of(context)?.settings.arguments
                      as Map<String, dynamic>?;
                  return WaitingForProviderScreen(
                    bookingId: args?['bookingId'] ?? '',
                    serviceName: args?['serviceName'] ?? '',
                    totalPrice: args?['totalPrice'] ?? 0.0,
                  );
                },
                '/reviews': (context) {
                  final args = ModalRoute.of(context)?.settings.arguments
                      as Map<String, dynamic>?;
                  return ReviewsScreen(
                    providerId: args?['providerId'],
                    bookingId: args?['bookingId'],
                  );
                },
                '/provider-analytics': (context) =>
                    const ProviderAnalyticsScreen(),
              },
              onGenerateRoute: (settings) {
                if (settings.name == '/register') {
                  final args = settings.arguments as Map<String, dynamic>?;
                  final role = args?['role'] ?? 'client';
                  return MaterialPageRoute(
                    builder: (_) => RegisterScreen(role: role),
                  );
                }
                return null;
              },
            );
          },
        );
      },
    );
  }
}

class SplashScreenWrapper extends StatefulWidget {
  const SplashScreenWrapper({super.key});

  @override
  State<SplashScreenWrapper> createState() => _SplashScreenWrapperState();
}

class _SplashScreenWrapperState extends State<SplashScreenWrapper> {
  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    if (!kIsWeb && SecurityService.isCompromised) {
      return;
    }
    await _initializeServices();
    if (mounted) _navigate();
  }

  Future<void> _initializeServices() async {
    try {
      await LocationService.handleLocationPermission().timeout(
        const Duration(seconds: 4),
        onTimeout: () => false,
      );
    } catch (e) {
      debugPrint('Location permission error: $e');
    }

    try {
      await AppConfig.initialize().timeout(
        const Duration(seconds: 4),
        onTimeout: () {},
      );
      await SupabaseService.initialize().timeout(
        const Duration(seconds: 4),
        onTimeout: () {},
      );

      if (!kIsWeb) {
        NotificationService.initialize().catchError((e) {
          debugPrint('NotificationService error: $e');
        });
      }

      if (SupabaseService.isLoggedIn) {
        NotificationBadgeService().initialize().catchError((e) {
          debugPrint('NotificationBadgeService error: $e');
        });
        ChatCleanupService.runIfNeeded().catchError((e) {
          debugPrint('ChatCleanupService error: $e');
        });
      }
    } catch (e) {
      debugPrint('Initialization error: $e');
    }
  }

  Future<void> _navigate() async {
    await Future.delayed(const Duration(milliseconds: 500));

    Widget destination;
    if (SupabaseService.isLoggedIn) {
      try {
        final role = await AuthRepository().getCurrentRole();

        if (role == null) {
          destination = const LoginScreen();
        } else if (MaintenanceService.isDownForRole(role)) {
          destination = const _MaintenanceGate();
        } else {
          destination = _getScreenByRole(role);
        }
      } catch (e) {
        debugPrint('Error fetching role: $e');
        destination = const LoginScreen();
      }
    } else {
      destination = const LoginScreen();
    }

    if (mounted) {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => destination,
          transitionsBuilder: (context, animation, secondaryAnimation, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
      );
    }
  }

  Widget _getScreenByRole(String role) {
    switch (role) {
      case 'admin':
        return const AdminNavScreen();
      case 'provider':
        return const ProviderNavScreen();
      case 'seller':
        return const SellerNavScreen();
      case 'driver':
        return const DriverNavScreen();
      case 'delivery':
        return const DeliveryNavScreen();
      case 'developer':
        return const DeveloperScreen();
      default:
        return const MainNavScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb && SecurityService.isCompromised) {
      return const _SecurityGate();
    }
    return const SplashScreen();
  }
}

class _SecurityGate extends StatelessWidget {
  const _SecurityGate();

  @override
  Widget build(BuildContext context) {
    final isRooted = SecurityService.isRooted;
    final isEmulator = SecurityService.isEmulator;
    String title;
    String message;
    if (isRooted) {
      title = 'جهاز غير آمن';
      message = 'تم اكتشاف أن جهازك يحتوي على صلاحيات جذر (Root). '
          'لأسباب أمنية، لا يمكن تشغيل التطبيق على الأجهزة المخترقة. '
          'يرجى إزالة صلاحيات الجذر وإعادة المحاولة.';
    } else if (SecurityService.isJailbroken) {
      title = 'جهاز غير آمن';
      message = 'تم اكتشاف أن جهازك قد تم اختراقه (Jailbreak). '
          'لأسباب أمنية، لا يمكن تشغيل التطبيق على الأجهزة المخترقة.';
    } else {
      title = 'بيئة غير مدعومة';
      message = 'لا يمكن تشغيل التطبيق في هذه البيئة. '
          'يرجى استخدام جهاز فعلي غير معدل.';
    }

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.red.withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.security_rounded,
                      color: Colors.red,
                      size: 56,
                    ),
                  ),
                ),
                const SizedBox(height: 36),
                Text(
                  title,
                  style: const TextStyle(
                    color: AppTheme.surfaceColor,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  message,
                  style: TextStyle(
                    color: AppTheme.surfaceColor.withValues(alpha: 0.7),
                    fontSize: 16,
                    height: 1.6,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MaintenanceGate extends StatelessWidget {
  const _MaintenanceGate();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.amber.withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.settings_suggest_rounded,
                      color: Colors.amber,
                      size: 56,
                    ),
                  ),
                ),
                const SizedBox(height: 36),
                const Text(
                  'سنعود قريباً',
                  style: TextStyle(
                    color: AppTheme.surfaceColor,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'نحن نقوم بتحديث التطبيق لتقديم تجربة أفضل لك.',
                  style: TextStyle(
                    color: AppTheme.surfaceColor.withValues(alpha: 0.7),
                    fontSize: 16,
                    height: 1.6,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),
                const LinearProgressIndicator(
                  color: Colors.amber,
                  backgroundColor: Colors.white12,
                  minHeight: 3,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
