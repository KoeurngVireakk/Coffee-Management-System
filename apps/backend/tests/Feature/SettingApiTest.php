<?php

namespace Tests\Feature;

use App\Enums\StaffRole;
use App\Models\AuditEvent;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Auth;
use Tests\TestCase;

class SettingApiTest extends TestCase
{
    use RefreshDatabase;

    private function staff(StaffRole $role = StaffRole::Cashier): User
    {
        $user = User::factory()->withRole($role)->create();
        Auth::forgetGuards();
        $this->withToken($user->createToken('Synthetic terminal', ['staff'], now()->addHour())->plainTextToken);

        return $user;
    }

    public function test_unauthenticated_settings_requests_are_401(): void
    {
        $this->getJson('/api/v1/settings')->assertUnauthorized();
        $this->getJson('/api/v1/settings/shop_name')->assertUnauthorized();
        $this->putJson('/api/v1/settings/shop_name', ['value' => 'New Name'])->assertUnauthorized();
    }

    public function test_cashier_is_denied_all_settings_endpoints(): void
    {
        $this->staff(StaffRole::Cashier);

        $this->getJson('/api/v1/settings')->assertForbidden();
        $this->getJson('/api/v1/settings/shop_name')->assertForbidden();
        $this->putJson('/api/v1/settings/shop_name', ['value' => 'New Name'])->assertForbidden();
    }

    public function test_manager_can_read_settings_but_cannot_update(): void
    {
        $this->staff(StaffRole::Manager);

        $this->getJson('/api/v1/settings')->assertOk()
            ->assertJsonPath('data.0.key', 'shop_name')
            ->assertJsonPath('data.1.key', 'shop_timezone');

        $this->getJson('/api/v1/settings/shop_name')->assertOk()
            ->assertJsonPath('data.key', 'shop_name')
            ->assertJsonPath('data.value', null);

        $this->putJson('/api/v1/settings/shop_name', ['value' => 'New Name'])->assertForbidden();
    }

    public function test_admin_can_read_and_update_settings_with_audit(): void
    {
        $admin = $this->staff(StaffRole::Admin);

        // Initially absent settings return with null value
        $this->getJson('/api/v1/settings')->assertOk()
            ->assertJsonCount(2, 'data');

        // Update shop_name
        $response = $this->putJson('/api/v1/settings/shop_name', [
            'value' => '  Artisan Coffee Roasters  ',
        ])->assertOk();

        $response->assertJsonPath('data.key', 'shop_name')
            ->assertJsonPath('data.value', 'Artisan Coffee Roasters')
            ->assertJsonPath('data.updated_by.id', $admin->id);

        $this->assertDatabaseHas('settings', [
            'key' => 'shop_name',
            'updated_by' => $admin->id,
        ]);

        // Audit event recorded
        $audit = AuditEvent::where('action', 'setting.updated')->where('metadata->key', 'shop_name')->firstOrFail();
        $this->assertSame($admin->id, $audit->actor_id);
        $this->assertNull($audit->metadata['from']);
        $this->assertSame('Artisan Coffee Roasters', $audit->metadata['to']);

        // Update shop_timezone
        $this->putJson('/api/v1/settings/shop_timezone', [
            'value' => 'Asia/Phnom_Penh',
        ])->assertOk()
            ->assertJsonPath('data.key', 'shop_timezone')
            ->assertJsonPath('data.value', 'Asia/Phnom_Penh');

        $auditTz = AuditEvent::where('action', 'setting.updated')->where('metadata->key', 'shop_timezone')->firstOrFail();
        $this->assertSame('Asia/Phnom_Penh', $auditTz->metadata['to']);
    }

    public function test_settings_validation_and_rejection_of_unallowed_keys(): void
    {
        $this->staff(StaffRole::Admin);

        // Empty shop name
        $this->putJson('/api/v1/settings/shop_name', ['value' => '   '])->assertUnprocessable();

        // Too long shop name
        $this->putJson('/api/v1/settings/shop_name', ['value' => str_repeat('a', 121)])->assertUnprocessable();

        // Invalid timezone
        $this->putJson('/api/v1/settings/shop_timezone', ['value' => 'Mars/Olympus_Mons'])->assertUnprocessable();

        // Unknown key
        $this->getJson('/api/v1/settings/unknown_setting')->assertNotFound();
        $this->putJson('/api/v1/settings/unknown_setting', ['value' => 'something'])->assertNotFound();

        // Secret key injection forbidden
        $this->putJson('/api/v1/settings/APP_KEY', ['value' => 'secret'])->assertNotFound();
        $this->putJson('/api/v1/settings/DB_PASSWORD', ['value' => 'secret'])->assertNotFound();
        $this->putJson('/api/v1/settings/INVENTORY_TRACKING_ENABLED', ['value' => true])->assertNotFound();
    }
}
