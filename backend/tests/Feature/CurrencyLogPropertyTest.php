<?php

namespace Tests\Feature;

use App\Models\CurrencyLog;
use App\Models\Employee;
use App\Models\Payroll;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Http;
use Tests\TestCase;

/**
 * Property-Based Test: Properti 7 — Log Konversi Tersimpan
 *
 * Feature: erp-presensi-payroll, Property 7: Log Konversi Tersimpan
 *
 * Untuk setiap konversi yang berhasil, harus ada tepat satu entri baru di
 * `currency_logs` dengan nilai `payroll_id`, `currency_type`, `exchange_rate`,
 * dan `converted_total` yang benar.
 *
 * **Validates: Requirements 6.5**
 *
 * Implementasi menggunakan @dataProvider PHPUnit dengan 100 skenario konversi
 * acak untuk memverifikasi bahwa setiap konversi berhasil menghasilkan tepat
 * satu log entry dengan data yang benar.
 */
class CurrencyLogPropertyTest extends TestCase
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

    // ─── Data Providers ───────────────────────────────────────────────────────

    /**
     * Menghasilkan 100 skenario konversi acak untuk property test.
     * Setiap skenario berisi: amount_idr, target_currency, dan exchange_rate.
     *
     * @return array<string, array{float, string, float}>
     */
    public static function randomConversionScenarioProvider(): array
    {
        $cases = [];
        $currencies = ['USD', 'EUR', 'GBP'];

        // Seed the random number generator for reproducibility in CI
        mt_srand(42);

        for ($i = 0; $i < 100; $i++) {
            // Generate random IDR amount between 10,000 and 100,000,000 (realistic payroll range)
            $amountIdr = mt_rand(1000000, 10000000000) / 100;

            // Pick a random target currency
            $targetCurrency = $currencies[mt_rand(0, 2)];

            // Generate random exchange rate (realistic range for IDR conversions)
            // USD: ~0.000063, EUR: ~0.000058, GBP: ~0.000050
            $exchangeRate = mt_rand(1, 100000) / 1000000000;

            $cases["IDR={$amountIdr}, currency={$targetCurrency}, rate={$exchangeRate} (iterasi {$i})"] = [
                $amountIdr,
                $targetCurrency,
                $exchangeRate,
            ];
        }

        // Reset seed
        mt_srand();

        return $cases;
    }

    // ─── Property Tests ───────────────────────────────────────────────────────

    /**
     * Properti 7: Untuk setiap konversi yang berhasil, harus ada tepat satu
     * entri baru di `currency_logs` dengan nilai `payroll_id`, `currency_type`,
     * `exchange_rate`, dan `converted_total` yang benar.
     *
     * Memvalidasi: Kebutuhan 6.5
     *
     * @dataProvider randomConversionScenarioProvider
     */
    public function test_property_conversion_log_saved_correctly(float $amountIdr, string $targetCurrency, float $exchangeRate): void
    {
        $token = $this->actingAsAdmin();
        $payroll = $this->createPayroll();

        // Mock the exchange rate API with the random rate
        Http::fake([
            'v6.exchangerate-api.com/*' => Http::response([
                'result' => 'success',
                'conversion_rates' => [
                    'USD' => $targetCurrency === 'USD' ? $exchangeRate : 0.000063,
                    'EUR' => $targetCurrency === 'EUR' ? $exchangeRate : 0.000058,
                    'GBP' => $targetCurrency === 'GBP' ? $exchangeRate : 0.000050,
                ],
            ], 200),
        ]);

        // Count existing logs before conversion
        $logCountBefore = CurrencyLog::count();

        // Perform the conversion
        $response = $this->withToken($token)->postJson('/api/v1/currency/convert', [
            'payroll_id'      => $payroll->id,
            'amount_idr'      => $amountIdr,
            'target_currency' => $targetCurrency,
        ]);

        // Verify conversion was successful
        $response->assertStatus(200);

        // Verify exactly 1 new entry in currency_logs
        $logCountAfter = CurrencyLog::count();
        $this->assertSame(
            $logCountBefore + 1,
            $logCountAfter,
            "Properti 7 dilanggar: Seharusnya ada tepat 1 entri baru di currency_logs. "
            . "Sebelum: {$logCountBefore}, Sesudah: {$logCountAfter}."
        );

        // Get the newly created log entry
        $log = CurrencyLog::latest('id')->first();

        // Verify payroll_id is correct
        $this->assertEquals(
            $payroll->id,
            $log->payroll_id,
            "Properti 7 dilanggar: payroll_id seharusnya {$payroll->id}, ditemukan {$log->payroll_id}."
        );

        // Verify currency_type is correct
        $this->assertSame(
            $targetCurrency,
            $log->currency_type,
            "Properti 7 dilanggar: currency_type seharusnya {$targetCurrency}, ditemukan {$log->currency_type}."
        );

        // Verify exchange_rate is correct
        $this->assertEquals(
            $exchangeRate,
            (float) $log->exchange_rate,
            "Properti 7 dilanggar: exchange_rate seharusnya {$exchangeRate}, ditemukan {$log->exchange_rate}."
        );

        // Verify converted_total is correct (amount_idr × exchange_rate, rounded to 2 decimals)
        $expectedConvertedTotal = round($amountIdr * $exchangeRate, 2);
        $this->assertEquals(
            $expectedConvertedTotal,
            (float) $log->converted_total,
            "Properti 7 dilanggar: converted_total seharusnya {$expectedConvertedTotal} "
            . "(IDR {$amountIdr} × rate {$exchangeRate}), ditemukan {$log->converted_total}."
        );
    }
}
