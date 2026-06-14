# Dokumen Kebutuhan: Autentikasi Biometrik dan Validasi Lokasi (LBS)

## Pendahuluan

Fitur ini menambahkan dua lapisan validasi tambahan pada proses login sistem ERP Presensi dan Payroll, yaitu autentikasi sidik jari (biometrik) dan validasi lokasi berbasis GPS (Location-Based Service). Kedua validasi ini harus berhasil agar proses login dapat dilanjutkan. Tujuannya adalah memastikan bahwa hanya pengguna yang sah dan berada di area kampus yang diizinkan mengakses sistem.

## Glosarium

- **Auth_Module**: Modul autentikasi yang menangani login dan logout admin, termasuk validasi kredensial, biometrik, dan lokasi
- **Biometric_Service**: Layanan yang mengelola autentikasi sidik jari menggunakan sensor biometrik perangkat
- **LBS_Service**: Layanan yang mengelola validasi lokasi pengguna menggunakan GPS perangkat
- **Titik_Koordinat_Referensi**: Koordinat pusat area yang diizinkan untuk login, yaitu latitude -7.7533720 dan longitude 110.4290118
- **Radius_Toleransi**: Jarak maksimum dari Titik_Koordinat_Referensi yang masih diizinkan untuk login, yaitu 100 meter
- **Admin**: Pengguna tunggal dengan akses penuh ke seluruh fitur sistem
- **Haversine**: Formula matematika untuk menghitung jarak antara dua titik koordinat di permukaan bumi

---

## Kebutuhan

### Kebutuhan 1: Autentikasi Biometrik Sidik Jari

**User Story:** Sebagai Admin, saya ingin login menggunakan sidik jari sebagai validasi tambahan setelah email dan password, agar keamanan akses sistem lebih terjamin.

#### Kriteria Penerimaan

1. WHEN Admin berhasil memasukkan email dan password yang valid, THE Auth_Module SHALL menampilkan prompt autentikasi sidik jari kepada Admin.
2. WHEN Admin berhasil memverifikasi sidik jari melalui sensor biometrik perangkat, THE Biometric_Service SHALL mengembalikan status autentikasi berhasil ke Auth_Module.
3. IF Admin gagal memverifikasi sidik jari, THEN THE Biometric_Service SHALL menampilkan pesan kesalahan bahwa autentikasi biometrik gagal dan memperbolehkan Admin mencoba kembali.
4. IF perangkat Admin tidak mendukung sensor biometrik atau tidak memiliki sidik jari terdaftar, THEN THE Biometric_Service SHALL menampilkan pesan bahwa fitur biometrik tidak tersedia pada perangkat dan menghentikan proses login.
5. THE Biometric_Service SHALL menggunakan API biometrik bawaan sistem operasi perangkat (Android BiometricPrompt / iOS LocalAuthentication) melalui paket local_auth.

---

### Kebutuhan 2: Validasi Lokasi Berbasis GPS (LBS)

**User Story:** Sebagai Admin, saya ingin sistem memvalidasi lokasi saya saat login, agar hanya pengguna yang berada di area kampus yang dapat mengakses sistem.

#### Kriteria Penerimaan

1. WHEN autentikasi biometrik berhasil, THE LBS_Service SHALL mengambil koordinat GPS perangkat Admin saat itu.
2. THE LBS_Service SHALL menghitung jarak antara koordinat GPS perangkat Admin dengan Titik_Koordinat_Referensi (latitude -7.7533720, longitude 110.4290118) menggunakan formula Haversine.
3. WHEN jarak antara koordinat perangkat Admin dan Titik_Koordinat_Referensi kurang dari atau sama dengan 100 meter, THE LBS_Service SHALL mengembalikan status validasi lokasi berhasil ke Auth_Module.
4. IF jarak antara koordinat perangkat Admin dan Titik_Koordinat_Referensi lebih dari 100 meter, THEN THE LBS_Service SHALL menampilkan pesan bahwa Admin berada di luar area yang diizinkan dan menghentikan proses login.
5. IF layanan GPS perangkat tidak aktif atau izin lokasi tidak diberikan, THEN THE LBS_Service SHALL menampilkan pesan yang meminta Admin mengaktifkan GPS dan memberikan izin akses lokasi.
6. IF LBS_Service tidak dapat memperoleh koordinat GPS dalam waktu 15 detik, THEN THE LBS_Service SHALL menampilkan pesan timeout dan memperbolehkan Admin mencoba kembali.

---

### Kebutuhan 3: Alur Login Terintegrasi

**User Story:** Sebagai Admin, saya ingin proses login berjalan secara berurutan (kredensial → biometrik → lokasi), agar setiap tahap validasi terpenuhi sebelum akses diberikan.

#### Kriteria Penerimaan

1. THE Auth_Module SHALL menjalankan validasi login dalam urutan: (1) validasi email dan password, (2) autentikasi biometrik sidik jari, (3) validasi lokasi GPS.
2. WHEN seluruh tiga tahap validasi berhasil, THE Auth_Module SHALL mengautentikasi Admin dan mengarahkan ke halaman dashboard.
3. IF salah satu tahap validasi gagal, THEN THE Auth_Module SHALL menghentikan proses login dan menampilkan pesan kesalahan sesuai tahap yang gagal.
4. WHILE proses validasi biometrik atau lokasi sedang berlangsung, THE Auth_Module SHALL menampilkan indikator loading kepada Admin.
5. WHEN Admin membatalkan proses autentikasi biometrik, THE Auth_Module SHALL menghentikan proses login dan mengembalikan Admin ke halaman login.

---

### Kebutuhan 4: Penanganan Izin dan Kompatibilitas Perangkat

**User Story:** Sebagai Admin, saya ingin mendapatkan panduan yang jelas jika perangkat saya tidak memenuhi syarat untuk login, agar saya memahami langkah yang perlu dilakukan.

#### Kriteria Penerimaan

1. WHEN aplikasi pertama kali membutuhkan akses lokasi, THE Auth_Module SHALL meminta izin akses lokasi (location permission) kepada Admin melalui dialog sistem operasi.
2. IF Admin menolak izin akses lokasi secara permanen, THEN THE Auth_Module SHALL menampilkan pesan yang mengarahkan Admin ke pengaturan aplikasi untuk mengaktifkan izin lokasi secara manual.
3. WHEN aplikasi pertama kali membutuhkan akses biometrik, THE Auth_Module SHALL memeriksa ketersediaan hardware biometrik dan sidik jari terdaftar pada perangkat.
4. IF perangkat tidak memiliki hardware biometrik, THEN THE Auth_Module SHALL menampilkan pesan bahwa perangkat tidak kompatibel dengan persyaratan login sistem.
