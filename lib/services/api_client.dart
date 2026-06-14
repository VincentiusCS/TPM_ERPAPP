import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ApiClient wraps Dio with base URL configuration, Bearer token injection,
/// and automatic 401 handling (redirect to login).
class ApiClient {
  // Ganti IP di bawah dengan IP komputer kamu (jalankan: ipconfig)
  // Emulator Android: 10.0.2.2 | HP fisik: IP WiFi komputer | Web: localhost
  static const String _defaultBaseUrl = 'http://172.20.10.8:8000/api/v1';

  late final Dio _dio;
  final GlobalKey<NavigatorState>? navigatorKey;

  ApiClient({String? baseUrl, this.navigatorKey}) {
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl ?? _defaultBaseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(onRequest: _onRequest, onError: _onError),
    );
  }

  Dio get dio => _dio;

  /// Injects Bearer token into every request if available.
  Future<void> _onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  /// Handles 401 errors by clearing the token and redirecting to login.
  Future<void> _onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.response?.statusCode == 401) {
      // Clear stored token
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth_token');

      // Navigate to login screen if navigator key is available
      if (navigatorKey?.currentState != null) {
        navigatorKey!.currentState!.pushNamedAndRemoveUntil(
          '/login',
          (route) => false,
        );
      }
    }
    handler.next(err);
  }

  // --- HTTP convenience methods ---

  Future<Response> get(String path, {Map<String, dynamic>? queryParameters}) {
    return _dio.get(path, queryParameters: queryParameters);
  }

  Future<Response> post(String path, {dynamic data}) {
    return _dio.post(path, data: data);
  }

  Future<Response> put(String path, {dynamic data}) {
    return _dio.put(path, data: data);
  }

  Future<Response> delete(String path) {
    return _dio.delete(path);
  }

  Future<Response> download(
    String path,
    String savePath, {
    Map<String, dynamic>? queryParameters,
  }) {
    return _dio.download(path, savePath, queryParameters: queryParameters);
  }
}
