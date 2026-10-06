<?php

namespace Tests\Feature;

use App\Enums\StaffRole;
use App\Models\AuditEvent;
use App\Models\Role;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Hash;
use Tests\TestCase;

class StaffApiTest extends TestCase
{
    use RefreshDatabase;

    private function staff(StaffRole $role = StaffRole::Cashier, array $state = []): User
    {
        $user = User::factory()->withRole($role)->create($state);
        Auth::forgetGuards();
        $this->withToken($user->createToken('Synthetic test device', ['staff'], now()->addHour())->plainTextToken);

        return $user;
    }

    public function test_unauthenticated_staff_requests_are_401(): void
    {
        $user = User::factory()->withRole(StaffRole::Cashier)->create();

        $this->getJson('/api/v1/staff')->assertUnauthorized();
        $this->postJson('/api/v1/staff', [])->assertUnauthorized();
        $this->getJson('/api/v1/staff/'.$user->id)->assertUnauthorized();
        $this->patchJson('/api/v1/staff/'.$user->id, ['name' => 'New Name'])->assertUnauthorized();
        $this->postJson('/api/v1/staff/'.$user->id.'/password', ['password' => 'New-passphrase!2026', 'password_confirmation' => 'New-passphrase!2026'])->assertUnauthorized();
        $this->postJson('/api/v1/staff/'.$user->id.'/revoke-tokens', ['reason' => 'Lost device'])->assertUnauthorized();
    }

    public function test_cashier_and_manager_cannot_access_staff_endpoints(): void
    {
        $target = User::factory()->withRole(StaffRole::Cashier)->create();

        foreach ([StaffRole::Cashier, StaffRole::Manager] as $role) {
            $this->staff($role);

            $this->getJson('/api/v1/staff')->assertForbidden();
            $this->postJson('/api/v1/staff', [
                'name' => 'Test User',
                'email' => 'test@example.com',
                'role' => 'cashier',
                'password' => 'Valid-passphrase!2026',
            ])->assertForbidden();
            $this->getJson('/api/v1/staff/'.$target->id)->assertForbidden();
            $this->patchJson('/api/v1/staff/'.$target->id, ['name' => 'New Name'])->assertForbidden();
            $this->postJson('/api/v1/staff/'.$target->id.'/password', [
                'password' => 'New-passphrase!2026',
                'password_confirmation' => 'New-passphrase!2026',
            ])->assertForbidden();
            $this->postJson('/api/v1/staff/'.$target->id.'/revoke-tokens', ['reason' => 'Lost device'])->assertForbidden();
        }
    }

    public function test_admin_can_list_staff_with_search_role_and_active_filters_and_pagination(): void
    {
        $admin = $this->staff(StaffRole::Admin, ['name' => 'Alice Admin', 'email' => 'alice@example.com']);
        $cashier1 = User::factory()->withRole(StaffRole::Cashier)->create(['name' => 'Bob Cashier', 'email' => 'bob@example.com', 'is_active' => true]);
        $cashier2 = User::factory()->withRole(StaffRole::Cashier)->create(['name' => 'Charlie Cashier', 'email' => 'charlie@example.com', 'is_active' => false]);
        $manager = User::factory()->withRole(StaffRole::Manager)->create(['name' => 'Dara Manager', 'email' => 'dara@example.com', 'is_active' => true]);

        // Default pagination (ordered name ASC, id ASC)
        $response = $this->getJson('/api/v1/staff?per_page=2')->assertOk();
        $response->assertJsonPath('data.0.id', $admin->id)
            ->assertJsonPath('data.1.id', $cashier1->id)
            ->assertJsonPath('meta.total', 4)
            ->assertJsonPath('meta.per_page', 2);

        // Search by name
        $this->getJson('/api/v1/staff?search=Bob')->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.id', $cashier1->id);

        // Search by email
        $this->getJson('/api/v1/staff?search=dara@example.com')->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.id', $manager->id);

        // Filter by role
        $this->getJson('/api/v1/staff?role=cashier')->assertOk()
            ->assertJsonCount(2, 'data');

        // Filter by active status
        $this->getJson('/api/v1/staff?is_active=0')->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.id', $cashier2->id);

        $this->getJson('/api/v1/staff?is_active=1')->assertOk()
            ->assertJsonCount(3, 'data');
    }

    public function test_admin_can_view_single_staff_member_with_safe_fields(): void
    {
        $this->staff(StaffRole::Admin);
        $target = User::factory()->withRole(StaffRole::Cashier)->create([
            'name' => 'Target Cashier',
            'email' => 'target@example.com',
            'is_active' => true,
        ]);

        $response = $this->getJson('/api/v1/staff/'.$target->id)->assertOk();
        $response->assertJsonStructure([
            'data' => ['id', 'name', 'email', 'role', 'is_active', 'created_at', 'updated_at'],
        ]);
        $response->assertJsonPath('data.id', $target->id)
            ->assertJsonPath('data.name', 'Target Cashier')
            ->assertJsonPath('data.email', 'target@example.com')
            ->assertJsonPath('data.role', 'cashier')
            ->assertJsonPath('data.is_active', true);

        // Ensure sensitive secrets are never serialized
        $content = $response->getContent();
        $this->assertStringNotContainsString('password', $content);
        $this->assertStringNotContainsString('remember_token', $content);
    }

    public function test_admin_can_create_staff_member_with_audit_event(): void
    {
        $admin = $this->staff(StaffRole::Admin);

        $payload = [
            'name' => 'Sok Dara',
            'email' => 'DARA@example.com ',
            'role' => 'cashier',
            'is_active' => true,
            'password' => 'Strong-temp-passphrase!2026',
        ];

        $response = $this->postJson('/api/v1/staff', $payload)->assertCreated();
        $response->assertJsonPath('data.name', 'Sok Dara')
            ->assertJsonPath('data.email', 'dara@example.com')
            ->assertJsonPath('data.role', 'cashier')
            ->assertJsonPath('data.is_active', true);

        $userId = $response->json('data.id');
        $this->assertDatabaseHas('users', [
            'id' => $userId,
            'name' => 'Sok Dara',
            'email' => 'dara@example.com',
            'is_active' => 1,
        ]);

        $user = User::find($userId);
        $this->assertTrue(Hash::check('Strong-temp-passphrase!2026', $user->password));

        // Audit event verified
        $this->assertDatabaseHas('audit_events', [
            'actor_id' => $admin->id,
            'action' => 'staff.created',
            'subject_type' => 'user',
            'subject_id' => $userId,
        ]);
        $audit = AuditEvent::where('action', 'staff.created')->where('subject_id', $userId)->firstOrFail();
        $this->assertSame('dara@example.com', $audit->metadata['email']);
        $this->assertSame('cashier', $audit->metadata['role']);
        $this->assertTrue($audit->metadata['is_active']);
    }

    public function test_create_staff_validation_and_rejections(): void
    {
        $this->staff(StaffRole::Admin);
        User::factory()->create(['email' => 'existing@example.com']);

        // Duplicate email
        $this->postJson('/api/v1/staff', [
            'name' => 'Another User',
            'email' => 'existing@example.com',
            'role' => 'cashier',
            'password' => 'Valid-passphrase!2026',
        ])->assertUnprocessable()->assertJsonValidationErrors(['email']);

        // Short password (< 12 chars)
        $this->postJson('/api/v1/staff', [
            'name' => 'Short Pass',
            'email' => 'short@example.com',
            'role' => 'cashier',
            'password' => 'short',
        ])->assertUnprocessable()->assertJsonValidationErrors(['password']);

        // Invalid role
        $this->postJson('/api/v1/staff', [
            'name' => 'Invalid Role',
            'email' => 'role@example.com',
            'role' => 'superadmin',
            'password' => 'Valid-passphrase!2026',
        ])->assertUnprocessable()->assertJsonValidationErrors(['role']);

        // Injected fields rejected
        $this->postJson('/api/v1/staff', [
            'name' => 'Injected User',
            'email' => 'injected@example.com',
            'role' => 'cashier',
            'password' => 'Valid-passphrase!2026',
            'role_id' => 1,
            'permissions' => ['all'],
            'is_admin' => true,
        ])->assertUnprocessable();
    }

    public function test_admin_can_update_staff_and_token_revocation_rules(): void
    {
        $admin = $this->staff(StaffRole::Admin);
        $subject = User::factory()->withRole(StaffRole::Cashier)->create([
            'name' => 'Original Name',
            'email' => 'original@example.com',
            'is_active' => true,
        ]);
        $token = $subject->createToken('Subject device', ['staff'], now()->addHour());

        // 1. Name-only update preserves token
        $this->patchJson('/api/v1/staff/'.$subject->id, [
            'name' => 'Updated Name',
        ])->assertOk()->assertJsonPath('data.name', 'Updated Name');

        $this->assertDatabaseHas('personal_access_tokens', ['id' => $token->accessToken->id]);

        // 2. Email change revokes token
        $this->patchJson('/api/v1/staff/'.$subject->id, [
            'email' => 'new-email@example.com',
        ])->assertOk()->assertJsonPath('data.email', 'new-email@example.com');

        $this->assertDatabaseMissing('personal_access_tokens', ['id' => $token->accessToken->id]);

        // Create new token for subject
        $token2 = $subject->createToken('Subject device 2', ['staff'], now()->addHour());

        // 3. Role change revokes token
        $this->patchJson('/api/v1/staff/'.$subject->id, [
            'role' => 'manager',
        ])->assertOk()->assertJsonPath('data.role', 'manager');

        $this->assertDatabaseMissing('personal_access_tokens', ['id' => $token2->accessToken->id]);

        // Create token for subject
        $token3 = $subject->createToken('Subject device 3', ['staff'], now()->addHour());

        // 4. Deactivation revokes token
        $this->patchJson('/api/v1/staff/'.$subject->id, [
            'is_active' => false,
        ])->assertOk()->assertJsonPath('data.is_active', false);

        $this->assertDatabaseMissing('personal_access_tokens', ['id' => $token3->accessToken->id]);

        // 5. Reactivation succeeds without issuing token
        $this->patchJson('/api/v1/staff/'.$subject->id, [
            'is_active' => true,
        ])->assertOk()->assertJsonPath('data.is_active', true);

        $this->assertDatabaseCount('personal_access_tokens', 1); // Only admin's token
    }

    public function test_update_staff_validation_and_rejections(): void
    {
        $this->staff(StaffRole::Admin);
        $subject = User::factory()->withRole(StaffRole::Cashier)->create(['email' => 'sub@example.com']);
        User::factory()->create(['email' => 'other@example.com']);

        // Empty body rejected
        $this->patchJson('/api/v1/staff/'.$subject->id, [])->assertUnprocessable();

        // Unknown properties rejected
        $this->patchJson('/api/v1/staff/'.$subject->id, ['unknown_field' => 'value'])->assertUnprocessable();

        // Password through general update rejected
        $this->patchJson('/api/v1/staff/'.$subject->id, [
            'name' => 'Name',
            'password' => 'New-passphrase!2026',
        ])->assertUnprocessable();

        // Duplicate email
        $this->patchJson('/api/v1/staff/'.$subject->id, [
            'email' => 'other@example.com',
        ])->assertUnprocessable()->assertJsonValidationErrors(['email']);
    }

    public function test_last_operational_admin_protection(): void
    {
        $adminA = $this->staff(StaffRole::Admin, ['name' => 'Admin A']);

        // When only 1 active admin exists:
        // Demoting to cashier fails 409
        $this->patchJson('/api/v1/staff/'.$adminA->id, [
            'role' => 'cashier',
        ])->assertStatus(409)
            ->assertJsonPath('message', 'Cannot demote or deactivate the last operational administrator.');

        // Demoting to manager fails 409
        $this->patchJson('/api/v1/staff/'.$adminA->id, [
            'role' => 'manager',
        ])->assertStatus(409);

        // Deactivating fails 409
        $this->patchJson('/api/v1/staff/'.$adminA->id, [
            'is_active' => false,
        ])->assertStatus(409);

        // Still active admin
        $adminA->refresh();
        $this->assertSame('admin', $adminA->role->name);
        $this->assertTrue($adminA->is_active);

        // Add second active admin
        $adminB = User::factory()->withRole(StaffRole::Admin)->create(['name' => 'Admin B', 'is_active' => true]);

        // Deactivating Admin B succeeds (leaving Admin A as the only one)
        $this->patchJson('/api/v1/staff/'.$adminB->id, [
            'is_active' => false,
        ])->assertOk();

        $adminB->refresh();
        $this->assertFalse($adminB->is_active);

        // Now Admin A is once again the last operational admin and cannot be deactivated
        $this->patchJson('/api/v1/staff/'.$adminA->id, [
            'is_active' => false,
        ])->assertStatus(409);
    }

    public function test_admin_can_reset_staff_password(): void
    {
        $admin = $this->staff(StaffRole::Admin);
        $cashier = User::factory()->withRole(StaffRole::Cashier)->create([
            'email' => 'cashier@example.com',
            'password' => Hash::make('Old-passphrase!2026'),
        ]);
        $token = $cashier->createToken('Cashier device', ['staff'], now()->addHour());

        $this->postJson('/api/v1/staff/'.$cashier->id.'/password', [
            'password' => 'Brand-new-passphrase!2026',
            'password_confirmation' => 'Brand-new-passphrase!2026',
        ])->assertOk()
            ->assertJsonPath('message', 'Password reset successfully.');

        // All existing tokens revoked
        $this->assertDatabaseMissing('personal_access_tokens', ['id' => $token->accessToken->id]);

        // Old password fails login
        Auth::forgetGuards();
        $this->postJson('/api/v1/auth/login', [
            'email' => 'cashier@example.com',
            'password' => 'Old-passphrase!2026',
            'device_name' => 'POS',
        ])->assertUnauthorized();

        // New password succeeds login
        $this->postJson('/api/v1/auth/login', [
            'email' => 'cashier@example.com',
            'password' => 'Brand-new-passphrase!2026',
            'device_name' => 'POS',
        ])->assertOk();

        // Audit event verified with no password leak
        $audit = AuditEvent::where('action', 'staff.password_reset')->where('subject_id', $cashier->id)->firstOrFail();
        $this->assertNull($audit->metadata);
    }

    public function test_admin_can_revoke_staff_tokens(): void
    {
        $admin = $this->staff(StaffRole::Admin);
        $cashier = User::factory()->withRole(StaffRole::Cashier)->create();
        $token1 = $cashier->createToken('Device 1', ['staff'], now()->addHour());
        $token2 = $cashier->createToken('Device 2', ['staff'], now()->addHour());

        $this->postJson('/api/v1/staff/'.$cashier->id.'/revoke-tokens', [
            'reason' => 'Device reported lost at counter',
        ])->assertOk()
            ->assertJsonPath('message', 'Tokens revoked successfully.');

        // Both tokens deleted
        $this->assertDatabaseMissing('personal_access_tokens', ['id' => $token1->accessToken->id]);
        $this->assertDatabaseMissing('personal_access_tokens', ['id' => $token2->accessToken->id]);

        // Admin token still intact
        $this->assertDatabaseCount('personal_access_tokens', 1);

        // Audit event recorded
        $audit = AuditEvent::where('action', 'staff.tokens_revoked')->where('subject_id', $cashier->id)->firstOrFail();
        $this->assertSame('Device reported lost at counter', $audit->metadata['reason']);
    }
}

