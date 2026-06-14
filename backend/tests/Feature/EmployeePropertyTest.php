<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Tests\TestCase;

/**
 * Property-Based Test: Properti 3 — Validasi Input Karyawan
 *
 * Feature: erp-presensi-payroll, Property 3: Validasi Input Karyawan
 *
 * Untuk setiap string yang hanya terdiri dari karakter whitespace atau string
 * kosong pada field wajib (nama, telepon, alamat), sistem harus menolak
 * penyimpanan dan mengembalikan HTTP 422.
 *
 * Memvalidasi: Kebutuhan 2.3
 *
 * Implementasi menggunakan @dataProvider PHPUnit dengan berbagai variasi
 * input whitespace/kosong untuk setiap field wajib.
 */
class EmployeePropertyTest extends TestCase
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
     * Variasi string yang hanya berisi whitespace atau string kosong.
     * Properti: untuk setiap nilai ini pada field wajib, sistem harus menolak.
     *
     * @return array<string, array{string}>
     */
    public static function whitespaceAndEmptyStringsProvider(): array
    {
        return [
            'string kosong'                         => [''],
            'satu spasi'                            => [' '],
            'banyak spasi'                          => ['     '],
            'tab tunggal'                           => ["\t"],
            'banyak tab'                            => ["\t\t\t"],
            'newline tunggal'                       => ["\n"],
            'banyak newline'                        => ["\n\n\n"],
            'carriage return'                       => ["\r"],
            'CRLF'                                  => ["\r\n"],
            'campuran spasi dan tab'                => [" \t "],
            'campuran spasi, tab, dan newline'      => [" \t\n\r "],
            'spasi unicode non-breaking (U+00A0)'   => ["\xc2\xa0"],
            'banyak spasi unicode'                  => ["\xc2\xa0\xc2\xa0\xc2\xa0"],
        ];
    }

    /**
     * Semua field wajib yang harus divalidasi.
     *
     * @return array<string, array{string}>
     */
    public static function requiredFieldsProvider(): array
    {
        return [
            'field employee_name' => ['employee_name'],
            'field phone'         => ['phone'],
            'field address'       => ['address'],
        ];
    }

    /**
     * Kombinasi semua field wajib × semua variasi whitespace/kosong.
     *
     * @return array<string, array{string, string}>
     */
    public static function fieldWithWhitespaceProvider(): array
    {
        $combinations = [];

        foreach (self::requiredFieldsProvider() as $fieldKey => [$field]) {
            foreach (self::whitespaceAndEmptyStringsProvider() as $valueKey => [$value]) {
                $key                  = "{$fieldKey} | {$valueKey}";
                $combinations[$key]   = [$field, $value];
            }
        }

        return $combinations;
    }

    // ─── Property Tests ───────────────────────────────────────────────────────

    /**
     * Properti 3: Untuk setiap string whitespace/kosong pada field wajib,
     * sistem harus menolak dan mengembalikan HTTP 422.
     *
     * Memvalidasi: Kebutuhan 2.3
     *
     * @dataProvider fieldWithWhitespaceProvider
     */
    public function test_store_rejects_whitespace_or_empty_required_field_with_422(
        string $field,
        string $invalidValue
    ): void {
        $token = $this->actingAsAdmin();

        // Mulai dengan data valid, lalu ganti satu field dengan nilai tidak valid
        $data = [
            'employee_name' => 'Budi Santoso',
            'phone'         => '08123456789',
            'address'       => 'Jl. Merdeka No. 1',
            'status'        => 'aktif',
        ];
        $data[$field] = $invalidValue;

        $response = $this->withToken($token)->postJson('/api/v1/employees', $data);

        // Properti: sistem HARUS menolak dengan HTTP 422
        $response->assertStatus(422);

        // Properti: respons HARUS menyertakan pesan validasi untuk field yang bermasalah
        $response->assertJsonValidationErrors([$field]);
    }

    /**
     * Properti 3 (update): Untuk setiap string whitespace/kosong pada field wajib
     * saat update, sistem harus menolak dan mengembalikan HTTP 422.
     *
     * Memvalidasi: Kebutuhan 2.3
     *
     * @dataProvider fieldWithWhitespaceProvider
     */
    public function test_update_rejects_whitespace_or_empty_required_field_with_422(
        string $field,
        string $invalidValue
    ): void {
        $token = $this->actingAsAdmin();

        // Buat karyawan yang valid terlebih dahulu
        $employee = \App\Models\Employee::factory()->create();

        // Mulai dengan data valid, lalu ganti satu field dengan nilai tidak valid
        $data = [
            'employee_name' => 'Budi Santoso',
            'phone'         => '08123456789',
            'address'       => 'Jl. Merdeka No. 1',
            'status'        => 'aktif',
        ];
        $data[$field] = $invalidValue;

        $response = $this->withToken($token)->putJson("/api/v1/employees/{$employee->id}", $data);

        // Properti: sistem HARUS menolak dengan HTTP 422
        $response->assertStatus(422);

        // Properti: respons HARUS menyertakan pesan validasi untuk field yang bermasalah
        $response->assertJsonValidationErrors([$field]);
    }

    /**
     * Properti 3 (semua field kosong sekaligus): Jika semua field wajib kosong,
     * sistem harus mengembalikan HTTP 422 dengan pesan untuk setiap field.
     *
     * Memvalidasi: Kebutuhan 2.3
     *
     * @dataProvider whitespaceAndEmptyStringsProvider
     */
    public function test_store_rejects_all_whitespace_fields_with_422_per_field(
        string $invalidValue
    ): void {
        $token = $this->actingAsAdmin();

        $response = $this->withToken($token)->postJson('/api/v1/employees', [
            'employee_name' => $invalidValue,
            'phone'         => $invalidValue,
            'address'       => $invalidValue,
            'status'        => 'aktif',
        ]);

        // Properti: sistem HARUS menolak dengan HTTP 422
        $response->assertStatus(422);

        // Properti: HARUS ada pesan validasi untuk setiap field yang bermasalah
        $response->assertJsonValidationErrors(['employee_name', 'phone', 'address']);
    }

    /**
     * Properti 3 (kebalikan — data valid tidak boleh ditolak):
     * Untuk setiap data valid (non-whitespace, non-kosong), sistem harus menerima.
     *
     * Memvalidasi: Kebutuhan 2.2 (sebagai kontrol positif untuk Properti 3)
     */
    public function test_store_accepts_valid_non_whitespace_data(): void
    {
        $token = $this->actingAsAdmin();

        $response = $this->withToken($token)->postJson('/api/v1/employees', [
            'employee_name' => 'Budi Santoso',
            'phone'         => '08123456789',
            'address'       => 'Jl. Merdeka No. 1',
            'status'        => 'aktif',
        ]);

        // Properti kebalikan: data valid HARUS diterima
        $response->assertStatus(201);
    }
}
