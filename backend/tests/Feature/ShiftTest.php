<?php

namespace Tests\Feature;

use App\Models\Employee;
use App\Models\Shift;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Tests\TestCase;

/**
 * Unit tests for ShiftController.
 *
 * Validates: Requirements 3.1, 3.2, 3.3, 3.4
 */
class ShiftTest extends TestCase
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
     * Data shift valid untuk digunakan di test.
     *
     * @return array<string, mixed>
     */
    private function validShiftData(int $employeeId, string $shiftDate = '2025-07-15'): array
    {
        return [
            'employee_id' => $employeeId,
            'shift_date'  => $shiftDate,
        ];
    }

    // ─── index Tests ──────────────────────────────────────────────────────────

    /**
     * Test index mengembalikan daftar shift.
     *
     * Validates: Requirement 3.2
     */
    public function test_index_returns_list_of_shifts(): void
    {
        $token    = $this->actingAsAdmin();
        $employee = Employee::factory()->create();

        Shift::create([
            'employee_id'    => $employee->id,
            'shift_date'     => '2025-07-10',
            'wage_per_shift' => 50000,
        ]);
        Shift::create([
            'employee_id'    => $employee->id,
            'shift_date'     => '2025-07-11',
            'wage_per_shift' => 50000,
        ]);

        $response = $this->withToken($token)->getJson('/api/v1/shifts');

        $response->assertStatus(200)
            ->assertJsonCount(2)
            ->assertJsonStructure([
                '*' => ['id', 'employee_id', 'shift_date', 'wage_per_shift', 'created_at', 'updated_at'],
            ]);
    }

    /**
     * Test index mengembalikan array kosong jika tidak ada shift.
     *
     * Validates: Requirement 3.2
     */
    public function test_index_returns_empty_array_when_no_shifts(): void
    {
        $token = $this->actingAsAdmin();

        $response = $this->withToken($token)->getJson('/api/v1/shifts');

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
        $response = $this->getJson('/api/v1/shifts');

        $response->assertStatus(401);
    }

    // ─── store Tests ──────────────────────────────────────────────────────────

    /**
     * Test store shift baru → HTTP 201 dan data tersimpan.
     *
     * Validates: Requirement 3.1
     */
    public function test_store_new_shift_returns_201(): void
    {
        $token    = $this->actingAsAdmin();
        $employee = Employee::factory()->create();

        $response = $this->withToken($token)->postJson('/api/v1/shifts', [
            'employee_id' => $employee->id,
            'shift_date'  => '2025-07-15',
        ]);

        $response->assertStatus(201)
            ->assertJsonStructure(['id', 'employee_id', 'shift_date', 'wage_per_shift'])
            ->assertJsonFragment([
                'employee_id'    => $employee->id,
                'wage_per_shift' => '50000.00',
            ]);

        $this->assertDatabaseHas('shifts', [
            'employee_id' => $employee->id,
        ]);
    }

    /**
     * Test store shift baru dengan wage_per_shift default = 50000.
     *
     * Validates: Requirement 3.1
     */
    public function test_store_shift_uses_default_wage_per_shift(): void
    {
        $token    = $this->actingAsAdmin();
        $employee = Employee::factory()->create();

        $response = $this->withToken($token)->postJson('/api/v1/shifts', [
            'employee_id' => $employee->id,
            'shift_date'  => '2025-07-20',
        ]);

        $response->assertStatus(201)
            ->assertJsonFragment(['wage_per_shift' => '50000.00']);
    }

    /**
     * Test store shift duplikat (employee + tanggal sama) → HTTP 409.
     *
     * Validates: Requirement 3.3
     */
    public function test_store_duplicate_shift_returns_409(): void
    {
        $token    = $this->actingAsAdmin();
        $employee = Employee::factory()->create();

        // Buat shift pertama
        Shift::create([
            'employee_id'    => $employee->id,
            'shift_date'     => '2025-07-15',
            'wage_per_shift' => 50000,
        ]);

        // Coba buat shift duplikat (employee + tanggal sama)
        $response = $this->withToken($token)->postJson('/api/v1/shifts', [
            'employee_id' => $employee->id,
            'shift_date'  => '2025-07-15',
        ]);

        $response->assertStatus(409)
            ->assertJsonFragment([
                'message' => 'Shift pada tanggal tersebut sudah terdaftar untuk karyawan ini.',
            ]);

        // Pastikan hanya ada satu record di database
        $this->assertDatabaseCount('shifts', 1);
    }

    /**
     * Test store shift duplikat tidak terjadi jika karyawan berbeda.
     *
     * Validates: Requirement 3.3
     */
    public function test_store_same_date_different_employee_returns_201(): void
    {
        $token     = $this->actingAsAdmin();
        $employee1 = Employee::factory()->create();
        $employee2 = Employee::factory()->create();

        // Buat shift untuk karyawan pertama
        Shift::create([
            'employee_id'    => $employee1->id,
            'shift_date'     => '2025-07-15',
            'wage_per_shift' => 50000,
        ]);

        // Buat shift untuk karyawan kedua pada tanggal yang sama → harus berhasil
        $response = $this->withToken($token)->postJson('/api/v1/shifts', [
            'employee_id' => $employee2->id,
            'shift_date'  => '2025-07-15',
        ]);

        $response->assertStatus(201);
        $this->assertDatabaseCount('shifts', 2);
    }

    /**
     * Test store tanpa employee_id → HTTP 422.
     *
     * Validates: Requirement 3.1
     */
    public function test_store_without_employee_id_returns_422(): void
    {
        $token = $this->actingAsAdmin();

        $response = $this->withToken($token)->postJson('/api/v1/shifts', [
            'shift_date' => '2025-07-15',
        ]);

        $response->assertStatus(422)
            ->assertJsonValidationErrors(['employee_id']);
    }

    /**
     * Test store tanpa shift_date → HTTP 422.
     *
     * Validates: Requirement 3.1
     */
    public function test_store_without_shift_date_returns_422(): void
    {
        $token    = $this->actingAsAdmin();
        $employee = Employee::factory()->create();

        $response = $this->withToken($token)->postJson('/api/v1/shifts', [
            'employee_id' => $employee->id,
        ]);

        $response->assertStatus(422)
            ->assertJsonValidationErrors(['shift_date']);
    }

    /**
     * Test store dengan employee_id yang tidak ada → HTTP 422.
     *
     * Validates: Requirement 3.1
     */
    public function test_store_with_nonexistent_employee_id_returns_422(): void
    {
        $token = $this->actingAsAdmin();

        $response = $this->withToken($token)->postJson('/api/v1/shifts', [
            'employee_id' => 9999,
            'shift_date'  => '2025-07-15',
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
        $employee = Employee::factory()->create();

        $response = $this->postJson('/api/v1/shifts', [
            'employee_id' => $employee->id,
            'shift_date'  => '2025-07-15',
        ]);

        $response->assertStatus(401);
    }

    // ─── destroy Tests ────────────────────────────────────────────────────────

    /**
     * Test destroy shift → HTTP 200 dan data terhapus.
     *
     * Validates: Requirement 3.4
     */
    public function test_destroy_shift_returns_200_and_data_deleted(): void
    {
        $token    = $this->actingAsAdmin();
        $employee = Employee::factory()->create();

        $shift = Shift::create([
            'employee_id'    => $employee->id,
            'shift_date'     => '2025-07-15',
            'wage_per_shift' => 50000,
        ]);

        $response = $this->withToken($token)->deleteJson("/api/v1/shifts/{$shift->id}");

        $response->assertStatus(200)
            ->assertJsonFragment(['message' => 'Shift berhasil dihapus.']);

        $this->assertDatabaseMissing('shifts', ['id' => $shift->id]);
    }

    /**
     * Test destroy shift yang tidak ada → HTTP 404.
     *
     * Validates: Requirement 3.4
     */
    public function test_destroy_nonexistent_shift_returns_404(): void
    {
        $token = $this->actingAsAdmin();

        $response = $this->withToken($token)->deleteJson('/api/v1/shifts/9999');

        $response->assertStatus(404);
    }

    /**
     * Test destroy tanpa token → HTTP 401.
     *
     * Validates: Requirement 1.4
     */
    public function test_destroy_without_token_returns_401(): void
    {
        $employee = Employee::factory()->create();

        $shift = Shift::create([
            'employee_id'    => $employee->id,
            'shift_date'     => '2025-07-15',
            'wage_per_shift' => 50000,
        ]);

        $response = $this->deleteJson("/api/v1/shifts/{$shift->id}");

        $response->assertStatus(401);
    }
}
