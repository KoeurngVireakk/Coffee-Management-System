<?php

namespace Tests\Feature;

use App\Enums\StaffRole;
use App\Http\Middleware\EnsureActiveStaff;
use App\Models\Role;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Gate;
use Illuminate\Support\Facades\Route;
use Tests\TestCase;

class AccessControlTest extends TestCase
{
    use RefreshDatabase;

    public function test_gate_matrix_matches_cashier_manager_and_admin_permissions(): void
    {
        $expected = [
            'cashier' => ['view-catalog', 'process-pos', 'view-own-orders', 'view-inventory'],
            'manager' => ['view-catalog', 'process-pos', 'view-own-orders', 'view-inventory', 'manage-catalog', 'view-all-orders', 'adjust-inventory', 'view-reports', 'view-settings'],
            'admin' => ['view-catalog', 'process-pos', 'view-own-orders', 'view-inventory', 'manage-catalog', 'view-all-orders', 'adjust-inventory', 'view-reports', 'view-settings', 'manage-staff', 'manage-settings'],
        ];

        foreach (StaffRole::cases() as $role) {
            $actor = User::factory()->withRole($role)->create();
            foreach ($expected['admin'] as $action) {
                $this->assertSame(in_array($action, $expected[$role->value], true), Gate::forUser($actor)->allows($action), $role->value.':'.$action);
            }
            $this->assertFalse(Gate::forUser($actor)->allows('unregistered-action'));
        }
    }

    public function test_disabled_and_unrecognized_role_users_have_no_gate_permissions(): void
    {
        $role = Role::query()->create(['name' => 'superuser', 'label' => 'Unknown']);
        $actors = [User::factory()->withRole(StaffRole::Admin)->inactive()->create(),
            User::factory()->create(['role_id' => null]), User::factory()->create(['role_id' => $role->id])];

        foreach ($actors as $actor) {
            foreach (StaffRole::Admin->permissions() as $action) {
                $this->assertFalse(Gate::forUser($actor)->allows($action));
            }
        }
    }

    public function test_user_view_policy_denies_other_staff_and_allows_self_or_admin(): void
    {
        $cashier = User::factory()->create();
        $other = User::factory()->create();
        $manager = User::factory()->withRole(StaffRole::Manager)->create();
        $admin = User::factory()->withRole(StaffRole::Admin)->create();
        $this->assertTrue(Gate::forUser($cashier)->allows('view', $cashier));
        $this->assertFalse(Gate::forUser($cashier)->allows('view', $other));
        $this->assertFalse(Gate::forUser($manager)->allows('view', $other));
        $this->assertTrue(Gate::forUser($admin)->allows('view', $other));
        $admin->forceFill(['is_active' => false])->save();
        $this->assertFalse(Gate::forUser($admin)->allows('view', $other));
    }

    public function test_gate_middleware_returns_403_to_cashier_and_allows_manager(): void
    {
        // Test-only protected route exercises the foundation without shipping catalog APIs.
        Route::middleware(['api', 'auth:sanctum', EnsureActiveStaff::class, 'can:manage-catalog'])
            ->get('/api/v1/test-only-access', fn () => response()->noContent());

        $this->get('/api/v1/test-only-access')->assertUnauthorized();
        foreach ([StaffRole::Cashier, StaffRole::Manager] as $role) {
            $user = User::factory()->withRole($role)->create();
            $token = $user->createToken('Synthetic gate test', ['staff'], now()->addHour())->plainTextToken;
            Auth::forgetGuards();
            $response = $this->withToken($token)->get('/api/v1/test-only-access');
            $role === StaffRole::Cashier ? $response->assertForbidden() : $response->assertNoContent();
        }
    }

    public function test_user_mass_assignment_cannot_change_role_or_status(): void
    {
        $user = User::factory()->create();
        $admin = User::factory()->withRole(StaffRole::Admin)->create();
        $originalRole = $user->role_id;
        $user->fill(['role_id' => $admin->role_id, 'is_active' => false, 'permissions' => ['*']])->save();

        $this->assertSame($originalRole, $user->fresh()->role_id);
        $this->assertTrue($user->fresh()->is_active);
        $this->assertSame('cashier', $user->fresh()->role->name);
    }
}
