<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Employee;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class EmployeeController extends Controller
{
    /**
     * GET /api/v1/employees
     *
     * Mengembalikan daftar seluruh karyawan.
     *
     * Validates: Requirement 2.1
     */
    public function index(): JsonResponse
    {
        $employees = Employee::all();

        return response()->json($employees, 200);
    }

    /**
     * POST /api/v1/employees
     *
     * Menyimpan karyawan baru ke database.
     * Field wajib tidak boleh kosong atau hanya whitespace.
     *
     * Validates: Requirement 2.2, 2.3
     */
    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'employee_name' => ['required', 'string', 'filled', function ($attribute, $value, $fail) {
                if (trim($value) === '') {
                    $fail("The {$attribute} field must not be empty or whitespace only.");
                }
            }],
            'phone' => ['required', 'string', 'filled', function ($attribute, $value, $fail) {
                if (trim($value) === '') {
                    $fail("The {$attribute} field must not be empty or whitespace only.");
                }
            }],
            'address' => ['required', 'string', 'filled', function ($attribute, $value, $fail) {
                if (trim($value) === '') {
                    $fail("The {$attribute} field must not be empty or whitespace only.");
                }
            }],
            'status' => ['required', Rule::in(['aktif', 'nonaktif'])],
        ]);

        // Trim whitespace from string fields before saving
        $validated['employee_name'] = trim($validated['employee_name']);
        $validated['phone']         = trim($validated['phone']);
        $validated['address']       = trim($validated['address']);

        $employee = Employee::create($validated);

        return response()->json($employee, 201);
    }

    /**
     * PUT /api/v1/employees/{id}
     *
     * Memperbarui data karyawan yang sudah ada.
     * Field wajib tidak boleh kosong atau hanya whitespace.
     *
     * Validates: Requirement 2.4
     */
    public function update(Request $request, $id): JsonResponse
    {
        $employee = Employee::findOrFail($id);

        $validated = $request->validate([
            'employee_name' => ['required', 'string', 'filled', function ($attribute, $value, $fail) {
                if (trim($value) === '') {
                    $fail("The {$attribute} field must not be empty or whitespace only.");
                }
            }],
            'phone' => ['required', 'string', 'filled', function ($attribute, $value, $fail) {
                if (trim($value) === '') {
                    $fail("The {$attribute} field must not be empty or whitespace only.");
                }
            }],
            'address' => ['required', 'string', 'filled', function ($attribute, $value, $fail) {
                if (trim($value) === '') {
                    $fail("The {$attribute} field must not be empty or whitespace only.");
                }
            }],
            'status' => ['required', Rule::in(['aktif', 'nonaktif'])],
        ]);

        // Trim whitespace from string fields before saving
        $validated['employee_name'] = trim($validated['employee_name']);
        $validated['phone']         = trim($validated['phone']);
        $validated['address']       = trim($validated['address']);

        $employee->update($validated);

        return response()->json($employee, 200);
    }

    /**
     * DELETE /api/v1/employees/{id}
     *
     * Menghapus karyawan dari database.
     * Jika karyawan memiliki data presensi atau payroll terkait → HTTP 409.
     *
     * Validates: Requirement 2.5, 2.6
     */
    public function destroy($id): JsonResponse
    {
        $employee = Employee::findOrFail($id);

        // Cek relasi ke attendances dan payrolls
        $hasAttendances = $employee->attendances()->exists();
        $hasPayrolls    = $employee->payrolls()->exists();

        if ($hasAttendances || $hasPayrolls) {
            return response()->json([
                'message' => 'Karyawan tidak dapat dihapus karena memiliki data presensi atau payroll terkait.',
            ], 409);
        }

        $employee->delete();

        return response()->json([
            'message' => 'Karyawan berhasil dihapus.',
        ], 200);
    }
}
