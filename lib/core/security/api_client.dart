import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'ssl_pinning_interceptor.dart';
import 'secure_storage_service.dart';
import 'app_sec_config.dart';
import 'api_honeypot_interceptor.dart';

class ApiClient {
  static ApiClient? _instance;
  late final Dio _dio;

  ApiClient._() {
    _dio = Dio(_baseOptions);
    _dio.interceptors.addAll([
      _AuthInterceptor(),
      SslPinningInterceptor(AppSecConfig.sslPinnedHosts),
      ApiHoneypotInterceptor(),
      _LoggingInterceptor(),
    ]);
  }

  static ApiClient get instance {
    _instance ??= ApiClient._();
    return _instance!;
  }

  static Dio get dio => instance._dio;

  static BaseOptions get _baseOptions => BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
    sendTimeout: const Duration(seconds: 15),
    headers: {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'X-Client-Version': '1.0.1',
    },
  );
}

class _AuthInterceptor extends Interceptor {
  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = SecureStorageService.authToken;
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }
}

class _LoggingInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response?.statusCode == 401) {
      debugPrint('Auth token expired - clearing');
      SecureStorageService.authToken = null;
    }
    handler.next(err);
  }
}
