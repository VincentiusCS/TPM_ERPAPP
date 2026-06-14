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
 * Property-Based Test: Properti 10 — Payroll Periode Kosong
 *
 * Feature: erp-presensi-payroll, Property 10: Payroll Periode Kosong
 *
 * Untuk setiap periode yang tidak memiliki data presensi berstatus "hadir",
 * sistem harus mengembalikan total gaji sebesar 0 dan menampilkan pesan informatif,
 * bukan error.
 *
 * **Validates: Requirements 5.8**
 *
 * Implementasi menggunakan @dataProvider PHPUnit dengan periode acak (minimal 100 iterasi)
 * untuk memverifikasi bahwa periode tanpa kehadiran selalu menghasilkan respons yang benar.
 */
class PayrollEmptyPeriodPropertyTest extends TestCase
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
     * Menghasilkan 100 periode acak yang dijamin tidak memiliki presensi "hadir".
     * Setiap iterasi menguji bahwa respons HTTP 200 dengan total=0 dan pesan informatif.
     *
     * @return array<string, array{string, string, string}>
     */
    public static function randomEmptyPeriodProvider(): array
    {
        $cases = [];

        // Seed for reproducibility
        mt_srand(123);

        for ($i = 0; $i < 100; $i++) {
            // Generate random year between 2020 and 2030
            $year = mt_rand(2020, 2030);
            // Generate random month
            $month = mt_rand(1, 12);
            // Generate random start day (1-20 to leave room for end day)
            $startDay = mt_rand(1, 20);
            // Generate random end day (start+1 to 28 to avoid month overflow)
            $endDay = mt_rand($startDay + 1, 28);

            $periodStart = sprintf('%04d-%02d-%02d', $year, $month, $startDay);
            $periodEnd   = sprintf('%04d-%02d-%02d', $year, $month, $endDay);

            // Variation type: 'empty' = completely empty period, 'tidak_hadir' = only "tidak hadir" attendances
            $variation = ($i % 2 === 0) ? 'empty' : 'tidak_hadir';

            $cases["periode {$periodStart} s/d {$periodEnd} ({$variation}, iterasi {$i})"] = [
                $periodStart,
                $periodEnd,
                $variation,
            ];
        }

        // Reset seed
        mt_srand();

        return $cases;
    }

    // ─── Property Tests ───────────────────────────────────────────────────────

    /**
     * Properti 10: Untuk setiap periode yang tidak memiliki presensi "hadir",
     * sistem harus mengembalikan total_salary = 0 dan pesan informatif, bukan error.
     *
     * Memvalidasi: Kebutuhan 5.8
     *
     * Variasi yang diuji:
     * - Periode yang benar-benar kosong (tidak ada presensi sama sekali)
     * - Periode yang hanya memiliki presensi "tidak hadir"
     *
     * @dataProvider randomEmptyPeriodProvider
     */
    public function test_property_empty_period_returns_zero_salary_with_message(
        string $periodStart,
        string $periodEnd,
        string $variation
    ): void {
        $token = $this->actingAsAdmin();

        if ($variation === 'tidak_hadir') {
            // Buat karyawan dengan presensi "tidak hadir" dalam periode ini
            $employee = Employee::factory()->aktif()->create();

            // Hitung jumlah hari dalam periode untuk menghindari duplikat shift_date
            $totalDays = max(1, (int) ((strtotime($periodEnd) - strtotime($periodStart)) / 86400));
            // Buat presensi "tidak hadir" dengan jumlah yang tidak melebihi hari yang tersedia
            $numAttendances = mt_rand(1, min(5, $totalDays));

            for ($i = 0; $i < $numAttendances; $i++) {
                $date = date('Y-m-d', strtotime($periodStart . " +{$i} days"));

                $shift = Shift::factory()->create([
                    'employee_id' => $employee->id,
                    'shift_date'  => $date,
                ]);

                Attendance::factory()->tidakHadir()->create([
                    'employee_id'     => $employee->id,
                    'shift_id'        => $shift->id,
                    'attendance_date' => $date,
                ]);
            }
        }
        // Untuk variasi 'empty', tidak ada data presensi sama sekali

        $response = $this->withToken($token)->getJson('/api/v1/payrolls?' . http_build_query([
            'period_start' => $periodStart,
            'period_end'   => $periodEnd,
        ]));

        // Properti 10: Harus HTTP 200, bukan error
        $response->assertStatus(200);

        // Properti 10: total harus 0
        $response->assertJsonPath('total', 0);

        // Properti 10: data harus array kosong
        $response->assertJsonPath('data', []);

        // Properti 10: pesan informatif harus ada (tidak kosong)
        $message = $response->json('message');
        $this->assertNotNull(
            $message,
            "Properti 10 dilanggar: pesan informatif harus ada untuk periode kosong ({$periodStart} s/d {$periodEnd}, variasi: {$variation})."
        );
        $this->assertNotEmpty(
            $message,
            "Properti 10 dilanggar: pesan informatif tidak boleh kosong untuk periode tanpa kehadiran ({$periodStart} s/d {$periodEnd}, variasi: {$variation})."
        );
    }
}
