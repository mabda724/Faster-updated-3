import 'package:supabase_flutter/supabase_flutter.dart';

/// Unified error handling utilities
class ErrorHandler {
  /// Handle errors from async operations and return a user-friendly message
  static String getErrorMessage(Object error, {String defaultMessage = 'حدث خطأ غير متوقع'}) {
    if (error is AuthException) {
      return _getAuthErrorMessage(error.message);
    }
    if (error is PostgrestException) {
      return 'خطأ في قاعدة البيانات: ${error.message}';
    }
    if (error is StorageException) {
      return 'خطأ في التخزين: ${error.message}';
    }
    if (error is FormatException) {
      return 'بيانات غير صالحة';
    }
    return error.toString().isNotEmpty ? error.toString() : defaultMessage;
  }

  static String _getAuthErrorMessage(String message) {
    if (message.contains('Invalid login credentials')) {
      return 'البريد الإلكتروني أو كلمة المرور غير صحيحة';
    }
    if (message.contains('User already registered')) {
      return 'هذا البريد الإلكتروني مسجل مسبقاً';
    }
    if (message.contains('Password should be at least')) {
      return 'كلمة المرور يجب أن تكون 6 أحرف على الأقل';
    }
    if (message.contains('Unable to validate email')) {
      return 'البريد الإلكتروني غير صحيح';
    }
    return message;
  }
}

/// Custom exceptions for the application
class AppException implements Exception {
  final String message;
  final String? code;
  
  const AppException(this.message, {this.code});
  
  @override
  String toString() => 'AppException($code): $message';
}

class NetworkException extends AppException {
  const NetworkException([super.message = 'خطأ في الاتصال بالشبكة']) : super(code: 'network_error');
}

class CacheException extends AppException {
  const CacheException([super.message = 'خطأ في التخزين المؤقت']) : super(code: 'cache_error');
}

class ValidationException extends AppException {
  const ValidationException([super.message = 'بيانات غير صالحة']) : super(code: 'validation_error');
}
