<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Str;

class ChatbotController extends Controller
{
    /**
     * Daftar skenario simulasi yang tersedia.
     * Semua skenario berlatar belakang toko kelontong/minimarket (convenient store).
     */
    protected array $scenarios = [
        [
            'id' => 'angry_customer',
            'name' => 'Pelanggan Marah',
            'description' => 'Pelanggan marah karena produk yang dibeli sudah kedaluwarsa.',
            'system_prompt' => 'Kamu adalah pelanggan sebuah toko kelontong/minimarket. Kamu SANGAT marah karena baru saja membeli susu kotak dan ternyata sudah kedaluwarsa. Kamu ingin uang kembali dan minta penjelasan kenapa produk expired masih dijual. Kamu berbicara dengan kasir/pegawai toko. ATURAN: (1) Selalu gunakan bahasa Indonesia sehari-hari. (2) Tetap dalam karakter sebagai pelanggan marah di toko kelontong. (3) Respons singkat 1-3 kalimat saja. (4) Jangan keluar dari konteks toko kelontong. (5) Jangan pernah mengaku sebagai AI.',
        ],
        [
            'id' => 'confused_customer',
            'name' => 'Pelanggan Bingung',
            'description' => 'Pelanggan bingung mencari produk dan butuh bantuan.',
            'system_prompt' => 'Kamu adalah pelanggan sebuah toko kelontong/minimarket. Kamu bingung mencari produk pembersih lantai merek tertentu yang biasa kamu beli tapi tidak ketemu di rak. Kamu juga ingin tahu promo apa yang sedang berlaku. Kamu berbicara dengan pegawai toko. ATURAN: (1) Selalu gunakan bahasa Indonesia sehari-hari. (2) Tetap dalam karakter sebagai pelanggan bingung di toko kelontong. (3) Respons singkat 1-3 kalimat saja. (4) Jangan keluar dari konteks toko kelontong. (5) Jangan pernah mengaku sebagai AI.',
        ],
        [
            'id' => 'refund_request',
            'name' => 'Permintaan Tukar Barang',
            'description' => 'Pelanggan ingin menukar barang yang salah beli.',
            'system_prompt' => 'Kamu adalah pelanggan sebuah toko kelontong/minimarket. Kamu baru saja membeli minyak goreng 2 liter tapi ternyata salah, kamu mau yang 1 liter saja. Kamu ingin menukar dan minta selisih uangnya dikembalikan. Struk masih ada. Kamu berbicara dengan kasir. ATURAN: (1) Selalu gunakan bahasa Indonesia sehari-hari. (2) Tetap dalam karakter sebagai pelanggan di toko kelontong. (3) Respons singkat 1-3 kalimat saja. (4) Jangan keluar dari konteks toko kelontong. (5) Jangan pernah mengaku sebagai AI.',
        ],
        [
            'id' => 'compliment_customer',
            'name' => 'Pelanggan Puas',
            'description' => 'Pelanggan puas dengan pelayanan dan bertanya soal member.',
            'system_prompt' => 'Kamu adalah pelanggan tetap sebuah toko kelontong/minimarket. Kamu senang karena pegawainya selalu ramah dan tokonya bersih. Kamu ingin tahu apakah ada kartu member atau program poin untuk pelanggan setia. Kamu berbicara dengan pegawai toko. ATURAN: (1) Selalu gunakan bahasa Indonesia sehari-hari. (2) Tetap dalam karakter sebagai pelanggan puas di toko kelontong. (3) Respons singkat 1-3 kalimat saja. (4) Jangan keluar dari konteks toko kelontong. (5) Jangan pernah mengaku sebagai AI.',
        ],
    ];

    /**
     * GET /api/v1/chatbot/scenarios
     */
    public function scenarios()
    {
        $list = collect($this->scenarios)->map(function ($scenario) {
            return [
                'id' => $scenario['id'],
                'name' => $scenario['name'],
                'description' => $scenario['description'],
            ];
        });

        return response()->json(['scenarios' => $list->values()], 200);
    }

    /**
     * POST /api/v1/chatbot/message
     */
    public function message(Request $request)
    {
        $validated = $request->validate([
            'scenario_id' => 'required|string',
            'session_id' => 'nullable|string',
            'message' => 'required|string',
        ]);

        $scenarioId = $validated['scenario_id'];
        $sessionId = $validated['session_id'] ?? Str::uuid()->toString();
        $userMessage = $validated['message'];

        $scenario = collect($this->scenarios)->firstWhere('id', $scenarioId);
        if (!$scenario) {
            return response()->json(['message' => 'Skenario tidak ditemukan.'], 422);
        }

        $cacheKey = "chatbot_session_{$sessionId}";
        $history = Cache::get($cacheKey, []);

        $history[] = ['role' => 'user', 'content' => $userMessage];

        $messages = $this->buildMessages($scenario['system_prompt'], $history);

        $reply = $this->callAI($messages);

        if ($reply === null) {
            Cache::put($cacheKey, $history, now()->addHours(1));
            return response()->json([
                'message' => 'Gagal menghubungi layanan AI. Silakan coba lagi.',
                'session_id' => $sessionId,
            ], 502);
        }

        $history[] = ['role' => 'assistant', 'content' => $reply];
        Cache::put($cacheKey, $history, now()->addHours(1));

        return response()->json([
            'reply' => $reply,
            'session_id' => $sessionId,
        ], 200);
    }

    /**
     * POST /api/v1/chatbot/feedback
     */
    public function feedback(Request $request)
    {
        $validated = $request->validate([
            'session_id' => 'required|string',
        ]);

        $sessionId = $validated['session_id'];
        $cacheKey = "chatbot_session_{$sessionId}";
        $history = Cache::get($cacheKey, []);

        if (empty($history)) {
            return response()->json([
                'message' => 'Sesi tidak ditemukan atau sudah kedaluwarsa.',
            ], 404);
        }

        $feedbackPrompt = 'Berdasarkan percakapan di atas, berikan evaluasi kualitas respons customer service. '
            . 'Nilai dari skala 1-10 dan berikan saran perbaikan spesifik dalam bahasa Indonesia.';

        $systemPrompt = 'Kamu adalah evaluator profesional untuk kualitas layanan pelanggan. '
            . 'Evaluasi percakapan berikut dan berikan feedback konstruktif dalam bahasa Indonesia.';

        $messages = $this->buildMessages($systemPrompt, $history);
        $messages[] = ['role' => 'user', 'content' => $feedbackPrompt];

        $reply = $this->callAI($messages);

        if ($reply === null) {
            return response()->json([
                'message' => 'Gagal menghubungi layanan AI untuk evaluasi. Silakan coba lagi.',
                'session_id' => $sessionId,
            ], 502);
        }

        return response()->json([
            'feedback' => $reply,
            'session_id' => $sessionId,
        ], 200);
    }

    /**
     * Build messages array in OpenAI/Groq format.
     */
    protected function buildMessages(string $systemPrompt, array $history): array
    {
        $messages = [
            ['role' => 'system', 'content' => $systemPrompt],
        ];

        foreach ($history as $entry) {
            $messages[] = [
                'role' => $entry['role'],
                'content' => $entry['content'],
            ];
        }

        return $messages;
    }

    /**
     * Call AI API (Groq - OpenAI compatible format).
     * Returns the reply text or null on failure.
     */
    protected function callAI(array $messages): ?string
    {
        $apiKey = config('services.groq.key');

        if (empty($apiKey)) {
            return null;
        }

        try {
            $response = Http::timeout(30)
                ->withHeaders([
                    'Authorization' => "Bearer {$apiKey}",
                    'Content-Type' => 'application/json',
                ])
                ->post('https://api.groq.com/openai/v1/chat/completions', [
                    'model' => 'llama-3.1-8b-instant',
                    'messages' => $messages,
                    'temperature' => 0.5,
                    'max_tokens' => 200,
                ]);

            if ($response->failed()) {
                return null;
            }

            $data = $response->json();
            return $data['choices'][0]['message']['content'] ?? null;
        } catch (\Exception $e) {
            return null;
        }
    }
}
