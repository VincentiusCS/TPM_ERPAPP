# Rencana Implementasi: Autentikasi Biometrik dan Validasi Lokasi (LBS)

## Overview

Implementasi fitur login multi-tahap (kredensial → biometrik → lokasi GPS) di sisi Flutter. Tidak ada perubahan backend. Menggunakan paket `local_auth` untuk biometrik dan `geolocator` untuk GPS dengan formula Haversine untuk kalkulasi jarak.

## Tasks

- [ ] 1. Setup dependensi dan model data
  - [x] 1.1 Tambahkan paket `local_auth` dan `geolocator` ke `pubspec.yaml`
    - Tambahkan `local_auth: ^2.1.0` dan `geolocator: ^10.1.0` di dependencies
    - Tambahkan `glados` di dev_dependencies untuk property-based testing
    - Jalankan `flutter pub get`
    - _Requirements: 1.5, 2.1_

  - [x] 1.2 Buat enum `LoginStep` dan model `LoginResult`
    - Buat file `lib/models/login_step.dart`
    - Definisikan enum `LoginStep { idle, credentials, biometric, location, success, failed }`
    - Definisikan class `LoginResult` dengan field `success`, `failedAt`, dan `errorMessage`
    - _Requirements: 3.1, 3.3_

- [ ] 2. Implementasi BiometricService
  - [x] 2.1 Buat `lib/services/biometric_service.dart`
    - Implementasi class `BiometricService` dengan dependency injection `LocalAuthentication`
    - Implementasi method `checkBiometricAvailability()` yang memeriksa hardware biometrik dan sidik jari terdaftar
    - Implementasi method `authenticate()` yang menjalankan autentikasi sidik jari via `local_auth`
    - Tangani kasus: hardware tidak tersedia, tidak ada sidik jari terdaftar, user membatalkan, autentikasi gagal
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 4.3, 4.4_

  - [x] 2.2 Tulis unit test untuk BiometricService
    - Buat file `test/services/biometric_service_test.dart`
    - Test `authenticate()` sukses ketika `local_auth` berhasil
    - Test `authenticate()` gagal ketika sidik jari tidak cocok
    - Test `checkBiometricAvailability()` false ketika hardware tidak ada
    - Test `checkBiometricAvailability()` false ketika tidak ada sidik jari terdaftar
    - Test user membatalkan biometric prompt
    - _Requirements: 1.2, 1.3, 1.4, 4.3, 4.4_

- [ ] 3. Implementasi LocationService
  - [x] 3.1 Buat `lib/services/location_service.dart`
    - Implementasi class `LocationService` dengan konstanta referensi (lat: -7.7533720, lon: 110.4290118, radius: 100m, timeout: 15s)
    - Implementasi method `checkLocationPermission()` yang memeriksa status layanan GPS dan izin lokasi
    - Implementasi method `calculateHaversineDistance(lat1, lon1, lat2, lon2)` menggunakan formula Haversine
    - Implementasi method `validateLocation()` yang mengambil koordinat GPS dan memvalidasi jarak ke titik referensi
    - Tangani kasus: GPS tidak aktif, izin ditolak, izin ditolak permanen, timeout 15 detik
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 4.1, 4.2_

  - [x] 3.2 Tulis property test untuk formula Haversine
    - **Property 3: Kebenaran Formula Haversine**
    - Buat file `test/services/location_service_property_test.dart`
    - Generator: random pairs of valid latitude (-90..90) dan longitude (-180..180)
    - Assertion: hasil `calculateHaversineDistance` sama dengan implementasi referensi (toleransi ≤ 0.01 meter)
    - Minimum 100 iterasi
    - **Validates: Requirements 2.2**

  - [x] 3.3 Tulis property test untuk threshold validasi lokasi
    - **Property 4: Threshold Validasi Lokasi**
    - Tambahkan di file `test/services/location_service_property_test.dart`
    - Generator: random koordinat GPS di sekitar titik referensi (mix dalam dan luar radius)
    - Assertion: `isWithinRadius == (haversineDistance <= 100.0)`
    - Minimum 100 iterasi
    - **Validates: Requirements 2.3, 2.4**

  - [x] 3.4 Tulis unit test untuk LocationService
    - Buat file `test/services/location_service_test.dart`
    - Test `validateLocation()` sukses dengan koordinat di dalam radius
    - Test `validateLocation()` gagal dengan koordinat di luar radius
    - Test `checkLocationPermission()` mendeteksi izin ditolak permanen
    - Test GPS timeout setelah 15 detik
    - Test GPS service tidak aktif
    - _Requirements: 2.3, 2.4, 2.5, 2.6, 4.1, 4.2_

- [x] 4. Checkpoint - Pastikan semua test service berjalan
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 5. Modifikasi AuthProvider untuk alur login multi-tahap
  - [x] 5.1 Tambahkan dependency BiometricService dan LocationService ke AuthProvider
    - Modifikasi `lib/providers/auth_provider.dart`
    - Tambahkan field `BiometricService` dan `LocationService` sebagai dependency
    - Tambahkan state `LoginStep _currentStep` dan `String? _errorMessage`
    - Tambahkan getter `currentStep` dan `errorMessage`
    - _Requirements: 3.1_

  - [x] 5.2 Implementasi alur login sequential di AuthProvider
    - Modifikasi method `login(email, password)` untuk menjalankan flow: kredensial → biometrik → lokasi
    - Update `_currentStep` di setiap tahap dan panggil `notifyListeners()`
    - Implementasi fail-fast: jika tahap gagal, hentikan proses dan set error message
    - Jika semua tahap berhasil, set `_currentStep = LoginStep.success` dan navigasi ke dashboard
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5_

  - [x] 5.3 Tulis property test untuk urutan validasi dan fail-fast
    - **Property 1: Urutan Validasi dan Fail-Fast**
    - Buat file `test/providers/auth_provider_property_test.dart`
    - Generator: random combination of (credential_result, biometric_result, location_result) sebagai boolean
    - Assertion: jika step N gagal, step N+1 tidak pernah dipanggil; failedAt menunjukkan step yang benar
    - Minimum 100 iterasi
    - **Validates: Requirements 1.1, 2.1, 3.1, 3.3**

  - [x] 5.4 Tulis property test untuk login sukses
    - **Property 2: Semua Tahap Berhasil Menghasilkan Login Sukses**
    - Tambahkan di file `test/providers/auth_provider_property_test.dart`
    - Generator: random valid credentials, biometric success, location within radius
    - Assertion: login result selalu success
    - Minimum 100 iterasi
    - **Validates: Requirements 3.2**

  - [x] 5.5 Tulis unit test untuk AuthProvider login flow
    - Buat file `test/providers/auth_provider_login_test.dart`
    - Test login sukses ketika semua tahap berhasil
    - Test login gagal di tahap kredensial tidak melanjutkan ke biometrik
    - Test login gagal di tahap biometrik tidak melanjutkan ke lokasi
    - Test `currentStep` ter-update dengan benar di setiap tahap
    - Test cancellation di tahap biometrik
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5_

- [x] 6. Checkpoint - Pastikan semua test provider berjalan
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 7. Modifikasi LoginScreen untuk UI multi-tahap
  - [x] 7.1 Tambahkan step indicator dan loading state di LoginScreen
    - Modifikasi `lib/screens/login_screen.dart`
    - Tambahkan widget step indicator yang menampilkan tahap login saat ini (kredensial / biometrik / lokasi)
    - Tampilkan `CircularProgressIndicator` atau indikator loading saat validasi biometrik atau lokasi berlangsung
    - Consume `currentStep` dari AuthProvider untuk menentukan state UI
    - _Requirements: 3.4_

  - [x] 7.2 Tambahkan pesan error kontekstual per tahap di LoginScreen
    - Tampilkan pesan error spesifik berdasarkan `currentStep` dan `errorMessage` dari AuthProvider
    - Untuk biometrik gagal: tampilkan pesan dan opsi retry
    - Untuk lokasi gagal: tampilkan pesan jarak/izin dan opsi retry atau buka Settings
    - Untuk perangkat tidak kompatibel: tampilkan pesan final tanpa retry
    - _Requirements: 1.3, 1.4, 2.4, 2.5, 2.6, 3.3, 4.1, 4.2, 4.4_

- [ ] 8. Integrasi dan wiring akhir
  - [x] 8.1 Register BiometricService dan LocationService di dependency injection
    - Pastikan BiometricService dan LocationService di-inject ke AuthProvider (via constructor atau provider setup)
    - Update konfigurasi provider di `main.dart` atau file setup yang sesuai
    - _Requirements: 3.1_

  - [x] 8.2 Tulis widget test untuk LoginScreen multi-tahap
    - Buat file `test/screens/login_screen_multistep_test.dart`
    - Test step indicator muncul saat proses login berjalan
    - Test pesan error kontekstual ditampilkan sesuai tahap yang gagal
    - Test loading indicator muncul saat validasi berlangsung
    - _Requirements: 3.3, 3.4_

- [x] 9. Final checkpoint - Pastikan semua test berjalan dan fitur terintegrasi
  - Ensure all tests pass, ask the user if questions arise.

## Catatan

- Tasks bertanda `*` bersifat opsional dan dapat dilewati untuk MVP lebih cepat
- Setiap task mereferensikan kebutuhan spesifik untuk traceability
- Checkpoint memastikan validasi inkremental di setiap fase
- Property tests memvalidasi kebenaran universal (formula Haversine, urutan validasi)
- Unit tests memvalidasi contoh spesifik dan edge case
- Semua implementasi di sisi Flutter saja, tidak ada perubahan backend
