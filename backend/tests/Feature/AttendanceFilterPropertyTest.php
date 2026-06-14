<?php

namespace Tests\Feature;

use App\Models\Attendance;
use App\Models\Employee;
use App\Models\Shift;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Tests\TestCase;

/**
 * Property-Based Test: Properti 5 — Filter Presensi Konsisten
 *
 * Feature: erp-presensi-payroll, Property 5: Filter Presensi Konsisten
 *
 * Untuk setiap query filter presensi berdasarkan `employee_id` dan rentang tanggal,
 * semua hasil yang dikembalikan harus memiliki `employee_id` yang sesuai dan
 * `attendance_date` yang berada dalam rentang yang diminta.
 *
 * Memvalidasi: Kebutuhan 4.4
 *
 * Implementasi menggunakan @dataProvider PHPUnit dengan berbagai kombinasi
 * rentang tanggal dan skenario data untuk memverifikasi konsistensi filter.
 */
class AttendanceFilterPropertyTest extends TestCase
{
    use RefreshDatabase;

    // ─── Helpers ──────────────────────────────────────────────────────────────

    /**
     * Buat user admin dan kembalikan token Bearer.
     */
    private function actingAsAdmin(): string
    {
        $user = User::factory()->create([
            'password' => Hash::make('password'),
            'role'     => 'admin',
        ]);

        return $user->createToken('api-token')->plainTextToken;
    }

    // ─── Data Providers ───────────────────────────────────────────────────────

    /**
     * Berbagai rentang tanggal untuk digunakan dalam property test filter.
     * Setiap entry: [date_from, date_to, tanggal_dalam_rentang[], tanggal_luar_rentang[]]
     *
     * @return array<string, array{string, string, list<string>, list<string>}>
     */
    public static function dateRangesProvider(): array
    {
        return [
            'rentang satu bulan Juli 2025' => [
                '2025-07-01',
                '2025-07-31',
                ['2025-07-01', '2025-07-15', '2025-07-31'],
                ['2025-06-30', '2025-08-01'],
            ],
            'rentang satu minggu' => [
                '2025-07-07',
                '2025-07-13',
                ['2025-07-07', '2025-07-10', '2025-07-13'],
                ['2025-07-06', '2025-07-14'],
            ],
            'rentang satu hari' => [
                '2025-07-15',
                '2025-07-15',
                ['2025-07-15'],
                ['2025-07-14', '2025-07-16'],
            ],
            'rentang lintas bulan' => [
                '2025-06-15',
                '2025-08-15',
                ['2025-06-15', '2025-07-01', '2025-08-15'],
                ['2025-06-14', '2025-08-16'],
            ],
            'rentang lintas tahun' => [
                '2024-12-01',
                '2025-01-31',
                ['2024-12-01', '2024-12-31', '2025-01-01', '2025-01-31'],
                ['2024-11-30', '2025-02-01'],
            ],
            'rentang awal tahun' => [
                '2025-01-01',
                '2025-03-31',
                ['2025-01-01', '2025-02-15', '2025-03-31'],
                ['2024-12-31', '2025-04-01'],
            ],
        ];
    }

    /**
     * Berbagai jumlah karyawan dan presensi untuk menguji isolasi filter employee_id.
     *
     * @return array<string, array{int, int}>
     */
    public static function employeeCountProvider(): array
    {
        return [
            '2 karyawan, 3 presensi per karyawan'  => [2, 3],
            '3 karyawan, 5 presensi per karyawan'  => [3, 5],
            '5 karyawan, 2 presensi per karyawan'  => [5, 2],
            '10 karyawan, 1 presensi per karyawan' => [10, 1],
        ];
    }

    // ─── Property Tests ───────────────────────────────────────────────────────

    /**
     * Properti 5: Untuk setiap query filter dengan employee_id,
     * semua hasil harus memiliki employee_id yang sesuai.
     *
     * Memvalidasi: Kebutuhan 4.4
     *
     * @dataProvider employeeCountProvider
     */
    public function test_property_filter_by_employee_id_returns_only_matching_records(
        int $employeeCount,
        int $attendancesPerEmployee
    ): void {
        $token = $this->actingAsAdmin();

        // Buat beberapa karyawan dengan presensi masing-masing
        $employees = [];
        for ($i = 0; $i < $employeeCount; $i++) {
            $employee    = Employee::factory()->create();
            $shift       = Shift::factory()->create(['employee_id' => $employee->id]);
            $employees[] = $employee;

            for ($j = 0; $j < $attendancesPerEmployee; $j++) {
                Attendance::factory()->create([
                    'employee_id'     => $employee->id,
                    'shift_id'        => $shift->id,
                    'attendance_date' => '2025-07-' . str_pad($j + 1, 2, '0', STR_PAD_LEFT),
                ]);
            }
        }

        // Uji filter untuk setiap karyawan
        foreach ($employees as $targetEmployee) {
            $response = $this->withToken($token)->getJson(
                "/api/v1/attendances?employee_id={$targetEmployee->id}"
            );

            $response->assertStatus(200);

            $data = $response->json();

            // Properti inti: SETIAP hasil harus memiliki employee_id yang sesuai
            $this->assertCount(
                $attendancesPerEmployee,
                $data,
                "Filter employee_id={$targetEmployee->id} harus mengembalikan tepat {$attendancesPerEmployee} presensi."
            );

            foreach ($data as $item) {
                $this->assertEquals(
                    $targetEmployee->id,
                    $item['employee_id'],
                    "Properti 5 dilanggar: hasil filter employee_id={$targetEmployee->id} mengandung record dengan employee_id={$item['employee_id']}."
                );
            }
        }
    }

    /**
     * Properti 5: Untuk setiap query filter dengan rentang tanggal,
     * semua hasil harus memiliki attendance_date dalam rentang yang diminta.
     *
     * Memvalidasi: Kebutuhan 4.4
     *
     * @dataProvider dateRangesProvider
     *
     * @param list<string> $datesInRange
     * @param list<string> $datesOutOfRange
     */
    public function test_property_filter_by_date_range_returns_only_dates_within_range(
        string $dateFrom,
        string $dateTo,
        array $datesInRange,
        array $datesOutOfRange
    ): void {
        $token    = $this->actingAsAdmin();
        $employee = Employee::factory()->create();
        $shift    = Shift::factory()->create(['employee_id' => $employee->id]);

        // Buat presensi untuk tanggal dalam rentang
        foreach ($datesInRange as $date) {
            Attendance::factory()->create([
                'employee_id'     => $employee->id,
                'shift_id'        => $shift->id,
                'attendance_date' => $date,
            ]);
        }

        // Buat presensi untuk tanggal di luar rentang
        foreach ($datesOutOfRange as $date) {
            Attendance::factory()->create([
                'employee_id'     => $employee->id,
                'shift_id'        => $shift->id,
                'attendance_date' => $date,
            ]);
        }

        $response = $this->withToken($token)->getJson(
            "/api/v1/attendances?date_from={$dateFrom}&date_to={$dateTo}"
        );

        $response->assertStatus(200);

        $data = $response->json();

        // Properti: jumlah hasil harus sama dengan jumlah tanggal dalam rentang
        $this->assertCount(
            count($datesInRange),
            $data,
            "Filter date_from={$dateFrom}&date_to={$dateTo} harus mengembalikan tepat " . count($datesInRange) . " presensi."
        );

        // Properti inti: SETIAP hasil harus memiliki attendance_date dalam rentang
        foreach ($data as $item) {
            // Normalisasi: ambil hanya bagian tanggal (Y-m-d) dari nilai yang mungkin berformat ISO 8601
            $attendanceDate = substr($item['attendance_date'], 0, 10);

            $this->assertGreaterThanOrEqual(
                $dateFrom,
                $attendanceDate,
                "Properti 5 dilanggar: attendance_date={$attendanceDate} lebih kecil dari date_from={$dateFrom}."
            );

            $this->assertLessThanOrEqual(
                $dateTo,
                $attendanceDate,
                "Properti 5 dilanggar: attendance_date={$attendanceDate} lebih besar dari date_to={$dateTo}."
            );
        }
    }

    /**
     * Properti 5: Untuk setiap query filter dengan employee_id DAN rentang tanggal,
     * semua hasil harus memiliki employee_id yang sesuai DAN attendance_date dalam rentang.
     *
     * Memvalidasi: Kebutuhan 4.4
     *
     * @dataProvider dateRangesProvider
     *
     * @param list<string> $datesInRange
     * @param list<string> $datesOutOfRange
     */
    public function test_property_combined_filter_returns_only_matching_employee_and_date_range(
        string $dateFrom,
        string $dateTo,
        array $datesInRange,
        array $datesOutOfRange
    ): void {
        $token     = $this->actingAsAdmin();
        $employee1 = Employee::factory()->create();
        $employee2 = Employee::factory()->create();
        $shift1    = Shift::factory()->create(['employee_id' => $employee1->id]);
        $shift2    = Shift::factory()->create(['employee_id' => $employee2->id]);

        // employee1: presensi dalam rentang
        foreach ($datesInRange as $date) {
            Attendance::factory()->create([
                'employee_id'     => $employee1->id,
                'shift_id'        => $shift1->id,
                'attendance_date' => $date,
            ]);
        }

        // employee1: presensi di luar rentang (tidak boleh muncul)
        foreach ($datesOutOfRange as $date) {
            Attendance::factory()->create([
                'employee_id'     => $employee1->id,
                'shift_id'        => $shift1->id,
                'attendance_date' => $date,
            ]);
        }

        // employee2: presensi dalam rentang (tidak boleh muncul karena filter employee_id)
        foreach ($datesInRange as $date) {
            Attendance::factory()->create([
                'employee_id'     => $employee2->id,
                'shift_id'        => $shift2->id,
                'attendance_date' => $date,
            ]);
        }

        $response = $this->withToken($token)->getJson(
            "/api/v1/attendances?employee_id={$employee1->id}&date_from={$dateFrom}&date_to={$dateTo}"
        );

        $response->assertStatus(200);

        $data = $response->json();

        // Properti: jumlah hasil harus sama dengan jumlah tanggal dalam rentang untuk employee1
        $this->assertCount(
            count($datesInRange),
            $data,
            "Filter kombinasi harus mengembalikan tepat " . count($datesInRange) . " presensi untuk employee1."
        );

        // Properti inti: SETIAP hasil harus memenuhi KEDUA kondisi filter
        foreach ($data as $item) {
            // Kondisi 1: employee_id harus sesuai
            $this->assertEquals(
                $employee1->id,
                $item['employee_id'],
                "Properti 5 dilanggar: hasil mengandung employee_id={$item['employee_id']}, seharusnya {$employee1->id}."
            );

            // Kondisi 2: attendance_date harus dalam rentang
            // Normalisasi: ambil hanya bagian tanggal (Y-m-d) dari nilai yang mungkin berformat ISO 8601
            $attendanceDate = substr($item['attendance_date'], 0, 10);

            $this->assertGreaterThanOrEqual(
                $dateFrom,
                $attendanceDate,
                "Properti 5 dilanggar: attendance_date={$attendanceDate} lebih kecil dari date_from={$dateFrom}."
            );

            $this->assertLessThanOrEqual(
                $dateTo,
                $attendanceDate,
                "Properti 5 dilanggar: attendance_date={$attendanceDate} lebih besar dari date_to={$dateTo}."
            );
        }
    }

    /**
     * Properti 5: Filter dengan employee_id yang tidak memiliki presensi
     * harus mengembalikan array kosong (bukan error).
     *
     * Memvalidasi: Kebutuhan 4.4
     */
    public function test_property_filter_with_no_matching_records_returns_empty_array(): void
    {
        $token     = $this->actingAsAdmin();
        $employee1 = Employee::factory()->create();
        $employee2 = Employee::factory()->create();
        $shift1    = Shift::factory()->create(['employee_id' => $employee1->id]);

        // Buat presensi hanya untuk employee1
        Attendance::factory()->count(3)->create([
            'employee_id' => $employee1->id,
            'shift_id'    => $shift1->id,
        ]);

        // Filter untuk employee2 yang tidak memiliki presensi
        $response = $this->withToken($token)->getJson(
            "/api/v1/attendances?employee_id={$employee2->id}"
        );

        $response->assertStatus(200)
            ->assertJson([]);

        // Properti: hasil harus kosong, bukan error
        $this->assertCount(0, $response->json());
    }

    /**
     * Properti 5: Filter dengan rentang tanggal yang tidak memiliki presensi
     * harus mengembalikan array kosong (bukan error).
     *
     * Memvalidasi: Kebutuhan 4.4
     */
    public function test_property_filter_with_date_range_having_no_data_returns_empty_array(): void
    {
        $token    = $this->actingAsAdmin();
        $employee = Employee::factory()->create();
        $shift    = Shift::factory()->create(['employee_id' => $employee->id]);

        // Buat presensi di bulan Juli
        Attendance::factory()->count(3)->create([
            'employee_id'     => $employee->id,
            'shift_id'        => $shift->id,
            'attendance_date' => '2025-07-15',
        ]);

        // Filter untuk bulan Agustus (tidak ada data)
        $response = $this->withToken($token)->getJson(
            '/api/v1/attendances?date_from=2025-08-01&date_to=2025-08-31'
        );

        $response->assertStatus(200)
            ->assertJson([]);

        $this->assertCount(0, $response->json());
    }

    /**
     * Properti 5: Tanpa filter apapun, semua presensi dikembalikan
     * dan setiap record memiliki struktur yang benar.
     *
     * Memvalidasi: Kebutuhan 4.4
     */
    public function test_property_no_filter_returns_all_attendances_with_correct_structure(): void
    {
        $token    = $this->actingAsAdmin();
        $employee = Employee::factory()->create();
        $shift    = Shift::factory()->create(['employee_id' => $employee->id]);

        $totalAttendances = 5;
        Attendance::factory()->count($totalAttendances)->create([
            'employee_id' => $employee->id,
            'shift_id'    => $shift->id,
        ]);

        $response = $this->withToken($token)->getJson('/api/v1/attendances');

        $response->assertStatus(200)
            ->assertJsonCount($totalAttendances);

        $data = $response->json();

        // Properti: setiap record harus memiliki field yang diperlukan
        foreach ($data as $item) {
            $this->assertArrayHasKey('id', $item);
            $this->assertArrayHasKey('employee_id', $item);
            $this->assertArrayHasKey('shift_id', $item);
            $this->assertArrayHasKey('attendance_date', $item);
            $this->assertArrayHasKey('status', $item);

            // Properti: status harus salah satu dari nilai yang valid
            $this->assertContains(
                $item['status'],
                ['hadir', 'tidak hadir'],
                "Properti 5: status '{$item['status']}' bukan nilai yang valid."
            );
        }
    }
}
