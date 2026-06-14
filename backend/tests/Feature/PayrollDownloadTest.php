<?php

namespace Tests\Feature;

use App\Models\Attendance;
use App\Models\Employee;
use App\Models\Payroll;
use App\Models\Shift;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Tests\TestCase;

/**
 * Unit tests for PayrollController download endpoints.
 *
 * Validates: Requirements 5.5, 5.6, 5.7
 */
class PayrollDownloadTest extends TestCase
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
    private function createEmployeeWithAttendances(int $count, string $periodStart = '2025-07-01', string $periodEnd = '2025-07-31'): Employee
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

        return $employee;
    }

    // ─── Download Report Tests ────────────────────────────────────────────────

    /**
     * Test download report requires authentication.
     *
     * Validates: Requirement 5.5
     */
    public function test_download_report_without_token_returns_401(): void
    {
        $response = $this->getJson('/api/v1/payrolls/download/report?period_start=2025-07-01&period_end=2025-07-31');

        $response->assertStatus(401);
    }

    /**
     * Test download report requires period_start parameter.
     *
     * Validates: Requirement 5.5
     */
    public function test_download_report_without_period_start_returns_422(): void
    {
        $token = $this->actingAsAdmin();

        $response = $this->withToken($token)->getJson('/api/v1/payrolls/download/report?period_end=2025-07-31');

        $response->assertStatus(422);
    }

    /**
     * Test download report requires period_end parameter.
     *
     * Validates: Requirement 5.5
     */
    public function test_download_report_without_period_end_returns_422(): void
    {
        $token = $this->actingAsAdmin();

        $response = $this->withToken($token)->getJson('/api/v1/payrolls/download/report?period_start=2025-07-01');

        $response->assertStatus(422);
    }

    /**
     * Test download report generates PDF successfully with payroll data.
     *
     * Validates: Requirement 5.5, 5.7
     */
    public function test_download_report_returns_pdf(): void
    {
        $token = $this->actingAsAdmin();

        // Create employee with attendances
        $employee = $this->createEmployeeWithAttendances(5, '2025-07-01', '2025-07-31');

        // First calculate payroll to create records
        $this->withToken($token)->getJson('/api/v1/payrolls?period_start=2025-07-01&period_end=2025-07-31');

        // Mock the dompdf wrapper
        $pdfMock = \Mockery::mock(\Barryvdh\DomPDF\PDF::class);
        $pdfMock->shouldReceive('loadView')
            ->once()
            ->with('payroll.report', \Mockery::type('array'))
            ->andReturnSelf();
        $pdfMock->shouldReceive('download')
            ->once()
            ->andReturn(response('PDF content', 200, [
                'Content-Type' => 'application/pdf',
                'Content-Disposition' => 'attachment; filename="laporan-payroll-2025-07-01-sd-2025-07-31.pdf"',
            ]));

        $this->app->instance('dompdf.wrapper', $pdfMock);

        $response = $this->withToken($token)->get('/api/v1/payrolls/download/report?period_start=2025-07-01&period_end=2025-07-31');

        $response->assertStatus(200);
        $response->assertHeader('Content-Type', 'application/pdf');
    }

    /**
     * Test download report with empty period still generates PDF.
     *
     * Validates: Requirement 5.5
     */
    public function test_download_report_empty_period_returns_pdf(): void
    {
        $token = $this->actingAsAdmin();

        // Mock the dompdf wrapper
        $pdfMock = \Mockery::mock(\Barryvdh\DomPDF\PDF::class);
        $pdfMock->shouldReceive('loadView')
            ->once()
            ->with('payroll.report', \Mockery::on(function ($data) {
                return isset($data['payrolls']) && isset($data['periodStart']) && isset($data['periodEnd']);
            }))
            ->andReturnSelf();
        $pdfMock->shouldReceive('download')
            ->once()
            ->andReturn(response('PDF content', 200, [
                'Content-Type' => 'application/pdf',
            ]));

        $this->app->instance('dompdf.wrapper', $pdfMock);

        $response = $this->withToken($token)->get('/api/v1/payrolls/download/report?period_start=2025-01-01&period_end=2025-01-31');

        $response->assertStatus(200);
    }

    // ─── Download Slip Tests ──────────────────────────────────────────────────

    /**
     * Test download slip requires authentication.
     *
     * Validates: Requirement 5.6
     */
    public function test_download_slip_without_token_returns_401(): void
    {
        $response = $this->getJson('/api/v1/payrolls/1/slip?period_start=2025-07-01&period_end=2025-07-31');

        $response->assertStatus(401);
    }

    /**
     * Test download slip requires period_start parameter.
     *
     * Validates: Requirement 5.6
     */
    public function test_download_slip_without_period_start_returns_422(): void
    {
        $token = $this->actingAsAdmin();
        $employee = Employee::factory()->aktif()->create();

        $response = $this->withToken($token)->getJson("/api/v1/payrolls/{$employee->id}/slip?period_end=2025-07-31");

        $response->assertStatus(422);
    }

    /**
     * Test download slip requires period_end parameter.
     *
     * Validates: Requirement 5.6
     */
    public function test_download_slip_without_period_end_returns_422(): void
    {
        $token = $this->actingAsAdmin();
        $employee = Employee::factory()->aktif()->create();

        $response = $this->withToken($token)->getJson("/api/v1/payrolls/{$employee->id}/slip?period_start=2025-07-01");

        $response->assertStatus(422);
    }

    /**
     * Test download slip for non-existent employee returns 404.
     *
     * Validates: Requirement 5.6
     */
    public function test_download_slip_nonexistent_employee_returns_404(): void
    {
        $token = $this->actingAsAdmin();

        $response = $this->withToken($token)->getJson('/api/v1/payrolls/99999/slip?period_start=2025-07-01&period_end=2025-07-31');

        $response->assertStatus(404);
    }

    /**
     * Test download slip generates PDF successfully.
     *
     * Validates: Requirement 5.6, 5.7
     */
    public function test_download_slip_returns_pdf(): void
    {
        $token = $this->actingAsAdmin();

        // Create employee with attendances
        $employee = $this->createEmployeeWithAttendances(3, '2025-07-01', '2025-07-31');

        // Mock the dompdf wrapper
        $pdfMock = \Mockery::mock(\Barryvdh\DomPDF\PDF::class);
        $pdfMock->shouldReceive('loadView')
            ->once()
            ->with('payroll.slip', \Mockery::on(function ($data) use ($employee) {
                return isset($data['employee'])
                    && isset($data['payroll'])
                    && isset($data['periodStart'])
                    && isset($data['periodEnd'])
                    && $data['employee']->id === $employee->id;
            }))
            ->andReturnSelf();
        $pdfMock->shouldReceive('download')
            ->once()
            ->andReturn(response('PDF content', 200, [
                'Content-Type' => 'application/pdf',
                'Content-Disposition' => "attachment; filename=\"slip-gaji-{$employee->employee_name}-2025-07-01-sd-2025-07-31.pdf\"",
            ]));

        $this->app->instance('dompdf.wrapper', $pdfMock);

        $response = $this->withToken($token)->get("/api/v1/payrolls/{$employee->id}/slip?period_start=2025-07-01&period_end=2025-07-31");

        $response->assertStatus(200);
        $response->assertHeader('Content-Type', 'application/pdf');
    }

    /**
     * Test download slip creates payroll record if not exists.
     *
     * Validates: Requirement 5.6
     */
    public function test_download_slip_creates_payroll_record_if_not_exists(): void
    {
        $token = $this->actingAsAdmin();

        // Create employee with attendances but don't calculate payroll first
        $employee = $this->createEmployeeWithAttendances(4, '2025-07-01', '2025-07-31');

        // Mock the dompdf wrapper
        $pdfMock = \Mockery::mock(\Barryvdh\DomPDF\PDF::class);
        $pdfMock->shouldReceive('loadView')->once()->andReturnSelf();
        $pdfMock->shouldReceive('download')->once()->andReturn(response('PDF content', 200, [
            'Content-Type' => 'application/pdf',
        ]));

        $this->app->instance('dompdf.wrapper', $pdfMock);

        $response = $this->withToken($token)->get("/api/v1/payrolls/{$employee->id}/slip?period_start=2025-07-01&period_end=2025-07-31");

        $response->assertStatus(200);

        // Verify payroll record was created
        $payroll = Payroll::where('employee_id', $employee->id)->first();

        $this->assertNotNull($payroll);
        $this->assertEquals('2025-07-01', $payroll->period_start->format('Y-m-d'));
        $this->assertEquals('2025-07-31', $payroll->period_end->format('Y-m-d'));
        $this->assertEquals(4, $payroll->total_attendance);
        $this->assertEquals(200000, (int) $payroll->total_salary);
    }

    /**
     * Test download slip uses existing payroll record.
     *
     * Validates: Requirement 5.6
     */
    public function test_download_slip_uses_existing_payroll_record(): void
    {
        $token = $this->actingAsAdmin();

        $employee = Employee::factory()->aktif()->create();

        // Create payroll record directly
        Payroll::create([
            'employee_id'      => $employee->id,
            'period_start'     => '2025-07-01',
            'period_end'       => '2025-07-31',
            'total_attendance' => 10,
            'total_salary'     => 500000,
        ]);

        // Mock the dompdf wrapper
        $pdfMock = \Mockery::mock(\Barryvdh\DomPDF\PDF::class);
        $pdfMock->shouldReceive('loadView')->once()->andReturnSelf();
        $pdfMock->shouldReceive('download')->once()->andReturn(response('PDF content', 200, [
            'Content-Type' => 'application/pdf',
        ]));

        $this->app->instance('dompdf.wrapper', $pdfMock);

        $this->withoutExceptionHandling();

        $response = $this->withToken($token)->get("/api/v1/payrolls/{$employee->id}/slip?period_start=2025-07-01&period_end=2025-07-31");

        $response->assertStatus(200);
    }
}
