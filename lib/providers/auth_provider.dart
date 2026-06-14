import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../models/login_step.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/biometric_service.dart';
import '../services/location_service.dart';

/// AuthProvider manages authentication state using ChangeNotifier.
/// Exposes: isLoggedIn, currentUser, login(), logout(), checkAuth().
class AuthProvider extends ChangeNotifier {
  final AuthService _authService;
  final BiometricService _biometricService;
  final LocationService _locationService;

  String? _token;
  User? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;
  LoginStep _currentStep = LoginStep.idle;
  String? _locationAddress;

  AuthProvider({
    required AuthService authService,
    required BiometricService biometricService,
    required LocationService locationService,
  })  : _authService = authService,
        _biometricService = biometricService,
        _locationService = locationService {
    checkAuth();
  }

  // --- Getters ---

  bool get isLoggedIn => _token != null;
  bool get isAuthenticated => _token != null;
  bool get isLoading => _isLoading;
  String? get token => _token;
  User? get currentUser => _currentUser;
  String? get errorMessage => _errorMessage;
  LoginStep get currentStep => _currentStep;
  String? get locationAddress => _locationAddress;

  // --- Methods ---

  /// Check if a stored token exists and restore session.
  Future<void> checkAuth() async {
    _isLoading = true;
    notifyListeners();

    try {
      final storedToken = await _authService.getStoredToken();
      if (storedToken != null && storedToken.isNotEmpty) {
        _token = storedToken;
      } else {
        _token = null;
        _currentUser = null;
      }
    } catch (_) {
      _token = null;
      _currentUser = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Login with email and password.
  /// Sequential flow: credentials → biometric → location.
  /// Returns true if all steps pass, false if any step fails.
  /// Note: Token is KEPT even if biometric/location fails (to avoid re-authentication on retry).
  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    _currentStep = LoginStep.credentials;
    notifyListeners();

    // Step 1: Credential validation
    try {
      final result = await _authService.login(email, password);
      _token = result.token;
      _currentUser = result.user;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        _errorMessage = 'Email atau password salah.';
      } else {
        _errorMessage =
            e.response?.data?['message'] as String? ?? 'Login gagal.';
      }
      _currentStep = LoginStep.failed;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Terjadi kesalahan. Silakan coba lagi.';
      _currentStep = LoginStep.failed;
      _isLoading = false;
      notifyListeners();
      return false;
    }

    // Step 2: Biometric authentication
    _currentStep = LoginStep.biometric;
    notifyListeners();

    final biometricResult = await _biometricService.authenticate();
    if (!biometricResult.success) {
      _errorMessage =
          biometricResult.errorMessage ?? 'Autentikasi biometrik gagal';
      _currentStep = LoginStep.failed;
      _isLoading = false;
      notifyListeners();
      return false;
    }

    // Step 3: Location validation
    _currentStep = LoginStep.location;
    notifyListeners();

    final locationResult = await _locationService.validateLocation();
    _locationAddress = locationResult.address;
    if (!locationResult.isWithinRadius) {
      _errorMessage =
          locationResult.errorMessage ?? 'Validasi lokasi gagal';
      _currentStep = LoginStep.failed;
      _isLoading = false;
      notifyListeners();
      return false;
    }

    // All steps passed
    _currentStep = LoginStep.success;
    _errorMessage = null;
    _isLoading = false;
    notifyListeners();
    return true;
  }

  /// Update the current user's name and persist to backend.
  Future<bool> updateName(String newName) async {
    if (_currentUser == null || newName.trim().isEmpty) return false;

    try {
      final updatedUser = await _authService.updateProfile(name: newName.trim());
      _currentUser = updatedUser;
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Logout the current user and clear state.
  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _authService.logout();
    } finally {
      _token = null;
      _currentUser = null;
      _errorMessage = null;
      _currentStep = LoginStep.idle;
      _locationAddress = null;
      _isLoading = false;
      notifyListeners();
    }
  }
}
