import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/design_tokens.dart';

/// Driver QR scanner to verify client and start the ride.
class DriverArrivalQrScanScreen extends StatefulWidget {
  final String bookingId;

  const DriverArrivalQrScanScreen({super.key, required this.bookingId});

  @override
  State<DriverArrivalQrScanScreen> createState() => _DriverArrivalQrScanScreenState();
}

class _DriverArrivalQrScanScreenState extends State<DriverArrivalQrScanScreen> {
  bool _handled = false;

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    final raw = capture.barcodes.first.rawValue?.trim();
    if (raw == null || raw.isEmpty) return;

    // Format: FASTER_RIDE:bookingId:code
    final parts = raw.split(':');
    if (parts.length != 3 || parts[0] != 'FASTER_RIDE') return;

    final bookingId = parts[1];
    final code = parts[2];
    if (bookingId != widget.bookingId) return;

    _handled = true;
    Navigator.pop(context, code);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('مسح باركود العميل لبدء الرحلة'),
      ),
      backgroundColor: AppTheme.textPrimary,
      body: Stack(
        children: [
          MobileScanner(onDetect: _onDetect),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              color: AppTheme.textPrimary.withValues(alpha: 0.54),
              padding: EdgeInsets.all(DesignTokens.space16),
              child: const Text(
                'وجّه الكاميرا إلى باركود العميل لبدء الرحلة',
                style: TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          if (!_handled)
            Center(
              child: IgnorePointer(
                child: Container(
                  width: 240,
                  height: 240,
                  decoration: BoxDecoration(
                    border: Border.all(color: AppTheme.primaryColor, width: 3),
                    borderRadius: DesignTokens.brLg,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
