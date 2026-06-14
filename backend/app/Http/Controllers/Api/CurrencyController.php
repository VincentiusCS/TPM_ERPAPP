<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\CurrencyLog;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Http;

class CurrencyController extends Controller
{
    /**
     * Supported target currencies for conversion from IDR.
     */
    private const SUPPORTED_CURRENCIES = ['USD', 'EUR', 'GBP'];

    /**
     * Convert IDR amount to a target currency using realtime exchange rate.
     *
     * @param  \Illuminate\Http\Request  $request
     * @return \Illuminate\Http\JsonResponse
     */
    public function convert(Request $request)
    {
        $validated = $request->validate([
            'payroll_id' => 'nullable|integer|exists:payrolls,id',
            'amount_idr' => 'required|numeric|min:0',
            'target_currency' => 'required|string',
        ]);

        $targetCurrency = strtoupper($validated['target_currency']);

        // Validate supported currency
        if (!in_array($targetCurrency, self::SUPPORTED_CURRENCIES)) {
            return response()->json([
                'message' => 'Mata uang tidak didukung. Gunakan: ' . implode(', ', self::SUPPORTED_CURRENCIES),
            ], 422);
        }

        // Fetch exchange rate from external API
        $apiKey = config('services.exchange_rate.key');
        $url = "https://v6.exchangerate-api.com/v6/{$apiKey}/latest/IDR";

        try {
            $response = Http::timeout(10)->get($url);

            if ($response->failed()) {
                return response()->json([
                    'message' => 'Gagal mengambil data kurs. Layanan tidak tersedia saat ini.',
                ], 503);
            }

            $data = $response->json();

            if (!isset($data['conversion_rates'][$targetCurrency])) {
                return response()->json([
                    'message' => 'Kurs untuk mata uang ' . $targetCurrency . ' tidak ditemukan.',
                ], 503);
            }

            $exchangeRate = $data['conversion_rates'][$targetCurrency];
        } catch (\Exception $e) {
            return response()->json([
                'message' => 'Gagal mengambil data kurs. Layanan tidak tersedia saat ini.',
            ], 503);
        }

        // Calculate converted amount
        $convertedAmount = round($validated['amount_idr'] * $exchangeRate, 2);

        // Save log to currency_logs table
        $log = CurrencyLog::create([
            'payroll_id' => $validated['payroll_id'] ?? null,
            'currency_type' => $targetCurrency,
            'exchange_rate' => $exchangeRate,
            'converted_total' => $convertedAmount,
        ]);

        return response()->json([
            'source_currency' => 'IDR',
            'target_currency' => $targetCurrency,
            'exchange_rate' => $exchangeRate,
            'converted_amount' => $convertedAmount,
            'log_id' => $log->id,
        ], 200);
    }
}
