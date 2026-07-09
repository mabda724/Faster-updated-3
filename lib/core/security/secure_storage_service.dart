import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  static const _storage = FlutterSecureStorage();

  static const _keyDbEncryptionKey = 'db_encryption_key';
  static const _keyAuthToken = 'auth_token';
  static const _keyRefreshToken = 'refresh_token';
  static const _keyThemeMode = 'theme_mode';
  static const _keyFcmToken = 'fcm_token';

  // In-memory cache for synchronous access
  static String? _cachedAuthToken;
  static String? _cachedRefreshToken;
  static String? _cachedThemeMode;
  static String? _cachedFcmToken;

  static Future<void> write(String key, String value) async {
    await _storage.write(key: key, value: value);
  }

  static Future<String?> read(String key) async {
    return await _storage.read(key: key);
  }

  static Future<void> delete(String key) async {
    await _storage.delete(key: key);
  }

  static Future<void> clearAll() async {
    await _storage.deleteAll();
    _cachedAuthToken = null;
    _cachedRefreshToken = null;
    _cachedThemeMode = null;
    _cachedFcmToken = null;
  }

  static Future<bool> containsKey(String key) async {
    final value = await _storage.read(key: key);
    return value != null;
  }

  static Future<String> getOrCreateEncryptionKey() async {
    final existing = await _storage.read(key: _keyDbEncryptionKey);
    if (existing != null && existing.isNotEmpty) return existing;
    final key = _generateSecureKey();
    await _storage.write(key: _keyDbEncryptionKey, value: key);
    return key;
  }

  static String _generateSecureKey() {
    final bytes = List<int>.generate(32, (_) => _secureRandom());
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  static int _secureRandom() {
    return DateTime.now().microsecondsSinceEpoch % 256;
  }

  static String? get authToken => _cachedAuthToken;

  static set authToken(String? value) {
    _cachedAuthToken = value;
    if (value != null) {
      write(_keyAuthToken, value);
    } else {
      delete(_keyAuthToken);
    }
  }

  static String? get refreshToken => _cachedRefreshToken;

  static set refreshToken(String? value) {
    _cachedRefreshToken = value;
    if (value != null) {
      write(_keyRefreshToken, value);
    } else {
      delete(_keyRefreshToken);
    }
  }

  static String? get themeMode => _cachedThemeMode;

  static set themeMode(String? value) {
    _cachedThemeMode = value;
    if (value != null) {
      write(_keyThemeMode, value);
    } else {
      delete(_keyThemeMode);
    }
  }

  static String? get fcmToken => _cachedFcmToken;

  static set fcmToken(String? value) {
    _cachedFcmToken = value;
    if (value != null) {
      write(_keyFcmToken, value);
    } else {
      delete(_keyFcmToken);
    }
  }
}
