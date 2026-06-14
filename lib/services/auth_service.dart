import 'package:shared_preferences/shared_preferences.dart';

import '../models/user.dart';
import 'api_client.dart';

/// AuthService handles authentication API calls and token persistence.
class AuthService {
  final ApiClient _apiClient;

  AuthService({required ApiClient apiClient}) : _apiClient = apiClient;

  /// Login with email and password.
  /// POST /auth/login → returns {token, user}
  /// Saves token to SharedPreferences on success.
  Future<({String token, User user})> login(
    String email,
    String password,
  ) async {
    final response = await _apiClient.post(
      '/auth/login',
      data: {'email': email, 'password': password},
    );

    final data = response.data as Map<String, dynamic>;
    final token = data['token'] as String;
    final user = User.fromJson(data['user'] as Map<String, dynamic>);

    // Persist token
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);

    return (token: token, user: user);
  }

  /// Logout the current user.
  /// POST /auth/logout → returns 200
  /// Removes token from SharedPreferences.
  Future<void> logout() async {
    try {
      await _apiClient.post('/auth/logout');
    } finally {
      // Always clear token locally, even if the API call fails
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth_token');
    }
  }

  /// Check if a stored token exists (for restoring session on app start).
  Future<String?> getStoredToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  /// Update the authenticated user's profile name.
  /// PUT /auth/profile → returns {message, user}
  Future<User> updateProfile({required String name}) async {
    final response = await _apiClient.put(
      '/auth/profile',
      data: {'name': name},
    );
    final data = response.data as Map<String, dynamic>;
    return User.fromJson(data['user'] as Map<String, dynamic>);
  }
}
