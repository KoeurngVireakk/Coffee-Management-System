<?php

namespace Tests\Feature;

use App\Models\Role;
use App\Models\User;
use Database\Seeders\DatabaseSeeder;
use Illuminate\Database\QueryException;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class AuthSchemaTest extends TestCase
{
    use RefreshDatabase;

    public function test_seeders_are_idempotent_and_create_no_default_accounts(): void
    {
        $this->seed(DatabaseSeeder::class);
        $this->seed(DatabaseSeeder::class);
        $this->assertSame(['admin', 'cashier', 'manager'], Role::query()->orderBy('name')->pluck('name')->all());
        $this->assertDatabaseCount('roles', 3);
        $this->assertDatabaseCount('users', 0);
    }

    public function test_new_non_factory_accounts_default_to_inactive_and_unassigned(): void
    {
        $user = User::query()->create(['name' => 'Synthetic provisioning', 'email' => 'provisioning@example.test', 'password' => 'Synthetic-only-credential!2026'])->fresh();
        $this->assertNull($user->role_id);
        $this->assertFalse($user->is_active);
        $this->assertFalse($user->isActiveStaff());
    }

    public function test_role_names_are_unique(): void
    {
        Role::query()->create(['name' => 'cashier', 'label' => 'Cashier']);
        $this->expectException(QueryException::class);
        Role::query()->create(['name' => 'cashier', 'label' => 'Duplicate']);
    }

    public function test_role_assignment_rejects_nonexistent_reference(): void
    {
        $this->expectException(QueryException::class);
        User::factory()->create(['role_id' => 999999]);
    }

    public function test_assigned_role_cannot_be_deleted(): void
    {
        $user = User::factory()->create();
        $this->expectException(QueryException::class);
        $user->role->delete();
    }
}
