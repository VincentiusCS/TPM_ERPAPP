<?php

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;

/*
|--------------------------------------------------------------------------
| API Routes — ERP Presensi dan Payroll
|--------------------------------------------------------------------------
|
| All routes are prefixed with /api/v1 (configured in RouteServiceProvider).
| Public routes: auth/login
| Protected routes: everything else (requires Bearer token via Sanctum)
|
*/

// ─── Public Routes ────────────────────────────────────────────────────────────
Route::prefix('auth')->group(function () {
    Route::post('login', [\App\Http\Controllers\Api\AuthController::class, 'login']);
});

// ─── Protected Routes (require valid Sanctum token) ───────────────────────────
Route::middleware('auth:sanctum')->group(function () {

    // Auth
    Route::prefix('auth')->group(function () {
        Route::post('logout', [\App\Http\Controllers\Api\AuthController::class, 'logout']);
        Route::put('profile', [\App\Http\Controllers\Api\AuthController::class, 'updateProfile']);
    });

    // Employees
    Route::apiResource('employees', \App\Http\Controllers\Api\EmployeeController::class)
        ->only(['index', 'store', 'update', 'destroy']);

    // Shifts
    Route::get('shifts', [\App\Http\Controllers\Api\ShiftController::class, 'index']);
    Route::post('shifts', [\App\Http\Controllers\Api\ShiftController::class, 'store']);
    Route::delete('shifts/{shift}', [\App\Http\Controllers\Api\ShiftController::class, 'destroy']);

    // Attendances
    Route::get('attendances', [\App\Http\Controllers\Api\AttendanceController::class, 'index']);
    Route::post('attendances', [\App\Http\Controllers\Api\AttendanceController::class, 'store']);
    Route::put('attendances/{attendance}', [\App\Http\Controllers\Api\AttendanceController::class, 'update']);

    // Payrolls
    Route::get('payrolls/download/report', [\App\Http\Controllers\Api\PayrollController::class, 'downloadReport']);
    Route::get('payrolls/{employee_id}/slip', [\App\Http\Controllers\Api\PayrollController::class, 'downloadSlip']);
    Route::get('payrolls', [\App\Http\Controllers\Api\PayrollController::class, 'index']);

    // Currency Conversion
    Route::post('currency/convert', [\App\Http\Controllers\Api\CurrencyController::class, 'convert']);

    // Chatbot (Gemini AI)
    Route::get('chatbot/scenarios', [\App\Http\Controllers\Api\ChatbotController::class, 'scenarios']);
    Route::post('chatbot/message', [\App\Http\Controllers\Api\ChatbotController::class, 'message']);
    Route::post('chatbot/feedback', [\App\Http\Controllers\Api\ChatbotController::class, 'feedback']);
});
