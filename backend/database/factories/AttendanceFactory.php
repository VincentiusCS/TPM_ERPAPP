<?php

namespace Database\Factories;

use App\Models\Attendance;
use App\Models\Employee;
use App\Models\Shift;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<Attendance>
 */
class AttendanceFactory extends Factory
{
    protected $model = Attendance::class;

    /**
     * Define the model's default state.
     *
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'employee_id'     => Employee::factory(),
            'shift_id'        => Shift::factory(),
            'attendance_date' => $this->faker->dateTimeBetween('-1 year', 'now')->format('Y-m-d'),
            'status'          => $this->faker->randomElement(['hadir', 'tidak hadir']),
        ];
    }

    /**
     * State: presensi dengan status "hadir".
     */
    public function hadir(): static
    {
        return $this->state(['status' => 'hadir']);
    }

    /**
     * State: presensi dengan status "tidak hadir".
     */
    public function tidakHadir(): static
    {
        return $this->state(['status' => 'tidak hadir']);
    }
}
