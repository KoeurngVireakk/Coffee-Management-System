<?php

namespace App\Enums;

enum StaffRole: string
{
    case Cashier = 'cashier';
    case Manager = 'manager';
    case Admin = 'admin';

    public function label(): string
    {
        return match ($this) {
            self::Cashier => 'Cashier',
            self::Manager => 'Manager',
            self::Admin => 'Administrator',
        };
    }

    /** @return list<string> */
    public function permissions(): array
    {
        $staff = ['view-catalog', 'process-pos', 'view-own-orders', 'view-inventory'];
        $management = ['manage-catalog', 'view-all-orders', 'adjust-inventory', 'view-reports', 'view-settings'];

        return match ($this) {
            self::Cashier => $staff,
            self::Manager => [...$staff, ...$management],
            self::Admin => [...$staff, ...$management, 'manage-staff', 'manage-settings'],
        };
    }
}
