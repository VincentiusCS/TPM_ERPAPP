<?php

namespace Database\Factories;

use App\Models\Employee;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<Employee>
 */
class EmployeeFactory extends Factory
{
    protected $model = Employee::class;

    /**
     * Define the model's default state.
     *
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'employee_name' => $this->faker->name(),
            'phone'         => $this->faker->numerify('08##########'),
            'address'       => $this->faker->address(),
            'status'        => $this->faker->randomElement(['aktif', 'nonaktif']),
        ];
    }

    /**
     * State: karyawan aktif.
     */
    public function aktif(): static
    {
        return $this->state(['status' => 'aktif']);
    }

    /**
     * State: karyawan nonaktif.
     */
    public function nonaktif(): static
    {
        return $this->state(['status' => 'nonaktif']);
    }
}
