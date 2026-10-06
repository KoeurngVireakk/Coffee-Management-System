<?php

namespace Database\Seeders;

use App\Enums\StaffRole;
use App\Models\Role;
use Illuminate\Database\Seeder;

class RoleSeeder extends Seeder
{
    public function run(): void
    {
        foreach (StaffRole::cases() as $role) {
            Role::query()->updateOrCreate(['name' => $role->value], ['label' => $role->label()]);
        }
    }
}
