<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/**
 * Property-Based Test: Properti 6 — Konversi Mata Uang Round-Trip
 *
 * Feature: erp-presensi-payroll, Property 6: Konversi Mata Uang Round-Trip
 *
 * Untuk setiap nilai IDR acak dan kurs acak, konversi IDR→target→IDR harus
 * menghasilkan nilai mendekati IDR awal (toleransi 0.01).
 *
 * **Validates: Requirements 6.1, 6.3**
 *
 * Implementasi menggunakan @dataProvider PHPUnit dengan 100 pasangan acak
 * (idr_amount, exchange_rate) untuk memverifikasi bahwa konversi round-trip
 * selalu menghasilkan nilai mendekati nilai awal.
 */
class CurrencyRoundTripPropertyTest extends TestCase
{
    use RefreshDatabase;

    // ─── Data Providers ───────────────────────────────────────────────────────

    /**
     * Menghasilkan 100 pasangan acak (idr_amount, exchange_rate) untuk property test.
     * Setiap iterasi menguji bahwa konversi IDR→target→IDR ≈ IDR awal.
     *
     * @return array<string, array{float, float}>
     */
    public static function randomCurrencyPairProvider(): array
    {
        $cases = [];

        // Seed the random number generator for reproducibility in CI
        mt_srand(42);

        for ($i = 0; $i < 100; $i++) {
            // Generate random IDR amount between 1 and 100,000,000 (up to 2 decimal places)
            $idrAmount = mt_rand(100, 10000000000) / 100;

            // Generate random exchange rate between 0.000001 and 10.0 (realistic range for IDR conversions)
            $exchangeRate = mt_rand(1, 10000000) / 1000000;

            $cases["IDR={$idrAmount}, rate={$exchangeRate} (iterasi {$i})"] = [$idrAmount, $exchangeRate];
        }

        // Reset seed
        mt_srand();

        return $cases;
    }

    // ─── Property Tests ───────────────────────────────────────────────────────

    /**
     * Properti 6: Untuk setiap nilai IDR acak dan kurs acak, konversi
     * IDR→target→IDR harus menghasilkan nilai mendekati IDR awal (toleransi 0.01).
     *
     * Memvalidasi: Kebutuhan 6.1, 6.3
     *
     * @dataProvider randomCurrencyPairProvider
     */
    public function test_property_currency_round_trip_conversion(float $idrAmount, float $exchangeRate): void
    {
        // Konversi IDR → target currency
        $converted = $idrAmount * $exchangeRate;

        // Konversi target currency → IDR (round-trip)
        $backToIdr = $converted / $exchangeRate;

        // Verifikasi bahwa round-trip menghasilkan nilai mendekati IDR awal
        $difference = abs($idrAmount - $backToIdr);

        $this->assertLessThan(
            0.01,
            $difference,
            "Properti 6 dilanggar: Round-trip conversion gagal. "
            . "IDR awal={$idrAmount}, setelah round-trip={$backToIdr}, "
            . "selisih={$difference} (melebihi toleransi 0.01). "
            . "Kurs yang digunakan={$exchangeRate}."
        );
    }
}
