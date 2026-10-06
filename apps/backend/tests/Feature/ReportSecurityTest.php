<?php

namespace Tests\Feature;

use App\Enums\StaffRole;
use App\Models\AuditEvent;
use App\Models\InventoryItem;
use App\Models\Order;
use App\Models\Payment;
use App\Models\Setting;
use App\Models\User;
use App\Settings\SettingRegistry;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Auth;
use Tests\TestCase;

class ReportSecurityTest extends TestCase
{
    use RefreshDatabase;

    private function staff(StaffRole $role = StaffRole::Cashier, bool $active = true): User
    {
        $user = User::factory()->withRole($role)->create(['is_active' => $active]);
        Auth::forgetGuards();
        $this->withToken($user->createToken('Synthetic security terminal', ['staff'], now()->addHour())->plainTextToken);

        return $user;
    }

    private function configureTimezone(): void
    {
        Setting::query()->updateOrCreate(
            ['key' => SettingRegistry::SHOP_TIMEZONE],
            ['value' => 'UTC']
        );
    }

    public function test_unauthenticated_requests_are_401(): void
    {
        $endpoints = [
            '/api/v1/reports/overview',
            '/api/v1/reports/sales-trend',
            '/api/v1/reports/payment-methods',
            '/api/v1/reports/top-products',
            '/api/v1/reports/inventory',
            '/api/v1/reports/reconciliation',
        ];

        foreach ($endpoints as $uri) {
            $this->getJson($uri)->assertUnauthorized();
        }
    }

    public function test_cashier_is_forbidden_on_all_report_endpoints(): void
    {
        $this->configureTimezone();
        $this->staff(StaffRole::Cashier);

        $endpoints = [
            '/api/v1/reports/overview',
            '/api/v1/reports/sales-trend',
            '/api/v1/reports/payment-methods',
            '/api/v1/reports/top-products',
            '/api/v1/reports/inventory',
            '/api/v1/reports/reconciliation',
        ];

        foreach ($endpoints as $uri) {
            $this->getJson($uri)->assertForbidden();
        }
    }

    public function test_inactive_staff_is_forbidden_on_all_report_endpoints(): void
    {
        $this->configureTimezone();

        // Inactive Manager
        $this->staff(StaffRole::Manager, active: false);
        $this->getJson('/api/v1/reports/overview')->assertForbidden();

        // Inactive Admin
        $this->staff(StaffRole::Admin, active: false);
        $this->getJson('/api/v1/reports/overview')->assertForbidden();
    }

    public function test_manager_and_admin_are_authorized_on_all_report_endpoints(): void
    {
        $this->configureTimezone();

        $endpoints = [
            '/api/v1/reports/overview',
            '/api/v1/reports/sales-trend',
            '/api/v1/reports/payment-methods',
            '/api/v1/reports/top-products',
            '/api/v1/reports/inventory',
            '/api/v1/reports/reconciliation',
        ];

        foreach ([StaffRole::Manager, StaffRole::Admin] as $role) {
            $this->staff($role);
            foreach ($endpoints as $uri) {
                $this->getJson($uri)->assertOk();
            }
        }
    }

    public function test_date_range_validation_rejects_invalid_inputs(): void
    {
        $this->configureTimezone();
        $this->staff(StaffRole::Manager);

        $invalidQueries = [
            'from_date=2026-13-45&to_date=2026-10-05', // invalid date
            'from_date=not-a-date&to_date=2026-10-05', // not a date
            'from_date=2026-10-06&to_date=2026-10-01', // inverted range
            'from_date=2025-01-01&to_date=2026-01-05', // > 366 days
            'from_date=2026-10-01', // missing to_date
            'to_date=2026-10-05', // missing from_date
            'from_date=2026-10-01&to_date=2026-10-05&unexpected_param=malicious', // unknown param
        ];

        foreach ($invalidQueries as $query) {
            $this->getJson('/api/v1/reports/overview?'.$query)->assertUnprocessable();
            $this->getJson('/api/v1/reports/sales-trend?'.$query)->assertUnprocessable();
            $this->getJson('/api/v1/reports/payment-methods?'.$query)->assertUnprocessable();
        }
    }

    public function test_top_products_validation_rejects_invalid_limit_and_parameters(): void
    {
        $this->configureTimezone();
        $this->staff(StaffRole::Manager);

        $invalidQueries = [
            'limit=0',
            'limit=51',
            'limit=-10',
            'limit=abc',
            'unknown_field=1',
        ];

        foreach ($invalidQueries as $query) {
            $this->getJson('/api/v1/reports/top-products?'.$query)->assertUnprocessable();
        }
    }

    public function test_inventory_report_validation_rejects_invalid_status_and_parameters(): void
    {
        $this->configureTimezone();
        $this->staff(StaffRole::Manager);

        $invalidQueries = [
            'status=unknown',
            'status=deleted',
            'page=0',
            'page=-1',
            'search='.str_repeat('a', 101),
            'unknown_field=test',
        ];

        foreach ($invalidQueries as $query) {
            $this->getJson('/api/v1/reports/inventory?'.$query)->assertUnprocessable();
        }
    }

    public function test_reconciliation_report_validation_rejects_invalid_pagination(): void
    {
        $this->configureTimezone();
        $this->staff(StaffRole::Manager);

        $invalidQueries = [
            'page=0',
            'page=-1',
            'per_page=0',
            'per_page=101',
            'unknown_field=test',
        ];

        foreach ($invalidQueries as $query) {
            $this->getJson('/api/v1/reports/reconciliation?'.$query)->assertUnprocessable();
        }
    }

    public function test_mutation_verbs_are_disallowed_on_report_endpoints(): void
    {
        $this->configureTimezone();
        $this->staff(StaffRole::Admin);

        $endpoints = [
            '/api/v1/reports/overview',
            '/api/v1/reports/sales-trend',
            '/api/v1/reports/payment-methods',
            '/api/v1/reports/top-products',
            '/api/v1/reports/inventory',
            '/api/v1/reports/reconciliation',
        ];

        foreach ($endpoints as $uri) {
            $this->postJson($uri, [])->assertStatus(405);
            $this->putJson($uri, [])->assertStatus(405);
            $this->patchJson($uri, [])->assertStatus(405);
            $this->deleteJson($uri)->assertStatus(405);
        }
    }

    public function test_report_endpoints_are_strictly_read_only_and_never_mutate_state(): void
    {
        $this->configureTimezone();
        $this->staff(StaffRole::Admin);

        $countsBefore = [
            'users' => User::query()->count(),
            'orders' => Order::query()->count(),
            'payments' => Payment::query()->count(),
            'inventory_items' => InventoryItem::query()->count(),
            'settings' => Setting::query()->count(),
            'audit_events' => AuditEvent::query()->count(),
        ];

        $endpoints = [
            '/api/v1/reports/overview',
            '/api/v1/reports/sales-trend',
            '/api/v1/reports/payment-methods',
            '/api/v1/reports/top-products',
            '/api/v1/reports/inventory',
            '/api/v1/reports/reconciliation',
        ];

        foreach ($endpoints as $uri) {
            $this->getJson($uri)->assertOk();
        }

        $countsAfter = [
            'users' => User::query()->count(),
            'orders' => Order::query()->count(),
            'payments' => Payment::query()->count(),
            'inventory_items' => InventoryItem::query()->count(),
            'settings' => Setting::query()->count(),
            'audit_events' => AuditEvent::query()->count(),
        ];

        $this->assertSame($countsBefore, $countsAfter);
    }
}
