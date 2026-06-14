<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Laravel\Sanctum\PersonalAccessToken;
use Tests\TestCase;

/**
 * Unit tests for AuthController.
 *
 * Validates: Requirements 1.1, 1.2, 1.3, 1.4
 */
class AuthTest extends TestCase
{
    use RefreshDatabase;

    /**
     * Create a test admin user.
     */
    private function createAdminUser(string $email = 'admin@example.com', string $password = 'password'): User
    {
        return User::factory()->create([
            'name'     => 'Admin',
            'email'    => $email,
            'password' => Hash::make($password),
            'role'     => 'admin',
        ]);
    }

    // ─── Login Tests ──────────────────────────────────────────────────────────

    /**
     * Test login dengan kredensial valid → HTTP 200 + token.
     *
     * Validates: Requirement 1.1
     */
    public function test_login_with_valid_credentials_returns_200_and_token(): void
    {
        $this->createAdminUser('admin@example.com', 'password');

        $response = $this->postJson('/api/v1/auth/login', [
            'email'    => 'admin@example.com',
            'password' => 'password',
        ]);

        $response->assertStatus(200)
            ->assertJsonStructure([
                'token',
                'user' => ['id', 'name', 'email', 'role'],
            ]);

        $this->assertNotEmpty($response->json('token'));
        $this->assertEquals('admin@example.com', $response->json('user.email'));
        $this->assertEquals('admin', $response->json('user.role'));
    }

    /**
     * Test login dengan email tidak valid → HTTP 401.
     *
     * Validates: Requirement 1.2
     */
    public function test_login_with_wrong_email_returns_401(): void
    {
        $this->createAdminUser('admin@example.com', 'password');

        $response = $this->postJson('/api/v1/auth/login', [
            'email'    => 'wrong@example.com',
            'password' => 'password',
        ]);

        $response->assertStatus(401);
    }

    /**
     * Test login dengan password tidak valid → HTTP 401.
     *
     * Validates: Requirement 1.2
     */
    public function test_login_with_wrong_password_returns_401(): void
    {
        $this->createAdminUser('admin@example.com', 'password');

        $response = $this->postJson('/api/v1/auth/login', [
            'email'    => 'admin@example.com',
            'password' => 'wrongpassword',
        ]);

        $response->assertStatus(401);
    }

    /**
     * Test login dengan email dan password tidak valid → HTTP 401.
     *
     * Validates: Requirement 1.2
     */
    public function test_login_with_invalid_credentials_returns_401(): void
    {
        $response = $this->postJson('/api/v1/auth/login', [
            'email'    => 'nobody@example.com',
            'password' => 'wrongpassword',
        ]);

        $response->assertStatus(401);
    }

    /**
     * Test login tanpa email → HTTP 422 (validasi).
     *
     * Validates: Requirement 1.2
     */
    public function test_login_without_email_returns_422(): void
    {
        $response = $this->postJson('/api/v1/auth/login', [
            'password' => 'password',
        ]);

        $response->assertStatus(422)
            ->assertJsonValidationErrors(['email']);
    }

    /**
     * Test login tanpa password → HTTP 422 (validasi).
     *
     * Validates: Requirement 1.2
     */
    public function test_login_without_password_returns_422(): void
    {
        $response = $this->postJson('/api/v1/auth/login', [
            'email' => 'admin@example.com',
        ]);

        $response->assertStatus(422)
            ->assertJsonValidationErrors(['password']);
    }

    // ─── Logout Tests ─────────────────────────────────────────────────────────

    /**
     * Test logout dengan token valid → HTTP 200, token dicabut.
     *
     * Validates: Requirement 1.3
     */
    public function test_logout_with_valid_token_returns_200_and_revokes_token(): void
    {
        $user  = $this->createAdminUser();
        $token = $user->createToken('api-token')->plainTextToken;

        $response = $this->withToken($token)
            ->postJson('/api/v1/auth/logout');

        $response->assertStatus(200)
            ->assertJson(['message' => 'Berhasil logout.']);

        // Verify the token has been revoked from the database
        $tokenId = explode('|', $token)[0];
        $this->assertNull(PersonalAccessToken::find($tokenId));
    }

    /**
     * Test logout tanpa token → HTTP 401.
     *
     * Validates: Requirement 1.4
     */
    public function test_logout_without_token_returns_401(): void
    {
        $response = $this->postJson('/api/v1/auth/logout');

        $response->assertStatus(401);
    }

    /**
     * Test logout dengan token tidak valid → HTTP 401.
     *
     * Validates: Requirement 1.4
     */
    public function test_logout_with_invalid_token_returns_401(): void
    {
        $response = $this->withToken('invalid-token-string')
            ->postJson('/api/v1/auth/logout');

        $response->assertStatus(401);
    }

    // ─── Protected Endpoint Access Tests ──────────────────────────────────────

    /**
     * Test akses endpoint protected tanpa token → HTTP 401.
     *
     * Validates: Requirement 1.4
     */
    public function test_accessing_protected_endpoint_without_token_returns_401(): void
    {
        $response = $this->getJson('/api/v1/employees');

        $response->assertStatus(401);
    }

    /**
     * Test akses endpoint protected dengan token valid → HTTP bukan 401.
     * Menggunakan endpoint logout (POST) yang pasti diimplementasikan.
     *
     * Validates: Requirement 1.4
     */
    public function test_accessing_protected_endpoint_with_valid_token_is_not_401(): void
    {
        $user   = $this->createAdminUser();
        $token  = $user->createToken('api-token')->plainTextToken;

        // Use logout endpoint — it is always implemented and returns 200 with valid token
        $response = $this->withToken($token)
            ->postJson('/api/v1/auth/logout');

        // Should not be 401 — valid token must be accepted
        $this->assertNotEquals(401, $response->status());
        $response->assertStatus(200);
    }

    /**
     * Test token yang sudah dicabut tidak bisa digunakan lagi.
     * Verifikasi bahwa token yang dihapus dari database tidak bisa digunakan.
     *
     * Validates: Requirement 1.3, 1.5
     */
    public function test_revoked_token_cannot_access_protected_endpoints(): void
    {
        $user  = $this->createAdminUser();
        $token = $user->createToken('api-token')->plainTextToken;

        // Directly delete the token from the database (simulating revocation)
        $user->tokens()->delete();

        // Flush any cached auth state
        $this->app['auth']->forgetGuards();

        // Try to use the revoked token — pass only the Authorization header
        // without any session cookie to avoid web guard fallback
        $response = $this->postJson('/api/v1/auth/logout', [], [
            'Authorization' => "Bearer {$token}",
        ]);

        $response->assertStatus(401);
    }
}
