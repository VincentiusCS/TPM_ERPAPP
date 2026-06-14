/// Enum yang merepresentasikan tahap-tahap dalam proses login multi-tahap.
enum LoginStep {
  idle, // Belum mulai
  credentials, // Sedang validasi email/password
  biometric, // Sedang autentikasi sidik jari
  location, // Sedang validasi lokasi GPS
  success, // Semua tahap berhasil
  failed, // Salah satu tahap gagal
}

/// Hasil dari proses login multi-tahap.
class LoginResult {
  final bool success;
  final LoginStep failedAt;
  final String? errorMessage;

  const LoginResult({
    required this.success,
    this.failedAt = LoginStep.idle,
    this.errorMessage,
  });
}
