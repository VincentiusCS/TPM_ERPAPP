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
 * Unit tests for EmployeeController.
 *
 * Validates: Requirements 2.1, 2.2, 2.3, 2.4, 2.5, 2.6
 */
class EmployeeTest extends TestCase
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
     * Data karyawan valid untuk digunakan di test.
     *
     * @return array<string, string>
     */
    private function validEmployeeData(): array
    {
        return [
            'employee_name' => 'Budi Santoso',
            'phone'         => '08123456789',
            'address'       => 'Jl. Merdeka No. 1, Jakarta',
            'status'        => 'aktif',
            'email'         => 'budi.santoso@example.com',
            'password'      => 'password123',
        ];
    }

    // ─── index Tests ──────────────────────────────────────────────────────────

    /**
     * Test index mengembalikan daftar karyawan.
     *
     * Validates: Requirement 2.1
     */
    public function test_index_returns_list_of_employees(): void
    {
        $token = $this->actingAsAdmin();

        Employee::factory()->count(3)->create();

        $response = $this->withToken($token)->getJson('/api/v1/employees');

        $response->assertStatus(200)
            ->assertJsonCount(3)
            ->assertJsonStructure([
                '*' => ['id', 'employee_name', 'phone', 'address', 'status', 'created_at', 'updated_at'],
            ]);
    }

    /**
     * Test index mengembalikan array kosong jika tidak ada karyawan.
     *
     * Validates: Requirement 2.1
     */
    public function test_index_returns_empty_array_when_no_employees(): void
    {
        $token = $this->actingAsAdmin();

        $response = $this->withToken($token)->getJson('/api/v1/employees');

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
        $response = $this->getJson('/api/v1/employees');

        $response->assertStatus(401);
    }

    // ─── store Tests ──────────────────────────────────────────────────────────

    /**
     * Test store dengan data valid → HTTP 201 dan data tersimpan.
     *
     * Validates: Requirement 2.2
     */
    public function test_store_with_valid_data_returns_201(): void
    {
        $token = $this->actingAsAdmin();

        $response = $this->withToken($token)->postJson('/api/v1/employees', $this->validEmployeeData());

        $response->assertStatus(201)
            ->assertJsonStructure(['id', 'employee_name', 'phone', 'address', 'status'])
            ->assertJsonFragment([
                'employee_name' => 'Budi Santoso',
                'phone'         => '08123456789',
                'address'       => 'Jl. Merdeka No. 1, Jakarta',
                'status'        => 'aktif',
            ]);

        $this->assertDatabaseHas('employees', [
            'employee_name' => 'Budi Santoso',
            'phone'         => '08123456789',
        ]);
    }

    /**
     * Test store dengan status nonaktif → HTTP 201.
     *
     * Validates: Requirement 2.2
     */
    public function test_store_with_nonaktif_status_returns_201(): void
    {
        $token = $this->actingAsAdmin();

        $data           = $this->validEmployeeData();
        $data['status'] = 'nonaktif';

        $response = $this->withToken($token)->postJson('/api/v1/employees', $data);

        $response->assertStatus(201)
            ->assertJsonFragment(['status' => 'nonaktif']);
    }

    /**
     * Test store dengan employee_name kosong → HTTP 422 dengan pesan per field.
     *
     * Validates: Requirement 2.3
     */
    public function test_store_with_empty_employee_name_returns_422(): void
    {
        $token = $this->actingAsAdmin();

        $data                   = $this->validEmployeeData();
        $data['employee_name']  = '';

        $response = $this->withToken($token)->postJson('/api/v1/employees', $data);

        $response->assertStatus(422)
            ->assertJsonValidationErrors(['employee_name']);
    }

    /**
     * Test store dengan phone kosong → HTTP 422 dengan pesan per field.
     *
     * Validates: Requirement 2.3
     */
    public function test_store_with_empty_phone_returns_422(): void
    {
        $token = $this->actingAsAdmin();

        $data          = $this->validEmployeeData();
        $data['phone'] = '';

        $response = $this->withToken($token)->postJson('/api/v1/employees', $data);

        $response->assertStatus(422)
            ->assertJsonValidationErrors(['phone']);
    }

    /**
     * Test store dengan address kosong → HTTP 422 dengan pesan per field.
     *
     * Validates: Requirement 2.3
     */
    public function test_store_with_empty_address_returns_422(): void
    {
        $token = $this->actingAsAdmin();

        $data            = $this->validEmployeeData();
        $data['address'] = '';

        $response = $this->withToken($token)->postJson('/api/v1/employees', $data);

        $response->assertStatus(422)
            ->assertJsonValidationErrors(['address']);
    }

    /**
     * Test store dengan semua field kosong → HTTP 422 dengan pesan untuk setiap field.
     *
     * Validates: Requirement 2.3
     */
    public function test_store_with_all_fields_empty_returns_422_with_errors_per_field(): void
    {
        $token = $this->actingAsAdmin();

        $response = $this->withToken($token)->postJson('/api/v1/employees', [
            'employee_name' => '',
            'phone'         => '',
            'address'       => '',
            'status'        => '',
        ]);

        $response->assertStatus(422)
            ->assertJsonValidationErrors(['employee_name', 'phone', 'address', 'status']);
    }

    /**
     * Test store dengan employee_name hanya whitespace → HTTP 422.
     *
     * Validates: Requirement 2.3
     */
    public function test_store_with_whitespace_only_employee_name_returns_422(): void
    {
        $token = $this->actingAsAdmin();

        $data                   = $this->validEmployeeData();
        $data['employee_name']  = '   ';

        $response = $this->withToken($token)->postJson('/api/v1/employees', $data);

        $response->assertStatus(422)
            ->assertJsonValidationErrors(['employee_name']);
    }

    /**
     * Test store dengan status tidak valid → HTTP 422.
     *
     * Validates: Requirement 2.2
     */
    public function test_store_with_invalid_status_returns_422(): void
    {
        $token = $this->actingAsAdmin();

        $data           = $this->validEmployeeData();
        $data['status'] = 'invalid_status';

        $response = $this->withToken($token)->postJson('/api/v1/employees', $data);

        $response->assertStatus(422)
            ->assertJsonValidationErrors(['status']);
    }

    // ─── update Tests ─────────────────────────────────────────────────────────

    /**
     * Test update dengan data valid → HTTP 200 dan data diperbarui.
     *
     * Validates: Requirement 2.4
     */
    public function test_update_with_valid_data_returns_200(): void
    {
        $token    = $this->actingAsAdmin();
        $employee = Employee::factory()->create([
            'employee_name' => 'Nama Lama',
            'status'        => 'aktif',
        ]);

        $response = $this->withToken($token)->putJson("/api/v1/employees/{$employee->id}", [
            'employee_name' => 'Nama Baru',
            'phone'         => '08999999999',
            'address'       => 'Alamat Baru',
            'status'        => 'nonaktif',
            'email'         => 'nama.baru@example.com',
        ]);

        $response->assertStatus(200)
            ->assertJsonFragment([
                'employee_name' => 'Nama Baru',
                'phone'         => '08999999999',
                'address'       => 'Alamat Baru',
                'status'        => 'nonaktif',
            ]);

        $this->assertDatabaseHas('employees', [
            'id'            => $employee->id,
            'employee_name' => 'Nama Baru',
            'status'        => 'nonaktif',
        ]);
    }

    /**
     * Test update karyawan yang tidak ada → HTTP 404.
     *
     * Validates: Requirement 2.4
     */
    public function test_update_nonexistent_employee_returns_404(): void
    {
        $token = $this->actingAsAdmin();

        $response = $this->withToken($token)->putJson('/api/v1/employees/9999', $this->validEmployeeData());

        $response->assertStatus(404);
    }

    /**
     * Test update dengan field kosong → HTTP 422.
     *
     * Validates: Requirement 2.3, 2.4
     */
    public function test_update_with_empty_fields_returns_422(): void
    {
        $token    = $this->actingAsAdmin();
        $employee = Employee::factory()->create();

        $response = $this->withToken($token)->putJson("/api/v1/employees/{$employee->id}", [
            'employee_name' => '',
            'phone'         => '',
            'address'       => '',
            'status'        => 'aktif',
            'email'         => 'some.email@example.com',
        ]);

        $response->assertStatus(422)
            ->assertJsonValidationErrors(['employee_name', 'phone', 'address']);
    }

    // ─── destroy Tests ────────────────────────────────────────────────────────

    /**
     * Test destroy karyawan tanpa data terkait → HTTP 200 dan data terhapus.
     *
     * Validates: Requirement 2.5
     */
    public function test_destroy_employee_without_related_data_returns_200(): void
    {
        $token    = $this->actingAsAdmin();
        $employee = Employee::factory()->create();

        $response = $this->withToken($token)->deleteJson("/api/v1/employees/{$employee->id}");

        $response->assertStatus(200)
            ->assertJsonFragment(['message' => 'Karyawan berhasil dihapus.']);

        $this->assertDatabaseMissing('employees', ['id' => $employee->id]);
    }

    /**
     * Test destroy karyawan yang tidak ada → HTTP 404.
     *
     * Validates: Requirement 2.5
     */
    public function test_destroy_nonexistent_employee_returns_404(): void
    {
        $token = $this->actingAsAdmin();

        $response = $this->withToken($token)->deleteJson('/api/v1/employees/9999');

        $response->assertStatus(404);
    }

    /**
     * Test destroy karyawan dengan data presensi terkait → HTTP 409.
     *
     * Validates: Requirement 2.6
     */
    public function test_destroy_employee_with_attendances_returns_409(): void
    {
        $token    = $this->actingAsAdmin();
        $employee = Employee::factory()->create();

        // Buat shift untuk employee ini
        $shift = Shift::create([
            'employee_id'    => $employee->id,
            'shift_date'     => '2025-01-15',
            'wage_per_shift' => 50000,
        ]);

        // Buat attendance terkait
        Attendance::create([
            'employee_id'     => $employee->id,
            'shift_id'        => $shift->id,
            'attendance_date' => '2025-01-15',
            'status'          => 'hadir',
        ]);

        $response = $this->withToken($token)->deleteJson("/api/v1/employees/{$employee->id}");

        $response->assertStatus(409)
            ->assertJsonFragment([
                'message' => 'Karyawan tidak dapat dihapus karena memiliki data presensi atau payroll terkait.',
            ]);

        // Pastikan karyawan tidak terhapus
        $this->assertDatabaseHas('employees', ['id' => $employee->id]);
    }

    /**
     * Test destroy karyawan dengan data payroll terkait → HTTP 409.
     *
     * Validates: Requirement 2.6
     */
    public function test_destroy_employee_with_payrolls_returns_409(): void
    {
        $token    = $this->actingAsAdmin();
        $employee = Employee::factory()->create();

        // Buat payroll terkait
        Payroll::create([
            'employee_id'      => $employee->id,
            'period_start'     => '2025-01-01',
            'period_end'       => '2025-01-31',
            'total_attendance' => 5,
            'total_salary'     => 250000,
        ]);

        $response = $this->withToken($token)->deleteJson("/api/v1/employees/{$employee->id}");

        $response->assertStatus(409)
            ->assertJsonFragment([
                'message' => 'Karyawan tidak dapat dihapus karena memiliki data presensi atau payroll terkait.',
            ]);

        // Pastikan karyawan tidak terhapus
        $this->assertDatabaseHas('employees', ['id' => $employee->id]);
    }
}
