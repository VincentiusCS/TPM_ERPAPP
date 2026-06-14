<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Attendance;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

/**
 * AttendanceController — Pencatatan Presensi Karyawan
 *
 * Menangani operasi untuk data presensi:
 * - index  : daftar presensi dengan filter employee_id, date_from, date_to
 * - store  : catat presensi baru (employee_id dan shift_id wajib)
 * - update : perbarui status presensi
 *
 * Validates: Requirements 4.1, 4.2, 4.3, 4.4, 4.5
 */
class AttendanceController extends Controller
{
    /**
     * Tampilkan riwayat presensi dengan filter opsional.
     *
     * GET /api/v1/attendances
     *
     * Query params:
     * - employee_id : filter berdasarkan ID karyawan
     * - date_from   : filter tanggal mulai (format: Y-m-d)
     * - date_to     : filter tanggal akhir (format: Y-m-d)
     *
     * Validates: Requirement 4.4
     */
    public function index(Request $request): JsonResponse
    {
        $user = $request->user();
        $query = Attendance::with([
            'employee:id,employee_name',
            'shift:id,shift_date,wage_per_shift',
        ]);

        // Filter berdasarkan employee_id
        if ($user->role === 'karyawan') {
            $query->where('employee_id', $user->employee_id);
        } elseif ($request->filled('employee_id')) {
            $query->where('employee_id', $request->integer('employee_id'));
        }

        // Filter berdasarkan rentang tanggal
        if ($request->filled('date_from')) {
            $query->whereDate('attendance_date', '>=', $request->input('date_from'));
        }

        if ($request->filled('date_to')) {
            $query->whereDate('attendance_date', '<=', $request->input('date_to'));
        }

        $attendances = $query->orderBy('attendance_date', 'desc')->get();

        return response()->json($attendances, 200);
    }

    /**
     * Simpan data presensi baru.
     *
     * POST /api/v1/attendances
     *
     * Validasi:
     * - employee_id wajib dan harus ada di tabel employees
     * - shift_id wajib dan harus ada di tabel shifts
     * - attendance_date wajib dan harus berformat tanggal valid
     * - status wajib: "hadir" atau "tidak hadir"
     *
     * Validates: Requirements 4.1, 4.2, 4.5
     */
    public function store(Request $request): JsonResponse
    {
        $user = $request->user();

        $validated = $request->validate([
            'employee_id'     => ['required', 'integer', 'exists:employees,id'],
            'shift_id'        => ['required', 'integer', 'exists:shifts,id'],
            'attendance_date' => ['required', 'date'],
            'status'          => ['required', Rule::in(['hadir', 'tidak hadir'])],
        ]);

        // Karyawan hanya bisa mencatat presensi untuk dirinya sendiri
        if ($user->role === 'karyawan') {
            $validated['employee_id'] = $user->employee_id;
        }

        // Cek duplikat: satu karyawan tidak boleh mencatat presensi lebih dari sekali untuk shift yang sama
        $duplicate = Attendance::where('employee_id', $validated['employee_id'])
            ->where('shift_id', $validated['shift_id'])
            ->exists();

        if ($duplicate) {
            return response()->json([
                'message' => 'Karyawan sudah melakukan presensi pada shift ini.',
            ], 409);
        }

        $attendance = Attendance::create($validated);
        $attendance->load([
            'employee:id,employee_name',
            'shift:id,shift_date,wage_per_shift',
        ]);

        return response()->json($attendance, 201);
    }

    /**
     * Perbarui status presensi yang sudah ada.
     *
     * PUT /api/v1/attendances/{id}
     *
     * Validasi:
     * - status wajib: "hadir" atau "tidak hadir"
     *
     * Validates: Requirement 4.3
     */
    public function update(Request $request, Attendance $attendance): JsonResponse
    {
        if ($request->user()->role !== 'admin') {
            return response()->json([
                'message' => 'Unauthorized. Admin role required.',
            ], 403);
        }

        $validated = $request->validate([
            'status' => ['required', Rule::in(['hadir', 'tidak hadir'])],
        ]);

        $attendance->update($validated);
        $attendance->load([
            'employee:id,employee_name',
            'shift:id,shift_date,wage_per_shift',
        ]);

        return response()->json($attendance, 200);
    }
}
