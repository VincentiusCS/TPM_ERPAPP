<?php

namespace Tests\Feature;

use App\Models\Attendance;
use App\Models\Employee;
use App\Models\Shift;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Tests\TestCase;

class PayrollControllerTest extends TestCase
{
    use RefreshDatabase;

    protected static array $mockHolidays = [];

    protected function setUp(): void
    {
        parent::setUp();
        
        // Dynamic mock setup for holidays API (ignoring query parameters)
        \Illuminate\Support\Facades\Http::fake(function ($request) {
            if (str_contains($request->url(), 'libur.deno.dev/api')) {
                return \Illuminate\Support\Facades\Http::response(self::$mockHolidays, 200);
            }
        });
        
        self::$mockHolidays = [];
        \Illuminate\Support\Facades\Cache::flush();
    }

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
     *
     * @return array{employee: Employee, shifts: \Illuminate\Support\Collection}
     */
    private function createEmployeeWithAttendances(int $count, string $periodStart = '2025-07-01', string $periodEnd = '2025-07-31'): array
    {
        $employee = Employee::factory()->aktif()->create();

        for ($i = 0; $i < $count; $i++) {
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

        return ['employee' => $employee];
    }

    // ─── Kalkulasi Payroll Tests ──────────────────────────────────────────────

    /**
     * Test kalkulasi payroll dengan 1 kehadiran → total_salary = 50000.
     *
     * Validates: Requirement 5.1, 5.2
     */
    public function test_payroll_calculation_with_1_attendance(): void
    {
        $token = $this->actingAsAdmin();
        $this->createEmployeeWithAttendances(1);

        $response = $this->withToken($token)->getJson('/api/v1/payrolls?' . http_build_query([
            'period_start' => '2025-07-01',
            'period_end'   => '2025-07-31',
        ]));

        $response->assertStatus(200);
        $response->assertJsonPath('data.0.total_attendance', 1);
        $response->assertJsonPath('data.0.total_salary', 50000);
    }

    /**
     * Test kalkulasi payroll dengan 5 kehadiran → total_salary = 250000.
     *
     * Validates: Requirement 5.1, 5.2
     */
    public function test_payroll_calculation_with_5_attendances(): void
    {
        $token = $this->actingAsAdmin();
        $this->createEmployeeWithAttendances(5);

        $response = $this->withToken($token)->getJson('/api/v1/payrolls?' . http_build_query([
            'period_start' => '2025-07-01',
            'period_end'   => '2025-07-31',
        ]));

        $response->assertStatus(200);
        $response->assertJsonPath('data.0.total_attendance', 5);
        $response->assertJsonPath('data.0.total_salary', 250000);
    }

    /**
     * Test kalkulasi payroll dengan 20 kehadiran → total_salary = 1000000.
     *
     * Validates: Requirement 5.1, 5.2
     */
    public function test_payroll_calculation_with_20_attendances(): void
    {
        $token = $this->actingAsAdmin();
        $this->createEmployeeWithAttendances(20);

        $response = $this->withToken($token)->getJson('/api/v1/payrolls?' . http_build_query([
            'period_start' => '2025-07-01',
            'period_end'   => '2025-07-31',
        ]));

        $response->assertStatus(200);
        $response->assertJsonPath('data.0.total_attendance', 20);
        $response->assertJsonPath('data.0.total_salary', 1000000);
    }

    /**
     * Test bahwa hanya presensi "hadir" yang dihitung, "tidak hadir" diabaikan.
     *
     * Validates: Requirement 5.2
     */
    public function test_payroll_only_counts_hadir_status(): void
    {
        $token = $this->actingAsAdmin();
        $employee = Employee::factory()->aktif()->create();

        // Buat 3 kehadiran "hadir"
        for ($i = 0; $i < 3; $i++) {
            $date = date('Y-m-d', strtotime("2025-07-01 +{$i} days"));
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

        // Buat 2 presensi "tidak hadir"
        for ($i = 3; $i < 5; $i++) {
            $date = date('Y-m-d', strtotime("2025-07-01 +{$i} days"));
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

        $response = $this->withToken($token)->getJson('/api/v1/payrolls?' . http_build_query([
            'period_start' => '2025-07-01',
            'period_end'   => '2025-07-31',
        ]));

        $response->assertStatus(200);
        // Hanya 3 kehadiran "hadir" yang dihitung
        $response->assertJsonPath('data.0.total_attendance', 3);
        $response->assertJsonPath('data.0.total_salary', 150000);
    }

    // ─── Periode Tanpa Data Tests ─────────────────────────────────────────────

    /**
     * Test periode tanpa data presensi → HTTP 200, total = 0, pesan informatif.
     *
     * Validates: Requirement 5.8
     */
    public function test_payroll_empty_period_returns_200_with_zero_total(): void
    {
        $token = $this->actingAsAdmin();

        $response = $this->withToken($token)->getJson('/api/v1/payrolls?' . http_build_query([
            'period_start' => '2025-01-01',
            'period_end'   => '2025-01-31',
        ]));

        $response->assertStatus(200);
        $response->assertJsonPath('total', 0);
        $response->assertJsonPath('data', []);
        $response->assertJsonStructure(['message']);
        // Pesan harus informatif (tidak null/kosong)
        $this->assertNotNull($response->json('message'));
        $this->assertNotEmpty($response->json('message'));
    }

    /**
     * Test periode dengan karyawan tapi tanpa kehadiran "hadir" → total = 0.
     *
     * Validates: Requirement 5.8
     */
    public function test_payroll_period_with_only_tidak_hadir_returns_zero(): void
    {
        $token = $this->actingAsAdmin();
        $employee = Employee::factory()->aktif()->create();

        // Buat presensi "tidak hadir" saja
        $shift = Shift::factory()->create([
            'employee_id' => $employee->id,
            'shift_date'  => '2025-07-10',
        ]);
        Attendance::factory()->tidakHadir()->create([
            'employee_id'     => $employee->id,
            'shift_id'        => $shift->id,
            'attendance_date' => '2025-07-10',
        ]);

        $response = $this->withToken($token)->getJson('/api/v1/payrolls?' . http_build_query([
            'period_start' => '2025-07-01',
            'period_end'   => '2025-07-31',
        ]));

        $response->assertStatus(200);
        $response->assertJsonPath('total', 0);
        $response->assertJsonPath('data', []);
        $response->assertJsonStructure(['message']);
        $this->assertNotNull($response->json('message'));
    }

    // ─── Filter Pencarian Nama Karyawan Tests ─────────────────────────────────

    /**
     * Test filter pencarian nama karyawan mengembalikan data yang sesuai.
     *
     * Validates: Requirement 5.4
     */
    public function test_payroll_search_filter_returns_matching_employee(): void
    {
        $token = $this->actingAsAdmin();

        // Buat karyawan dengan nama spesifik
        $employee1 = Employee::factory()->aktif()->create(['employee_name' => 'Budi Santoso']);
        $employee2 = Employee::factory()->aktif()->create(['employee_name' => 'Andi Wijaya']);

        // Buat kehadiran untuk kedua karyawan
        foreach ([$employee1, $employee2] as $employee) {
            $shift = Shift::factory()->create([
                'employee_id' => $employee->id,
                'shift_date'  => '2025-07-05',
            ]);
            Attendance::factory()->hadir()->create([
                'employee_id'     => $employee->id,
                'shift_id'        => $shift->id,
                'attendance_date' => '2025-07-05',
            ]);
        }

        // Cari "Budi"
        $response = $this->withToken($token)->getJson('/api/v1/payrolls?' . http_build_query([
            'period_start' => '2025-07-01',
            'period_end'   => '2025-07-31',
            'search'       => 'Budi',
        ]));

        $response->assertStatus(200);
        $response->assertJsonPath('total', 1);
        $response->assertJsonPath('data.0.employee_name', 'Budi Santoso');
    }

    /**
     * Test filter pencarian yang tidak cocok → total = 0, pesan informatif.
     *
     * Validates: Requirement 5.4, 5.8
     */
    public function test_payroll_search_filter_no_match_returns_zero(): void
    {
        $token = $this->actingAsAdmin();

        // Buat karyawan dengan kehadiran
        $this->createEmployeeWithAttendances(3);

        // Cari nama yang tidak ada
        $response = $this->withToken($token)->getJson('/api/v1/payrolls?' . http_build_query([
            'period_start' => '2025-07-01',
            'period_end'   => '2025-07-31',
            'search'       => 'NamaTidakAda',
        ]));

        $response->assertStatus(200);
        $response->assertJsonPath('total', 0);
        $response->assertJsonPath('data', []);
        $response->assertJsonStructure(['message']);
    }

    /**
     * Test filter pencarian partial match (substring).
     *
     * Validates: Requirement 5.4
     */
    public function test_payroll_search_filter_partial_match(): void
    {
        $token = $this->actingAsAdmin();

        $employee = Employee::factory()->aktif()->create(['employee_name' => 'Muhammad Rizki Pratama']);

        $shift = Shift::factory()->create([
            'employee_id' => $employee->id,
            'shift_date'  => '2025-07-10',
        ]);
        Attendance::factory()->hadir()->create([
            'employee_id'     => $employee->id,
            'shift_id'        => $shift->id,
            'attendance_date' => '2025-07-10',
        ]);

        // Cari dengan substring "Rizki"
        $response = $this->withToken($token)->getJson('/api/v1/payrolls?' . http_build_query([
            'period_start' => '2025-07-01',
            'period_end'   => '2025-07-31',
            'search'       => 'Rizki',
        ]));

        $response->assertStatus(200);
        $response->assertJsonPath('total', 1);
        $response->assertJsonPath('data.0.employee_name', 'Muhammad Rizki Pratama');
    }

    // ─── Validasi dan Struktur Response Tests ─────────────────────────────────

    /**
     * Test response structure memuat field yang diperlukan.
     *
     * Validates: Requirement 5.3
     */
    public function test_payroll_response_structure(): void
    {
        $token = $this->actingAsAdmin();
        $this->createEmployeeWithAttendances(2);

        $response = $this->withToken($token)->getJson('/api/v1/payrolls?' . http_build_query([
            'period_start' => '2025-07-01',
            'period_end'   => '2025-07-31',
        ]));

        $response->assertStatus(200);
        $response->assertJsonStructure([
            'data' => [
                '*' => [
                    'employee_id',
                    'employee_name',
                    'total_attendance',
                    'total_salary',
                ],
            ],
            'total',
            'message',
        ]);
    }

    /**
     * Test akses payroll tanpa token → HTTP 401.
     *
     * Validates: Requirement 1.4
     */
    public function test_payroll_without_token_returns_401(): void
    {
        $response = $this->getJson('/api/v1/payrolls?' . http_build_query([
            'period_start' => '2025-07-01',
            'period_end'   => '2025-07-31',
        ]));

        $response->assertStatus(401);
    }

    /**
     * Test payroll tanpa period_start → HTTP 422.
     */
    public function test_payroll_without_period_start_returns_422(): void
    {
        $token = $this->actingAsAdmin();

        $response = $this->withToken($token)->getJson('/api/v1/payrolls?' . http_build_query([
            'period_end' => '2025-07-31',
        ]));

        $response->assertStatus(422);
    }

    /**
     * Test payroll tanpa period_end → HTTP 422.
     */
    public function test_payroll_without_period_end_returns_422(): void
    {
        $token = $this->actingAsAdmin();

        $response = $this->withToken($token)->getJson('/api/v1/payrolls?' . http_build_query([
            'period_start' => '2025-07-01',
        ]));

        $response->assertStatus(422);
    }

    /**
     * Test payroll sets shift wage to Rp100,000 when worked on a holiday.
     */
    public function test_payroll_sets_holiday_fee_to_100000(): void
    {
        // Set mock holidays for this test case
        self::$mockHolidays = [
            [
                'date' => '2025-07-10',
                'name' => 'Hari Libur Test',
                'is_national_holiday' => true,
            ]
        ];

        \Illuminate\Support\Facades\Cache::flush();

        $token = $this->actingAsAdmin();
        $employee = Employee::factory()->aktif()->create();

        // 2 shifts: one normal (2025-07-09) and one holiday (2025-07-10)
        $s1 = Shift::create(['employee_id' => $employee->id, 'shift_date' => '2025-07-09', 'wage_per_shift' => 50000]);
        $s2 = Shift::create(['employee_id' => $employee->id, 'shift_date' => '2025-07-10', 'wage_per_shift' => 50000]);

        Attendance::create(['employee_id' => $employee->id, 'shift_id' => $s1->id, 'attendance_date' => '2025-07-09', 'status' => 'hadir']);
        Attendance::create(['employee_id' => $employee->id, 'shift_id' => $s2->id, 'attendance_date' => '2025-07-10', 'status' => 'hadir']);

        $response = $this->withToken($token)->getJson('/api/v1/payrolls?' . http_build_query([
            'period_start' => '2025-07-01',
            'period_end'   => '2025-07-31',
        ]));

        $response->assertStatus(200);
        
        // normal wage (50000) + holiday wage (100000) = 150000
        $response->assertJsonPath('data.0.total_salary', 150000);
    }
}
