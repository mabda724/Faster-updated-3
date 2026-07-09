// ============================================================
// Faster App - جميع الحقوق محفوظة
// All Rights Reserved © 2024-2026
// المالك: محمد ابراهيم عبدالله | 01128966996
// ============================================================
// ============================================================
// Faster App - ???? ?????? ??????
// ??????: ???? ??????? ??????? | 01128966996
import 'dart:async';

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/design_tokens.dart';
import '../services/maintenance_service.dart';
import '../services/supabase_service.dart';

/// Full-screen maintenance overlay shown when admin enables maintenance mode.
class MaintenanceScreen extends StatefulWidget {
  const MaintenanceScreen({super.key});

  @override
  State<MaintenanceScreen> createState() => _MaintenanceScreenState();
}

class _MaintenanceScreenState extends State<MaintenanceScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fade;
  late Animation<double> _scale;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _fade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.2, 1.0, curve: Curves.easeOut)),
    );
    _scale = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    _controller.forward();

    // Poll every 15 seconds to see if maintenance is lifted
    _pollTimer = Timer.periodic(const Duration(seconds: 15), (_) => _checkAgain());
  }

  Future<void> _checkAgain() async {
    final role = await _getCurrentRole();
    await MaintenanceService.check();
    if (!MaintenanceService.isDownForRole(role)) {
      if (mounted) {
        // Restart app flow by popping and letting the caller rebuild
        Navigator.of(context).pushReplacementNamed('/');
      }
    }
  }

  Future<String?> _getCurrentRole() async {
    try {
      final profile = await SupabaseService.db
          .from('profiles')
          .select('role')
          .eq('id', SupabaseService.currentUserId!)
          .maybeSingle();
      return profile?['role']?.toString();
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

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
            padding: const EdgeInsets.all(DesignTokens.space32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Animated gear icon
                ListenableBuilder(
                  listenable: _controller,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _scale.value,
                      child: Opacity(
                        opacity: _fade.value,
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: AppTheme.tertiaryColor.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                            border: Border.all(color: AppTheme.tertiaryColor.withValues(alpha: 0.3), width: 2),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.settings_suggest_rounded,
                              color: AppTheme.tertiaryColor,
                              size: DesignTokens.iconXl + 16,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                    SizedBox(height: DesignTokens.space9),
                ListenableBuilder(
                  listenable: _controller,
                  builder: (context, child) {
                    return Opacity(
                      opacity: _fade.value,
                      child: child,
                    );
                  },
                  child: Column(
                    children: [
                      const Text(
                        'سنعود قريباً',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: DesignTokens.textDisplayLarge - 4,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: DesignTokens.space16),
                      Text(
                        MaintenanceService.message,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: DesignTokens.textBodyLarge,
                          height: 1.6,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: DesignTokens.space48),
                      // Pulsing dots
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _dot(0),
                          const SizedBox(width: DesignTokens.space8),
                          _dot(1),
                          const SizedBox(width: DesignTokens.space8),
                          _dot(2),
                        ],
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => _checkAgain(),
                  child: const Text(
                    'التحقق مرة أخرى',
                    style: TextStyle(color: Colors.white38, fontSize: 13),
                  ),
                ),
                const SizedBox(height: DesignTokens.space16),
                const Text(
                  'Faster App',
                  style: TextStyle(color: Colors.white24, fontSize: DesignTokens.textLabelMedium, letterSpacing: 2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _dot(int index) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, child) {
        final delay = index * 0.15;
        final v = (_controller.value - delay).clamp(0.0, 1.0);
        final opacity = (0.4 + 0.6 * (1 - (v * 2 % 1).abs())).clamp(0.0, 1.0);
        return Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: AppTheme.tertiaryColor.withValues(alpha: opacity),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }
}
