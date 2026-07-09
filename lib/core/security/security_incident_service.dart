import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'secure_storage_service.dart';
import 'encrypted_cache_service.dart';
import '../services/supabase_service.dart';

enum SecuritySeverity { low, medium, high, critical }

enum SecurityEventType {
  honeypotTableRead,
  honeypotTableWrite,
  honeypotFieldTamper,
  payloadReplay,
  debuggerAttached,
  unknown,
}

class SecurityIncident {
  final SecurityEventType type;
  final SecuritySeverity severity;
  final String detail;
  final DateTime timestamp;
  final String? userId;
  final Map<String, dynamic> metadata;

  SecurityIncident({
    required this.type,
    required this.severity,
    required this.detail,
    DateTime? timestamp,
    this.userId,
    this.metadata = const {},
  }) : timestamp = timestamp ?? DateTime.now();
}

class SecurityIncidentService {
  static SecurityIncidentService? _instance;
  SecurityIncidentService._();

  static SecurityIncidentService get instance {
    _instance ??= SecurityIncidentService._();
    return _instance!;
  }

  static bool _armed = false;
  static String? _logPath;

  static Future<void> arm() async {
    if (_armed) return;
    final dir = await getApplicationDocumentsDirectory();
    _logPath = '${dir.path}/.security_events.log';
    _armed = true;
  }

  static Future<void> report(SecurityIncident incident) async {
    if (!_armed) return;
    await _writeLog(incident);
    await _remoteLog(incident);
    if (incident.severity == SecuritySeverity.critical) {
      await _respondCritical(incident);
    } else if (incident.severity == SecuritySeverity.high) {
      await _respondHigh(incident);
    }
  }

  static Future<void> _writeLog(SecurityIncident incident) async {
    try {
      final file = File(_logPath!);
      await file.writeAsString(
        '[${incident.timestamp.toIso8601String()}] [${incident.severity.name.toUpperCase()}] '
        '${incident.type.name}: ${incident.detail} '
        '${incident.metadata.isNotEmpty ? incident.metadata.toString() : ''}\n',
        mode: FileMode.append,
      );
    } catch (_) {}
  }

  static Future<void> _remoteLog(SecurityIncident incident) async {
    try {
      if (!SupabaseService.isLoggedIn) return;
      await SupabaseService.db.from('security_event_log').insert({
        'event_type': incident.type.name,
        'severity': incident.severity.name,
        'detail': incident.detail,
        'user_id': incident.userId ?? SupabaseService.currentUserId,
        'metadata': incident.metadata,
      });
    } catch (_) {}
  }

  static Future<void> _respondCritical(SecurityIncident incident) async {
    await EncryptedCacheService.clear();
    await SecureStorageService.clearAll();
    try {
      await SupabaseService.auth.signOut();
    } catch (_) {}
  }

  static Future<void> _respondHigh(SecurityIncident incident) async {
    await EncryptedCacheService.clear();
    SecureStorageService.authToken = null;
    try {
      await SupabaseService.auth.signOut();
    } catch (_) {}
  }
}
