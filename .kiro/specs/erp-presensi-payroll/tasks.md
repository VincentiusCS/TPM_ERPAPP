# Rencana Implementasi: ERP Presensi dan Payroll

## Ikhtisar

Implementasi dilakukan secara bertahap: dimulai dari fondasi backend Laravel (autentikasi, model, migrasi), dilanjutkan ke setiap modul API, kemudian fondasi Flutter (struktur proyek, service layer), dan terakhir setiap layar Flutter beserta integrasi sensor dan fitur tambahan.

---

## Tugas

- [x] 1. Setup Backend Laravel — Fondasi Proyek
  - Inisialisasi proyek Laravel, konfigurasi `.env` untuk koneksi MySQL
  - Install Laravel Sanctum (`composer require laravel/sanctum`) dan publish konfigurasi
  - Buat file migrasi untuk tabel: `users`, `employees`, `shifts`, `attendances`, `payrolls`, `currency_logs`
  - Jalankan `php artisan migrate` dan buat seeder untuk akun Admin awal
  - Daftarkan `HasApiTokens` pada model `User` dan aktifkan middleware Sanctum di `api` guard
  - _Kebutuhan: 1.1, 1.4_

- [x] 2. Implementasi Modul Autentikasi (Backend)
  - [x] 2.1 Buat `AuthController` dengan method `login` dan `logout`
    - `login`: validasi email+password, kembalikan token Sanctum dan data user
    - `logout`: cabut token aktif dengan `$request->user()->currentAccessToken()->delete()`
    - Daftarkan route `POST /api/v1/auth/login` (publik) dan `POST /api/v1/auth/logout` (protected)
    - _Kebutuhan: 1.1, 1.2, 1.3_

  - [x] 2.2 Tulis unit test untuk AuthController
    - Test login dengan kredensial valid → HTTP 200 + token
    - Test login dengan kredensial tidak valid → HTTP 401
    - Test logout dengan token valid → HTTP 200, token dicabut
    - Test akses endpoint protected tanpa token → HTTP 401
    - _Kebutuhan: 1.1, 1.2, 1.3, 1.4_

  - [x] 2.3 Tulis property test untuk Properti 9: Proteksi Rute Terautentikasi
    - **Properti 9: Proteksi Rute Terautentikasi**
    - **Memvalidasi: Kebutuhan 1.4, 1.5**
    - Untuk setiap endpoint protected dan setiap token tidak valid/kosong, respons harus HTTP 401
    - Gunakan `@dataProvider` PHPUnit dengan daftar semua endpoint protected dan variasi token invalid

- [x] 3. Implementasi Modul Karyawan (Backend)
  - [x] 3.1 Buat model `Employee`, `EmployeeController`, dan route CRUD
    - Model: field `employee_name`, `phone`, `address`, `status` (enum: aktif|nonaktif)
    - Controller: method `index`, `store`, `update`, `destroy`
    - Validasi di `store` dan `update`: field wajib tidak boleh kosong atau hanya whitespace
    - Route: `GET/POST /api/v1/employees`, `PUT/DELETE /api/v1/employees/{id}` (semua protected)
    - Pada `destroy`: cek relasi ke `attendances` dan `payrolls`, kembalikan HTTP 409 jika ada
    - _Kebutuhan: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6_

  - [x] 3.2 Tulis unit test untuk EmployeeController
    - Test `index` mengembalikan daftar karyawan
    - Test `store` dengan data valid → HTTP 201
    - Test `store` dengan field kosong → HTTP 422 dengan pesan per field
    - Test `update` dan `destroy` normal
    - Test `destroy` karyawan dengan data terkait → HTTP 409
    - _Kebutuhan: 2.1–2.6_

  - [x] 3.3 Tulis property test untuk Properti 3: Validasi Input Karyawan
    - **Properti 3: Validasi Input Karyawan**
    - **Memvalidasi: Kebutuhan 2.3**
    - Untuk setiap string yang hanya berisi whitespace atau string kosong pada field wajib, sistem harus menolak dan mengembalikan HTTP 422

- [x] 4. Implementasi Modul Shift (Backend)
  - [x] 4.1 Buat model `Shift`, `ShiftController`, dan route
    - Model: field `employee_id` (FK), `shift_date`, `wage_per_shift` (default 50000)
    - Controller: method `index`, `store`, `destroy`
    - Validasi di `store`: cek duplikat shift (employee_id + shift_date) → HTTP 409 jika sudah ada
    - Route: `GET/POST /api/v1/shifts`, `DELETE /api/v1/shifts/{id}` (semua protected)
    - _Kebutuhan: 3.1, 3.2, 3.3, 3.4_

  - [x] 4.2 Tulis unit test untuk ShiftController
    - Test `store` shift baru → HTTP 201
    - Test `store` shift duplikat (employee + tanggal sama) → HTTP 409
    - Test `destroy` → HTTP 200, data terhapus
    - _Kebutuhan: 3.1, 3.3, 3.4_

  - [x] 4.3 Tulis property test untuk Properti 2: Shift Unik per Karyawan per Tanggal
    - **Properti 2: Shift Unik per Karyawan per Tanggal**
    - **Memvalidasi: Kebutuhan 3.3**
    - Untuk setiap kombinasi employee_id dan shift_date, tidak boleh ada dua record shift yang sama di database

- [x] 5. Implementasi Modul Presensi (Backend)
  - [x] 5.1 Buat model `Attendance`, `AttendanceController`, dan route
    - Model: field `employee_id` (FK), `shift_id` (FK), `attendance_date`, `status` (enum: hadir|tidak hadir)
    - Controller: method `index` (dengan filter `employee_id`, `date_from`, `date_to`), `store`, `update`
    - Validasi di `store`: `employee_id` dan `shift_id` wajib ada → HTTP 422 jika tidak
    - Route: `GET/POST /api/v1/attendances`, `PUT /api/v1/attendances/{id}` (semua protected)
    - _Kebutuhan: 4.1, 4.2, 4.3, 4.4, 4.5_

  - [x] 5.2 Tulis unit test untuk AttendanceController
    - Test `store` dengan data lengkap → HTTP 201
    - Test `store` tanpa `employee_id` atau `shift_id` → HTTP 422
    - Test `update` status presensi → HTTP 200
    - Test `index` dengan filter employee_id dan rentang tanggal
    - _Kebutuhan: 4.1–4.5_

  - [x] 5.3 Tulis property test untuk Properti 4: Validasi Input Presensi
    - **Properti 4: Validasi Input Presensi**
    - **Memvalidasi: Kebutuhan 4.5**
    - Untuk setiap request tanpa `employee_id` atau `shift_id`, sistem harus mengembalikan HTTP 422

  - [x] 5.4 Tulis property test untuk Properti 5: Filter Presensi Konsisten
    - **Properti 5: Filter Presensi Konsisten**
    - **Memvalidasi: Kebutuhan 4.4**
    - Untuk setiap query filter dengan `employee_id` dan rentang tanggal, semua hasil harus memiliki `employee_id` yang sesuai dan `attendance_date` dalam rentang yang diminta

- [-] 6. Implementasi Modul Payroll (Backend)
  - [x] 6.1 Buat model `Payroll`, `PayrollController`, dan route
    - Controller method `index`: terima `period_start`, `period_end`, `search`; hitung payroll dari tabel `attendances` dengan status "hadir"; rumus: `total_salary = jumlah_hadir × 50000`
    - Jika tidak ada data presensi dalam periode → kembalikan HTTP 200 dengan `total = 0` dan pesan informatif
    - Simpan atau update record `payrollhs` saat kalkulasi dilakukan
    - Route: `GET /api/v1/payrolls` (protected)
    - _Kebutuhan: 5.1, 5.2, 5.3, 5.4, 5.8_

  - [x] 6.2 Tulis unit test untuk PayrollController
    - Test kalkulasi dengan N kehadiran → `total_salary = N × 50000`
    - Test periode tanpa data → HTTP 200, `total = 0`, pesan informatif
    - Test filter pencarian nama karyawan
    - _Kebutuhan: 5.1, 5.2, 5.3, 5.4, 5.8_

  - [x] 6.3 Tulis property test untuk Properti 1: Kalkulasi Payroll Konsisten
    - **Properti 1: Kalkulasi Payroll Konsisten**
    - **Memvalidasi: Kebutuhan 5.1, 5.2**
    - Untuk setiap N kehadiran acak (0–100), `total_salary` harus selalu = N × 50000 tanpa memandang urutan data

  - [x] 6.4 Tulis property test untuk Properti 10: Payroll Periode Kosong
    - **Properti 10: Payroll Periode Kosong**
    - **Memvalidasi: Kebutuhan 5.8**
    - Untuk setiap periode yang tidak memiliki presensi "hadir", sistem harus mengembalikan `total_salary = 0` dan pesan informatif, bukan error

  - [x] 6.5 Implementasi endpoint unduh laporan dan slip gaji
    - `GET /api/v1/payrolls/download/report`: generate PDF atau Excel menggunakan library (`barryvdh/laravel-dompdf` atau `maatwebsite/excel`)
    - `GET /api/v1/payrolls/{employee_id}/slip`: generate PDF slip gaji per karyawan
    - Setelah file berhasil dibuat, kembalikan response file download
    - _Kebutuhan: 5.5, 5.6, 5.7_

- [ ] 7. Implementasi Modul Konversi Mata Uang (Backend)
  - [x] 7.1 Buat `CurrencyController` dan route
    - Method `convert`: terima `payroll_id`, `amount_idr`, `target_currency`
    - Panggil `https://v6.exchangerate-api.com/v6/{API_KEY}/latest/IDR` untuk mendapatkan kurs
    - Hitung `converted_amount = amount_idr × exchange_rate`
    - Simpan log ke tabel `currency_logs` dengan `payroll_id`, `currency_type`, `exchange_rate`, `converted_total`
    - Jika API gagal → kembalikan HTTP 503 dengan pesan error
    - Route: `POST /api/v1/currency/convert` (protected)
    - _Kebutuhan: 6.1, 6.2, 6.3, 6.4, 6.5_

  - [x] 7.2 Tulis unit test untuk CurrencyController
    - Test konversi berhasil (mock HTTP client) → HTTP 200, log tersimpan
    - Test API kurs gagal → HTTP 503
    - Test mata uang tidak didukung → HTTP 422
    - _Kebutuhan: 6.1–6.5_

  - [x] 7.3 Tulis property test untuk Properti 6: Konversi Mata Uang Round-Trip
    - **Properti 6: Konversi Mata Uang Round-Trip**
    - **Memvalidasi: Kebutuhan 6.1, 6.3**
    - Untuk setiap nilai IDR acak dan kurs acak, konversi IDR→target→IDR harus menghasilkan nilai mendekati IDR awal (toleransi 0.01)

  - [x] 7.4 Tulis property test untuk Properti 7: Log Konversi Tersimpan
    - **Properti 7: Log Konversi Tersimpan**
    - **Memvalidasi: Kebutuhan 6.5**
    - Untuk setiap konversi yang berhasil, harus ada tepat satu entri baru di `currency_logs` dengan nilai `payroll_id`, `currency_type`, `exchange_rate`, dan `converted_total` yang benar

- [ ] 8. Implementasi Modul Chatbot AI (Backend)
  - [x] 8.1 Buat `ChatbotController` dan route
    - Method `scenarios`: kembalikan daftar skenario simulasi yang tersedia (hardcoded atau dari config)
    - Method `message`: terima `scenario_id`, `session_id`, `message`; kirim ke Gemini API dengan system prompt yang sesuai skenario; kembalikan balasan
    - Method `feedback`: kirim riwayat sesi ke Gemini API untuk evaluasi; kembalikan feedback kualitas respons
    - Jika Gemini API gagal → kembalikan HTTP 502, pertahankan sesi
    - Route: `GET /api/v1/chatbot/scenarios`, `POST /api/v1/chatbot/message`, `POST /api/v1/chatbot/feedback` (semua protected)
    - _Kebutuhan: 8.1, 8.2, 8.3, 8.5_

  - [x] 8.2 Tulis unit test untuk ChatbotController
    - Test `scenarios` → HTTP 200 dengan daftar skenario
    - Test `message` berhasil (mock Gemini API) → HTTP 200 dengan balasan
    - Test `message` saat Gemini gagal → HTTP 502
    - Test `feedback` berhasil (mock Gemini API) → HTTP 200 dengan evaluasi
    - _Kebutuhan: 8.1, 8.2, 8.3, 8.5_

- [x] 9. Checkpoint Backend — Pastikan Semua Test Lulus
  - Jalankan `php artisan test` dan pastikan semua unit test dan property test lulus
  - Verifikasi semua endpoint dapat diakses dengan Postman atau tool sejenis
  - Tanyakan kepada pengguna jika ada pertanyaan sebelum melanjutkan ke frontend

- [x] 10. Setup Frontend Flutter — Fondasi Proyek
  - Inisialisasi proyek Flutter, konfigurasi `pubspec.yaml` dengan dependensi:
    - `provider`, `dio` atau `http`, `sensor_plus`, `flutter_screen_orientation`
    - `intl`, `timezone`, `flutter_timezone` untuk konversi zona waktu
    - `pdf`, `open_file` atau `flutter_file_dialog` untuk membuka file unduhan
  - Buat struktur direktori: `lib/screens/`, `lib/services/`, `lib/providers/`, `lib/utils/`, `lib/models/`
  - Buat `ApiClient` (wrapper Dio/http) dengan base URL, interceptor untuk menyisipkan token Bearer, dan penanganan error 401 (redirect ke login)
  - Buat model Dart untuk: `User`, `Employee`, `Shift`, `Attendance`, `Payroll`, `CurrencyLog`
  - _Kebutuhan: 1.4, 1.5_

- [ ] 11. Implementasi Layar Autentikasi (Flutter)
  - [x] 11.1 Buat `AuthService` dan `AuthProvider`
    - `AuthService.login(email, password)`: POST ke `/api/v1/auth/login`, simpan token ke `SharedPreferences`
    - `AuthService.logout()`: POST ke `/api/v1/auth/logout`, hapus token dari storage
    - `AuthProvider`: kelola state `isLoggedIn`, expose method login/logout
    - _Kebutuhan: 1.1, 1.2, 1.3_

  - [x] 11.2 Buat `LoginScreen`
    - Form dengan field email dan password, tombol login
    - Tampilkan pesan error dari API jika login gagal (SnackBar)
    - Navigasi ke `DashboardScreen` setelah login berhasil
    - _Kebutuhan: 1.1, 1.2_

  - [x] 11.3 Implementasi route guard
    - Buat `AuthGuard` atau gunakan `AuthProvider` di `MaterialApp.router` untuk memblokir akses ke halaman selain login jika belum terautentikasi
    - Tangani HTTP 401 di `ApiClient` interceptor → hapus token, redirect ke `LoginScreen`
    - _Kebutuhan: 1.4, 1.5_

  - [x] 11.4 Tulis widget test untuk LoginScreen
    - Test form kosong → tampilkan validasi
    - Test login berhasil → navigasi ke dashboard
    - Test login gagal → tampilkan SnackBar error
    - _Kebutuhan: 1.1, 1.2_

- [ ] 12. Implementasi Layar Manajemen Karyawan (Flutter)
  - [x] 12.1 Buat `EmployeeService` dan `EmployeeProvider`
    - Service: method `getAll`, `create`, `update`, `delete` yang memanggil endpoint `/api/v1/employees`
    - Provider: kelola state daftar karyawan, loading, dan error
    - _Kebutuhan: 2.1–2.6_

  - [x] 12.2 Buat `EmployeeScreen` (daftar) dan form tambah/edit karyawan
    - Tampilkan daftar karyawan dengan nama, telepon, alamat, status
    - Tombol tambah → buka form, tombol edit per item → buka form dengan data terisi
    - Tombol hapus per item → tampilkan dialog konfirmasi; jika API kembalikan HTTP 409, tampilkan pesan bahwa karyawan memiliki data terkait
    - Tampilkan pesan validasi per field jika API kembalikan HTTP 422
    - _Kebutuhan: 2.1–2.6_

  - [x] 12.3 Tulis widget test untuk EmployeeScreen
    - Test daftar karyawan tampil
    - Test form validasi field kosong
    - Test dialog konfirmasi hapus
    - _Kebutuhan: 2.1–2.6_

- [ ] 13. Implementasi Layar Manajemen Shift (Flutter)
  - [x] 13.1 Buat `ShiftService` dan layar shift
    - Service: method `getAll`, `create`, `delete` yang memanggil endpoint `/api/v1/shifts`
    - `ShiftScreen`: tampilkan daftar shift, form tambah shift (pilih karyawan + tanggal), tombol hapus
    - Jika API kembalikan HTTP 409 (duplikat), tampilkan SnackBar pesan shift sudah ada
    - _Kebutuhan: 3.1, 3.2, 3.3, 3.4_

- [ ] 14. Implementasi Layar Presensi (Flutter)
  - [x] 14.1 Buat `AttendanceService` dan `AttendanceProvider`
    - Service: method `getAll(filters)`, `create`, `update` yang memanggil endpoint `/api/v1/attendances`
    - Provider: kelola state daftar presensi, filter aktif, loading
    - _Kebutuhan: 4.1–4.5_

  - [x] 14.2 Buat `AttendanceScreen`
    - Tampilkan riwayat presensi dengan filter nama karyawan dan rentang tanggal
    - Form catat presensi: pilih karyawan, shift, tanggal, status (hadir/tidak hadir)
    - Form edit status presensi yang sudah ada
    - Tampilkan pesan validasi jika karyawan atau shift tidak dipilih
    - _Kebutuhan: 4.1–4.5_

  - [x] 14.3 Tulis widget test untuk AttendanceScreen
    - Test filter presensi
    - Test form validasi tanpa karyawan/shift
    - _Kebutuhan: 4.1, 4.4, 4.5_

- [ ] 15. Implementasi Layar Payroll (Flutter)
  - [x] 15.1 Buat `PayrollService` dan `PayrollProvider`
    - Service: method `calculate(periodStart, periodEnd, search)`, `downloadReport(format)`, `downloadSlip(employeeId)`
    - Provider: kelola state hasil payroll, loading, error
    - _Kebutuhan: 5.1–5.8_

  - [x] 15.2 Buat `PayrollScreen`
    - Input periode (date picker untuk tanggal mulai dan akhir), tombol hitung
    - Tampilkan tabel hasil payroll: nama karyawan, jumlah kehadiran, total gaji
    - Field pencarian untuk filter nama karyawan
    - Tombol unduh laporan (PDF/Excel) dan unduh slip per karyawan
    - Tampilkan SnackBar notifikasi setelah unduhan berhasil
    - Tampilkan pesan informatif jika tidak ada data untuk periode yang dipilih
    - _Kebutuhan: 5.1–5.8_

  - [x] 15.3 Tulis widget test untuk PayrollScreen
    - Test tampilan hasil kalkulasi
    - Test pesan periode kosong
    - Test notifikasi unduhan berhasil
    - _Kebutuhan: 5.1, 5.7, 5.8_

- [ ] 16. Implementasi Layar Konversi Mata Uang (Flutter)
  - [x] 16.1 Buat `CurrencyService` dan `CurrencyScreen`
    - Service: method `convert(payrollId, amountIdr, targetCurrency)` yang memanggil `POST /api/v1/currency/convert`
    - `CurrencyScreen`: input nominal IDR, dropdown pilih mata uang tujuan (USD/EUR/GBP), tombol konversi
    - Tampilkan hasil konversi beserta kurs yang digunakan
    - Tampilkan pesan error jika API kurs gagal (HTTP 503)
    - _Kebutuhan: 6.1, 6.2, 6.3, 6.4, 6.5_

- [ ] 17. Implementasi Layar Konversi Zona Waktu (Flutter)
  - [x] 17.1 Buat `TimezoneUtil` dan `TimeScreen`
    - `TimezoneUtil`: gunakan package `timezone` untuk konversi antar WIB (Asia/Jakarta), WITA (Asia/Makassar), WIT (Asia/Jayapura), London (Europe/London)
    - Method `convert(DateTime dt, String fromTz, String toTz)` dan `getOffset(String fromTz, String toTz)`
    - `TimeScreen`: input waktu (time picker), dropdown zona asal dan tujuan, tombol konversi
    - Tampilkan hasil konversi dan selisih jam antar zona
    - Validasi format waktu, tampilkan pesan jika tidak valid
    - _Kebutuhan: 7.1, 7.2, 7.3, 7.4_

  - [ ]* 17.2 Tulis unit test untuk TimezoneUtil
    - Test konversi WIB → WITA, WIB → WIT, WIB → London
    - Test validasi input waktu tidak valid
    - _Kebutuhan: 7.1, 7.2, 7.4_

  - [ ]* 17.3 Tulis property test untuk Properti 8: Konversi Zona Waktu Round-Trip
    - **Properti 8: Konversi Zona Waktu Round-Trip**
    - **Memvalidasi: Kebutuhan 7.1, 7.2**
    - Untuk setiap DateTime acak dan pasangan zona waktu, konversi A→B→A harus menghasilkan DateTime yang sama dengan input awal

- [ ] 18. Implementasi Modul Sensor — Rotasi Layar Otomatis (Flutter)
  - [x] 18.1 Buat `SensorUtil` dan `SensorProvider`
    - `SensorUtil`: subscribe ke `accelerometerEventStream()` dari `sensor_plus`
    - Deteksi orientasi: jika `|x| > |y|` → landscape, jika `|y| > |x|` → portrait
    - Panggil `FlutterScreenOrientation.orientationAction()` untuk mengubah orientasi layar
    - `SensorProvider`: kelola state orientasi aktif, mulai/hentikan listener
    - Tangkap exception jika sensor tidak tersedia → graceful degradation (nonaktifkan fitur)
    - _Kebutuhan: 9.1, 9.2, 9.3, 9.4_

  - [x] 18.2 Integrasikan `SensorProvider` ke `main.dart`
    - Inisialisasi `SensorProvider` di root widget dan mulai listener saat app di foreground
    - Hentikan listener saat app di background menggunakan `AppLifecycleState`
    - _Kebutuhan: 9.3, 9.4_

- [ ] 19. Implementasi Modul Chatbot AI — Mini Game (Flutter)
  - [x] 19.1 Buat `ChatbotService` dan `ChatbotScreen`
    - Service: method `getScenarios()`, `sendMessage(scenarioId, sessionId, message)`, `getFeedback(sessionId)`
    - `ChatbotScreen`: tampilkan daftar skenario, setelah dipilih tampilkan UI chat
    - UI chat: daftar pesan (bubble chat), input teks, tombol kirim
    - Tampilkan feedback evaluasi di akhir sesi
    - Jika API gagal → tampilkan SnackBar error dan tombol coba lagi, pertahankan sesi
    - _Kebutuhan: 8.1, 8.2, 8.3, 8.5_

  - [x] 19.2 Implementasi gesture shake untuk reset sesi
    - Subscribe ke `gyroscopeEventStream()` dari `sensor_plus`
    - Deteksi shake: jika magnitude giroskop melebihi threshold (misal > 5.0 rad/s) dalam waktu singkat → trigger reset
    - Reset sesi: hapus riwayat chat, kembali ke halaman pemilihan skenario
    - _Kebutuhan: 8.4, 8.6_

  - [ ]* 19.3 Tulis widget test untuk ChatbotScreen
    - Test tampilan daftar skenario
    - Test pengiriman pesan dan tampilan balasan (mock service)
    - Test tampilan feedback di akhir sesi
    - Test tampilan error saat API gagal
    - _Kebutuhan: 8.1, 8.2, 8.3, 8.5_

- [ ] 20. Integrasi Akhir dan Wiring
  - [x] 20.1 Hubungkan semua Provider ke `MultiProvider` di `main.dart`
    - Daftarkan: `AuthProvider`, `EmployeeProvider`, `AttendanceProvider`, `PayrollProvider`, `SensorProvider`
    - Pastikan `ApiClient` menggunakan token dari `AuthProvider` via interceptor
    - _Kebutuhan: semua modul_

  - [x] 20.2 Buat `DashboardScreen` sebagai navigasi utama
    - Implementasi bottom navigation bar atau drawer dengan akses ke semua modul
    - Tombol logout di dashboard yang memanggil `AuthProvider.logout()`
    - _Kebutuhan: 1.3_

  - [ ]* 20.3 Tulis integration test end-to-end alur utama
    - Test alur: login → buka daftar karyawan → tambah karyawan → catat presensi → hitung payroll → logout
    - _Kebutuhan: 1.1, 2.2, 4.1, 5.1, 1.3_

- [x] 21. Checkpoint Akhir — Pastikan Semua Test Lulus
  - Jalankan `php artisan test` (backend) dan `flutter test` (frontend)
  - Pastikan semua unit test, property test, dan widget test lulus
  - Verifikasi integrasi Flutter ↔ Laravel berjalan untuk semua modul
  - Tanyakan kepada pengguna jika ada pertanyaan sebelum dianggap selesai

---

## Catatan

- Tugas bertanda `*` bersifat opsional dan dapat dilewati untuk MVP yang lebih cepat
- Setiap tugas mereferensikan kebutuhan spesifik untuk keterlacakan
- Property test memvalidasi properti universal yang harus berlaku untuk semua input valid
- Konversi zona waktu diimplementasikan sepenuhnya di sisi Flutter (tidak memerlukan API backend)
- Konversi mata uang diimplementasikan di sisi Laravel agar log dapat disimpan ke database
- Deteksi sensor (akselerometer dan giroskop) ditangani sepenuhnya di sisi Flutter via `sensor_plus`
