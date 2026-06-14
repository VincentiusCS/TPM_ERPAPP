# Dokumen Kebutuhan Sistem Presensi dan Payroll

## Pendahuluan

Sistem ERP Presensi dan Payroll adalah aplikasi berbasis Flutter (frontend) dan Laravel (backend) yang dirancang untuk membantu admin kampus dalam mengelola data karyawan, penjadwalan shift, pencatatan kehadiran, dan penghitungan penggajian periodik. Sistem ini memiliki satu peran akses yaitu Admin. Fitur tambahan mencakup konversi mata uang realtime, konversi zona waktu, simulasi chatbot mini game berbasis AI (Gemini), dan rotasi layar otomatis berbasis akselerometer.

## Glosarium

- **System**: Sistem ERP Presensi dan Payroll secara keseluruhan
- **Auth_Module**: Modul autentikasi yang menangani login dan logout admin
- **Employee_Module**: Modul pengelolaan data karyawan
- **Shift_Module**: Modul pengelolaan jadwal shift karyawan
- **Attendance_Module**: Modul pencatatan kehadiran karyawan
- **Payroll_Module**: Modul penghitungan dan pelaporan penggajian
- **Currency_Module**: Modul konversi mata uang menggunakan kurs realtime
- **Time_Module**: Modul konversi zona waktu
- **Chatbot_Module**: Modul mini game simulasi chatbot berbasis AI Gemini
- **Sensor_Module**: Modul deteksi orientasi layar berbasis akselerometer
- **Admin**: Pengguna tunggal dengan akses penuh ke seluruh fitur sistem
- **Karyawan**: Entitas yang dikelola oleh Admin, memiliki data nama, telepon, alamat, dan status
- **Shift**: Satu sesi kerja karyawan dengan nilai Rp50.000 per shift
- **Presensi**: Catatan kehadiran karyawan pada suatu shift tertentu
- **Payroll**: Rekap penggajian karyawan dalam suatu periode, dihitung dari jumlah kehadiran dikali nilai per shift
- **Periode Payroll**: Rentang tanggal awal dan akhir yang digunakan untuk menghitung total gaji
- **Kurs Realtime**: Nilai tukar mata uang yang diambil dari API exchangerate-api.com
- **Gemini_API**: Layanan AI dari Google yang digunakan untuk simulasi chatbot

---

## Kebutuhan

### Kebutuhan 1: Autentikasi Admin

**User Story:** Sebagai Admin, saya ingin dapat login dan logout dari sistem, agar akses ke data sensitif terlindungi.

#### Kriteria Penerimaan

1. WHEN Admin memasukkan email dan password yang valid, THE Auth_Module SHALL mengautentikasi Admin dan mengarahkan ke halaman dashboard.
2. WHEN Admin memasukkan email atau password yang tidak valid, THE Auth_Module SHALL menampilkan pesan kesalahan yang menjelaskan bahwa kredensial tidak sesuai.
3. WHEN Admin menekan tombol logout, THE Auth_Module SHALL mengakhiri sesi Admin dan mengarahkan kembali ke halaman login.
4. WHILE Admin belum login, THE Auth_Module SHALL memblokir akses ke seluruh halaman selain halaman login.
5. IF token sesi Admin kedaluwarsa, THEN THE Auth_Module SHALL mengarahkan Admin ke halaman login secara otomatis.

---

### Kebutuhan 2: Manajemen Data Karyawan

**User Story:** Sebagai Admin, saya ingin dapat menambah, mengubah, menghapus, dan melihat daftar karyawan, agar data karyawan selalu terkelola dengan baik.

#### Kriteria Penerimaan

1. THE Employee_Module SHALL menampilkan daftar seluruh karyawan beserta nama, nomor telepon, alamat, dan status.
2. WHEN Admin mengisi formulir tambah karyawan dengan data lengkap dan valid, THE Employee_Module SHALL menyimpan data karyawan baru ke database.
3. IF Admin mengirimkan formulir tambah karyawan dengan field wajib yang kosong, THEN THE Employee_Module SHALL menampilkan pesan validasi per field yang tidak terisi.
4. WHEN Admin memperbarui data karyawan yang sudah ada, THE Employee_Module SHALL menyimpan perubahan dan menampilkan data terbaru.
5. WHEN Admin menghapus data karyawan, THE Employee_Module SHALL menghapus karyawan dari database dan memperbarui daftar tampilan.
6. IF Admin mencoba menghapus karyawan yang memiliki data presensi atau payroll terkait, THEN THE Employee_Module SHALL menampilkan pesan konfirmasi sebelum melanjutkan penghapusan.

---

### Kebutuhan 3: Manajemen Jadwal Shift

**User Story:** Sebagai Admin, saya ingin dapat menetapkan dan melihat jadwal shift karyawan, agar penugasan kerja terdokumentasi dengan jelas.

#### Kriteria Penerimaan

1. WHEN Admin menetapkan shift untuk karyawan dengan memilih karyawan dan tanggal shift, THE Shift_Module SHALL menyimpan jadwal shift dengan nilai Rp50.000 per shift ke database.
2. THE Shift_Module SHALL menampilkan daftar jadwal shift seluruh karyawan beserta tanggal dan nilai shift.
3. IF Admin mencoba menetapkan shift pada tanggal yang sudah ada untuk karyawan yang sama, THEN THE Shift_Module SHALL menampilkan pesan bahwa shift pada tanggal tersebut sudah terdaftar.
4. WHEN Admin menghapus jadwal shift, THE Shift_Module SHALL menghapus data shift dari database dan memperbarui tampilan jadwal.

---

### Kebutuhan 4: Pencatatan Presensi (Attendance)

**User Story:** Sebagai Admin, saya ingin dapat mencatat, mengubah, dan melihat riwayat kehadiran karyawan, agar data presensi akurat untuk penghitungan payroll.

#### Kriteria Penerimaan

1. WHEN Admin mencatat presensi karyawan dengan memilih karyawan, shift, tanggal, dan status kehadiran, THE Attendance_Module SHALL menyimpan data presensi ke database.
2. THE Attendance_Module SHALL mendukung dua nilai status kehadiran yaitu "hadir" dan "tidak hadir".
3. WHEN Admin mengubah status presensi yang sudah ada, THE Attendance_Module SHALL memperbarui data presensi dan menampilkan perubahan.
4. THE Attendance_Module SHALL menampilkan riwayat presensi seluruh karyawan yang dapat difilter berdasarkan nama karyawan dan rentang tanggal.
5. IF Admin mencoba menyimpan presensi tanpa memilih karyawan atau shift, THEN THE Attendance_Module SHALL menampilkan pesan validasi yang menjelaskan field yang wajib diisi.

---

### Kebutuhan 5: Penghitungan dan Laporan Payroll

**User Story:** Sebagai Admin, saya ingin sistem menghitung gaji karyawan secara otomatis berdasarkan jumlah kehadiran dalam suatu periode, agar proses penggajian efisien dan akurat.

#### Kriteria Penerimaan

1. WHEN Admin memilih periode (tanggal mulai dan tanggal akhir) dan meminta penghitungan payroll, THE Payroll_Module SHALL menghitung total gaji setiap karyawan dengan rumus: Total Gaji = Jumlah Hadir × Rp50.000.
2. THE Payroll_Module SHALL hanya menghitung presensi dengan status "hadir" dalam periode yang dipilih ke dalam total gaji.
3. THE Payroll_Module SHALL menampilkan laporan payroll yang memuat nama karyawan, jumlah kehadiran, dan total gaji untuk periode yang dipilih.
4. WHEN Admin mencari karyawan tertentu pada halaman payroll, THE Payroll_Module SHALL memfilter dan menampilkan data payroll karyawan yang sesuai dengan kata kunci pencarian.
5. WHEN Admin mengunduh laporan payroll, THE Payroll_Module SHALL menghasilkan file dalam format PDF atau Excel yang memuat seluruh data payroll periode tersebut.
6. WHEN Admin mengunduh slip gaji per karyawan, THE Payroll_Module SHALL menghasilkan file PDF yang memuat detail gaji karyawan tersebut untuk periode yang dipilih.
7. WHEN proses unduhan laporan atau slip gaji selesai, THE Payroll_Module SHALL menampilkan notifikasi bahwa unduhan berhasil.
8. IF rentang periode yang dipilih Admin tidak memiliki data presensi, THEN THE Payroll_Module SHALL menampilkan pesan bahwa tidak ada data payroll untuk periode tersebut.

---

### Kebutuhan 6: Konversi Mata Uang

**User Story:** Sebagai Admin, saya ingin dapat mengkonversi total gaji ke mata uang lain menggunakan kurs terkini, agar nilai gaji dapat dipahami dalam berbagai denominasi mata uang.

#### Kriteria Penerimaan

1. WHEN Admin memasukkan nominal dalam IDR dan memilih mata uang tujuan, THE Currency_Module SHALL mengambil kurs terkini dari API exchangerate-api.com dan menampilkan hasil konversi.
2. THE Currency_Module SHALL mendukung konversi antara mata uang IDR, USD, EUR, dan GBP.
3. THE Currency_Module SHALL menampilkan nilai kurs yang digunakan beserta hasil konversi.
4. IF permintaan ke API kurs gagal atau koneksi tidak tersedia, THEN THE Currency_Module SHALL menampilkan pesan kesalahan yang menginformasikan bahwa data kurs tidak dapat diambil saat ini.
5. WHEN konversi mata uang berhasil dilakukan, THE Currency_Module SHALL menyimpan log konversi yang memuat ID payroll terkait, jenis mata uang, nilai kurs, dan hasil konversi ke database.

---

### Kebutuhan 7: Konversi Zona Waktu

**User Story:** Sebagai Admin, saya ingin dapat mengkonversi waktu antar zona waktu yang relevan, agar koordinasi jadwal dengan berbagai wilayah lebih mudah.

#### Kriteria Penerimaan

1. WHEN Admin memasukkan waktu dan memilih zona waktu asal serta zona waktu tujuan, THE Time_Module SHALL menghitung dan menampilkan waktu yang telah dikonversi.
2. THE Time_Module SHALL mendukung konversi antar zona waktu WIB (UTC+7), WITA (UTC+8), WIT (UTC+9), dan London (UTC+0 / UTC+1 saat daylight saving).
3. THE Time_Module SHALL menampilkan selisih jam antara zona waktu asal dan tujuan bersama hasil konversi.
4. IF Admin memasukkan format waktu yang tidak valid, THEN THE Time_Module SHALL menampilkan pesan validasi yang menjelaskan format waktu yang diterima.

---

### Kebutuhan 8: Mini Game Simulasi Chatbot (AI)

**User Story:** Sebagai Admin, saya ingin dapat memainkan simulasi percakapan dengan pelanggan virtual berbasis AI, agar keterampilan layanan pelanggan dapat dilatih secara interaktif.

#### Kriteria Penerimaan

1. WHEN Admin memilih skenario simulasi, THE Chatbot_Module SHALL memulai sesi percakapan dengan AI sebagai pelanggan virtual menggunakan Gemini API.
2. WHEN Admin mengirimkan respons dalam sesi simulasi, THE Chatbot_Module SHALL meneruskan respons ke Gemini API dan menampilkan balasan dari pelanggan virtual.
3. WHEN sesi simulasi selesai, THE Chatbot_Module SHALL menampilkan feedback kualitas respons Admin berdasarkan evaluasi dari Gemini API.
4. WHEN Admin mengguncang perangkat (shake gesture) selama sesi simulasi aktif, THE Chatbot_Module SHALL mereset sesi simulasi dan kembali ke halaman pemilihan skenario.
5. IF permintaan ke Gemini API gagal, THEN THE Chatbot_Module SHALL menampilkan pesan kesalahan dan mempertahankan sesi simulasi agar Admin dapat mencoba kembali.
6. THE Chatbot_Module SHALL mendeteksi gesture shake menggunakan sensor giroskop perangkat melalui paket sensor_plus.

---

### Kebutuhan 9: Rotasi Layar Otomatis Berbasis Akselerometer

**User Story:** Sebagai Admin, saya ingin layar aplikasi berotasi secara otomatis sesuai orientasi perangkat, agar tampilan aplikasi optimal di berbagai posisi penggunaan.

#### Kriteria Penerimaan

1. WHEN sensor akselerometer mendeteksi perubahan orientasi perangkat ke posisi landscape, THE Sensor_Module SHALL mengubah orientasi tampilan aplikasi menjadi landscape.
2. WHEN sensor akselerometer mendeteksi perubahan orientasi perangkat ke posisi portrait, THE Sensor_Module SHALL mengubah orientasi tampilan aplikasi menjadi portrait.
3. THE Sensor_Module SHALL membaca data orientasi secara realtime menggunakan paket sensor_plus dan flutter_screen_orientation.
4. WHILE aplikasi berjalan di foreground, THE Sensor_Module SHALL terus memantau perubahan orientasi perangkat.
