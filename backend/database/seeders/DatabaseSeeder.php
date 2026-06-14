<?php

namespace Database\Seeders;

// use Illuminate\Database\Console\Seeds\WithoutModelEvents;
use App\Models\Employee;
use App\Models\User;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;

class DatabaseSeeder extends Seeder
{
    /**
     * Seed the application's database.
     */
    public function run(): void
    {
        $this->call([
            AdminSeeder::class,
        ]);

        // Seed a dummy employee and user with role karyawan
        $employee = Employee::updateOrCreate(
            ['employee_name' => 'Karyawan Budi'],
            [
                'phone'   => '08123456789',
                'address' => 'Jl. Kaliurang KM 5, Sleman',
                'status'  => 'aktif',
            ]
        );

        User::updateOrCreate(
            ['email' => 'karyawan@example.com'],
            [
                'name'        => 'Karyawan Budi',
                'email'       => 'karyawan@example.com',
                'password'    => Hash::make('password'),
                'role'        => 'karyawan',
                'employee_id' => $employee->id,
            ]
        );
    }
}
