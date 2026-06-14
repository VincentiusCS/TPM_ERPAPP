<?php

namespace Tests\Feature;

use App\Models\Attendance;
use App\Models\Employee;
use App\Models\Shift;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Tests\TestCase;

class AnalyticsControllerTest extends TestCase
{
    use RefreshDatabase;

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
     * Buat user karyawan biasa dan kembalikan token Bearer.
     */
    private function actingAsEmployee(Employee $employee): string
    {
        $user = User::factory()->create([
            'password'    => Hash::make('password'),
            'role'        => 'karyawan',
            'employee_id' => $employee->id,
        ]);

        return $user->createToken('api-token')->plainTextToken;
    }

    /**
     * Test endpoint blocks unauthenticated requests.
     */
    public function test_performance_unauthenticated_returns_401(): void
    {
        $response = $this->getJson('/api/v1/analytics/performance');
        $response->assertStatus(401);
    }

    /**
     * Test endpoint blocks employee role (non-admin).
     */
    public function test_performance_employee_returns_403(): void
    {
        $employee = Employee::factory()->create();
        $token = $this->actingAsEmployee($employee);

        $response = $this->withToken($token)->getJson('/api/v1/analytics/performance');
        $response->assertStatus(403)
            ->assertJsonFragment([
                'message' => 'Unauthorized. Admin role required.',
            ]);
    }

    /**
     * Test performance index returns 200 with empty list if no employees exist.
     */
    public function test_performance_empty_data_returns_200(): void
    {
        $token = $this->actingAsAdmin();

        $response = $this->withToken($token)->getJson('/api/v1/analytics/performance');

        $response->assertStatus(200)
            ->assertJsonFragment([
                'average_rate' => 0,
                'distribution' => [
                    'Baik' => 0,
                    'Cukup' => 0,
                    'Kurang' => 0,
                ],
                'employees' => [],
                'algorithm' => 'No Data Available',
            ]);
    }

    /**
     * Test rule-based fallback when there is only 1 employee.
     */
    public function test_performance_fallback_rule_based_on_low_count(): void
    {
        $token = $this->actingAsAdmin();

        $employee = Employee::factory()->create(['employee_name' => 'Budi']);
        
        // 2 Shifts
        $shift1 = Shift::create(['employee_id' => $employee->id, 'shift_date' => '2025-01-01']);
        $shift2 = Shift::create(['employee_id' => $employee->id, 'shift_date' => '2025-01-02']);

        // 1 Attendance present
        Attendance::create([
            'employee_id' => $employee->id,
            'shift_id' => $shift1->id,
            'attendance_date' => '2025-01-01',
            'status' => 'hadir',
        ]);
        Attendance::create([
            'employee_id' => $employee->id,
            'shift_id' => $shift2->id,
            'attendance_date' => '2025-01-02',
            'status' => 'tidak hadir',
        ]);

        $response = $this->withToken($token)->getJson('/api/v1/analytics/performance');

        $response->assertStatus(200)
            ->assertJsonFragment([
                'average_rate' => 50,
                'algorithm' => 'Rule-Based Classification',
            ])
            ->assertJsonPath('employees.0.employee_name', 'Budi')
            ->assertJsonPath('employees.0.attendance_rate', 50)
            ->assertJsonPath('employees.0.classification', 'Kurang'); // 50% is < 60%
    }

    /**
     * Test K-Means clustering algorithm when there are 3 employees with distinct rates.
     */
    public function test_performance_kmeans_clustering_on_multiple_employees(): void
    {
        $token = $this->actingAsAdmin();

        // 3 Employees
        $emp1 = Employee::factory()->create(['employee_name' => 'Karyawan 100']);
        $emp2 = Employee::factory()->create(['employee_name' => 'Karyawan 50']);
        $emp3 = Employee::factory()->create(['employee_name' => 'Karyawan 0']);

        // Shift 1
        $s1 = Shift::create(['employee_id' => $emp1->id, 'shift_date' => '2025-01-01']);
        $s2 = Shift::create(['employee_id' => $emp2->id, 'shift_date' => '2025-01-01']);
        $s3 = Shift::create(['employee_id' => $emp3->id, 'shift_date' => '2025-01-01']);

        // Emp 1 present (100%)
        Attendance::create(['employee_id' => $emp1->id, 'shift_id' => $s1->id, 'attendance_date' => '2025-01-01', 'status' => 'hadir']);

        // Emp 2 present 50% (need 2 shifts to show 50%)
        $s2_2 = Shift::create(['employee_id' => $emp2->id, 'shift_date' => '2025-01-02']);
        Attendance::create(['employee_id' => $emp2->id, 'shift_id' => $s2->id, 'attendance_date' => '2025-01-01', 'status' => 'hadir']);
        Attendance::create(['employee_id' => $emp2->id, 'shift_id' => $s2_2->id, 'attendance_date' => '2025-01-02', 'status' => 'tidak hadir']);

        // Emp 3 absent (0%)
        Attendance::create(['employee_id' => $emp3->id, 'shift_id' => $s3->id, 'attendance_date' => '2025-01-01', 'status' => 'tidak hadir']);

        $response = $this->withToken($token)->getJson('/api/v1/analytics/performance');

        $response->assertStatus(200)
            ->assertJsonFragment([
                'algorithm' => 'K-Means Clustering (K=3)',
            ])
            ->assertJsonFragment([
                'average_rate' => 50, // (100 + 50 + 0) / 3 = 50%
            ])
            ->assertJsonPath('distribution.Baik', 1)
            ->assertJsonPath('distribution.Cukup', 1)
            ->assertJsonPath('distribution.Kurang', 1);
    }
}
