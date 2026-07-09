import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';

class SslPinningInterceptor extends Interceptor {
  final Map<String, List<String>> _pinnedFingerprints;

  SslPinningInterceptor(this._pinnedFingerprints);

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (!kIsWeb) {
      final host = Uri.parse(options.baseUrl).host;
      final pinned = _pinnedFingerprints[host];
      if (pinned != null && pinned.isNotEmpty) {
        await _verifyCertificate(host, options, handler);
        return;
      }
    }
    handler.next(options);
  }

  Future<void> _verifyCertificate(
    String host,
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    try {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 10)
        ..badCertificateCallback = (X509Certificate cert, String h, int p) {
          final fingerprints = _pinnedFingerprints[h];
          if (fingerprints == null || fingerprints.isEmpty) return false;
          final sha = sha256.convert(utf8.encode(cert.pem ?? '')).toString().toUpperCase();
          for (final fp in fingerprints) {
            if (sha == fp.toUpperCase()) return true;
          }
          _logSecurityAlert('SSL pinning mismatch for $h');
          return false;
        };

      final uri = Uri.parse('${options.baseUrl}${options.path}');
      final request = await client.headUrl(uri);
      await request.close();
      client.close();
      handler.next(options);
    } catch (e) {
      _logSecurityAlert('SSL pinning verification failed for $host: $e');
      handler.reject(
        DioException(
          requestOptions: options,
          error: 'SSL pinning failed: certificate mismatch for $host',
          type: DioExceptionType.connectionError,
        ),
      );
    }
  }

  static void _logSecurityAlert(String message) {
    debugPrint('SECURITY: $message');
  }
}

class PinningHttpOverrides extends HttpOverrides {
  final Map<String, List<String>> pinnedHosts;

  PinningHttpOverrides(this.pinnedHosts);

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    client.badCertificateCallback = (X509Certificate cert, String host, int port) {
      if (host.startsWith('10.')) return true;
      if (host == 'localhost' || host == '127.0.0.1') return true;
      final fingerprints = pinnedHosts[host];
      if (fingerprints == null || fingerprints.isEmpty) {
        debugPrint('SECURITY: Unpinned host $host - rejecting');
        return false;
      }
      final sha = sha256.convert(utf8.encode(cert.pem ?? '')).toString().toUpperCase();
      for (final fp in fingerprints) {
        if (sha == fp.toUpperCase()) return true;
      }
      debugPrint('SECURITY ALERT: MITM detected for $host');
      debugPrint('  Expected: ${fingerprints.join(', ')}');
      debugPrint('  Got: $sha');
      return false;
    };
    return client;
  }
}
