import 'package:flutter/foundation.dart';
import 'security_incident_service.dart';

mixin HoneypotFieldMixin {
  static const String _honeypotField = 'is_superuser_bypass';
  static const String _honeypotField2 = 'honeypot_client_token';
  static const String _expectedToken = '__hpt_f8a2b3c4__';

  static Map<String, dynamic> applyHoneypotFields(Map<String, dynamic> json) {
    if (json[_honeypotField] == true) {
      debugPrint('HONEYPOT TRIGGERED: is_superuser_bypass=true received from server');
      SecurityIncidentService.report(
        SecurityIncident(
          type: SecurityEventType.honeypotFieldTamper,
          severity: SecuritySeverity.critical,
          detail: 'Honeypot field "is_superuser_bypass" was true in server response',
          metadata: {
            'field': _honeypotField,
            'expected': false,
            'actual': true,
          },
        ),
      );
    }
    return json;
  }

  static Map<String, dynamic> injectHoneypotFields(Map<String, dynamic> json) {
    json[_honeypotField] = false;
    json[_honeypotField2] = _expectedToken;
    return json;
  }

  static bool checkResponseForTampering(Map<String, dynamic> json) {
    return json[_honeypotField] == true;
  }
}
