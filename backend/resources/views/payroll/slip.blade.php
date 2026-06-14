<!DOCTYPE html>
<html lang="id">
<head>
    <meta charset="UTF-8">
    <title>Slip Gaji - {{ $employee->employee_name }}</title>
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
            border-bottom: 2px solid #4a90d9;
            padding-bottom: 15px;
            margin-bottom: 25px;
        }
        .header h1 {
            font-size: 18px;
            margin-bottom: 5px;
            color: #4a90d9;
        }
        .header p {
            font-size: 11px;
            color: #666;
            margin: 2px 0;
        }
        .info-section {
            margin-bottom: 20px;
        }
        .info-section h3 {
            font-size: 13px;
            border-bottom: 1px solid #eee;
            padding-bottom: 5px;
            margin-bottom: 10px;
        }
        .info-table {
            width: 100%;
            margin-bottom: 15px;
        }
        .info-table td {
            padding: 5px 10px;
            vertical-align: top;
        }
        .info-table .label {
            font-weight: bold;
            width: 180px;
            color: #555;
        }
        .salary-box {
            background-color: #f0f7ff;
            border: 1px solid #4a90d9;
            border-radius: 5px;
            padding: 15px;
            margin-top: 20px;
            text-align: center;
        }
        .salary-box .amount {
            font-size: 20px;
            font-weight: bold;
            color: #4a90d9;
        }
        .salary-box .label {
            font-size: 11px;
            color: #666;
            margin-bottom: 5px;
        }
        .footer {
            margin-top: 40px;
            text-align: right;
            font-size: 10px;
            color: #999;
        }
        .note {
            margin-top: 30px;
            font-size: 10px;
            color: #999;
            font-style: italic;
        }
    </style>
</head>
<body>
    <div class="header">
        <h1>SLIP GAJI KARYAWAN</h1>
        <p>Periode: {{ $periodStart }} s/d {{ $periodEnd }}</p>
    </div>

    <div class="info-section">
        <h3>Data Karyawan</h3>
        <table class="info-table">
            <tr>
                <td class="label">Nama Karyawan</td>
                <td>: {{ $employee->employee_name }}</td>
            </tr>
            <tr>
                <td class="label">No. Telepon</td>
                <td>: {{ $employee->phone }}</td>
            </tr>
            <tr>
                <td class="label">Alamat</td>
                <td>: {{ $employee->address }}</td>
            </tr>
            <tr>
                <td class="label">Status</td>
                <td>: {{ ucfirst($employee->status) }}</td>
            </tr>
        </table>
    </div>

    <div class="info-section">
        <h3>Detail Penggajian</h3>
        <table class="info-table">
            <tr>
                <td class="label">Periode</td>
                <td>: {{ $periodStart }} s/d {{ $periodEnd }}</td>
            </tr>
            <tr>
                <td class="label">Jumlah Kehadiran</td>
                <td>: {{ $payroll->total_attendance }} hari</td>
            </tr>
            <tr>
                <td class="label">Nilai per Shift (Rata-rata)</td>
                <td>: {{ $currencySymbol }} {{ number_format($convertedWagePerShift, 2, ',', '.') }}</td>
            </tr>
        </table>
    </div>

    <div class="salary-box">
        <div class="label">TOTAL GAJI YANG DITERIMA</div>
        <div class="amount">{{ $currencySymbol }} {{ number_format($convertedSalary, 2, ',', '.') }}</div>
    </div>

    <div class="note">
        <p>* Slip gaji ini digenerate secara otomatis oleh sistem ERP Presensi dan Payroll.</p>
        <p>* Gaji dihitung dengan ketentuan: {{ $currencySymbol }} {{ number_format($baseWage, 2, ',', '.') }} per shift (hari kerja biasa) dan {{ $currencySymbol }} {{ number_format($holidayWage, 2, ',', '.') }} per shift (hari libur/akhir pekan).</p>
    </div>

    <div class="footer">
        <p>Dicetak pada: {{ $printedAt }}</p>
    </div>
</body>
</html>
