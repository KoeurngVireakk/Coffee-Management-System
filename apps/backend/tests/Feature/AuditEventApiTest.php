<?php

namespace Tests\Feature;

use App\Enums\StaffRole;
use App\Models\AuditEvent;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Auth;
use LogicException;
use Tests\TestCase;

class AuditEventApiTest extends TestCase
{
    use RefreshDatabase;

    private function staff(StaffRole $role = StaffRole::Cashier): User
    {
        $user = User::factory()->withRole($role)->create();
        Auth::forgetGuards();
        $this->withToken($user->createToken('Synthetic terminal', ['staff'], now()->addHour())->plainTextToken);

        return $user;
    }

    public function test_unauthenticated_audit_requests_are_401(): void
    {
        $this->getJson('/api/v1/audit-events')->assertUnauthorized();
    }

    public function test_cashier_and_manager_cannot_read_audit_events(): void
    {
        foreach ([StaffRole::Cashier, StaffRole::Manager] as $role) {
            $this->staff($role);
            $this->getJson('/api/v1/audit-events')->assertForbidden();
        }
    }

    public function test_admin_can_read_audit_events_with_filters_and_pagination(): void
    {
        $admin = $this->staff(StaffRole::Admin);

        // Generate events via staff & settings APIs
        $this->postJson('/api/v1/staff', [
            'name' => 'Created Staff',
            'email' => 'created@example.com',
            'role' => 'cashier',
            'password' => 'Valid-passphrase!2026',
        ])->assertCreated();

        $this->putJson('/api/v1/settings/shop_name', [
            'value' => 'New Shop Name',
        ])->assertOk();

        // Admin queries audit events
        $response = $this->getJson('/api/v1/audit-events')->assertOk();
        $response->assertJsonCount(2, 'data');

        // Reverse chronological order: setting.updated (most recent) comes before staff.created
        $response->assertJsonPath('data.0.action', 'setting.updated')
            ->assertJsonPath('data.1.action', 'staff.created');

        // Filter by action
        $this->getJson('/api/v1/audit-events?action=staff.created')->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.action', 'staff.created');

        // Filter by subject_type
        $this->getJson('/api/v1/audit-events?subject_type=setting')->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.subject_type', 'setting');

        // Filter by actor_id
        $this->getJson('/api/v1/audit-events?actor_id='.$admin->id)->assertOk()
            ->assertJsonCount(2, 'data');
    }

    public function test_audit_events_are_immutable(): void
    {
        $admin = $this->staff(StaffRole::Admin);

        $event = AuditEvent::create([
            'actor_id' => $admin->id,
            'action' => 'staff.created',
            'subject_type' => 'user',
            'subject_id' => $admin->id,
            'metadata' => ['test' => true],
            'created_at' => now(),
        ]);

        $this->expectException(LogicException::class);
        $this->expectExceptionMessage('Audit events are immutable and cannot be updated.');
        $event->update(['action' => 'tampered']);
    }

    public function test_audit_events_cannot_be_deleted(): void
    {
        $admin = $this->staff(StaffRole::Admin);

        $event = AuditEvent::create([
            'actor_id' => $admin->id,
            'action' => 'staff.created',
            'subject_type' => 'user',
            'subject_id' => $admin->id,
            'metadata' => ['test' => true],
            'created_at' => now(),
        ]);

        $this->expectException(LogicException::class);
        $this->expectExceptionMessage('Audit events are immutable and cannot be deleted.');
        $event->delete();
    }
}

