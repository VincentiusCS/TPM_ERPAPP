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
     * Protect EmployeeController: Only admin is authorized.
     */
    public function __construct()
    {
        $this->middleware(function ($request, $next) {
            if ($request->user()->role !== 'admin') {
                return response()->json([
                    'message' => 'Unauthorized. Admin role required.',
                ], 403);
            }
            return $next($request);
        });
    }

    /**
     * GET /api/v1/employees
     *
     * Mengembalikan daftar seluruh karyawan.
     *
     * Validates: Requirement 2.1
     */
    public function index(): JsonResponse
    {
        $employees = Employee::with('user:id,employee_id,email')->get();

        return response()->json($employees, 200);
    }

    /**
     * POST /api/v1/employees
     *
     * Menyimpan karyawan baru ke database beserta akun User terkait.
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
            'email' => ['required', 'email', 'unique:users,email'],
            'password' => ['required', 'string', 'min:6'],
        ]);

        // Trim whitespace from string fields before saving
        $validated['employee_name'] = trim($validated['employee_name']);
        $validated['phone']         = trim($validated['phone']);
        $validated['address']       = trim($validated['address']);

        $employee = Employee::create([
            'employee_name' => $validated['employee_name'],
            'phone'         => $validated['phone'],
            'address'       => $validated['address'],
            'status'        => $validated['status'],
        ]);

        \App\Models\User::create([
            'name'        => $employee->employee_name,
            'email'       => $validated['email'],
            'password'    => \Illuminate\Support\Facades\Hash::make($validated['password']),
            'role'        => 'karyawan',
            'employee_id' => $employee->id,
        ]);

        $employee->load('user:id,employee_id,email');

        return response()->json($employee, 201);
    }

    /**
     * PUT /api/v1/employees/{id}
     *
     * Memperbarui data karyawan yang sudah ada beserta akun User terkait.
     * Field wajib tidak boleh kosong atau hanya whitespace.
     *
     * Validates: Requirement 2.4
     */
    public function update(Request $request, $id): JsonResponse
    {
        $employee = Employee::findOrFail($id);
        $user = \App\Models\User::where('employee_id', $employee->id)->first();

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
            'email' => ['required', 'email', Rule::unique('users', 'email')->ignore($user ? $user->id : null)],
            'password' => ['nullable', 'string', 'min:6'],
        ]);

        // Trim whitespace from string fields before saving
        $validated['employee_name'] = trim($validated['employee_name']);
        $validated['phone']         = trim($validated['phone']);
        $validated['address']       = trim($validated['address']);

        $employee->update([
            'employee_name' => $validated['employee_name'],
            'phone'         => $validated['phone'],
            'address'       => $validated['address'],
            'status'        => $validated['status'],
        ]);

        if ($user) {
            $user->name = $employee->employee_name;
            $user->email = $validated['email'];
            if (!empty($validated['password'])) {
                $user->password = \Illuminate\Support\Facades\Hash::make($validated['password']);
            }
            $user->save();
        } else {
            \App\Models\User::create([
                'name'        => $employee->employee_name,
                'email'       => $validated['email'],
                'password'    => \Illuminate\Support\Facades\Hash::make($validated['password'] ?? 'password123'),
                'role'        => 'karyawan',
                'employee_id' => $employee->id,
            ]);
        }

        $employee->load('user:id,employee_id,email');

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
