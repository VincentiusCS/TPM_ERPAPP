<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Attendance;
use App\Models\Employee;
use App\Models\Payroll;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Http;

class PayrollController extends Controller
{
    /**
     * Hitung dan tampilkan payroll untuk semua karyawan dalam periode tertentu.
     *
     * Query params:
     *   - period_start (required): tanggal mulai periode (Y-m-d)
     *   - period_end   (required): tanggal akhir periode (Y-m-d)
     *   - search       (optional): filter nama karyawan (partial match)
     *
     * Rumus: total_salary = jumlah_hadir × 50000 (kecuali hari libur nasional flat Rp100.000,00)
     *
     * Validates: Requirements 5.1, 5.2, 5.3, 5.4, 5.8
     */
    public function index(Request $request)
    {
        $request->validate([
            'period_start' => ['required', 'date'],
            'period_end'   => ['required', 'date', 'after_or_equal:period_start'],
        ]);

        $periodStart = $request->input('period_start');
        $periodEnd   = $request->input('period_end');
        $search      = $request->input('search');
        $user        = $request->user();

        // Ambil semua karyawan, filter berdasarkan nama jika ada parameter search, atau saring ke karyawan bersangkutan jika role adalah karyawan
        $employeesQuery = Employee::query();
        if ($user->role === 'karyawan') {
            $employeesQuery->where('id', $user->employee_id);
        } elseif ($search) {
            $employeesQuery->where('employee_name', 'like', '%' . $search . '%');
        }
        $employees = $employeesQuery->get();

        // Ambil data presensi "hadir" beserta shift terkait untuk semua karyawan dalam periode ini berdasarkan tanggal shift
        $attendances = Attendance::where('status', 'hadir')
            ->whereHas('shift', function ($q) use ($periodStart, $periodEnd) {
                $q->whereBetween('shift_date', [$periodStart, $periodEnd]);
            })
            ->with('shift')
            ->when($search, function ($q) use ($employees) {
                $q->whereIn('employee_id', $employees->pluck('id'));
            })
            ->get()
            ->groupBy('employee_id');

        // Jika tidak ada data presensi sama sekali dalam periode ini
        if ($attendances->isEmpty()) {
            return response()->json([
                'data'    => [],
                'total'   => 0,
                'message' => 'Tidak ada data presensi untuk periode yang dipilih.',
            ], 200);
        }

        $results = [];

        foreach ($employees as $employee) {
            $employeeAttendances = $attendances->get($employee->id, collect());
            $totalAttendance = $employeeAttendances->count();

            // Hanya sertakan karyawan yang memiliki data presensi dalam periode
            if ($totalAttendance === 0) {
                continue;
            }

            $totalSalary = 0;
            foreach ($employeeAttendances as $attendance) {
                $baseWage = $attendance->shift ? $attendance->shift->wage_per_shift : 50000;
                
                // Cek hari libur menggunakan API libur.deno.dev berdasarkan tanggal shift
                $checkDate = $attendance->shift ? $attendance->shift->shift_date : $attendance->attendance_date;
                if ($this->isHoliday($checkDate->format('Y-m-d'))) {
                    $totalSalary += 100000; // Total fee Rp100.000,00 saat hari libur
                } else {
                    $totalSalary += $baseWage;
                }
            }

            // Simpan atau update record payroll
            Payroll::updateOrCreate(
                [
                    'employee_id'  => $employee->id,
                    'period_start' => $periodStart,
                    'period_end'   => $periodEnd,
                ],
                [
                    'total_attendance' => $totalAttendance,
                    'total_salary'     => $totalSalary,
                ]
            );

            $results[] = [
                'employee_id'      => $employee->id,
                'employee_name'    => $employee->employee_name,
                'total_attendance' => $totalAttendance,
                'total_salary'     => $totalSalary,
            ];
        }

        // Jika setelah filter tidak ada hasil (misal search tidak cocok dengan yang hadir)
        if (empty($results)) {
            return response()->json([
                'data'    => [],
                'total'   => 0,
                'message' => 'Tidak ada data payroll yang sesuai dengan kriteria pencarian.',
            ], 200);
        }

        return response()->json([
            'data'    => $results,
            'total'   => count($results),
            'message' => null,
        ], 200);
    }

    /**
     * Unduh laporan payroll dalam format PDF.
     *
     * Query params:
     *   - period_start (required): tanggal mulai periode (Y-m-d)
     *   - period_end   (required): tanggal akhir periode (Y-m-d)
     *
     * Validates: Requirements 5.5, 5.7
     */
    public function downloadReport(Request $request)
    {
        if ($request->user()->role !== 'admin') {
            return response()->json([
                'message' => 'Unauthorized. Admin role required.',
            ], 403);
        }

        $request->validate([
            'period_start' => ['required', 'date'],
            'period_end'   => ['required', 'date', 'after_or_equal:period_start'],
        ]);

        $periodStart = $request->input('period_start');
        $periodEnd   = $request->input('period_end');
        $currency    = $request->input('currency', 'IDR');
        $timezone    = $request->input('timezone', 'WIB');

        $currencySymbols = [
            'IDR' => 'Rp', 'USD' => '$', 'EUR' => '€', 'GBP' => '£',
            'JPY' => '¥', 'SGD' => 'S$', 'AUD' => 'A$', 'CNY' => '¥',
            'KRW' => '₩', 'MYR' => 'RM', 'THB' => '฿',
        ];

        $timezoneMap = [
            'WIB' => 'Asia/Jakarta', 'WITA' => 'Asia/Makassar', 'WIT' => 'Asia/Jayapura',
            'UTC' => 'UTC', 'GMT' => 'Europe/London', 'JST' => 'Asia/Tokyo',
            'SGT' => 'Asia/Singapore', 'KST' => 'Asia/Seoul', 'CST' => 'Asia/Shanghai',
            'EST' => 'America/New_York', 'PST' => 'America/Los_Angeles', 'CET' => 'Europe/Berlin',
        ];

        $currencySymbol = $currencySymbols[$currency] ?? $currency;
        $tz = $timezoneMap[$timezone] ?? 'Asia/Jakarta';
        $printedAt = Carbon::now($tz)->format('d/m/Y H:i:s') . ' ' . $timezone;

        // Ambil data payroll yang sudah dihitung untuk periode ini
        $payrolls = Payroll::with('employee')
            ->whereBetween('period_start', [$periodStart, $periodEnd])
            ->orWhereBetween('period_end', [$periodStart, $periodEnd])
            ->get()
            ->filter(fn ($p) =>
                $p->period_start->format('Y-m-d') === $periodStart &&
                $p->period_end->format('Y-m-d') === $periodEnd
            );

        // Jika tidak ada data, hitung ulang dari attendances
        if ($payrolls->isEmpty()) {
            $attendances = Attendance::where('status', 'hadir')
                ->whereHas('shift', function ($q) use ($periodStart, $periodEnd) {
                    $q->whereBetween('shift_date', [$periodStart, $periodEnd]);
                })
                ->with('shift')
                ->get()
                ->groupBy('employee_id');

            $payrollData = Employee::whereIn('id', $attendances->keys())
                ->get()
                ->map(function ($employee) use ($attendances, $periodStart, $periodEnd) {
                    $employeeAttendances = $attendances->get($employee->id, collect());
                    $totalAttendance = $employeeAttendances->count();

                    $totalSalary = 0;
                    foreach ($employeeAttendances as $attendance) {
                        $baseWage = $attendance->shift ? $attendance->shift->wage_per_shift : 50000;
                        $checkDate = $attendance->shift ? $attendance->shift->shift_date : $attendance->attendance_date;
                        if ($this->isHoliday($checkDate->format('Y-m-d'))) {
                            $totalSalary += 100000;
                        } else {
                            $totalSalary += $baseWage;
                        }
                    }

                    return [
                        'employee_name'    => $employee->employee_name,
                        'total_attendance' => $totalAttendance,
                        'total_salary'     => $totalSalary,
                    ];
                });
        } else {
            $payrollData = $payrolls->map(fn ($p) => [
                'employee_name'    => $p->employee->employee_name ?? '-',
                'total_attendance' => $p->total_attendance,
                'total_salary'     => $p->total_salary,
            ]);
        }

        // Convert salary amounts if currency is not IDR
        if ($currency !== 'IDR') {
            $exchangeRate = $this->getExchangeRate($currency);
            if ($exchangeRate) {
                $payrollData = $payrollData->map(function ($item) use ($exchangeRate) {
                    $item['total_salary'] = round($item['total_salary'] * $exchangeRate, 2);
                    return $item;
                });
            }
        }

        $pdf = app('dompdf.wrapper');
        $pdf->loadView('payroll.report', [
            'payrolls'       => $payrollData,
            'periodStart'    => $periodStart,
            'periodEnd'      => $periodEnd,
            'currencySymbol' => $currencySymbol,
            'printedAt'      => $printedAt,
        ]);

        $filename = "laporan-payroll-{$periodStart}-sd-{$periodEnd}.pdf";

        return $pdf->download($filename);
    }

    /**
     * Unduh slip gaji per karyawan dalam format PDF.
     *
     * Route param: employee_id
     * Query params:
     *   - period_start (required): tanggal mulai periode (Y-m-d)
     *   - period_end   (required): tanggal akhir periode (Y-m-d)
     *
     * Validates: Requirements 5.6, 5.7
     */
    public function downloadSlip(Request $request, $employee_id)
    {
        $user = $request->user();
        if ($user->role === 'karyawan' && $user->employee_id != $employee_id) {
            return response()->json([
                'message' => 'Unauthorized. You can only download your own slip.',
            ], 403);
        }

        $request->validate([
            'period_start' => ['required', 'date'],
            'period_end'   => ['required', 'date', 'after_or_equal:period_start'],
        ]);

        $employee = Employee::findOrFail($employee_id);

        $periodStart = $request->input('period_start');
        $periodEnd   = $request->input('period_end');
        $currency    = $request->input('currency', 'IDR');
        $timezone    = $request->input('timezone', 'WIB');

        $currencySymbols = [
            'IDR' => 'Rp', 'USD' => '$', 'EUR' => '€', 'GBP' => '£',
            'JPY' => '¥', 'SGD' => 'S$', 'AUD' => 'A$', 'CNY' => '¥',
            'KRW' => '₩', 'MYR' => 'RM', 'THB' => '฿',
        ];

        $timezoneMap = [
            'WIB' => 'Asia/Jakarta', 'WITA' => 'Asia/Makassar', 'WIT' => 'Asia/Jayapura',
            'UTC' => 'UTC', 'GMT' => 'Europe/London', 'JST' => 'Asia/Tokyo',
            'SGT' => 'Asia/Singapore', 'KST' => 'Asia/Seoul', 'CST' => 'Asia/Shanghai',
            'EST' => 'America/New_York', 'PST' => 'America/Los_Angeles', 'CET' => 'Europe/Berlin',
        ];

        $currencySymbol = $currencySymbols[$currency] ?? $currency;
        $tz = $timezoneMap[$timezone] ?? 'Asia/Jakarta';
        $printedAt = Carbon::now($tz)->format('d/m/Y H:i:s') . ' ' . $timezone;

        // Cari payroll yang sudah tersimpan, atau hitung dari attendances
        $payroll = Payroll::where('employee_id', $employee->id)
            ->where('period_start', $periodStart)
            ->where('period_end', $periodEnd)
            ->first();

        if (! $payroll) {
            $employeeAttendances = Attendance::where('employee_id', $employee->id)
                ->where('status', 'hadir')
                ->whereHas('shift', function ($q) use ($periodStart, $periodEnd) {
                    $q->whereBetween('shift_date', [$periodStart, $periodEnd]);
                })
                ->with('shift')
                ->get();

            $totalAttendance = $employeeAttendances->count();
            $totalSalary = 0;
            foreach ($employeeAttendances as $attendance) {
                $baseWage = $attendance->shift ? $attendance->shift->wage_per_shift : 50000;
                $checkDate = $attendance->shift ? $attendance->shift->shift_date : $attendance->attendance_date;
                if ($this->isHoliday($checkDate->format('Y-m-d'))) {
                    $totalSalary += 100000;
                } else {
                    $totalSalary += $baseWage;
                }
            }

            $payroll = Payroll::updateOrCreate(
                [
                    'employee_id'  => $employee->id,
                    'period_start' => $periodStart,
                    'period_end'   => $periodEnd,
                ],
                [
                    'total_attendance' => $totalAttendance,
                    'total_salary'     => $totalSalary,
                ]
            );
        }

        // Convert salary if currency is not IDR
        $avgWage = $payroll->total_attendance > 0 ? ($payroll->total_salary / $payroll->total_attendance) : 50000;
        $baseWage = 50000;
        $holidayWage = 100000;
        $convertedSalary = $payroll->total_salary;
        $convertedWagePerShift = $avgWage;
        
        if ($currency !== 'IDR') {
            $exchangeRate = $this->getExchangeRate($currency);
            if ($exchangeRate) {
                $convertedSalary = round($payroll->total_salary * $exchangeRate, 2);
                $convertedWagePerShift = round($avgWage * $exchangeRate, 2);
                $baseWage = round(50000 * $exchangeRate, 2);
                $holidayWage = round(100000 * $exchangeRate, 2);
            }
        }

        $pdf = app('dompdf.wrapper');
        $pdf->loadView('payroll.slip', [
            'employee'       => $employee,
            'payroll'        => $payroll,
            'periodStart'    => $periodStart,
            'periodEnd'      => $periodEnd,
            'currencySymbol' => $currencySymbol,
            'printedAt'      => $printedAt,
            'convertedSalary' => $convertedSalary,
            'convertedWagePerShift' => $convertedWagePerShift,
            'baseWage'       => $baseWage,
            'holidayWage'    => $holidayWage,
        ]);

        $filename = "slip-gaji-{$employee->employee_name}-{$periodStart}-sd-{$periodEnd}.pdf";

        return $pdf->download($filename);
    }

    /**
     * Fetch exchange rate from IDR to target currency using Exchange Rate API.
     * Returns the rate or null on failure.
     */
    private function getExchangeRate(string $targetCurrency): ?float
    {
        $apiKey = config('services.exchange_rate.key');
        $url = "https://v6.exchangerate-api.com/v6/{$apiKey}/latest/IDR";

        try {
            $response = Http::timeout(10)->get($url);
            if ($response->successful()) {
                $data = $response->json();
                return $data['conversion_rates'][$targetCurrency] ?? null;
            }
        } catch (\Exception $e) {
            // Fall through — return null
        }

        return null;
    }

    /**
     * Mengambil daftar hari libur nasional Indonesia dari libur.deno.dev API berdasarkan tahun.
     * Hasil di-cache selama 24 jam untuk menghindari kuota API terbuang.
     *
     * @param string $year
     * @return array Array berisi tanggal format 'Y-m-d' sebagai key, dan nama libur sebagai value.
     */
    private function getHolidays(string $year): array
    {
        return \Cache::remember("indonesian_holidays_{$year}", 86400, function () use ($year) {
            try {
                $response = Http::timeout(10)->get('https://libur.deno.dev/api', [
                    'year' => $year
                ]);

                if ($response->successful()) {
                    $data = $response->json();
                    $holidays = [];
                    if (is_array($data)) {
                        foreach ($data as $item) {
                            if (isset($item['date'])) {
                                $holidays[$item['date']] = $item['name'] ?? 'Hari Libur Nasional';
                            }
                        }
                    }
                    return $holidays;
                }
            } catch (\Exception $e) {
                // Return empty so it's not cached permanently if it fails
            }

            return [];
        });
    }

    /**
     * Memeriksa apakah suatu tanggal merupakan hari libur.
     */
    private function isHoliday(string $dateStr): bool
    {
        // Cek apakah libur nasional dari API
        $year = substr($dateStr, 0, 4);
        $holidays = $this->getHolidays($year);
        return isset($holidays[$dateStr]);
    }
}
