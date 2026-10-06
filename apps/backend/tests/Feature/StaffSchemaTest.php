<?php

namespace Tests\Feature;

use App\Enums\StaffRole;
use App\Models\AuditEvent;
use App\Models\Setting;
use App\Models\User;
use Illuminate\Database\QueryException;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class StaffSchemaTest extends TestCase
{
    use RefreshDatabase;

    public function test_setting_primary_key_and_relationships(): void
    {
        $user = User::factory()->withRole(StaffRole::Admin)->create();

        $setting = Setting::create([
            'key' => 'shop_name',
            'value' => 'Test Café',
            'updated_by' => $user->id,
        ]);

        $this->assertSame('shop_name', $setting->key);
        $this->assertSame('Test Café', $setting->value);
        $this->assertTrue($setting->updater->is($user));
        $this->assertTrue($user->updatedSettings->contains($setting));

        // Duplicate primary key fails
        $this->expectException(QueryException::class);
        Setting::create([
            'key' => 'shop_name',
            'value' => 'Duplicate Café',
            'updated_by' => $user->id,
        ]);
    }

    public function test_setting_foreign_key_restricts_user_deletion(): void
    {
        $user = User::factory()->withRole(StaffRole::Admin)->create();

        Setting::create([
            'key' => 'shop_name',
            'value' => 'Test Café',
            'updated_by' => $user->id,
        ]);

        $this->expectException(QueryException::class);
        $user->delete();
    }

    public function test_audit_event_relationships_and_restrict_on_delete(): void
    {
        $user = User::factory()->withRole(StaffRole::Admin)->create();

        $event = AuditEvent::create([
            'actor_id' => $user->id,
            'action' => 'staff.created',
            'subject_type' => 'user',
            'subject_id' => 99,
            'metadata' => ['role' => 'cashier'],
            'created_at' => now(),
        ]);

        $this->assertTrue($event->actor->is($user));
        $this->assertTrue($user->auditEvents->contains($event));

        $this->expectException(QueryException::class);
        $user->delete();
    }
}

