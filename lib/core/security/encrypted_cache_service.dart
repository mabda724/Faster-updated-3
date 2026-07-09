import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../services/path_provider_service.dart';
import 'secure_storage_service.dart';

class EncryptedCacheService {
  static bool _initialized = false;
  static Box? _cacheBox;
  static const String _boxName = 'secure_cache';

  static Future<void> initialize() async {
    if (_initialized) return;
    final dir = await PathProviderService.cacheDir;
    await Hive.initFlutter(dir.path);
    final encryptionKey = await _getEncryptionKey();
    _cacheBox = await Hive.openBox(
      _boxName,
      encryptionKey: encryptionKey,
    );
    _initialized = true;
  }

  static Future<Uint8List> _getEncryptionKey() async {
    final keyStr = await SecureStorageService.getOrCreateEncryptionKey();
    final bytes = utf8.encode(keyStr);
    final key = Uint8List.fromList(bytes);
    if (key.length < 32) {
      final padded = Uint8List(32);
      for (var i = 0; i < key.length; i++) padded[i] = key[i];
      return padded;
    }
    return key.sublist(0, 32);
  }

  static Future<void> put(String key, dynamic value) async {
    if (_cacheBox == null) return;
    await _cacheBox!.put(key, value);
  }

  static dynamic get(String key) => _cacheBox?.get(key);

  static Future<void> remove(String key) async {
    await _cacheBox?.delete(key);
  }

  static Future<void> clear() async {
    await _cacheBox?.clear();
  }

  static Future<void> close() async {
    await _cacheBox?.close();
    _initialized = false;
  }

  static Set<String> get keys => _cacheBox?.keys.cast<String>().toSet() ?? {};
}
