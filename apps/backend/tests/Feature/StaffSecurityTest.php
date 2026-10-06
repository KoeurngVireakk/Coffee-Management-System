<?php

namespace Tests\Feature;

use App\Enums\StaffRole;
use App\Models\AuditEvent;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Auth;
use Tests\TestCase;

class StaffSecurityTest extends TestCase
{
    use RefreshDatabase;

    private function staff(StaffRole $role = StaffRole::Cashier): User
    {
        $user = User::factory()->withRole($role)->create();
        Auth::forgetGuards();
        $this->withToken($user->createToken('Synthetic security terminal', ['staff'], now()->addHour())->plainTextToken);

        return $user;
    }

    public function test_manager_cannot_escalate_privilege_or_administer_staff(): void
    {
        $manager = $this->staff(StaffRole::Manager);
        $cashier = User::factory()->withRole(StaffRole::Cashier)->create();

        // Manager cannot create staff with admin role
        $this->postJson('/api/v1/staff', [
            'name' => 'Escalated Admin',
            'email' => 'escalated@example.com',
            'role' => 'admin',
            'password' => 'Valid-passphrase!2026',
        ])->assertForbidden();

        // Manager cannot promote cashier to admin
        $this->patchJson('/api/v1/staff/'.$cashier->id, [
            'role' => 'admin',
        ])->assertForbidden();

        // Manager cannot promote themselves to admin
        $this->patchJson('/api/v1/staff/'.$manager->id, [
            'role' => 'admin',
        ])->assertForbidden();
    }

    public function test_cashier_cannot_self_escalate_or_alter_status(): void
    {
        $cashier = $this->staff(StaffRole::Cashier);

        // Cashier cannot update own role or activation
        $this->patchJson('/api/v1/staff/'.$cashier->id, [
            'role' => 'admin',
        ])->assertForbidden();

        $this->patchJson('/api/v1/staff/'.$cashier->id, [
            'is_active' => true,
        ])->assertForbidden();
    }

    public function test_unknown_role_is_rejected(): void
    {
        $this->staff(StaffRole::Admin);

        $this->postJson('/api/v1/staff', [
            'name' => 'Bad Role',
            'email' => 'badrole@example.com',
            'role' => 'super_admin',
            'password' => 'Valid-passphrase!2026',
        ])->assertUnprocessable()->assertJsonValidationErrors(['role']);
    }

    public function test_direct_role_id_and_permission_array_injections_are_rejected(): void
    {
        $this->staff(StaffRole::Admin);
        $subject = User::factory()->withRole(StaffRole::Cashier)->create();

        // On creation
        $this->postJson('/api/v1/staff', [
            'name' => 'Injected User',
            'email' => 'injected@example.com',
            'role' => 'cashier',
            'role_id' => 1,
            'password' => 'Valid-passphrase!2026',
        ])->assertUnprocessable();

        $this->postJson('/api/v1/staff', [
            'name' => 'Injected User 2',
            'email' => 'injected2@example.com',
            'role' => 'cashier',
            'permissions' => ['manage-staff'],
            'password' => 'Valid-passphrase!2026',
        ])->assertUnprocessable();

        // On update
        $this->patchJson('/api/v1/staff/'.$subject->id, [
            'role_id' => 1,
        ])->assertUnprocessable();

        $this->patchJson('/api/v1/staff/'.$subject->id, [
            'permissions' => ['manage-staff'],
        ])->assertUnprocessable();
    }

    public function test_password_field_in_general_patch_is_rejected(): void
    {
        $this->staff(StaffRole::Admin);
        $subject = User::factory()->withRole(StaffRole::Cashier)->create();

        $this->patchJson('/api/v1/staff/'.$subject->id, [
            'name' => 'Updated Name',
            'password' => 'Attempted-passphrase!2026',
        ])->assertUnprocessable();
    }

    public function test_bola_protection_non_admin_cannot_access_other_staff(): void
    {
        $cashier = $this->staff(StaffRole::Cashier);
        $otherCashier = User::factory()->withRole(StaffRole::Cashier)->create();
        $admin = User::factory()->withRole(StaffRole::Admin)->create();

        $this->getJson('/api/v1/staff/'.$otherCashier->id)->assertForbidden();
        $this->getJson('/api/v1/staff/'.$admin->id)->assertForbidden();
    }

    public function test_token_and_password_secrets_never_serialized(): void
    {
        $admin = $this->staff(StaffRole::Admin);
        $cashier = User::factory()->withRole(StaffRole::Cashier)->create();
        $token = $cashier->createToken('Test token', ['staff']);

        // Check staff index
        $indexRes = $this->getJson('/api/v1/staff')->assertOk();
        $this->assertStringNotContainsString($token->plainTextToken, $indexRes->getContent());
        $this->assertStringNotContainsString('password', $indexRes->getContent());

        // Check staff detail
        $detailRes = $this->getJson('/api/v1/staff/'.$cashier->id)->assertOk();
        $this->assertStringNotContainsString('remember_token', $detailRes->getContent());
        $this->assertStringNotContainsString('password', $detailRes->getContent());
    }

    public function test_audit_events_cannot_be_mutated_or_forged_via_http(): void
    {
        $this->staff(StaffRole::Admin);
        $event = AuditEvent::create([
            'action' => 'staff.created',
            'subject_type' => 'user',
            'created_at' => now(),
        ]);

        $this->postJson('/api/v1/audit-events', ['action' => 'forged'])->assertStatus(405);
        $this->putJson('/api/v1/audit-events/'.$event->id, ['action' => 'tampered'])->assertNotFound();
        $this->patchJson('/api/v1/audit-events/'.$event->id, ['action' => 'tampered'])->assertNotFound();
        $this->deleteJson('/api/v1/audit-events/'.$event->id)->assertNotFound();
    }

    public function test_secret_setting_tampering_is_prevented(): void
    {
        $this->staff(StaffRole::Admin);

        foreach (['APP_KEY', 'DB_PASSWORD', 'DB_USERNAME', 'INVENTORY_TRACKING_ENABLED', 'SECRET_KEY'] as $secretKey) {
            $this->putJson('/api/v1/settings/'.$secretKey, ['value' => 'compromised'])->assertNotFound();
            $this->getJson('/api/v1/settings/'.$secretKey)->assertNotFound();
        }
    }
}
