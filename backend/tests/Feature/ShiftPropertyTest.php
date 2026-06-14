<?php

namespace Tests\Feature;

use App\Models\Employee;
use App\Models\Shift;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Tests\TestCase;

/**
 * Property-Based Test: Properti 2 — Shift Unik per Karyawan per Tanggal
 *
 * Feature: erp-presensi-payroll, Property 2: Shift Unik per Karyawan per Tanggal
 *
 * Untuk setiap kombinasi employee_id dan shift_date, tidak boleh ada dua record
 * shift yang sama di database secara bersamaan.
 *
 * Memvalidasi: Kebutuhan 3.3
 *
 * Implementasi menggunakan @dataProvider PHPUnit dengan berbagai kombinasi
 * tanggal dan skenario duplikasi untuk memverifikasi properti keunikan shift.
 */
class ShiftPropertyTest extends TestCase
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
     * Berbagai tanggal shift yang valid untuk digunakan dalam property test.
     * Mencakup tanggal di masa lalu, sekarang, dan masa depan.
     *
     * @return array<string, array{string}>
     */
    public static function shiftDatesProvider(): array
    {
        return [
            'tanggal di masa lalu (2020)'       => ['2020-01-15'],
            'tanggal di masa lalu (2023)'       => ['2023-06-30'],
            'tanggal awal tahun'                => ['2025-01-01'],
            'tanggal akhir bulan Januari'       => ['2025-01-31'],
            'tanggal awal Februari'             => ['2025-02-01'],
            'tanggal akhir Februari (non-leap)' => ['2025-02-28'],
            'tanggal tengah tahun'              => ['2025-07-15'],
            'tanggal akhir tahun'               => ['2025-12-31'],
            'tanggal di masa depan (2026)'      => ['2026-03-20'],
            'tanggal di masa depan (2030)'      => ['2030-12-01'],
        ];
    }

    /**
     * Berbagai jumlah percobaan duplikasi (N kali mencoba membuat shift yang sama).
     * Properti harus berlaku untuk semua N ≥ 2.
     *
     * @return array<string, array{int}>
     */
    public static function duplicateAttemptsProvider(): array
    {
        return [
            '2 percobaan duplikasi'   => [2],
            '3 percobaan duplikasi'   => [3],
            '5 percobaan duplikasi'   => [5],
            '10 percobaan duplikasi'  => [10],
        ];
    }

    /**
     * Kombinasi tanggal × jumlah percobaan duplikasi.
     *
     * @return array<string, array{string, int}>
     */
    public static function dateWithDuplicateAttemptsProvider(): array
    {
        $combinations = [];

        foreach (self::shiftDatesProvider() as $dateKey => [$date]) {
            foreach (self::duplicateAttemptsProvider() as $attemptKey => [$attempts]) {
                $key                = "{$dateKey} | {$attemptKey}";
                $combinations[$key] = [$date, $attempts];
            }
        }

        return $combinations;
    }

    // ─── Property Tests ───────────────────────────────────────────────────────

    /**
     * Properti 2: Untuk setiap kombinasi employee_id dan shift_date,
     * tidak boleh ada dua record shift yang sama di database.
     *
     * Skenario: Buat shift pertama (berhasil), lalu coba buat shift duplikat
     * (employee + tanggal sama) → harus ditolak dengan HTTP 409.
     * Database harus tetap hanya memiliki satu record.
     *
     * Memvalidasi: Kebutuhan 3.3
     *
     * @dataProvider shiftDatesProvider
     */
    public function test_property_shift_uniqueness_per_employee_per_date(string $shiftDate): void
    {
        $token    = $this->actingAsAdmin();
        $employee = Employee::factory()->create();

        // Langkah 1: Buat shift pertama — harus berhasil
        $firstResponse = $this->withToken($token)->postJson('/api/v1/shifts', [
            'employee_id' => $employee->id,
            'shift_date'  => $shiftDate,
        ]);

        $firstResponse->assertStatus(201);

        // Properti: setelah insert pertama, harus ada tepat 1 record
        $this->assertSame(
            1,
            Shift::where('employee_id', $employee->id)->count(),
            "Setelah insert pertama, harus ada tepat 1 shift untuk karyawan ini."
        );

        // Langkah 2: Coba buat shift duplikat (employee + tanggal sama) — harus ditolak
        $duplicateResponse = $this->withToken($token)->postJson('/api/v1/shifts', [
            'employee_id' => $employee->id,
            'shift_date'  => $shiftDate,
        ]);

        $duplicateResponse->assertStatus(409);

        // Properti inti: database HARUS tetap hanya memiliki 1 record (tidak ada duplikat)
        $this->assertSame(
            1,
            Shift::where('employee_id', $employee->id)->count(),
            "Properti 2 dilanggar: ditemukan lebih dari satu shift untuk employee_id={$employee->id} pada tanggal {$shiftDate}."
        );
    }

    /**
     * Properti 2 (multi-attempt): Untuk setiap N percobaan duplikasi,
     * database harus tetap hanya memiliki 1 record shift per employee per tanggal.
     *
     * Memvalidasi: Kebutuhan 3.3
     *
     * @dataProvider duplicateAttemptsProvider
     */
    public function test_property_multiple_duplicate_attempts_still_result_in_one_record(int $attempts): void
    {
        $token    = $this->actingAsAdmin();
        $employee = Employee::factory()->create();
        $date     = '2025-07-15';

        // Buat shift pertama
        $this->withToken($token)->postJson('/api/v1/shifts', [
            'employee_id' => $employee->id,
            'shift_date'  => $date,
        ])->assertStatus(201);

        // Coba N kali membuat shift duplikat
        for ($i = 0; $i < $attempts - 1; $i++) {
            $response = $this->withToken($token)->postJson('/api/v1/shifts', [
                'employee_id' => $employee->id,
                'shift_date'  => $date,
            ]);

            // Setiap percobaan duplikasi harus ditolak dengan HTTP 409
            $response->assertStatus(409);
        }

        // Properti inti: setelah N percobaan, harus tetap hanya ada 1 record
        $count = Shift::where('employee_id', $employee->id)
            ->whereDate('shift_date', $date)
            ->count();

        $this->assertSame(
            1,
            $count,
            "Properti 2 dilanggar: setelah {$attempts} percobaan, ditemukan {$count} record shift (seharusnya 1)."
        );
    }

    /**
     * Properti 2 (isolasi antar karyawan): Keunikan shift berlaku per karyawan,
     * bukan secara global. Karyawan berbeda boleh memiliki shift pada tanggal yang sama.
     *
     * Memvalidasi: Kebutuhan 3.3
     *
     * @dataProvider shiftDatesProvider
     */
    public function test_property_uniqueness_is_scoped_per_employee_not_global(string $shiftDate): void
    {
        $token = $this->actingAsAdmin();

        // Buat N karyawan berbeda
        $employees = Employee::factory()->count(5)->create();

        // Setiap karyawan boleh memiliki shift pada tanggal yang sama
        foreach ($employees as $employee) {
            $response = $this->withToken($token)->postJson('/api/v1/shifts', [
                'employee_id' => $employee->id,
                'shift_date'  => $shiftDate,
            ]);

            // Properti: shift untuk karyawan berbeda pada tanggal sama harus diterima
            $response->assertStatus(201);
        }

        // Properti: total record harus sama dengan jumlah karyawan (5)
        $totalShifts = Shift::whereDate('shift_date', $shiftDate)->count();

        $this->assertSame(
            5,
            $totalShifts,
            "Properti 2 (isolasi): seharusnya ada 5 shift (satu per karyawan) pada tanggal {$shiftDate}, ditemukan {$totalShifts}."
        );

        // Properti: setiap karyawan hanya memiliki tepat 1 shift pada tanggal tersebut
        foreach ($employees as $employee) {
            $count = Shift::where('employee_id', $employee->id)
                ->whereDate('shift_date', $shiftDate)
                ->count();

            $this->assertSame(
                1,
                $count,
                "Properti 2 (isolasi): karyawan ID {$employee->id} seharusnya memiliki tepat 1 shift pada {$shiftDate}."
            );
        }
    }

    /**
     * Properti 2 (database constraint): Constraint unik di database harus mencegah
     * insert duplikat bahkan jika dilakukan langsung ke model (bypass controller).
     *
     * Memvalidasi: Kebutuhan 3.3
     *
     * @dataProvider shiftDatesProvider
     */
    public function test_property_database_unique_constraint_prevents_duplicate_shifts(string $shiftDate): void
    {
        $employee = Employee::factory()->create();

        // Insert pertama langsung ke model — harus berhasil
        Shift::create([
            'employee_id'    => $employee->id,
            'shift_date'     => $shiftDate,
            'wage_per_shift' => 50000,
        ]);

        // Insert duplikat langsung ke model — harus melempar exception
        $this->expectException(\Illuminate\Database\QueryException::class);

        Shift::create([
            'employee_id'    => $employee->id,
            'shift_date'     => $shiftDate,
            'wage_per_shift' => 50000,
        ]);
    }

    /**
     * Properti 2 (karyawan berbeda, tanggal berbeda): Setiap kombinasi unik
     * employee_id + shift_date harus dapat disimpan tanpa konflik.
     *
     * Memvalidasi: Kebutuhan 3.3
     */
    public function test_property_each_unique_employee_date_combination_can_be_stored(): void
    {
        $token    = $this->actingAsAdmin();
        $employee = Employee::factory()->create();

        $dates = [
            '2025-01-01', '2025-01-02', '2025-01-03',
            '2025-02-15', '2025-03-20', '2025-07-15',
            '2025-10-01', '2025-12-31',
        ];

        // Setiap tanggal unik untuk karyawan yang sama harus dapat disimpan
        foreach ($dates as $date) {
            $response = $this->withToken($token)->postJson('/api/v1/shifts', [
                'employee_id' => $employee->id,
                'shift_date'  => $date,
            ]);

            $response->assertStatus(201);
        }

        // Properti: jumlah record harus sama dengan jumlah tanggal unik
        $count = Shift::where('employee_id', $employee->id)->count();

        $this->assertSame(
            count($dates),
            $count,
            "Properti 2: setiap kombinasi unik employee+tanggal harus tersimpan. Diharapkan " . count($dates) . " record, ditemukan {$count}."
        );
    }
}
