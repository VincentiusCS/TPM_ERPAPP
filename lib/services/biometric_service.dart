import 'package:local_auth/local_auth.dart';
import 'package:local_auth/error_codes.dart' as auth_error;

/// BiometricService mengelola autentikasi sidik jari menggunakan local_auth.
class BiometricService {
  final LocalAuthentication _localAuth;

  BiometricService({LocalAuthentication? localAuth})
      : _localAuth = localAuth ?? LocalAuthentication();

  /// Memeriksa apakah perangkat mendukung biometrik dan memiliki sidik jari terdaftar.
  /// Returns: (isAvailable, errorMessage?)
  Future<({bool isAvailable, String? errorMessage})>
      checkBiometricAvailability() async {
    try {
      final canAuthenticateWithBiometrics = await _localAuth.canCheckBiometrics;
      if (!canAuthenticateWithBiometrics) {
        return (
          isAvailable: false,
          errorMessage: 'Perangkat tidak mendukung biometrik',
        );
      }

      final isDeviceSupported = await _localAuth.isDeviceSupported();
      if (!isDeviceSupported) {
        return (
          isAvailable: false,
          errorMessage: 'Perangkat tidak mendukung biometrik',
        );
      }

      final availableBiometrics = await _localAuth.getAvailableBiometrics();
      if (availableBiometrics.isEmpty) {
        return (
          isAvailable: false,
          errorMessage: 'Daftarkan sidik jari di pengaturan perangkat',
        );
      }

      return (isAvailable: true, errorMessage: null);
    } catch (e) {
      return (
        isAvailable: false,
        errorMessage: 'Perangkat tidak mendukung biometrik',
      );
    }
  }

  /// Menjalankan autentikasi sidik jari.
  /// Returns: (success, errorMessage?)
  Future<({bool success, String? errorMessage})> authenticate() async {
    // Check availability first
    final availability = await checkBiometricAvailability();
    if (!availability.isAvailable) {
      return (success: false, errorMessage: availability.errorMessage);
    }

    try {
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Verifikasi sidik jari untuk melanjutkan login',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );

      if (authenticated) {
        return (success: true, errorMessage: null);
      } else {
        return (
          success: false,
          errorMessage: 'Autentikasi biometrik gagal',
        );
      }
    } on Exception catch (e) {
      final errorString = e.toString();

      // User cancelled the authentication
      if (errorString.contains(auth_error.lockedOut) ||
          errorString.contains(auth_error.permanentlyLockedOut)) {
        return (
          success: false,
          errorMessage: 'Autentikasi biometrik gagal',
        );
      }

      // Handle PlatformException for user cancellation
      if (errorString.contains('auth_in_progress') ||
          errorString.contains('user_cancel') ||
          errorString.contains('AuthenticationCanceled')) {
        return (
          success: false,
          errorMessage: 'Autentikasi biometrik dibatalkan',
        );
      }

      return (
        success: false,
        errorMessage: 'Autentikasi biometrik gagal',
      );
    }
  }
}
