import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/design_tokens.dart';

class OnTheWayOverlay extends StatefulWidget {
  final String providerName;
  final String serviceName;
  final VoidCallback onDismiss;

  const OnTheWayOverlay({
    super.key,
    required this.providerName,
    required this.serviceName,
    required this.onDismiss,
  });

  @override
  State<OnTheWayOverlay> createState() => _OnTheWayOverlayState();
}

class _OnTheWayOverlayState extends State<OnTheWayOverlay> with TickerProviderStateMixin {
  late AnimationController _speedCtrl;
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    _speedCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400))..repeat();
    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut));
    _fadeCtrl.forward();
    _dismissTimer = Timer(const Duration(seconds: 5), () {
      _fadeCtrl.reverse().then((_) => widget.onDismiss());
    });
  }

  @override
  void dispose() {
    _speedCtrl.dispose();
    _fadeCtrl.dispose();
    _dismissTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: Container(
        color: AppTheme.textPrimary,
        child: Stack(
          children: [
            // Speed lines
            ...List.generate(4, (i) => _speedLine(i)),
            Center(
              child: ListenableBuilder(
                listenable: _speedCtrl,
                builder: (_, __) => Transform.translate(
                  offset: Offset(
                    (_speedCtrl.value * 3 - 1.5).toDouble(),
                    (_speedCtrl.value * 2 - 1).toDouble(),
                  ),
                  child: Transform.rotate(
                    angle: (_speedCtrl.value * 0.1 - 0.05),
                    child: _buildSpeeder(),
                  ),
                ),
              ),
            ),
            // Text
            Positioned(
              bottom: MediaQuery.of(context).size.height * 0.25,
              left: 0, right: 0,
              child: Column(
                children: [
                  const Text(
                    'في الطريق! 🚗',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: DesignTokens.textDisplayLarge,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: DesignTokens.space8),
                  Text(
                    widget.providerName,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: DesignTokens.textTitleMedium,
                    ),
                  ),
                  const SizedBox(height: DesignTokens.space4),
                  Text(
                    widget.serviceName,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: DesignTokens.textBodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _speedLine(int index) {
    final delays = [0.0, -0.15, -0.3, -0.5];
    final tops = [0.2, 0.4, 0.6, 0.8];
    return Positioned(
      top: MediaQuery.of(context).size.height * tops[index],
      child: ListenableBuilder(
        listenable: _speedCtrl,
        builder: (_, __) {
          final progress = (_speedCtrl.value + delays[index]) % 1.0;
          final left = (progress * 400 - 100).toDouble();
          return Opacity(
            opacity: progress > 0.7 ? (1 - (progress - 0.7) / 0.3) : 1.0,
            child: Transform.translate(
              offset: Offset(left, 0),
              child: Container(
                width: MediaQuery.of(context).size.width * 0.2,
                height: 2,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSpeeder() {
    return SizedBox(
      width: 120,
      height: 80,
      child: CustomPaint(
        painter: _SpeederPainter(),
      ),
    );
  }
}

class _SpeederPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2
      ..style = PaintingStyle.fill;

    final cx = size.width / 2;
    final cy = size.height / 2;

    // Base/triangle
    final basePath = Path()
      ..moveTo(cx - 40, cy + 10)
      ..lineTo(cx + 40, cy + 10)
      ..lineTo(cx, cy - 10)
      ..close();
    canvas.drawPath(basePath, paint);

    // Body line
    canvas.drawLine(Offset(cx, cy - 10), Offset(cx + 20, cy - 25), paint..style = PaintingStyle.stroke);
    paint.style = PaintingStyle.fill;

    // Small circle (wheel)
    canvas.drawCircle(Offset(cx - 25, cy + 12), 6, paint);

    // Face/headlight
    final facePath = Path()
      ..moveTo(cx + 10, cy - 20)
      ..lineTo(cx + 25, cy - 15)
      ..lineTo(cx + 20, cy - 28)
      ..close();
    canvas.drawPath(facePath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// Show the overlay as a full-screen dialog
Future<void> showOnTheWayOverlay({
  required BuildContext context,
  required String providerName,
  required String serviceName,
}) async {
  final overlay = OverlayEntry(
    builder: (_) => OnTheWayOverlay(
      providerName: providerName,
      serviceName: serviceName,
      onDismiss: () {},
    ),
  );
  Overlay.of(context).insert(overlay);
  await Future.delayed(const Duration(seconds: 5));
  overlay.remove();
}
