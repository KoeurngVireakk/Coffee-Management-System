<?php

namespace Tests\Feature;

use App\Enums\StaffRole;
use App\Models\InventoryItem;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Auth;
use PHPUnit\Framework\Attributes\DataProvider;
use Tests\TestCase;

class InventoryApiTest extends TestCase
{
    use RefreshDatabase;

    private function staff(StaffRole $role = StaffRole::Manager): User
    {
        $user = User::factory()->withRole($role)->create();
        Auth::forgetGuards();
        $this->withToken($user->createToken('Synthetic inventory terminal', ['staff'], now()->addHour())->plainTextToken);

        return $user;
    }

    public function test_authentication_and_role_boundaries(): void
    {
        $item = InventoryItem::factory()->create();
        $this->getJson('/api/v1/inventory/items')->assertUnauthorized();
        $this->staff(StaffRole::Cashier);
        $this->getJson('/api/v1/inventory/items')->assertOk();
        $this->getJson('/api/v1/inventory/items/'.$item->id)->assertOk();
        $this->postJson('/api/v1/inventory/items', ['sku' => 'NEW', 'name' => 'Beans', 'base_unit' => 'g'])->assertForbidden();
        $this->patchJson('/api/v1/inventory/items/'.$item->id, ['name' => 'Injected'])->assertForbidden();
        $this->getJson('/api/v1/inventory/items/'.$item->id.'/movements')->assertForbidden();
        $this->postJson('/api/v1/inventory/items/'.$item->id.'/movements', ['reason' => 'receipt', 'quantity_delta' => '10'])->assertForbidden();
        $user = $this->staff(StaffRole::Admin);
        $user->forceFill(['is_active' => false])->save();
        Auth::forgetGuards();
        $this->getJson('/api/v1/inventory/items')->assertForbidden();
    }

    public function test_management_creates_zero_stock_edits_metadata_and_retires_without_deleting(): void
    {
        foreach ([StaffRole::Manager, StaffRole::Admin] as $role) {
            $this->staff($role);
            $data = $this->postJson('/api/v1/inventory/items', ['sku' => 'stock-'.$role->value, 'name' => 'Beans', 'base_unit' => 'g', 'reorder_level' => '2.5'])
                ->assertCreated()->assertJsonPath('data.sku', 'STOCK-'.strtoupper($role->value))
                ->assertJsonPath('data.on_hand', '0.0000')->assertJsonPath('data.reserved', '0.0000')
                ->assertJsonPath('data.available', '0.0000')->assertJsonPath('data.reorder_level', '2.5000')
                ->assertJsonPath('data.low_stock', true)->json('data');
            $this->assertSame(['id', 'sku', 'name', 'base_unit', 'on_hand', 'reserved', 'available', 'reorder_level', 'is_active', 'low_stock', 'created_at', 'updated_at'], array_keys($data));
            $this->patchJson('/api/v1/inventory/items/'.$data['id'], ['name' => 'Retired beans', 'is_active' => false])->assertOk()->assertJsonPath('data.is_active', false);
            $this->getJson('/api/v1/inventory/items?status=inactive')->assertOk();
            $this->deleteJson('/api/v1/inventory/items/'.$data['id'])->assertStatus(405);
        }
        $this->assertDatabaseCount('stock_movements', 0);
        $this->assertDatabaseCount('inventory_items', 2);
    }

    public static function invalidMetadata(): array
    {
        return [
            'balances' => [['on_hand' => '100', 'reserved' => '0', 'available' => '100']],
            'actor' => [['actor_id' => 1, 'operation_key' => 'fake']],
            'float' => [['reorder_level' => 1.5]],
            'integer' => [['reorder_level' => 1]],
            'precision' => [['reorder_level' => '0.00001']],
            'leading zero' => [['reorder_level' => '01']],
            'exponent' => [['reorder_level' => '1e2']],
            'negative' => [['reorder_level' => '-1']],
            'overflow' => [['reorder_level' => '10000000000']],
            'flag' => [['is_active' => 1]],
        ];
    }

    #[DataProvider('invalidMetadata')]
    public function test_injected_stock_and_malformed_metadata_are_rejected(array $fields): void
    {
        $this->staff();
        $item = InventoryItem::factory()->create();
        $this->postJson('/api/v1/inventory/items', [...['sku' => 'NEW', 'name' => 'Milk', 'base_unit' => 'ml'], ...$fields])->assertUnprocessable();
        $this->patchJson('/api/v1/inventory/items/'.$item->id, $fields)->assertUnprocessable();
        $this->assertSame('0.0000', $item->fresh()->on_hand);
        $this->assertDatabaseCount('inventory_items', 1);
    }

    public function test_base_unit_is_immutable_and_missing_fields_duplicate_sku_empty_update_are_rejected(): void
    {
        $this->staff();
        $item = InventoryItem::factory()->create(['sku' => 'EXISTING']);
        $this->patchJson('/api/v1/inventory/items/'.$item->id, ['base_unit' => 'ml'])->assertUnprocessable();
        $this->patchJson('/api/v1/inventory/items/'.$item->id, [])->assertUnprocessable();
        $this->postJson('/api/v1/inventory/items', [])->assertUnprocessable()->assertJsonValidationErrors(['sku', 'name', 'base_unit']);
        $this->postJson('/api/v1/inventory/items', ['sku' => 'existing', 'name' => 'Duplicate', 'base_unit' => 'unit'])->assertUnprocessable()->assertJsonValidationErrors(['sku']);
        $this->postJson('/api/v1/inventory/items', ['sku' => 'WRONG-UNIT', 'name' => 'Beans', 'base_unit' => 'kg'])->assertUnprocessable();
        $this->getJson('/api/v1/inventory/items/999999')->assertNotFound();
    }

    public function test_browse_is_bounded_literal_deterministic_and_filters_available_low_stock(): void
    {
        $first = InventoryItem::factory()->create(['name' => '50% Beans', 'reorder_level' => '1']);
        InventoryItem::factory()->create(['name' => '50x Beans', 'is_active' => false]);
        InventoryItem::factory()->create(['name' => 'Zulu', 'on_hand' => '10', 'reserved' => '2', 'reorder_level' => '5']);
        $this->staff(StaffRole::Cashier);
        $this->getJson('/api/v1/inventory/items?search=50%25&status=all')->assertOk()->assertJsonCount(1, 'data')->assertJsonPath('data.0.id', $first->id);
        $this->getJson('/api/v1/inventory/items?low_stock=1')->assertOk()->assertJsonCount(1, 'data')->assertJsonPath('data.0.id', $first->id);
        $this->getJson('/api/v1/inventory/items?low_stock=0')->assertOk()->assertJsonPath('data.0.available', '8.0000');
        $this->getJson('/api/v1/inventory/items?status=all&per_page=1')->assertOk()->assertJsonPath('meta.total', 3)->assertJsonPath('data.0.id', $first->id);
        foreach (['per_page=101', 'page=10001', 'status=unknown', 'low_stock=true', 'sort=on_hand', 'search='.str_repeat('a', 81)] as $query) {
            $this->getJson('/api/v1/inventory/items?'.$query)->assertUnprocessable();
        }
    }
}
