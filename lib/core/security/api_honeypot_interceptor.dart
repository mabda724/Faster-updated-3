import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'security_incident_service.dart';

class ApiHoneypotInterceptor extends Interceptor {
  static const String _honeypotField = 'is_superuser_bypass';
  static const String _honeypotField2 = 'honeypot_client_token';
  static const String _expectedHoneypotValue = '__hpt_f8a2b3c4__';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (options.data is Map<String, dynamic>) {
      final data = options.data as Map<String, dynamic>;
      data[_honeypotField] = false;
      data[_honeypotField2] = _expectedHoneypotValue;
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    _checkResponseForTamperedHoneypot(response);
    handler.next(response);
  }

  void _checkResponseForTamperedHoneypot(Response response) {
    if (response.data is Map<String, dynamic>) {
      final data = response.data as Map<String, dynamic>;
      if (data[_honeypotField] == true) {
        debugPrint('HONEYPOT TRIGGERED: is_superuser_bypass tampered in response');
        SecurityIncidentService.report(
          SecurityIncident(
            type: SecurityEventType.honeypotFieldTamper,
            severity: SecuritySeverity.critical,
            detail: 'Honeypot field "is_superuser_bypass" tampered to true in API response',
            metadata: {
              'field': _honeypotField,
              'expected': false,
              'actual': data[_honeypotField],
              'url': response.requestOptions.uri.toString(),
            },
          ),
        );
      }
      if (data[_honeypotField2] != null && data[_honeypotField2] != _expectedHoneypotValue) {
        debugPrint('HONEYPOT TRIGGERED: honeypot_client_token tampered');
        SecurityIncidentService.report(
          SecurityIncident(
            type: SecurityEventType.honeypotFieldTamper,
            severity: SecuritySeverity.high,
            detail: 'Honeypot field "honeypot_client_token" tampered in API response',
            metadata: {
              'field': _honeypotField2,
              'expected': _expectedHoneypotValue,
              'actual': data[_honeypotField2],
              'url': response.requestOptions.uri.toString(),
            },
          ),
        );
      }
    }

    if (response.data is List) {
      for (final item in response.data as List) {
        if (item is Map<String, dynamic>) {
          if (item[_honeypotField] == true) {
            SecurityIncidentService.report(
              SecurityIncident(
                type: SecurityEventType.honeypotFieldTamper,
                severity: SecuritySeverity.critical,
                detail: 'Honeypot field "is_superuser_bypass" tampered to true in list response',
                metadata: {
                  'field': _honeypotField,
                  'expected': false,
                  'url': response.requestOptions.uri.toString(),
                },
              ),
            );
            break;
          }
        }
      }
    }
  }
}
