<?php

namespace Tests\Feature;

use App\Enums\OrderStatus;
use App\Models\Order;
use App\Models\OrderItem;
use Illuminate\Database\QueryException;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use LogicException;
use PHPUnit\Framework\Attributes\DataProvider;
use Tests\TestCase;

class OrderSchemaTest extends TestCase
{
    use RefreshDatabase;

    public function test_order_relations_defaults_snapshots_and_indexes(): void
    {
        $item = OrderItem::factory()->create();
        $order = $item->order;
        $this->assertSame(OrderStatus::PendingPayment, $order->status);
        $this->assertFalse($order->inventory_tracked);
        $this->assertTrue($order->items->sole()->is($item));
        $this->assertNotNull($order->creator);
        $this->assertSame('Synthetic historical coffee', $item->product_name);
        $this->assertNotSame($item->product->name, $item->product_name);
        $columns = array_column(Schema::getIndexes('orders'), 'columns');
        foreach ([['created_by', 'checkout_key'], ['created_by', 'created_at', 'id'], ['created_at', 'id'], ['status', 'created_at', 'id']] as $index) {
            $this->assertContains($index, $columns);
        }
        $this->assertArrayNotHasKey('request_hash', $order->toArray());
        $this->assertArrayNotHasKey('checkout_key', $order->toArray());
    }

    public static function constraints(): array
    {
        return ['reference unique' => ['reference'], 'actor key unique' => ['key'], 'creator FK' => ['creator'],
            'product FK' => ['product'], 'order FK' => ['order'], 'line unique' => ['line'],
            'product per order unique' => ['item-product'], 'creator delete restricted' => ['creator-delete'],
            'product delete restricted' => ['product-delete'], 'order delete restricted' => ['order-delete']];
    }

    #[DataProvider('constraints')]
    public function test_history_foreign_keys_and_uniqueness(string $case): void
    {
        $item = OrderItem::factory()->create();
        $order = $item->order;
        $this->expectException(QueryException::class);
        match ($case) {
            'reference' => Order::factory()->create(['public_reference' => $order->public_reference]),
            'key' => Order::factory()->create(['created_by' => $order->created_by, 'checkout_key' => $order->checkout_key]),
            'creator' => Order::factory()->create(['created_by' => 999999]),
            'product' => OrderItem::factory()->create(['product_id' => 999999]),
            'order' => OrderItem::factory()->create(['order_id' => 999999]),
            'line' => OrderItem::factory()->create(['order_id' => $order->id]),
            'item-product' => OrderItem::factory()->create(['order_id' => $order->id, 'product_id' => $item->product_id, 'line_number' => 2]),
            'creator-delete' => $order->creator->delete(),
            'product-delete' => $item->product->delete(),
            'order-delete' => DB::table('orders')->where('id', $order->id)->delete(),
        };
    }

    public function test_same_checkout_key_is_allowed_for_separate_actors_and_is_case_sensitive(): void
    {
        $first = Order::factory()->create(['checkout_key' => 'CASE-key-01']);
        Order::factory()->create(['checkout_key' => 'CASE-key-01']);
        Order::factory()->create(['created_by' => $first->created_by, 'checkout_key' => 'case-key-01']);
        $this->assertDatabaseCount('orders', 3);
    }

    public function test_snapshots_cannot_be_updated_through_models(): void
    {
        $item = OrderItem::factory()->create();
        $this->expectException(LogicException::class);
        $item->forceFill(['unit_price_minor' => 1])->save();
    }

    public function test_order_history_cannot_be_deleted_through_models(): void
    {
        $order = Order::factory()->create();
        $this->expectException(LogicException::class);
        $order->delete();
    }

    public function test_mysql_session_and_physical_timestamp_epoch_are_utc(): void
    {
        if (DB::getDriverName() !== 'mysql') {
            $this->markTestSkipped('Session timezone/physical TIMESTAMP conversion is a MySQL invariant.');
        }
        $this->assertSame('+00:00', DB::selectOne('SELECT @@session.time_zone AS timezone')->timezone);
        $order = Order::factory()->create(['created_at' => '2026-10-06 08:00:00']);
        $epoch = DB::selectOne('SELECT UNIX_TIMESTAMP(created_at) AS epoch FROM orders WHERE id = ?', [$order->id])->epoch;
        $this->assertSame((new \DateTimeImmutable('2026-10-06T08:00:00Z'))->getTimestamp(), (int) $epoch);
    }

    public static function moneyChecks(): array
    {
        return ['negative order' => ['orders', ['subtotal_minor' => -1, 'total_minor' => -1]],
            'excessive order' => ['orders', ['subtotal_minor' => 4949995051, 'total_minor' => 4949995051]],
            'order arithmetic' => ['orders', ['total_minor' => 326]], 'order tax' => ['orders', ['tax_minor' => 1]],
            'order discount' => ['orders', ['discount_minor' => 1]], 'currency' => ['orders', ['currency' => 'usd']],
            'invalid status' => ['orders', ['status' => 'unknown']], 'quantity' => ['order_items', ['quantity' => 100]],
            'line number' => ['order_items', ['line_number' => 0]], 'item arithmetic' => ['order_items', ['line_total_minor' => 326]],
            'unit price' => ['order_items', ['unit_price_minor' => -1]]];
    }

    #[DataProvider('moneyChecks')]
    public function test_mysql_enforces_exact_money_lifecycle_and_quantity_checks(string $table, array $state): void
    {
        if (DB::getDriverName() !== 'mysql') {
            $this->markTestSkipped('Production CHECKs require isolated MySQL.');
        }
        $item = OrderItem::factory()->create();
        $this->expectException(QueryException::class);
        DB::table($table)->where('id', $table === 'orders' ? $item->order_id : $item->id)->update($state);
    }
}
