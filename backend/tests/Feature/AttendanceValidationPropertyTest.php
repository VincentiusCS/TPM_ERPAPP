<?php

namespace Tests\Feature;

use App\Models\Employee;
use App\Models\Shift;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Tests\TestCase;

/**
 * Property-Based Test: Properti 4 — Validasi Input Presensi
 *
 * Feature: erp-presensi-payroll, Property 4: Validasi Input Presensi
 *
 * Untuk setiap permintaan pencatatan presensi tanpa `employee_id` atau `shift_id`,
 * sistem harus menolak permintaan dan mengembalikan HTTP 422 dengan pesan validasi
 * yang menjelaskan field yang wajib diisi.
 *
 * Memvalidasi: Kebutuhan 4.5
 *
 * Implementasi menggunakan @dataProvider PHPUnit dengan berbagai kombinasi
 * payload yang tidak lengkap untuk memverifikasi properti validasi input.
 */
class AttendanceValidationPropertyTest extends TestCase
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
     * Berbagai payload yang tidak memiliki employee_id.
     * Properti harus berlaku: sistem mengembalikan HTTP 422.
     *
     * @return array<string, array{array<string, mixed>, list<string>}>
     */
    public static function missingEmployeeIdProvider(): array
    {
        return [
            'hanya shift_id dan tanggal dan status' => [
                ['shift_id' => 1, 'attendance_date' => '2025-07-15', 'status' => 'hadir'],
                ['employee_id'],
            ],
            'hanya shift_id' => [
                ['shift_id' => 1],
                ['employee_id'],
            ],
            'hanya tanggal' => [
                ['attendance_date' => '2025-07-15'],
                ['employee_id'],
            ],
            'hanya status' => [
                ['status' => 'hadir'],
                ['employee_id'],
            ],
            'payload kosong' => [
                [],
                ['employee_id', 'shift_id'],
            ],
            'employee_id null' => [
                ['employee_id' => null, 'shift_id' => 1, 'attendance_date' => '2025-07-15', 'status' => 'hadir'],
                ['employee_id'],
            ],
            'employee_id string kosong' => [
                ['employee_id' => '', 'shift_id' => 1, 'attendance_date' => '2025-07-15', 'status' => 'hadir'],
                ['employee_id'],
            ],
        ];
    }

    /**
     * Berbagai payload yang tidak memiliki shift_id.
     * Properti harus berlaku: sistem mengembalikan HTTP 422.
     *
     * @return array<string, array{array<string, mixed>, list<string>}>
     */
    public static function missingShiftIdProvider(): array
    {
        return [
            'hanya employee_id dan tanggal dan status' => [
                ['employee_id' => 1, 'attendance_date' => '2025-07-15', 'status' => 'hadir'],
                ['shift_id'],
            ],
            'hanya employee_id' => [
                ['employee_id' => 1],
                ['shift_id'],
            ],
            'shift_id null' => [
                ['employee_id' => 1, 'shift_id' => null, 'attendance_date' => '2025-07-15', 'status' => 'hadir'],
                ['shift_id'],
            ],
            'shift_id string kosong' => [
                ['employee_id' => 1, 'shift_id' => '', 'attendance_date' => '2025-07-15', 'status' => 'hadir'],
                ['shift_id'],
            ],
        ];
    }

    /**
     * Berbagai payload yang tidak memiliki employee_id maupun shift_id.
     * Properti harus berlaku: sistem mengembalikan HTTP 422 untuk kedua field.
     *
     * @return array<string, array{array<string, mixed>, list<string>}>
     */
    public static function missingBothRequiredFieldsProvider(): array
    {
        return [
            'hanya tanggal dan status' => [
                ['attendance_date' => '2025-07-15', 'status' => 'hadir'],
                ['employee_id', 'shift_id'],
            ],
            'hanya tanggal' => [
                ['attendance_date' => '2025-07-15'],
                ['employee_id', 'shift_id'],
            ],
            'hanya status' => [
                ['status' => 'hadir'],
                ['employee_id', 'shift_id'],
            ],
            'payload benar-benar kosong' => [
                [],
                ['employee_id', 'shift_id'],
            ],
            'employee_id dan shift_id keduanya null' => [
                ['employee_id' => null, 'shift_id' => null, 'attendance_date' => '2025-07-15', 'status' => 'hadir'],
                ['employee_id', 'shift_id'],
            ],
            'employee_id dan shift_id keduanya string kosong' => [
                ['employee_id' => '', 'shift_id' => '', 'attendance_date' => '2025-07-15', 'status' => 'hadir'],
                ['employee_id', 'shift_id'],
            ],
        ];
    }

    /**
     * Berbagai nilai employee_id yang tidak valid (bukan integer positif atau tidak ada di DB).
     *
     * @return array<string, array{mixed}>
     */
    public static function invalidEmployeeIdValuesProvider(): array
    {
        return [
            'employee_id = 0'          => [0],
            'employee_id negatif'      => [-1],
            'employee_id sangat besar' => [999999],
            'employee_id string teks'  => ['bukan-angka'],
        ];
    }

    /**
     * Berbagai nilai shift_id yang tidak valid (bukan integer positif atau tidak ada di DB).
     *
     * @return array<string, array{mixed}>
     */
    public static function invalidShiftIdValuesProvider(): array
    {
        return [
            'shift_id = 0'          => [0],
            'shift_id negatif'      => [-1],
            'shift_id sangat besar' => [999999],
            'shift_id string teks'  => ['bukan-angka'],
        ];
    }

    // ─── Property Tests ───────────────────────────────────────────────────────

    /**
     * Properti 4: Untuk setiap request tanpa employee_id,
     * sistem harus mengembalikan HTTP 422.
     *
     * Memvalidasi: Kebutuhan 4.5
     *
     * @dataProvider missingEmployeeIdProvider
     *
     * @param array<string, mixed> $payload
     * @param list<string>         $expectedErrors
     */
    public function test_property_missing_employee_id_returns_422(array $payload, array $expectedErrors): void
    {
        $token = $this->actingAsAdmin();

        $response = $this->withToken($token)->postJson('/api/v1/attendances', $payload);

        // Properti inti: sistem HARUS mengembalikan HTTP 422
        $response->assertStatus(422);

        // Properti tambahan: respons harus menyertakan pesan validasi untuk field yang hilang
        $response->assertJsonValidationErrors($expectedErrors);
    }

    /**
     * Properti 4: Untuk setiap request tanpa shift_id,
     * sistem harus mengembalikan HTTP 422.
     *
     * Memvalidasi: Kebutuhan 4.5
     *
     * @dataProvider missingShiftIdProvider
     *
     * @param array<string, mixed> $payload
     * @param list<string>         $expectedErrors
     */
    public function test_property_missing_shift_id_returns_422(array $payload, array $expectedErrors): void
    {
        $token = $this->actingAsAdmin();

        $response = $this->withToken($token)->postJson('/api/v1/attendances', $payload);

        // Properti inti: sistem HARUS mengembalikan HTTP 422
        $response->assertStatus(422);

        // Properti tambahan: respons harus menyertakan pesan validasi untuk field yang hilang
        $response->assertJsonValidationErrors($expectedErrors);
    }

    /**
     * Properti 4: Untuk setiap request tanpa employee_id maupun shift_id,
     * sistem harus mengembalikan HTTP 422 dengan error untuk kedua field.
     *
     * Memvalidasi: Kebutuhan 4.5
     *
     * @dataProvider missingBothRequiredFieldsProvider
     *
     * @param array<string, mixed> $payload
     * @param list<string>         $expectedErrors
     */
    public function test_property_missing_both_required_fields_returns_422(array $payload, array $expectedErrors): void
    {
        $token = $this->actingAsAdmin();

        $response = $this->withToken($token)->postJson('/api/v1/attendances', $payload);

        // Properti inti: sistem HARUS mengembalikan HTTP 422
        $response->assertStatus(422);

        // Properti tambahan: respons harus menyertakan pesan validasi untuk semua field yang hilang
        $response->assertJsonValidationErrors($expectedErrors);
    }

    /**
     * Properti 4: Untuk setiap nilai employee_id yang tidak valid atau tidak ada di DB,
     * sistem harus mengembalikan HTTP 422.
     *
     * Memvalidasi: Kebutuhan 4.5
     *
     * @dataProvider invalidEmployeeIdValuesProvider
     */
    public function test_property_invalid_employee_id_returns_422(mixed $invalidEmployeeId): void
    {
        $token  = $this->actingAsAdmin();
        $shift  = Shift::factory()->create();

        $response = $this->withToken($token)->postJson('/api/v1/attendances', [
            'employee_id'     => $invalidEmployeeId,
            'shift_id'        => $shift->id,
            'attendance_date' => '2025-07-15',
            'status'          => 'hadir',
        ]);

        // Properti inti: sistem HARUS mengembalikan HTTP 422
        $response->assertStatus(422);
        $response->assertJsonValidationErrors(['employee_id']);
    }

    /**
     * Properti 4: Untuk setiap nilai shift_id yang tidak valid atau tidak ada di DB,
     * sistem harus mengembalikan HTTP 422.
     *
     * Memvalidasi: Kebutuhan 4.5
     *
     * @dataProvider invalidShiftIdValuesProvider
     */
    public function test_property_invalid_shift_id_returns_422(mixed $invalidShiftId): void
    {
        $token    = $this->actingAsAdmin();
        $employee = Employee::factory()->create();

        $response = $this->withToken($token)->postJson('/api/v1/attendances', [
            'employee_id'     => $employee->id,
            'shift_id'        => $invalidShiftId,
            'attendance_date' => '2025-07-15',
            'status'          => 'hadir',
        ]);

        // Properti inti: sistem HARUS mengembalikan HTTP 422
        $response->assertStatus(422);
        $response->assertJsonValidationErrors(['shift_id']);
    }

    /**
     * Properti 4 (kontrol positif): Request dengan employee_id dan shift_id yang valid
     * TIDAK boleh mengembalikan HTTP 422 karena field wajib sudah terpenuhi.
     *
     * Memvalidasi: Kebutuhan 4.5
     */
    public function test_property_valid_employee_id_and_shift_id_does_not_return_422(): void
    {
        $token    = $this->actingAsAdmin();
        $employee = Employee::factory()->create();
        $shift    = Shift::factory()->create(['employee_id' => $employee->id]);

        $response = $this->withToken($token)->postJson('/api/v1/attendances', [
            'employee_id'     => $employee->id,
            'shift_id'        => $shift->id,
            'attendance_date' => '2025-07-15',
            'status'          => 'hadir',
        ]);

        // Properti kontrol: request valid TIDAK boleh menghasilkan HTTP 422
        $this->assertNotEquals(422, $response->status());
        $response->assertStatus(201);
    }
}
