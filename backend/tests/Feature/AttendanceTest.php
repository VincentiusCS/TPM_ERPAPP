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
 * Unit tests for AttendanceController.
 *
 * Validates: Requirements 4.1, 4.2, 4.3, 4.4, 4.5
 */
class AttendanceTest extends TestCase
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
     * Buat employee dan shift yang terkait, kembalikan keduanya.
     *
     * @return array{employee: Employee, shift: Shift}
     */
    private function createEmployeeAndShift(): array
    {
        $employee = Employee::factory()->create();
        $shift    = Shift::factory()->create(['employee_id' => $employee->id]);

        return ['employee' => $employee, 'shift' => $shift];
    }

    /**
     * Data presensi valid untuk digunakan di test.
     *
     * @return array<string, mixed>
     */
    private function validAttendanceData(int $employeeId, int $shiftId, string $date = '2025-07-15'): array
    {
        return [
            'employee_id'     => $employeeId,
            'shift_id'        => $shiftId,
            'attendance_date' => $date,
            'status'          => 'hadir',
        ];
    }

    // ─── store Tests ──────────────────────────────────────────────────────────

    /**
     * Test store presensi dengan data lengkap → HTTP 201.
     *
     * Validates: Requirement 4.1
     */
    public function test_store_with_complete_data_returns_201(): void
    {
        $token  = $this->actingAsAdmin();
        $models = $this->createEmployeeAndShift();

        $response = $this->withToken($token)->postJson('/api/v1/attendances', [
            'employee_id'     => $models['employee']->id,
            'shift_id'        => $models['shift']->id,
            'attendance_date' => '2025-07-15',
            'status'          => 'hadir',
        ]);

        $response->assertStatus(201)
            ->assertJsonStructure(['id', 'employee_id', 'shift_id', 'attendance_date', 'status'])
            ->assertJsonFragment([
                'employee_id' => $models['employee']->id,
                'shift_id'    => $models['shift']->id,
                'status'      => 'hadir',
            ]);

        $this->assertDatabaseHas('attendances', [
            'employee_id' => $models['employee']->id,
            'shift_id'    => $models['shift']->id,
            'status'      => 'hadir',
        ]);
    }

    /**
     * Test store presensi dengan status "tidak hadir" → HTTP 201.
     *
     * Validates: Requirement 4.2
     */
    public function test_store_with_status_tidak_hadir_returns_201(): void
    {
        $token  = $this->actingAsAdmin();
        $models = $this->createEmployeeAndShift();

        $response = $this->withToken($token)->postJson('/api/v1/attendances', [
            'employee_id'     => $models['employee']->id,
            'shift_id'        => $models['shift']->id,
            'attendance_date' => '2025-07-15',
            'status'          => 'tidak hadir',
        ]);

        $response->assertStatus(201)
            ->assertJsonFragment(['status' => 'tidak hadir']);
    }

    /**
     * Test store tanpa employee_id → HTTP 422.
     *
     * Validates: Requirement 4.5
     */
    public function test_store_without_employee_id_returns_422(): void
    {
        $token  = $this->actingAsAdmin();
        $models = $this->createEmployeeAndShift();

        $response = $this->withToken($token)->postJson('/api/v1/attendances', [
            'shift_id'        => $models['shift']->id,
            'attendance_date' => '2025-07-15',
            'status'          => 'hadir',
        ]);

        $response->assertStatus(422)
            ->assertJsonValidationErrors(['employee_id']);
    }

    /**
     * Test store tanpa shift_id → HTTP 422.
     *
     * Validates: Requirement 4.5
     */
    public function test_store_without_shift_id_returns_422(): void
    {
        $token  = $this->actingAsAdmin();
        $models = $this->createEmployeeAndShift();

        $response = $this->withToken($token)->postJson('/api/v1/attendances', [
            'employee_id'     => $models['employee']->id,
            'attendance_date' => '2025-07-15',
            'status'          => 'hadir',
        ]);

        $response->assertStatus(422)
            ->assertJsonValidationErrors(['shift_id']);
    }

    /**
     * Test store tanpa employee_id dan shift_id → HTTP 422 dengan kedua error.
     *
     * Validates: Requirement 4.5
     */
    public function test_store_without_employee_id_and_shift_id_returns_422(): void
    {
        $token = $this->actingAsAdmin();

        $response = $this->withToken($token)->postJson('/api/v1/attendances', [
            'attendance_date' => '2025-07-15',
            'status'          => 'hadir',
        ]);

        $response->assertStatus(422)
            ->assertJsonValidationErrors(['employee_id', 'shift_id']);
    }

    /**
     * Test store dengan status tidak valid → HTTP 422.
     *
     * Validates: Requirement 4.2
     */
    public function test_store_with_invalid_status_returns_422(): void
    {
        $token  = $this->actingAsAdmin();
        $models = $this->createEmployeeAndShift();

        $response = $this->withToken($token)->postJson('/api/v1/attendances', [
            'employee_id'     => $models['employee']->id,
            'shift_id'        => $models['shift']->id,
            'attendance_date' => '2025-07-15',
            'status'          => 'absen', // status tidak valid
        ]);

        $response->assertStatus(422)
            ->assertJsonValidationErrors(['status']);
    }

    /**
     * Test store dengan employee_id yang tidak ada → HTTP 422.
     *
     * Validates: Requirement 4.5
     */
    public function test_store_with_nonexistent_employee_id_returns_422(): void
    {
        $token  = $this->actingAsAdmin();
        $models = $this->createEmployeeAndShift();

        $response = $this->withToken($token)->postJson('/api/v1/attendances', [
            'employee_id'     => 9999,
            'shift_id'        => $models['shift']->id,
            'attendance_date' => '2025-07-15',
            'status'          => 'hadir',
        ]);

        $response->assertStatus(422)
            ->assertJsonValidationErrors(['employee_id']);
    }

    /**
     * Test store tanpa token → HTTP 401.
     *
     * Validates: Requirement 1.4
     */
    public function test_store_without_token_returns_401(): void
    {
        $models = $this->createEmployeeAndShift();

        $response = $this->postJson('/api/v1/attendances', [
            'employee_id'     => $models['employee']->id,
            'shift_id'        => $models['shift']->id,
            'attendance_date' => '2025-07-15',
            'status'          => 'hadir',
        ]);

        $response->assertStatus(401);
    }

    // ─── update Tests ─────────────────────────────────────────────────────────

    /**
     * Test update status presensi → HTTP 200.
     *
     * Validates: Requirement 4.3
     */
    public function test_update_attendance_status_returns_200(): void
    {
        $token      = $this->actingAsAdmin();
        $models     = $this->createEmployeeAndShift();
        $attendance = Attendance::factory()->create([
            'employee_id' => $models['employee']->id,
            'shift_id'    => $models['shift']->id,
            'status'      => 'hadir',
        ]);

        $response = $this->withToken($token)->putJson("/api/v1/attendances/{$attendance->id}", [
            'status' => 'tidak hadir',
        ]);

        $response->assertStatus(200)
            ->assertJsonFragment(['status' => 'tidak hadir']);

        $this->assertDatabaseHas('attendances', [
            'id'     => $attendance->id,
            'status' => 'tidak hadir',
        ]);
    }

    /**
     * Test update dari "tidak hadir" ke "hadir" → HTTP 200.
     *
     * Validates: Requirement 4.3
     */
    public function test_update_status_from_tidak_hadir_to_hadir_returns_200(): void
    {
        $token      = $this->actingAsAdmin();
        $models     = $this->createEmployeeAndShift();
        $attendance = Attendance::factory()->create([
            'employee_id' => $models['employee']->id,
            'shift_id'    => $models['shift']->id,
            'status'      => 'tidak hadir',
        ]);

        $response = $this->withToken($token)->putJson("/api/v1/attendances/{$attendance->id}", [
            'status' => 'hadir',
        ]);

        $response->assertStatus(200)
            ->assertJsonFragment(['status' => 'hadir']);
    }

    /**
     * Test update dengan status tidak valid → HTTP 422.
     *
     * Validates: Requirement 4.2
     */
    public function test_update_with_invalid_status_returns_422(): void
    {
        $token      = $this->actingAsAdmin();
        $models     = $this->createEmployeeAndShift();
        $attendance = Attendance::factory()->create([
            'employee_id' => $models['employee']->id,
            'shift_id'    => $models['shift']->id,
        ]);

        $response = $this->withToken($token)->putJson("/api/v1/attendances/{$attendance->id}", [
            'status' => 'invalid-status',
        ]);

        $response->assertStatus(422)
            ->assertJsonValidationErrors(['status']);
    }

    /**
     * Test update presensi yang tidak ada → HTTP 404.
     *
     * Validates: Requirement 4.3
     */
    public function test_update_nonexistent_attendance_returns_404(): void
    {
        $token = $this->actingAsAdmin();

        $response = $this->withToken($token)->putJson('/api/v1/attendances/9999', [
            'status' => 'hadir',
        ]);

        $response->assertStatus(404);
    }

    /**
     * Test update tanpa token → HTTP 401.
     *
     * Validates: Requirement 1.4
     */
    public function test_update_without_token_returns_401(): void
    {
        $models     = $this->createEmployeeAndShift();
        $attendance = Attendance::factory()->create([
            'employee_id' => $models['employee']->id,
            'shift_id'    => $models['shift']->id,
        ]);

        $response = $this->putJson("/api/v1/attendances/{$attendance->id}", [
            'status' => 'hadir',
        ]);

        $response->assertStatus(401);
    }

    // ─── index Tests ──────────────────────────────────────────────────────────

    /**
     * Test index mengembalikan semua presensi tanpa filter.
     *
     * Validates: Requirement 4.4
     */
    public function test_index_returns_all_attendances(): void
    {
        $token  = $this->actingAsAdmin();
        $models = $this->createEmployeeAndShift();

        Attendance::factory()->count(3)->create([
            'employee_id' => $models['employee']->id,
            'shift_id'    => $models['shift']->id,
        ]);

        $response = $this->withToken($token)->getJson('/api/v1/attendances');

        $response->assertStatus(200)
            ->assertJsonCount(3)
            ->assertJsonStructure([
                '*' => ['id', 'employee_id', 'shift_id', 'attendance_date', 'status'],
            ]);
    }

    /**
     * Test index dengan filter employee_id.
     *
     * Validates: Requirement 4.4
     */
    public function test_index_filtered_by_employee_id(): void
    {
        $token     = $this->actingAsAdmin();
        $employee1 = Employee::factory()->create();
        $employee2 = Employee::factory()->create();
        $shift1    = Shift::factory()->create(['employee_id' => $employee1->id]);
        $shift2    = Shift::factory()->create(['employee_id' => $employee2->id]);

        // Buat 2 presensi untuk employee1 dan 3 untuk employee2
        Attendance::factory()->count(2)->create([
            'employee_id' => $employee1->id,
            'shift_id'    => $shift1->id,
        ]);
        Attendance::factory()->count(3)->create([
            'employee_id' => $employee2->id,
            'shift_id'    => $shift2->id,
        ]);

        $response = $this->withToken($token)->getJson("/api/v1/attendances?employee_id={$employee1->id}");

        $response->assertStatus(200)
            ->assertJsonCount(2);

        // Pastikan semua hasil memiliki employee_id yang sesuai
        $data = $response->json();
        foreach ($data as $item) {
            $this->assertEquals($employee1->id, $item['employee_id']);
        }
    }

    /**
     * Test index dengan filter date_from dan date_to.
     *
     * Validates: Requirement 4.4
     */
    public function test_index_filtered_by_date_range(): void
    {
        $token  = $this->actingAsAdmin();
        $models = $this->createEmployeeAndShift();

        // Buat presensi di berbagai tanggal
        Attendance::factory()->create([
            'employee_id'     => $models['employee']->id,
            'shift_id'        => $models['shift']->id,
            'attendance_date' => '2025-07-01',
        ]);
        Attendance::factory()->create([
            'employee_id'     => $models['employee']->id,
            'shift_id'        => $models['shift']->id,
            'attendance_date' => '2025-07-15',
        ]);
        Attendance::factory()->create([
            'employee_id'     => $models['employee']->id,
            'shift_id'        => $models['shift']->id,
            'attendance_date' => '2025-08-01',
        ]);

        $response = $this->withToken($token)->getJson(
            '/api/v1/attendances?date_from=2025-07-01&date_to=2025-07-31'
        );

        $response->assertStatus(200)
            ->assertJsonCount(2);
    }

    /**
     * Test index dengan filter employee_id dan rentang tanggal sekaligus.
     *
     * Validates: Requirement 4.4
     */
    public function test_index_filtered_by_employee_id_and_date_range(): void
    {
        $token     = $this->actingAsAdmin();
        $employee1 = Employee::factory()->create();
        $employee2 = Employee::factory()->create();
        $shift1    = Shift::factory()->create(['employee_id' => $employee1->id]);
        $shift2    = Shift::factory()->create(['employee_id' => $employee2->id]);

        // employee1: 2 presensi dalam rentang, 1 di luar rentang
        Attendance::factory()->create([
            'employee_id'     => $employee1->id,
            'shift_id'        => $shift1->id,
            'attendance_date' => '2025-07-10',
        ]);
        Attendance::factory()->create([
            'employee_id'     => $employee1->id,
            'shift_id'        => $shift1->id,
            'attendance_date' => '2025-07-20',
        ]);
        Attendance::factory()->create([
            'employee_id'     => $employee1->id,
            'shift_id'        => $shift1->id,
            'attendance_date' => '2025-08-05', // di luar rentang
        ]);

        // employee2: 1 presensi dalam rentang (tidak boleh muncul karena filter employee_id)
        Attendance::factory()->create([
            'employee_id'     => $employee2->id,
            'shift_id'        => $shift2->id,
            'attendance_date' => '2025-07-15',
        ]);

        $response = $this->withToken($token)->getJson(
            "/api/v1/attendances?employee_id={$employee1->id}&date_from=2025-07-01&date_to=2025-07-31"
        );

        $response->assertStatus(200)
            ->assertJsonCount(2);

        $data = $response->json();
        foreach ($data as $item) {
            $this->assertEquals($employee1->id, $item['employee_id']);
        }
    }

    /**
     * Test index mengembalikan array kosong jika tidak ada presensi.
     *
     * Validates: Requirement 4.4
     */
    public function test_index_returns_empty_array_when_no_attendances(): void
    {
        $token = $this->actingAsAdmin();

        $response = $this->withToken($token)->getJson('/api/v1/attendances');

        $response->assertStatus(200)
            ->assertJson([]);
    }

    /**
     * Test index tanpa token → HTTP 401.
     *
     * Validates: Requirement 1.4
     */
    public function test_index_without_token_returns_401(): void
    {
        $response = $this->getJson('/api/v1/attendances');

        $response->assertStatus(401);
    }
}
