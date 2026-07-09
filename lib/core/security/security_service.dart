import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum DeviceIntegrityStatus {
  clean,
  rooted,
  jailbroken,
  emulator,
  debugger,
  tampered,
}

class SecurityService {
  static const _channel = MethodChannel('com.faster.app/security');

  static DeviceIntegrityStatus _status = DeviceIntegrityStatus.clean;
  static bool _checked = false;

  static DeviceIntegrityStatus get status => _status;
  static bool get isCompromised =>
      _status != DeviceIntegrityStatus.clean;
  static bool get isRooted =>
      _status == DeviceIntegrityStatus.rooted;
  static bool get isJailbroken =>
      _status == DeviceIntegrityStatus.jailbroken;
  static bool get isEmulator =>
      _status == DeviceIntegrityStatus.emulator;

  static Future<DeviceIntegrityStatus> checkIntegrity() async {
    if (_checked) return _status;

    if (kIsWeb) {
      _status = DeviceIntegrityStatus.clean;
      _checked = true;
      return _status;
    }

    try {
      final result = await _channel.invokeMethod<Map>('checkIntegrity');
      if (result != null) {
        if (result['isRooted'] == true) {
          _status = DeviceIntegrityStatus.rooted;
        } else if (result['isJailbroken'] == true) {
          _status = DeviceIntegrityStatus.jailbroken;
        } else if (result['isEmulator'] == true) {
          _status = DeviceIntegrityStatus.emulator;
        } else if (result['isDebugger'] == true) {
          _status = DeviceIntegrityStatus.debugger;
        } else {
          _status = DeviceIntegrityStatus.clean;
        }
      }
    } on MissingPluginException {
      _status = _dartSideCheck();
    } catch (e) {
      debugPrint('🔒 Security check error: $e');
      _status = _dartSideCheck();
    }

    _checked = true;
    return _status;
  }

  static DeviceIntegrityStatus _dartSideCheck() {
    if (!kIsWeb && Platform.isAndroid) {
      try {
        final buildTags = Platform.environment['ROOTED'] ?? '';
        if (buildTags.isNotEmpty) {
          return DeviceIntegrityStatus.rooted;
        }
      } catch (_) {}
    }
    return DeviceIntegrityStatus.clean;
  }
}
