import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/design_tokens.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppTheme.primaryColor,
              AppTheme.primaryColor.withValues(alpha: 0.85),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(flex: 3),
            ClipOval(
              child: Image.asset(
                'assets/images/logo (1)/logo_faster.png',
                width: 100,
                height: 100,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Icon(
                  Icons.flash_on_rounded,
                  size: 56,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: DesignTokens.space6),
            Text(
              'FASTER',
              style: TextStyle(
                fontSize: DesignTokens.textDisplayLarge,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 6,
              ),
            ),
            const Spacer(flex: 2),
            SizedBox(
              width: 120,
              child: LinearProgressIndicator(
                backgroundColor: Colors.white.withValues(alpha: 0.15),
                valueColor: AlwaysStoppedAnimation<Color>(
                  Colors.white.withValues(alpha: 0.6),
                ),
              ),
            ),
            const SizedBox(height: DesignTokens.space4),
            Text(
              'v1.0.0',
              style: TextStyle(
                fontSize: DesignTokens.textLabelSmall,
                color: Colors.white.withValues(alpha: 0.3),
              ),
            ),
            const Spacer(flex: 1),
          ],
        ),
      ),
    );
  }
}
