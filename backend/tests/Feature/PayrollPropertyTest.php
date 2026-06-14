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
 * Property-Based Test: Properti 1 — Kalkulasi Payroll Konsisten
 *
 * Feature: erp-presensi-payroll, Property 1: Kalkulasi Payroll Konsisten
 *
 * Untuk setiap N kehadiran acak (0–100), total_salary harus selalu = N × 50000
 * tanpa memandang urutan data presensi diproses.
 *
 * **Validates: Requirements 5.1, 5.2**
 *
 * Implementasi menggunakan @dataProvider PHPUnit dengan nilai N acak (0–100)
 * untuk memverifikasi bahwa kalkulasi payroll selalu konsisten.
 */
class PayrollPropertyTest extends TestCase
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

    /**
     * Buat employee dengan N kehadiran "hadir" dalam periode tertentu.
     */
    private function createEmployeeWithNAttendances(int $n, string $periodStart = '2025-01-01'): Employee
    {
        $employee = Employee::factory()->aktif()->create();

        for ($i = 0; $i < $n; $i++) {
            $date = date('Y-m-d', strtotime($periodStart . " +{$i} days"));

            $shift = Shift::factory()->create([
                'employee_id' => $employee->id,
                'shift_date'  => $date,
            ]);

            Attendance::factory()->hadir()->create([
                'employee_id'     => $employee->id,
                'shift_id'        => $shift->id,
                'attendance_date' => $date,
            ]);
        }

        return $employee;
    }

    // ─── Data Providers ───────────────────────────────────────────────────────

    /**
     * Menghasilkan 100 nilai N acak antara 0 dan 100 untuk property test.
     * Setiap iterasi menguji bahwa total_salary = N × 50000.
     *
     * @return array<string, array{int}>
     */
    public static function randomAttendanceCountProvider(): array
    {
        $cases = [];

        // Seed the random number generator for reproducibility in CI
        mt_srand(42);

        for ($i = 0; $i < 100; $i++) {
            $n = mt_rand(0, 100);
            $cases["N={$n} (iterasi {$i})"] = [$n];
        }

        // Reset seed
        mt_srand();

        return $cases;
    }

    // ─── Property Tests ───────────────────────────────────────────────────────

    /**
     * Properti 1: Untuk setiap N kehadiran acak (0–100), total_salary harus
     * selalu = N × 50000 tanpa memandang urutan data.
     *
     * Memvalidasi: Kebutuhan 5.1, 5.2
     *
     * @dataProvider randomAttendanceCountProvider
     */
    public function test_property_payroll_calculation_consistent(int $n): void
    {
        $token = $this->actingAsAdmin();
        $this->createEmployeeWithNAttendances($n);

        $response = $this->withToken($token)->getJson('/api/v1/payrolls?' . http_build_query([
            'period_start' => '2025-01-01',
            'period_end'   => '2025-12-31',
        ]));

        $response->assertStatus(200);

        $expectedSalary = $n * 50000;

        if ($n === 0) {
            // Ketika N=0, tidak ada kehadiran → total = 0, data kosong
            $response->assertJsonPath('total', 0);
        } else {
            // Ketika N > 0, harus ada data karyawan dengan kalkulasi yang benar
            $data = $response->json('data');
            $this->assertNotEmpty($data, "Seharusnya ada data payroll untuk N={$n} kehadiran.");

            $employeePayroll = $data[0];
            $this->assertSame(
                $n,
                $employeePayroll['total_attendance'],
                "Properti 1 dilanggar: total_attendance seharusnya {$n}, ditemukan {$employeePayroll['total_attendance']}."
            );
            $this->assertSame(
                $expectedSalary,
                $employeePayroll['total_salary'],
                "Properti 1 dilanggar: total_salary seharusnya {$expectedSalary} (N={$n} × 50000), ditemukan {$employeePayroll['total_salary']}."
            );
        }
    }
}
