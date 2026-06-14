<!DOCTYPE html>
<html lang="id">
<head>
    <meta charset="UTF-8">
    <title>Laporan Payroll</title>
    <style>
        body {
            font-family: 'DejaVu Sans', sans-serif;
            font-size: 12px;
            color: #333;
            margin: 0;
            padding: 20px;
        }
        .header {
            text-align: center;
            margin-bottom: 30px;
        }
        .header h1 {
            font-size: 18px;
            margin-bottom: 5px;
        }
        .header p {
            font-size: 12px;
            color: #666;
            margin: 2px 0;
        }
        table {
            width: 100%;
            border-collapse: collapse;
            margin-top: 15px;
        }
        th, td {
            border: 1px solid #ddd;
            padding: 8px 10px;
            text-align: left;
        }
        th {
            background-color: #4a90d9;
            color: #fff;
            font-weight: bold;
        }
        tr:nth-child(even) {
            background-color: #f9f9f9;
        }
        .footer {
            margin-top: 30px;
            text-align: right;
            font-size: 10px;
            color: #999;
        }
        .summary {
            margin-top: 15px;
            font-weight: bold;
        }
    </style>
</head>
<body>
    <div class="header">
        <h1>Laporan Payroll</h1>
        <p>Periode: {{ $periodStart }} s/d {{ $periodEnd }}</p>
    </div>

    <table>
        <thead>
            <tr>
                <th>No</th>
                <th>Nama Karyawan</th>
                <th>Jumlah Kehadiran</th>
                <th>Total Gaji ({{ $currencySymbol }})</th>
            </tr>
        </thead>
        <tbody>
            @forelse($payrolls as $index => $payroll)
                <tr>
                    <td>{{ $loop->iteration }}</td>
                    <td>{{ $payroll['employee_name'] }}</td>
                    <td>{{ $payroll['total_attendance'] }}</td>
                    <td>{{ number_format($payroll['total_salary'], 2, ',', '.') }}</td>
                </tr>
            @empty
                <tr>
                    <td colspan="4" style="text-align: center;">Tidak ada data payroll untuk periode ini.</td>
                </tr>
            @endforelse
        </tbody>
    </table>

    @if(count($payrolls) > 0)
        <div class="summary">
            <p>Total Karyawan: {{ count($payrolls) }}</p>
            <p>Total Pengeluaran Gaji: {{ $currencySymbol }} {{ number_format(collect($payrolls)->sum('total_salary'), 2, ',', '.') }}</p>
        </div>
    @endif

    <div class="footer">
        <p>Dicetak pada: {{ $printedAt }}</p>
    </div>
</body>
</html>
