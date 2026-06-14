<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Tests\TestCase;

/**
 * Property-Based Test: Properti 9 — Proteksi Rute Terautentikasi
 *
 * Feature: erp-presensi-payroll, Property 9: Proteksi Rute Terautentikasi
 *
 * Untuk setiap permintaan ke endpoint yang dilindungi tanpa token valid,
 * sistem harus mengembalikan HTTP 401 dan tidak mengembalikan data apapun.
 *
 * Memvalidasi: Kebutuhan 1.4, 1.5
 *
 * Implementasi menggunakan @dataProvider PHPUnit dengan daftar semua
 * endpoint protected dan variasi token invalid.
 */
class AuthPropertyTest extends TestCase
{
    use RefreshDatabase;

    // ─── Data Providers ───────────────────────────────────────────────────────

    /**
     * Semua endpoint yang dilindungi oleh middleware auth:sanctum.
     *
     * @return array<string, array{string, string}>
     */
    public static function protectedEndpointsProvider(): array
    {
        return [
            // Auth
            'POST /api/v1/auth/logout'              => ['POST', '/api/v1/auth/logout'],

            // Employees
            'GET /api/v1/employees'                 => ['GET',    '/api/v1/employees'],
            'POST /api/v1/employees'                => ['POST',   '/api/v1/employees'],
            'PUT /api/v1/employees/1'               => ['PUT',    '/api/v1/employees/1'],
            'DELETE /api/v1/employees/1'            => ['DELETE', '/api/v1/employees/1'],

            // Shifts
            'GET /api/v1/shifts'                    => ['GET',    '/api/v1/shifts'],
            'POST /api/v1/shifts'                   => ['POST',   '/api/v1/shifts'],
            'DELETE /api/v1/shifts/1'               => ['DELETE', '/api/v1/shifts/1'],

            // Attendances
            'GET /api/v1/attendances'               => ['GET',    '/api/v1/attendances'],
            'POST /api/v1/attendances'              => ['POST',   '/api/v1/attendances'],
            'PUT /api/v1/attendances/1'             => ['PUT',    '/api/v1/attendances/1'],

            // Payrolls
            'GET /api/v1/payrolls'                  => ['GET',    '/api/v1/payrolls'],

            // Currency
            'POST /api/v1/currency/convert'         => ['POST',   '/api/v1/currency/convert'],

            // Chatbot
            'GET /api/v1/chatbot/scenarios'         => ['GET',    '/api/v1/chatbot/scenarios'],
            'POST /api/v1/chatbot/message'          => ['POST',   '/api/v1/chatbot/message'],
            'POST /api/v1/chatbot/feedback'         => ['POST',   '/api/v1/chatbot/feedback'],
        ];
    }

    /**
     * Variasi token tidak valid / kosong.
     *
     * @return array<string, array{string|null}>
     */
    public static function invalidTokensProvider(): array
    {
        return [
            'token kosong (empty string)'           => [''],
            'token acak pendek'                     => ['invalid'],
            'token acak panjang'                    => ['thisisaninvalidtokenthatdoesnotexistindatabase'],
            'token format salah (bukan Bearer)'     => ['Basic dXNlcjpwYXNz'],
            'token dengan karakter khusus'          => ['!@#$%^&*()_+'],
            'token numerik saja'                    => ['1234567890'],
            'token format Sanctum palsu'            => ['999|fakeplaintexttoken00000000000000000000000'],
        ];
    }

    /**
     * Kombinasi semua endpoint protected × semua token invalid.
     *
     * @return array<string, array{string, string, string}>
     */
    public static function protectedEndpointsWithInvalidTokensProvider(): array
    {
        $combinations = [];

        foreach (self::protectedEndpointsProvider() as $endpointKey => [$method, $url]) {
            foreach (self::invalidTokensProvider() as $tokenKey => [$token]) {
                $key = "{$endpointKey} | {$tokenKey}";
                $combinations[$key] = [$method, $url, $token];
            }
        }

        return $combinations;
    }

    // ─── Property Tests ───────────────────────────────────────────────────────

    /**
     * Properti 9: Untuk setiap endpoint protected dan setiap token tidak valid/kosong,
     * respons harus HTTP 401.
     *
     * Memvalidasi: Kebutuhan 1.4, 1.5
     *
     * @dataProvider protectedEndpointsWithInvalidTokensProvider
     */
    public function test_protected_endpoint_with_invalid_token_returns_401(
        string $method,
        string $url,
        string $token
    ): void {
        // Arrange: kirim request dengan token tidak valid
        $headers = [];
        if ($token !== '') {
            $headers['Authorization'] = "Bearer {$token}";
        }

        // Act: kirim request ke endpoint protected
        $response = $this->json($method, $url, [], $headers);

        // Assert: harus HTTP 401
        $response->assertStatus(401);
    }

    /**
     * Properti 9 (tanpa header Authorization sama sekali):
     * Untuk setiap endpoint protected tanpa header Authorization,
     * respons harus HTTP 401.
     *
     * Memvalidasi: Kebutuhan 1.4
     *
     * @dataProvider protectedEndpointsProvider
     */
    public function test_protected_endpoint_without_any_token_returns_401(
        string $method,
        string $url
    ): void {
        // Act: kirim request tanpa header Authorization
        $response = $this->json($method, $url);

        // Assert: harus HTTP 401
        $response->assertStatus(401);
    }

    /**
     * Properti 9 (token yang sudah dicabut / expired):
     * Token yang sudah di-logout tidak boleh mengakses endpoint protected.
     *
     * Memvalidasi: Kebutuhan 1.5
     *
     * @dataProvider protectedEndpointsProvider
     */
    public function test_protected_endpoint_with_revoked_token_returns_401(
        string $method,
        string $url
    ): void {
        // Arrange: buat user dan token, lalu cabut token tersebut
        $user  = User::factory()->create([
            'password' => Hash::make('password'),
            'role'     => 'admin',
        ]);
        $token = $user->createToken('api-token')->plainTextToken;

        // Cabut token via logout
        $user->currentAccessToken()?->delete();
        // Pastikan semua token user dicabut
        $user->tokens()->delete();

        // Act: coba akses dengan token yang sudah dicabut
        $response = $this->withToken($token)->json($method, $url);

        // Assert: harus HTTP 401
        $response->assertStatus(401);
    }
}
