import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/design_tokens.dart';

class ProviderArrivalQrScanScreen extends StatefulWidget {
  final String bookingId;

  const ProviderArrivalQrScanScreen({super.key, required this.bookingId});

  @override
  State<ProviderArrivalQrScanScreen> createState() =>
      _ProviderArrivalQrScanScreenState();
}

class _ProviderArrivalQrScanScreenState
    extends State<ProviderArrivalQrScanScreen> {
  bool _handled = false;

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    final raw = capture.barcodes.first.rawValue?.trim();
    if (raw == null || raw.isEmpty) return;
    final parts = raw.split(':');
    if (parts.length != 3 || parts[0] != 'FASTER_ARRIVAL') return;

    final bookingId = parts[1];
    final code = parts[2];
    if (bookingId != widget.bookingId) return;

    _handled = true;
    Navigator.pop(context, code);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          MobileScanner(
            onDetect: _onDetect,
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              color: Colors.black.withOpacity(0.54),
              padding: EdgeInsets.all(DesignTokens.space16),
              child: const Text(
                'وجّه الكاميرا إلى باركود العميل لتأكيد الوصول',
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
                    borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
