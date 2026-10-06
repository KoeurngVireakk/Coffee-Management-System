<?php

namespace Tests\Feature;

use App\Inventory\Quantity;
use App\Models\InventoryItem;
use App\Models\Order;
use App\Models\Product;
use App\Models\StockMovement;
use App\Models\StockReservation;
use App\Models\User;
use Illuminate\Database\QueryException;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use LogicException;
use PHPUnit\Framework\Attributes\DataProvider;
use Tests\TestCase;

class InventorySchemaTest extends TestCase
{
    use RefreshDatabase;

    public function test_inventory_initializes_zero_and_can_retire_without_losing_history(): void
    {
        $item = InventoryItem::factory()->create();
        $this->assertSame('0.0000', $item->on_hand);
        $this->assertSame('0.0000', $item->reserved);
        $item->forceFill(['is_active' => false])->save();
        $this->assertFalse($item->fresh()->is_active);
        $this->assertDatabaseHas('inventory_items', ['id' => $item->id]);
    }

    public static function integrityCases(): array
    {
        return ['SKU' => ['sku'], 'recipe pair' => ['recipe'], 'reservation pair' => ['reservation'],
            'recipe FK' => ['recipe_fk'], 'reservation FK' => ['reservation_fk'], 'movement FK' => ['movement_fk'],
            'operation identity' => ['operation'], 'actor replay across items' => ['actor_key'],
            'restrict inventory' => ['delete_inventory'], 'restrict order' => ['delete_order'],
            'restrict actor' => ['delete_actor'], 'restrict product' => ['delete_product']];
    }

    #[DataProvider('integrityCases')]
    public function test_foreign_keys_composite_keys_and_idempotency_uniqueness(string $case): void
    {
        $item = InventoryItem::factory()->create();
        $other = InventoryItem::factory()->create();
        $order = Order::factory()->create();
        $product = Product::factory()->create();
        $actor = User::factory()->create();
        $recipe = ['product_id' => $product->id, 'inventory_item_id' => $item->id, 'quantity' => '0.0001'];
        $reservation = ['order_id' => $order->id, 'inventory_item_id' => $item->id, 'quantity' => '0.0001',
            'status' => 'reserved', 'created_at' => now(), 'updated_at' => now()];
        $movement = $this->manualMovement($item, $actor);
        DB::table('product_ingredients')->insert($recipe);
        DB::table('stock_reservations')->insert($reservation);
        DB::table('stock_movements')->insert($movement);
        $this->expectException(QueryException::class);
        match ($case) {
            'sku' => InventoryItem::factory()->create(['sku' => strtolower($item->sku)]),
            'recipe' => DB::table('product_ingredients')->insert($recipe),
            'reservation' => DB::table('stock_reservations')->insert($reservation),
            'recipe_fk' => DB::table('product_ingredients')->insert(array_replace($recipe, ['inventory_item_id' => 999999])),
            'reservation_fk' => DB::table('stock_reservations')->insert(array_replace($reservation, ['order_id' => 999999])),
            'movement_fk' => DB::table('stock_movements')->insert(array_replace($movement, ['inventory_item_id' => 999999, 'operation_key' => 'other', 'attempt_key' => 'other-key'])),
            'operation' => DB::table('stock_movements')->insert(array_replace($movement, ['attempt_key' => 'other-key'])),
            'actor_key' => DB::table('stock_movements')->insert(array_replace($movement, ['inventory_item_id' => $other->id, 'operation_key' => 'other'])),
            'delete_inventory' => DB::table('inventory_items')->where('id', $item->id)->delete(),
            'delete_order' => DB::table('orders')->where('id', $order->id)->delete(),
            'delete_actor' => DB::table('users')->where('id', $actor->id)->delete(),
            'delete_product' => DB::table('products')->where('id', $product->id)->delete(),
        };
    }

    public static function checkCases(): array
    {
        return ['negative on hand' => ['inventory_items', ['on_hand' => '-0.0001']],
            'negative reserve' => ['inventory_items', ['reserved' => '-0.0001']],
            'oversold reserve' => ['inventory_items', ['reserved' => '0.0001']],
            'negative threshold' => ['inventory_items', ['reorder_level' => '-0.0001']],
            'wrong unit' => ['inventory_items', ['base_unit' => 'kg']],
            'recipe zero' => ['product_ingredients', ['quantity' => '0.0000']],
            'reservation zero' => ['stock_reservations', ['quantity' => '0.0000']],
            'reservation status' => ['stock_reservations', ['status' => 'pending']],
            'receipt negative' => ['stock_movements', ['quantity_delta' => '-1.0000']],
            'opening negative' => ['stock_movements', ['reason' => 'opening_balance', 'quantity_delta' => '-1.0000']],
            'waste positive' => ['stock_movements', ['reason' => 'waste']],
            'adjustment no note' => ['stock_movements', ['reason' => 'adjustment']],
            'zero movement' => ['stock_movements', ['quantity_delta' => '0.0000']],
            'unsupported release' => ['stock_movements', ['reason' => 'release']],
            'manual actor required' => ['stock_movements', ['actor_id' => null]],
            'manual replay key required' => ['stock_movements', ['attempt_key' => null]],
            'manual hash required' => ['stock_movements', ['request_hash' => null]],
            'manual order forbidden' => ['stock_movements', ['order_id' => 1]],
            'sale origin required' => ['stock_movements', ['reason' => 'sale', 'quantity_delta' => '-1.0000']]];
    }

    #[DataProvider('checkCases')]
    public function test_mysql_inventory_decimal_and_origin_checks(string $table, array $changes): void
    {
        if (DB::getDriverName() !== 'mysql') {
            $this->markTestSkipped('Production inventory CHECK constraints require isolated MySQL.');
        }
        $item = InventoryItem::factory()->create();
        $actor = User::factory()->create();
        $product = Product::factory()->create();
        $order = Order::factory()->create();
        DB::table('product_ingredients')->insert(['product_id' => $product->id, 'inventory_item_id' => $item->id, 'quantity' => '1.0000']);
        DB::table('stock_reservations')->insert(['order_id' => $order->id, 'inventory_item_id' => $item->id,
            'quantity' => '1.0000', 'status' => 'reserved', 'created_at' => now(), 'updated_at' => now()]);
        DB::table('stock_movements')->insert($this->manualMovement($item, $actor));
        $this->expectException(QueryException::class);
        DB::table($table)->update($changes);
    }

    public function test_mysql_physical_decimal_precision_and_exact_smallest_unit(): void
    {
        if (DB::getDriverName() !== 'mysql') {
            $this->markTestSkipped('SQLite affinity does not prove exact DECIMAL physical storage.');
        }
        $columns = DB::select("SELECT TABLE_NAME, COLUMN_NAME, DATA_TYPE, NUMERIC_PRECISION, NUMERIC_SCALE FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME IN ('inventory_items','product_ingredients','stock_reservations','stock_movements') AND DATA_TYPE='decimal'");
        $this->assertCount(6, $columns);
        foreach ($columns as $column) {
            $this->assertSame(14, (int) $column->NUMERIC_PRECISION);
            $this->assertSame(4, (int) $column->NUMERIC_SCALE);
        }
        $item = InventoryItem::factory()->create();
        DB::transaction(fn () => $item->writeBalances(Quantity::MAX_SCALED, 1));
        $this->assertSame('9999999999.9999', $item->on_hand);
        $this->assertSame('0.0001', $item->reserved);
    }

    public function test_workflow_balance_update_rejects_stale_item(): void
    {
        $item = InventoryItem::factory()->create();
        $stale = $item->fresh();
        DB::transaction(fn () => $item->writeBalances(10000, 0));
        $this->expectException(LogicException::class);
        DB::transaction(fn () => $stale->writeBalances(20000, 0));
    }

    public function test_reservation_transition_keeps_snapshot_and_cannot_transition_twice(): void
    {
        $item = InventoryItem::factory()->create();
        $reservation = new StockReservation;
        $reservation->forceFill(['order_id' => Order::factory()->create()->id, 'inventory_item_id' => $item->id,
            'quantity' => '0.0001', 'status' => 'reserved'])->save();
        DB::transaction(fn () => $reservation->transitionTo('released'));
        $this->assertSame('released', $reservation->status);
        $this->assertSame('0.0001', $reservation->quantity);
        $this->expectException(LogicException::class);
        DB::transaction(fn () => $reservation->transitionTo('consumed'));
    }

    public function test_workflow_balance_update_never_coerces_native_float(): void
    {
        $item = InventoryItem::factory()->create();
        $this->expectException(LogicException::class);
        DB::transaction(fn () => $item->writeBalances(1.5, 0));
    }

    public function test_workflow_balance_update_cannot_hide_unsaved_base_unit_mutation(): void
    {
        $item = InventoryItem::factory()->create();
        $item->forceFill(['base_unit' => 'ml']);
        $this->expectException(LogicException::class);
        DB::transaction(fn () => $item->writeBalances(10000, 0));
    }

    public static function immutableOperations(): array
    {
        return ['balance edit' => ['balance'], 'base unit edit' => ['unit'], 'item delete' => ['item_delete'],
            'ledger edit' => ['movement'], 'ledger delete' => ['movement_delete'], 'reservation edit' => ['reservation'],
            'reservation delete' => ['reservation_delete']];
    }

    #[DataProvider('immutableOperations')]
    public function test_models_deny_direct_balance_snapshot_or_history_mutation(string $case): void
    {
        $item = InventoryItem::factory()->create();
        $movement = new StockMovement;
        $movement->forceFill($this->manualMovement($item, User::factory()->create()))->save();
        $reservation = new StockReservation;
        $reservation->forceFill(['order_id' => Order::factory()->create()->id, 'inventory_item_id' => $item->id,
            'quantity' => '1.0000', 'status' => 'reserved'])->save();
        $this->expectException(LogicException::class);
        match ($case) {
            'balance' => $item->forceFill(['on_hand' => '1.0000'])->save(),
            'unit' => $item->forceFill(['base_unit' => 'ml'])->save(),
            'item_delete' => $item->delete(),
            'movement' => $movement->forceFill(['quantity_delta' => '2.0000'])->save(),
            'movement_delete' => $movement->delete(),
            'reservation' => $reservation->forceFill(['quantity' => '2.0000'])->save(),
            'reservation_delete' => $reservation->delete(),
        };
    }

    private function manualMovement(InventoryItem $item, User $actor): array
    {
        return ['inventory_item_id' => $item->id, 'order_id' => null, 'actor_id' => $actor->id,
            'quantity_delta' => '1.0000', 'reason' => 'receipt', 'operation_key' => 'manual-test',
            'attempt_key' => 'manual-test-key', 'request_hash' => str_repeat('a', 64), 'note' => null, 'created_at' => now()];
    }
}
