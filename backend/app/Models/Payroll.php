<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Payroll extends Model
{
    use HasFactory;

    protected $fillable = [
        'employee_id',
        'period_start',
        'period_end',
        'total_attendance',
        'total_salary',
    ];

    protected $casts = [
        'period_start' => 'date',
        'period_end' => 'date',
        'total_attendance' => 'integer',
        'total_salary' => 'decimal:2',
    ];

    /**
     * Get the employee for this payroll.
     */
    public function employee()
    {
        return $this->belongsTo(Employee::class);
    }

    /**
     * Get the currency logs for this payroll.
     */
    public function currencyLogs()
    {
        return $this->hasMany(CurrencyLog::class);
    }
}
