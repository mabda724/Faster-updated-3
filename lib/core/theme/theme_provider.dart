import 'package:flutter/material.dart';
import '../security/secure_storage_service.dart';

class ThemeProvider extends ChangeNotifier {
  static const _key = 'dark_mode';
  bool _isDarkMode = false;

  bool get isDarkMode => _isDarkMode;
  ThemeMode get themeMode => _isDarkMode ? ThemeMode.dark : ThemeMode.light;

  ThemeProvider() {
    _load();
  }

  void _load() async {
    try {
      final val = SecureStorageService.themeMode;
      _isDarkMode = val == 'dark';
    } catch (_) {
      _isDarkMode = false;
    }
    notifyListeners();
  }

  Future<void> toggleDarkMode(bool value) async {
    _isDarkMode = value;
    notifyListeners();
    await SecureStorageService.write(_key, value ? 'dark' : 'light');
  }
}
