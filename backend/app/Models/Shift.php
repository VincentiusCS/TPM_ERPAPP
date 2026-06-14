<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Shift extends Model
{
    use HasFactory;

    protected $fillable = [
        'employee_id',
        'shift_date',
        'wage_per_shift',
    ];

    protected $casts = [
        'shift_date' => 'date',
        'wage_per_shift' => 'decimal:2',
    ];

    /**
     * Get the employee that owns this shift.
     */
    public function employee()
    {
        return $this->belongsTo(Employee::class);
    }

    /**
     * Get the attendances for this shift.
     */
    public function attendances()
    {
        return $this->hasMany(Attendance::class);
    }
}
