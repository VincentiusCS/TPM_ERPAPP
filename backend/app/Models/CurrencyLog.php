<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class CurrencyLog extends Model
{
    use HasFactory;

    protected $fillable = [
        'payroll_id',
        'currency_type',
        'exchange_rate',
        'converted_total',
    ];

    protected $casts = [
        'exchange_rate' => 'decimal:10',
        'converted_total' => 'decimal:4',
    ];

    /**
     * Get the payroll that owns this currency log.
     */
    public function payroll()
    {
        return $this->belongsTo(Payroll::class);
    }
}
