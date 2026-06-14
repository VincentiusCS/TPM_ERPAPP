<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Http;
use Tests\TestCase;

/**
 * Unit tests for ChatbotController.
 *
 * Validates: Requirements 8.1, 8.2, 8.3, 8.5
 */
class ChatbotControllerTest extends TestCase
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
     * Fake Gemini API response yang berhasil.
     */
    private function fakeGeminiSuccess(string $replyText = 'Ini balasan dari AI.'): void
    {
        Http::fake([
            'generativelanguage.googleapis.com/*' => Http::response([
                'candidates' => [
                    [
                        'content' => [
                            'parts' => [
                                ['text' => $replyText],
                            ],
                        ],
                    ],
                ],
            ], 200),
        ]);
    }

    /**
     * Fake Gemini API response yang gagal.
     */
    private function fakeGeminiFailure(): void
    {
        Http::fake([
            'generativelanguage.googleapis.com/*' => Http::response(null, 500),
        ]);
    }

    // ─── Scenarios Tests ──────────────────────────────────────────────────────

    /**
     * Test GET /api/v1/chatbot/scenarios → HTTP 200 dengan daftar skenario.
     *
     * Validates: Requirement 8.1
     */
    public function test_scenarios_returns_list_of_scenarios(): void
    {
        $token = $this->actingAsAdmin();

        $response = $this->withToken($token)->getJson('/api/v1/chatbot/scenarios');

        $response->assertStatus(200)
            ->assertJsonStructure([
                'scenarios' => [
                    '*' => ['id', 'name', 'description'],
                ],
            ]);

        $scenarios = $response->json('scenarios');
        $this->assertCount(4, $scenarios);

        $ids = collect($scenarios)->pluck('id')->toArray();
        $this->assertContains('angry_customer', $ids);
        $this->assertContains('confused_customer', $ids);
        $this->assertContains('refund_request', $ids);
        $this->assertContains('compliment_customer', $ids);
    }

    /**
     * Test scenarios tanpa token → HTTP 401.
     *
     * Validates: Requirement 1.4
     */
    public function test_scenarios_without_token_returns_401(): void
    {
        $response = $this->getJson('/api/v1/chatbot/scenarios');

        $response->assertStatus(401);
    }

    // ─── Message Tests ────────────────────────────────────────────────────────

    /**
     * Test POST /api/v1/chatbot/message berhasil (mock Gemini API) → HTTP 200.
     *
     * Validates: Requirement 8.2
     */
    public function test_message_success_returns_reply(): void
    {
        $token = $this->actingAsAdmin();
        $this->fakeGeminiSuccess('Sudah terlambat 30 menit! Ini tidak bisa diterima!');

        $response = $this->withToken($token)->postJson('/api/v1/chatbot/message', [
            'scenario_id' => 'angry_customer',
            'session_id'  => 'test-session-123',
            'message'     => 'Maaf atas ketidaknyamanannya, izinkan saya membantu.',
        ]);

        $response->assertStatus(200)
            ->assertJsonStructure(['reply', 'session_id'])
            ->assertJson([
                'reply'      => 'Sudah terlambat 30 menit! Ini tidak bisa diterima!',
                'session_id' => 'test-session-123',
            ]);
    }

    /**
     * Test message menyimpan riwayat sesi ke cache.
     *
     * Validates: Requirement 8.2
     */
    public function test_message_stores_session_history_in_cache(): void
    {
        $token = $this->actingAsAdmin();
        $this->fakeGeminiSuccess('Balasan AI');

        $this->withToken($token)->postJson('/api/v1/chatbot/message', [
            'scenario_id' => 'angry_customer',
            'session_id'  => 'session-cache-test',
            'message'     => 'Halo',
        ]);

        $history = Cache::get('chatbot_session_session-cache-test');
        $this->assertNotNull($history);
        $this->assertCount(2, $history); // user message + model reply
        $this->assertEquals('user', $history[0]['role']);
        $this->assertEquals('model', $history[1]['role']);
    }

    /**
     * Test message tanpa session_id → auto-generate session_id.
     *
     * Validates: Requirement 8.2
     */
    public function test_message_generates_session_id_when_not_provided(): void
    {
        $token = $this->actingAsAdmin();
        $this->fakeGeminiSuccess('Balasan AI');

        $response = $this->withToken($token)->postJson('/api/v1/chatbot/message', [
            'scenario_id' => 'angry_customer',
            'message'     => 'Halo',
        ]);

        $response->assertStatus(200)
            ->assertJsonStructure(['reply', 'session_id']);

        $sessionId = $response->json('session_id');
        $this->assertNotEmpty($sessionId);
    }

    /**
     * Test message saat Gemini API gagal → HTTP 502.
     *
     * Validates: Requirement 8.5
     */
    public function test_message_returns_502_when_gemini_fails(): void
    {
        $token = $this->actingAsAdmin();
        $this->fakeGeminiFailure();

        $response = $this->withToken($token)->postJson('/api/v1/chatbot/message', [
            'scenario_id' => 'angry_customer',
            'session_id'  => 'session-fail-test',
            'message'     => 'Halo',
        ]);

        $response->assertStatus(502)
            ->assertJson([
                'message'    => 'Gagal menghubungi layanan AI. Silakan coba lagi.',
                'session_id' => 'session-fail-test',
            ]);
    }

    /**
     * Test sesi dipertahankan saat Gemini gagal.
     *
     * Validates: Requirement 8.5
     */
    public function test_message_preserves_session_when_gemini_fails(): void
    {
        $token = $this->actingAsAdmin();
        $this->fakeGeminiFailure();

        $this->withToken($token)->postJson('/api/v1/chatbot/message', [
            'scenario_id' => 'angry_customer',
            'session_id'  => 'session-preserve-test',
            'message'     => 'Halo',
        ]);

        // Session should still be stored with the user message
        $history = Cache::get('chatbot_session_session-preserve-test');
        $this->assertNotNull($history);
        $this->assertCount(1, $history); // only user message, no model reply
        $this->assertEquals('user', $history[0]['role']);
    }

    /**
     * Test message dengan skenario tidak valid → HTTP 422.
     *
     * Validates: Requirement 8.1
     */
    public function test_message_with_invalid_scenario_returns_422(): void
    {
        $token = $this->actingAsAdmin();

        $response = $this->withToken($token)->postJson('/api/v1/chatbot/message', [
            'scenario_id' => 'nonexistent_scenario',
            'session_id'  => 'test-session',
            'message'     => 'Halo',
        ]);

        $response->assertStatus(422);
    }

    // ─── Feedback Tests ───────────────────────────────────────────────────────

    /**
     * Test POST /api/v1/chatbot/feedback berhasil (mock Gemini API) → HTTP 200.
     *
     * Validates: Requirement 8.3
     */
    public function test_feedback_success_returns_evaluation(): void
    {
        $token = $this->actingAsAdmin();

        // Setup session history in cache
        $sessionId = 'feedback-session-test';
        $history = [
            ['role' => 'user', 'parts' => [['text' => 'Maaf atas ketidaknyamanannya.']]],
            ['role' => 'model', 'parts' => [['text' => 'Sudah terlambat 30 menit!']]],
            ['role' => 'user', 'parts' => [['text' => 'Saya akan segera menyelesaikan masalah ini.']]],
            ['role' => 'model', 'parts' => [['text' => 'Baiklah, saya tunggu.']]],
        ];
        Cache::put("chatbot_session_{$sessionId}", $history, now()->addHours(1));

        $feedbackText = '{"score": 8, "feedback": "Respons cukup baik.", "suggestions": ["Lebih empati"]}';
        $this->fakeGeminiSuccess($feedbackText);

        $response = $this->withToken($token)->postJson('/api/v1/chatbot/feedback', [
            'session_id' => $sessionId,
        ]);

        $response->assertStatus(200)
            ->assertJsonStructure(['feedback', 'session_id'])
            ->assertJson([
                'feedback'   => $feedbackText,
                'session_id' => $sessionId,
            ]);
    }

    /**
     * Test feedback saat sesi tidak ditemukan → HTTP 404.
     *
     * Validates: Requirement 8.3
     */
    public function test_feedback_returns_404_when_session_not_found(): void
    {
        $token = $this->actingAsAdmin();

        $response = $this->withToken($token)->postJson('/api/v1/chatbot/feedback', [
            'session_id' => 'nonexistent-session',
        ]);

        $response->assertStatus(404)
            ->assertJson([
                'message' => 'Sesi tidak ditemukan atau sudah kedaluwarsa.',
            ]);
    }

    /**
     * Test feedback saat Gemini API gagal → HTTP 502.
     *
     * Validates: Requirement 8.5
     */
    public function test_feedback_returns_502_when_gemini_fails(): void
    {
        $token = $this->actingAsAdmin();

        // Setup session history in cache
        $sessionId = 'feedback-fail-session';
        $history = [
            ['role' => 'user', 'parts' => [['text' => 'Halo']]],
            ['role' => 'model', 'parts' => [['text' => 'Balasan']]],
        ];
        Cache::put("chatbot_session_{$sessionId}", $history, now()->addHours(1));

        $this->fakeGeminiFailure();

        $response = $this->withToken($token)->postJson('/api/v1/chatbot/feedback', [
            'session_id' => $sessionId,
        ]);

        $response->assertStatus(502)
            ->assertJson([
                'message'    => 'Gagal menghubungi layanan AI untuk evaluasi. Silakan coba lagi.',
                'session_id' => $sessionId,
            ]);
    }

    /**
     * Test feedback tanpa token → HTTP 401.
     *
     * Validates: Requirement 1.4
     */
    public function test_feedback_without_token_returns_401(): void
    {
        $response = $this->postJson('/api/v1/chatbot/feedback', [
            'session_id' => 'some-session',
        ]);

        $response->assertStatus(401);
    }
}
