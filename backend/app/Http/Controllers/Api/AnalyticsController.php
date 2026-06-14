<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Employee;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class AnalyticsController extends Controller
{
    /**
     * Tampilkan analisis performa kehadiran karyawan.
     * Hanya dapat diakses oleh Admin.
     *
     * GET /api/v1/analytics/performance
     */
    public function performance(Request $request): JsonResponse
    {
        // Pastikan pengguna adalah admin
        if ($request->user()->role !== 'admin') {
            return response()->json([
                'message' => 'Unauthorized. Admin role required.',
            ], 403);
        }

        // Ambil data karyawan dengan menghitung relasi shift dan attendance berstatus 'hadir'
        $employees = Employee::withCount([
            'shifts',
            'attendances as hadir_count' => function ($query) {
                $query->where('status', 'hadir');
            }
        ])->get();

        if ($employees->isEmpty()) {
            return response()->json([
                'average_rate' => 0,
                'distribution' => [
                    'Baik' => 0,
                    'Cukup' => 0,
                    'Kurang' => 0,
                ],
                'employees' => [],
                'algorithm' => 'No Data Available',
                'centroids' => []
            ], 200);
        }

        $employeesData = [];
        $totalRateSum = 0;

        foreach ($employees as $employee) {
            $totalShifts = $employee->shifts_count;
            $hadirCount = $employee->hadir_count;
            
            // Hitung rate kehadiran
            $rate = $totalShifts > 0 ? round(($hadirCount / $totalShifts) * 100, 2) : 0.0;
            $totalRateSum += $rate;

            $employeesData[] = [
                'id' => $employee->id,
                'employee_name' => $employee->employee_name,
                'total_shifts' => $totalShifts,
                'hadir_count' => $hadirCount,
                'attendance_rate' => $rate,
            ];
        }

        $companyAverage = round($totalRateSum / count($employees), 2);

        // Jalankan klasifikasi berdasarkan K-Means atau Rule-Based
        $analyticsResult = $this->classifyEmployees($employeesData);

        // Hitung distribusi jumlah karyawan di tiap kategori
        $distribution = [
            'Baik' => 0,
            'Cukup' => 0,
            'Kurang' => 0,
        ];

        foreach ($analyticsResult['employees'] as $emp) {
            $classification = $emp['classification'];
            if (isset($distribution[$classification])) {
                $distribution[$classification]++;
            }
        }

        return response()->json([
            'average_rate' => $companyAverage,
            'distribution' => $distribution,
            'employees' => $analyticsResult['employees'],
            'algorithm' => $analyticsResult['algorithm'],
            'centroids' => $analyticsResult['centroids']
        ], 200);
    }

    /**
     * Memilih metode klasifikasi berdasarkan kuantitas data.
     */
    private function classifyEmployees(array $employeesData): array
    {
        // Jika data < 3 karyawan, K-Means (K=3) tidak efisien/gagal. Fallback ke Rule-Based.
        if (count($employeesData) < 3) {
            return $this->runRuleBasedClassification($employeesData);
        }

        return $this->runKMeans($employeesData);
    }

    /**
     * Algoritma K-Means Clustering 1D untuk K=3.
     */
    private function runKMeans(array $employeesData): array
    {
        $rates = array_map(function ($e) {
            return $e['attendance_rate'];
        }, $employeesData);

        // Jika semua nilai kehadiran sama persis, K-Means akan gagal memisahkannya.
        // Fallback ke Rule-Based.
        $uniqueRates = array_unique($rates);
        if (count($uniqueRates) === 1) {
            return $this->runRuleBasedClassification($employeesData);
        }

        // Urutkan nilai untuk inisialisasi centroid awal
        sort($rates);
        
        // Centroid awal: Nilai terendah, nilai rata-rata, nilai tertinggi
        $c1 = $rates[0];
        $c3 = $rates[count($rates) - 1];
        $sum = array_sum($rates);
        $c2 = $sum / count($rates);

        // Pastikan centroid awal unik
        if ($c2 == $c1) {
            $c2 = ($c1 + $c3) / 2;
        }
        if ($c2 == $c3) {
            $c2 = ($c1 + $c3) / 2;
        }

        $maxIterations = 100;
        $clusters = [[], [], []];

        for ($iter = 0; $iter < $maxIterations; $iter++) {
            $nextClusters = [[], [], []];

            foreach ($employeesData as $employee) {
                $rate = $employee['attendance_rate'];
                
                // Cari jarak terdekat ke masing-masing centroid
                $d1 = abs($rate - $c1);
                $d2 = abs($rate - $c2);
                $d3 = abs($rate - $c3);

                $minD = min($d1, $d2, $d3);
                
                if ($minD === $d1) {
                    $nextClusters[0][] = $employee;
                } elseif ($minD === $d2) {
                    $nextClusters[1][] = $employee;
                } else {
                    $nextClusters[2][] = $employee;
                }
            }

            // Hitung nilai centroid baru dari rata-rata cluster
            $newC1 = $this->calculateMean($nextClusters[0], $c1);
            $newC2 = $this->calculateMean($nextClusters[1], $c2);
            $newC3 = $this->calculateMean($nextClusters[2], $c3);

            // Cek kondisi konvergensi
            if (abs($newC1 - $c1) < 0.01 && abs($newC2 - $c2) < 0.01 && abs($newC3 - $c3) < 0.01) {
                $clusters = $nextClusters;
                break;
            }

            $c1 = $newC1;
            $c2 = $newC2;
            $c3 = $newC3;
            $clusters = $nextClusters;
        }

        // Hitung rata-rata cluster untuk mengurutkan label: Kurang, Cukup, Baik
        $clusterMeans = [];
        foreach ($clusters as $i => $cluster) {
            $clusterMeans[$i] = empty($cluster) 
                ? ($i === 0 ? 0.0 : ($i === 1 ? 50.0 : 100.0)) 
                : $this->calculateMean($cluster, 0.0);
        }

        // Urutkan indeks klaster berdasarkan nilai rata-ratanya
        asort($clusterMeans);
        $sortedIndices = array_keys($clusterMeans);

        $labels = [
            $sortedIndices[0] => 'Kurang', // Cluster dengan rata-rata terendah
            $sortedIndices[1] => 'Cukup',  // Cluster dengan rata-rata sedang
            $sortedIndices[2] => 'Baik',   // Cluster dengan rata-rata tertinggi
        ];

        $classifiedEmployees = [];
        foreach ($clusters as $clusterIndex => $cluster) {
            $label = $labels[$clusterIndex];
            foreach ($cluster as $employee) {
                $employee['classification'] = $label;
                $classifiedEmployees[] = $employee;
            }
        }

        return [
            'employees' => $classifiedEmployees,
            'algorithm' => 'K-Means Clustering (K=3)',
            'centroids' => [
                'Kurang' => round($clusterMeans[$sortedIndices[0]], 2),
                'Cukup' => round($clusterMeans[$sortedIndices[1]], 2),
                'Baik' => round($clusterMeans[$sortedIndices[2]], 2),
            ]
        ];
    }

    /**
     * Hitung rata-rata nilai kehadiran dari sebuah cluster.
     */
    private function calculateMean(array $cluster, float $fallback): float
    {
        if (empty($cluster)) {
            return $fallback;
        }
        $sum = array_sum(array_map(function ($e) {
            return $e['attendance_rate'];
        }, $cluster));
        return $sum / count($cluster);
    }

    /**
     * Metode klasifikasi manual berdasarkan threshold (Rule-Based).
     */
    private function runRuleBasedClassification(array $employeesData): array
    {
        $classifiedEmployees = [];
        foreach ($employeesData as $employee) {
            $rate = $employee['attendance_rate'];
            if ($rate >= 85) {
                $label = 'Baik';
            } elseif ($rate >= 60) {
                $label = 'Cukup';
            } else {
                $label = 'Kurang';
            }
            $employee['classification'] = $label;
            $classifiedEmployees[] = $employee;
        }

        return [
            'employees' => $classifiedEmployees,
            'algorithm' => 'Rule-Based Classification',
            'centroids' => [
                'Kurang' => '< 60.00%',
                'Cukup' => '60.00% - 84.99%',
                'Baik' => '>= 85.00%'
            ]
        ];
    }
}
