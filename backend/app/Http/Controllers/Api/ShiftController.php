<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Shift;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\ValidationException;

/**
 * ShiftController — Manajemen Jadwal Shift Karyawan
 *
 * Menangani operasi CRUD untuk jadwal shift:
 * - index  : daftar semua shift
 * - store  : tambah shift baru (cek duplikat employee_id + shift_date)
 * - destroy: hapus shift
 *
 * Validates: Requirements 3.1, 3.2, 3.3, 3.4
 */
class ShiftController extends Controller
{
    /**
     * Tampilkan daftar semua jadwal shift beserta data karyawan.
     *
     * GET /api/v1/shifts
     *
     * Validates: Requirement 3.2
     */
    public function index(Request $request): JsonResponse
    {
        $user = $request->user();
        $query = Shift::with('employee:id,employee_name');

        if ($user->role === 'karyawan') {
            $query->where('employee_id', $user->employee_id);
        }

        $shifts = $query->orderBy('shift_date', 'desc')->get();

        return response()->json($shifts, 200);
    }

    /**
     * Simpan jadwal shift baru.
     *
     * POST /api/v1/shifts
     *
     * Validasi:
     * - employee_id wajib dan harus ada di tabel employees
     * - shift_date wajib dan harus berformat tanggal valid
     * - wage_per_shift opsional, default 50000
     * - Duplikat (employee_id + shift_date) → HTTP 409
     *
     * Validates: Requirements 3.1, 3.3
     */
    public function store(Request $request): JsonResponse
    {
        if ($request->user()->role !== 'admin') {
            return response()->json([
                'message' => 'Unauthorized. Admin role required.',
            ], 403);
        }

        $validated = $request->validate([
            'employee_id'    => ['required', 'integer', 'exists:employees,id'],
            'shift_date'     => ['required', 'date'],
            'wage_per_shift' => ['sometimes', 'numeric', 'min:0'],
        ]);

        // Cek duplikat: satu karyawan tidak boleh memiliki dua shift pada tanggal yang sama
        $duplicate = Shift::where('employee_id', $validated['employee_id'])
            ->whereDate('shift_date', $validated['shift_date'])
            ->exists();

        if ($duplicate) {
            return response()->json([
                'message' => 'Shift pada tanggal tersebut sudah terdaftar untuk karyawan ini.',
            ], 409);
        }

        // Terapkan default wage_per_shift jika tidak dikirim
        $validated['wage_per_shift'] = $validated['wage_per_shift'] ?? 50000;

        $shift = Shift::create($validated);
        $shift->load('employee:id,employee_name');

        return response()->json($shift, 201);
    }

    /**
     * Hapus jadwal shift berdasarkan ID.
     *
     * DELETE /api/v1/shifts/{id}
     *
     * Validates: Requirement 3.4
     */
    public function destroy(Request $request, Shift $shift): JsonResponse
    {
        if ($request->user()->role !== 'admin') {
            return response()->json([
                'message' => 'Unauthorized. Admin role required.',
            ], 403);
        }

        $shift->delete();

        return response()->json([
            'message' => 'Shift berhasil dihapus.',
        ], 200);
    }
}
