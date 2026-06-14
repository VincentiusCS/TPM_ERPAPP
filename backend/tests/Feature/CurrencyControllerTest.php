<?php

namespace Tests\Feature;

use App\Models\Employee;
use App\Models\Payroll;
use App\Models\CurrencyLog;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Http;
use Tests\TestCase;

/**
 * Unit tests for CurrencyController.
 *
 * Validates: Requirements 6.1, 6.2, 6.3, 6.4, 6.5
 */
class CurrencyControllerTest extends TestCase
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
     * Buat payroll record untuk digunakan dalam test konversi.
     */
    private function createPayroll(): Payroll
    {
        $employee = Employee::factory()->aktif()->create();

        return Payroll::create([
            'employee_id'      => $employee->id,
            'period_start'     => '2025-07-01',
            'period_end'       => '2025-07-31',
            'total_attendance' => 10,
            'total_salary'     => 500000,
        ]);
    }

    // ─── Konversi Berhasil Tests ──────────────────────────────────────────────

    /**
     * Test konversi IDR ke USD berhasil dengan mock HTTP client.
     *
     * Validates: Requirement 6.1, 6.3, 6.5
     */
    public function test_convert_idr_to_usd_success(): void
    {
        $token = $this->actingAsAdmin();
        $payroll = $this->createPayroll();

        Http::fake([
            'v6.exchangerate-api.com/*' => Http::response([
                'result' => 'success',
                'conversion_rates' => [
                    'USD' => 0.000063,
                    'EUR' => 0.000058,
                    'GBP' => 0.000050,
                ],
            ], 200),
        ]);

        $response = $this->withToken($token)->postJson('/api/v1/currency/convert', [
            'payroll_id'      => $payroll->id,
            'amount_idr'      => 1000000,
            'target_currency' => 'USD',
        ]);

        $response->assertStatus(200)
            ->assertJsonStructure([
                'source_currency',
                'target_currency',
                'exchange_rate',
                'converted_amount',
                'log_id',
            ])
            ->assertJson([
                'source_currency'  => 'IDR',
                'target_currency'  => 'USD',
                'exchange_rate'    => 0.000063,
                'converted_amount' => 63.00,
            ]);

        // Verify log tersimpan di database
        $this->assertDatabaseHas('currency_logs', [
            'payroll_id'      => $payroll->id,
            'currency_type'   => 'USD',
            'exchange_rate'   => 0.000063,
            'converted_total' => 63.00,
        ]);
    }

    /**
     * Test konversi IDR ke EUR berhasil.
     *
     * Validates: Requirement 6.1, 6.2
     */
    public function test_convert_idr_to_eur_success(): void
    {
        $token = $this->actingAsAdmin();
        $payroll = $this->createPayroll();

        Http::fake([
            'v6.exchangerate-api.com/*' => Http::response([
                'result' => 'success',
                'conversion_rates' => [
                    'USD' => 0.000063,
                    'EUR' => 0.000058,
                    'GBP' => 0.000050,
                ],
            ], 200),
        ]);

        $response = $this->withToken($token)->postJson('/api/v1/currency/convert', [
            'payroll_id'      => $payroll->id,
            'amount_idr'      => 500000,
            'target_currency' => 'EUR',
        ]);

        $response->assertStatus(200)
            ->assertJson([
                'source_currency'  => 'IDR',
                'target_currency'  => 'EUR',
                'exchange_rate'    => 0.000058,
                'converted_amount' => 29.00,
            ]);
    }

    /**
     * Test konversi IDR ke GBP berhasil.
     *
     * Validates: Requirement 6.1, 6.2
     */
    public function test_convert_idr_to_gbp_success(): void
    {
        $token = $this->actingAsAdmin();
        $payroll = $this->createPayroll();

        Http::fake([
            'v6.exchangerate-api.com/*' => Http::response([
                'result' => 'success',
                'conversion_rates' => [
                    'USD' => 0.000063,
                    'EUR' => 0.000058,
                    'GBP' => 0.000050,
                ],
            ], 200),
        ]);

        $response = $this->withToken($token)->postJson('/api/v1/currency/convert', [
            'payroll_id'      => $payroll->id,
            'amount_idr'      => 2000000,
            'target_currency' => 'GBP',
        ]);

        $response->assertStatus(200)
            ->assertJson([
                'source_currency'  => 'IDR',
                'target_currency'  => 'GBP',
                'exchange_rate'    => 0.000050,
                'converted_amount' => 100.00,
            ]);
    }

    /**
     * Test log konversi tersimpan dengan benar di database.
     *
     * Validates: Requirement 6.5
     */
    public function test_conversion_log_is_saved_to_database(): void
    {
        $token = $this->actingAsAdmin();
        $payroll = $this->createPayroll();

        Http::fake([
            'v6.exchangerate-api.com/*' => Http::response([
                'result' => 'success',
                'conversion_rates' => [
                    'USD' => 0.000063,
                ],
            ], 200),
        ]);

        $this->withToken($token)->postJson('/api/v1/currency/convert', [
            'payroll_id'      => $payroll->id,
            'amount_idr'      => 1000000,
            'target_currency' => 'USD',
        ]);

        $this->assertDatabaseCount('currency_logs', 1);

        $log = CurrencyLog::first();
        $this->assertEquals($payroll->id, $log->payroll_id);
        $this->assertEquals('USD', $log->currency_type);
        $this->assertEquals(0.000063, (float) $log->exchange_rate);
        $this->assertEquals(63.00, (float) $log->converted_total);
    }

    // ─── API Kurs Gagal Tests ─────────────────────────────────────────────────

    /**
     * Test API kurs gagal (HTTP 500 dari external API) → HTTP 503.
     *
     * Validates: Requirement 6.4
     */
    public function test_convert_returns_503_when_exchange_api_fails(): void
    {
        $token = $this->actingAsAdmin();
        $payroll = $this->createPayroll();

        Http::fake([
            'v6.exchangerate-api.com/*' => Http::response(null, 500),
        ]);

        $response = $this->withToken($token)->postJson('/api/v1/currency/convert', [
            'payroll_id'      => $payroll->id,
            'amount_idr'      => 1000000,
            'target_currency' => 'USD',
        ]);

        $response->assertStatus(503)
            ->assertJson([
                'message' => 'Gagal mengambil data kurs. Layanan tidak tersedia saat ini.',
            ]);

        // Verify no log is saved when API fails
        $this->assertDatabaseCount('currency_logs', 0);
    }

    /**
     * Test API kurs timeout (connection exception) → HTTP 503.
     *
     * Validates: Requirement 6.4
     */
    public function test_convert_returns_503_when_exchange_api_throws_exception(): void
    {
        $token = $this->actingAsAdmin();
        $payroll = $this->createPayroll();

        Http::fake([
            'v6.exchangerate-api.com/*' => function () {
                throw new \Illuminate\Http\Client\ConnectionException('Connection timed out');
            },
        ]);

        $response = $this->withToken($token)->postJson('/api/v1/currency/convert', [
            'payroll_id'      => $payroll->id,
            'amount_idr'      => 1000000,
            'target_currency' => 'USD',
        ]);

        $response->assertStatus(503)
            ->assertJson([
                'message' => 'Gagal mengambil data kurs. Layanan tidak tersedia saat ini.',
            ]);

        $this->assertDatabaseCount('currency_logs', 0);
    }

    // ─── Mata Uang Tidak Didukung Tests ───────────────────────────────────────

    /**
     * Test mata uang tidak didukung → HTTP 422.
     *
     * Validates: Requirement 6.2
     */
    public function test_convert_returns_422_for_unsupported_currency(): void
    {
        $token = $this->actingAsAdmin();
        $payroll = $this->createPayroll();

        $response = $this->withToken($token)->postJson('/api/v1/currency/convert', [
            'payroll_id'      => $payroll->id,
            'amount_idr'      => 1000000,
            'target_currency' => 'JPY',
        ]);

        $response->assertStatus(422)
            ->assertJson([
                'message' => 'Mata uang tidak didukung. Gunakan: USD, EUR, GBP',
            ]);

        $this->assertDatabaseCount('currency_logs', 0);
    }

    /**
     * Test mata uang tidak didukung (lowercase input) → HTTP 422.
     *
     * Validates: Requirement 6.2
     */
    public function test_convert_returns_422_for_unsupported_currency_random_string(): void
    {
        $token = $this->actingAsAdmin();
        $payroll = $this->createPayroll();

        $response = $this->withToken($token)->postJson('/api/v1/currency/convert', [
            'payroll_id'      => $payroll->id,
            'amount_idr'      => 1000000,
            'target_currency' => 'XYZ',
        ]);

        $response->assertStatus(422)
            ->assertJson([
                'message' => 'Mata uang tidak didukung. Gunakan: USD, EUR, GBP',
            ]);
    }

    // ─── Validasi Input Tests ─────────────────────────────────────────────────

    /**
     * Test tanpa token → HTTP 401.
     *
     * Validates: Requirement 1.4
     */
    public function test_convert_without_token_returns_401(): void
    {
        $response = $this->postJson('/api/v1/currency/convert', [
            'payroll_id'      => 1,
            'amount_idr'      => 1000000,
            'target_currency' => 'USD',
        ]);

        $response->assertStatus(401);
    }

    /**
     * Test target_currency case-insensitive (lowercase 'usd' diterima).
     *
     * Validates: Requirement 6.2
     */
    public function test_convert_accepts_lowercase_currency(): void
    {
        $token = $this->actingAsAdmin();
        $payroll = $this->createPayroll();

        Http::fake([
            'v6.exchangerate-api.com/*' => Http::response([
                'result' => 'success',
                'conversion_rates' => [
                    'USD' => 0.000063,
                ],
            ], 200),
        ]);

        $response = $this->withToken($token)->postJson('/api/v1/currency/convert', [
            'payroll_id'      => $payroll->id,
            'amount_idr'      => 1000000,
            'target_currency' => 'usd',
        ]);

        $response->assertStatus(200)
            ->assertJson([
                'target_currency' => 'USD',
            ]);
    }
}
