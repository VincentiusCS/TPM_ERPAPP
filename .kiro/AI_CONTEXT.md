# AI Context — ERP Presensi & Payroll

Dokumen ini berisi konteks lengkap aplikasi untuk membantu AI menyusun laporan pengembangan. Semua informasi di sini berasal dari source code aktual dan bukan ekspektasi atau perencanaan.

---

## 1. Identitas Proyek

- **Nama**: ERP Presensi & Payroll (`erp_app`)
- **Konsep**: Aplikasi mobile untuk admin/HRD mengelola karyawan, presensi, shift kerja, dan penggajian. Dilengkapi modul pelatihan customer service berbasis AI.
- **Mata Kuliah**: Teknologi Pemrograman Mobile (TPM)
- **Versi**: 0.1.0+1
- **Dart SDK**: ^3.11.1
- **Target Platform**: Android (utama), iOS-ready

---

## 2. Arsitektur

### 2.1 Tech Stack

**Frontend (Mobile App)**
- Flutter / Dart
- State management: Provider (ChangeNotifier)
- HTTP client: Dio
- Persistensi lokal: SharedPreferences

**Backend (REST API)**
- Laravel (PHP)
- Database: MySQL
- Autentikasi: Laravel Sanctum (token-based)
- AI: Groq API (model `llama-3.1-8b-instant`, OpenAI-compatible format)

### 2.2 Struktur Folder

```
lib/
├── main.dart                       # Entry point, DI manual, routing guard
├── models/                         # Data models (User, Employee, Attendance, Payroll, Shift, dll)
├── providers/                      # Provider/ChangeNotifier (Auth, Employee, Attendance, Payroll, Sensor)
├── routes/
│   └── app_routes.dart             # Konstanta route names
├── screens/                        # Halaman UI (login, dashboard, profile, dll)
├── services/                       # API services & utility services
├── utils/                          # Helper utility (sensor, timezone, notifikasi)
└── widgets/
    ├── animated_character.dart     # Avatar maskot chatbot
    └── app_bottom_nav.dart         # Bottom nav reusable

backend/
├── app/Http/Controllers/Api/       # AuthController, EmployeeController, dll
├── app/Models/                     # Eloquent models
├── routes/api.php                  # Definisi endpoint REST
└── database/migrations/            # Skema database
```

### 2.3 Arsitektur Aplikasi

```
[Flutter UI] ↔ [Provider (state)] ↔ [Service] ↔ [ApiClient (Dio)] ↔ [Laravel API] ↔ [MySQL]
```

---

## 3. Fitur Utama

### 3.1 Autentikasi Multi-Faktor

Login melibatkan 3 langkah berurutan:

1. **Credential** — Email + password divalidasi ke backend (Laravel `Auth::attempt`, password di-hash bcrypt). Saat berhasil, backend mengembalikan token Sanctum.
2. **Biometric** — `local_auth` package memvalidasi fingerprint/face di device.
3. **LBS (Location-Based Service)** — `geolocator` mengambil koordinat GPS, lalu dihitung jarak ke kantor menggunakan formula Haversine. Login hanya berhasil jika user dalam radius yang ditentukan.

Token Sanctum disimpan di SharedPreferences. Sesi otomatis dipulihkan saat app dibuka kembali.

**File**: `lib/services/auth_service.dart`, `lib/services/biometric_service.dart`, `lib/services/location_service.dart`, `lib/providers/auth_provider.dart`, `backend/app/Http/Controllers/Api/AuthController.php`

### 3.2 Manajemen Data ERP

| Modul | Operasi | Backend Controller |
|-------|---------|---------------------|
| Employees | List, Create, Update, Delete | `EmployeeController` |
| Shifts | List, Create, Delete | `ShiftController` |
| Attendances | List, Create, Update | `AttendanceController` |
| Payrolls | List, Download report (PDF), Download slip per karyawan | `PayrollController` |

### 3.3 Konversi Mata Uang

- 3 mata uang target: USD, EUR, GBP
- Source: IDR
- Endpoint backend: `POST /api/v1/currency/convert` (memanggil exchange rate API eksternal, hasil disimpan ke tabel `currency_logs`)
- File: `lib/screens/currency_screen.dart`, `backend/app/Http/Controllers/Api/CurrencyController.php`

### 3.4 Konversi Zona Waktu

Mendukung WIB, WITA, WIT, UTC, GMT, JST, SGT, KST, CST, EST, PST, CET, **London**. Menggunakan paket `timezone` (IANA database) untuk presisi termasuk daylight saving.

**File**: `lib/screens/time_screen.dart`, `lib/utils/timezone_util.dart`

### 3.5 Sensor (Multi-sensor)

- **Accelerometer**: Mendeteksi orientasi device (`SensorUtil.startListening`). Awalnya digunakan untuk auto-rotate, sekarang orientasi di-lock ke portrait via `SystemChrome.setPreferredOrientations` di `main.dart`. Sensor accelerometer tetap aktif untuk monitoring.
- **Gyroscope**: Shake-to-reset session di chatbot. Threshold magnitude `10.0`, cooldown 3 detik untuk mencegah trigger tidak sengaja.

**File**: `lib/utils/sensor_util.dart`, `lib/providers/sensor_provider.dart`, `lib/screens/chatbot_screen.dart`

### 3.6 AI Chatbot (LLM)

Pelatihan customer service berbasis **Groq API** (model `llama-3.1-8b-instant`) berlatar toko kelontong/minimarket:

- 4 skenario tersedia: Pelanggan Marah (produk kedaluwarsa), Pelanggan Bingung (cari produk + tanya promo), Permintaan Tukar Barang, Pelanggan Puas (tanya membership)
- Setiap skenario punya `system_prompt` yang membuat AI berperan sebagai pelanggan dalam bahasa Indonesia, respons singkat 1-3 kalimat
- Riwayat percakapan disimpan di Laravel Cache (TTL 1 jam) per `session_id`
- Setelah selesai, user trigger evaluasi → AI evaluator memberikan skor 1-10 + saran perbaikan
- Endpoint AI: `POST https://api.groq.com/openai/v1/chat/completions` dengan temperature 0.5, max_tokens 200

**Karakter maskot animasi** (`AnimatedCharacter`) menampilkan ekspresi yang mencerminkan mood AI berdasarkan keyword di respons:

| Mood | Trigger keywords |
|------|-------------------|
| angry | kesal, marah, batal, refund, buruk, kecewa, komplain, gagal, parah |
| happy | terima kasih, bagus, sempurna, mantap, selesai, senang, puas, berhasil, hebat |
| confused | tidak mengerti, bingung, maksudnya, apa itu, kurang jelas, belum paham, gimana |
| talking | Saat AI sedang merespons (loading) |
| neutral | Default |

Karakter digambar dengan `CustomPainter` (face, eyes, eyebrows, mouth) dan beranimasi (idle bounce, mood transition, talking mouth).

**File**: `lib/screens/chatbot_screen.dart`, `lib/services/chatbot_service.dart`, `lib/widgets/animated_character.dart`, `backend/app/Http/Controllers/Api/ChatbotController.php`

### 3.7 Mini Game — Quiz Customer Service

Quiz interaktif 5 soal pilihan ganda tentang skenario customer service. Setiap soal:
- Menampilkan situasi pelanggan
- 4 pilihan jawaban (A-D)
- Feedback langsung benar/salah + penjelasan
- Progress bar dan score chip
- Hasil akhir: skor (X/5), persentase, label motivasi (Sempurna/Luar Biasa/Bagus/Cukup Baik/Perlu Belajar Lagi)

**File**: `lib/screens/quiz_screen.dart`

### 3.8 Profil dengan Foto

- User bisa upload foto profil dari galeri (`image_picker`)
- Path foto disimpan di SharedPreferences
- Foto ditampilkan di Profile screen dan Dashboard
- Fallback ke initial huruf jika belum ada foto
- Edit nama tersimpan ke database via endpoint `PUT /api/v1/auth/profile`

**File**: `lib/screens/profile_screen.dart`, `lib/services/profile_image_service.dart`, `lib/screens/dashboard_screen.dart`

### 3.9 Kesan & Pesan TPM

Halaman dedicated untuk kesan dan pesan mata kuliah TPM, dapat diakses dari dashboard.

**File**: `lib/screens/kesan_pesan_screen.dart`

### 3.10 Notifikasi Push

`flutter_local_notifications` digunakan untuk notifikasi saat berhasil download laporan/slip payroll.

**File**: `lib/services/push_notification_service.dart`

### 3.11 Pencarian & Pemilihan

- **Pencarian**: Search bar di halaman Employees untuk filter karyawan
- **Pemilihan**: Dropdown shift, scenario picker chatbot, picker mata uang/timezone

---

## 4. Bottom Navigation

Menu utama: Dashboard, Staff, Attendance, Payroll, Support (Chatbot).
Halaman Profile, Kesan & Pesan TPM, dan Logout dapat diakses dari Dashboard.

**Komponen reusable**: `lib/widgets/app_bottom_nav.dart`

---

## 5. API Endpoints (Backend)

Base URL: `/api/v1`

### Public
- `POST /auth/login`

### Protected (Sanctum Bearer Token)
- `POST /auth/logout`
- `PUT  /auth/profile` — Update nama user
- `GET|POST|PUT|DELETE /employees`
- `GET|POST|DELETE /shifts`
- `GET|POST|PUT /attendances`
- `GET /payrolls`
- `GET /payrolls/download/report` — Download laporan PDF
- `GET /payrolls/{employee_id}/slip` — Download slip PDF
- `POST /currency/convert`
- `GET  /chatbot/scenarios`
- `POST /chatbot/message`
- `POST /chatbot/feedback` (proxy ke Groq Llama 3.1 8B)

---

## 6. Database (Tabel Utama)

- `users` — id, name, email, password, role
- `employees` — id, name, phone, address, status
- `shifts` — id, employee_id, date, time
- `attendances` — id, employee_id, shift_id, attendance_date, status
- `payrolls` — id, employee_id, period_start, period_end, total_attendance, total_salary
- `currency_logs` — Log konversi mata uang
- `personal_access_tokens` — Token Sanctum

---

## 7. Dependencies (pubspec.yaml)

```yaml
provider: ^6.0.0
shared_preferences: ^2.0.18
dio: ^5.4.0
http: ^1.6.0
intl: ^0.18.0
sensors_plus: ^6.1.1
timezone: ^0.9.2
flutter_timezone: ^3.0.1
pdf: ^3.11.2
open_file: ^3.5.10
local_auth: ^2.1.0
geolocator: ^10.1.0
flutter_local_notifications: ^18.0.1
image_picker: ^1.0.7
```

---

## 8. Permission Android (AndroidManifest.xml)

```xml
USE_BIOMETRIC
ACCESS_FINE_LOCATION
ACCESS_COARSE_LOCATION
READ_MEDIA_IMAGES
```

---

## 9. Quality & Refactor

- Bottom nav widget di-extract ke 1 komponen reusable (`AppBottomNav`), menghapus ~280 baris duplikasi
- File unused dihapus: `lib/utils/constants.dart`, `lib/services/api_service.dart`, `lib/widgets/employee_tile.dart`
- Kode source di `lib/` lulus `flutter analyze` tanpa warning. Hanya beberapa info `withOpacity` deprecation (non-blocking, dari Flutter SDK update)

---

## 10. Testing

Test files di `test/` folder mencakup:
- `auth_provider_login_test.dart`, `auth_provider_property_test.dart`
- `login_screen_test.dart`, `login_screen_multistep_test.dart`
- `attendance_screen_test.dart`, `payroll_screen_test.dart`
- `currency_service_test.dart`, `timezone_util_test.dart`

Property-based testing menggunakan `glados`.

> **Catatan**: Beberapa test mungkin perlu update mock signature setelah penambahan fitur (`updateProfile`, payroll currency/timezone params).

---

## 11. Pemenuhan Kriteria Tugas Akhir TPM

| Kriteria | Status | Catatan |
|---------|--------|---------|
| Konsep proyek akhir | ✅ | ERP Presensi & Payroll |
| Login dengan enkripsi & session | ✅ | Sanctum + bcrypt |
| Login biometric | ✅ | `local_auth` |
| Database/penyimpanan | ✅ | MySQL via API |
| Web service / API | ✅ | REST API Laravel |
| LBS terkait tema | ✅ | Validasi radius lokasi saat login |
| Bottom nav (profil + kesan pesan + logout) | ✅ | Profile dengan foto, Kesan Pesan TPM, Logout |
| Konversi mata uang (≥3) | ✅ | USD, EUR, GBP |
| Konversi waktu (WIB, WITA, WIT, London) | ✅ | + 9 zona lain |
| Min. 2 sensor | ✅ | Accelerometer + Gyroscope |
| AI/ML/LLM | ✅ | Groq API (Llama 3.1 8B) |
| Mini games | ✅ | Quiz CS (5 soal + skor) |
| Pencarian & pemilihan | ✅ | Search bar employees, dropdowns |
| Notifikasi | ✅ | flutter_local_notifications untuk download payroll |

---

## 12. Saran Bahasan Laporan

Bagi laporan menjadi:

1. **Pendahuluan** — Latar belakang ERP, kebutuhan integrasi presensi+payroll, dan tujuan
2. **Tinjauan Teknologi** — Flutter, Laravel, Sanctum, LBS, biometric, Groq Llama API
3. **Analisis & Desain** — Use case (admin login → manage employee → record attendance → generate payroll), arsitektur 3-tier, ERD database
4. **Implementasi** — Per fitur (autentikasi 3-step, sensor, chatbot, dll)
5. **Pengujian** — Unit test, property-based test (glados), manual testing
6. **Hasil** — Screenshot per layar
7. **Kesimpulan & Saran Pengembangan**
