<?php

namespace Tests\Feature;

use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class AuthMigrationUpgradeTest extends TestCase
{
    public function test_additive_access_migrations_preserve_legacy_users_without_granting_access(): void
    {
        $original = config('database.default');
        $connection = 'auth_upgrade_test';
        config(["database.connections.{$connection}" => [...config('database.connections.sqlite'), 'database' => ':memory:', 'url' => null]]);
        DB::setDefaultConnection($connection);

        try {
            $legacy = require database_path('migrations/0001_01_01_000000_create_users_table.php');
            $legacy->up();
            DB::table('users')->insert(['name' => 'Synthetic legacy staff', 'email' => 'legacy@example.test', 'password' => 'synthetic-existing-hash']);
            (require database_path('migrations/2026_10_06_000001_create_roles_table.php'))->up();
            $access = require database_path('migrations/2026_10_06_000002_add_staff_access_to_users_table.php');
            $access->up();

            $user = DB::table('users')->sole();
            $this->assertSame('Synthetic legacy staff', $user->name);
            $this->assertSame('legacy@example.test', $user->email);
            $this->assertSame('synthetic-existing-hash', $user->password);
            $this->assertNull($user->role_id);
            $this->assertSame(0, $user->is_active);

            // Rollback is tested only on this disposable SQLite connection.
            $access->down();
            $this->assertSame('synthetic-existing-hash', DB::table('users')->sole()->password);
        } finally {
            DB::setDefaultConnection($original);
            DB::purge($connection);
        }
    }
}
