<?php

namespace Tests\Feature;

use App\Enums\StaffRole;
use App\Models\Order;
use App\Models\OrderItem;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Gate;
use Tests\TestCase;

class OrderHistoryTest extends TestCase
{
    use RefreshDatabase;

    private function staff(User $user): void
    {
        Auth::forgetGuards();
        $this->withToken($user->createToken('Synthetic order history', ['staff'], now()->addHour())->plainTextToken);
    }

    public function test_cashier_history_and_detail_are_scoped_before_lookup_and_do_not_leak_other_orders(): void
    {
        $caller = User::factory()->create();
        $own = OrderItem::factory()->create(['order_id' => Order::factory()->create(['created_by' => $caller->id])->id])->order;
        $other = OrderItem::factory()->create()->order;
        $this->staff($caller);
        $this->getJson('/api/v1/orders')->assertOk()->assertJsonCount(1, 'data')->assertJsonPath('data.0.public_reference', $own->public_reference);
        $this->getJson('/api/v1/orders/'.$own->public_reference)->assertOk();
        $hidden = $this->getJson('/api/v1/orders/'.$other->public_reference)->assertNotFound()->json();
        $missing = $this->getJson('/api/v1/orders/ORD-00000000000000000000000000')->assertNotFound()->json();
        $this->assertSame($missing, $hidden);
        $this->assertFalse(Gate::forUser($caller)->allows('view', $other));
        $this->getJson('/api/v1/orders?created_by='.$other->created_by)->assertUnprocessable();
    }

    public function test_managers_and_admins_see_shop_orders(): void
    {
        $first = OrderItem::factory()->create()->order;
        OrderItem::factory()->create();
        foreach ([StaffRole::Manager, StaffRole::Admin] as $role) {
            $this->staff(User::factory()->withRole($role)->create());
            $this->getJson('/api/v1/orders')->assertOk()->assertJsonCount(2, 'data');
            $this->getJson('/api/v1/orders/'.$first->public_reference)->assertOk();
        }
    }

    public function test_history_filters_validate_absolute_time_and_order_equal_timestamps_by_id_descending(): void
    {
        $actor = User::factory()->create();
        $first = Order::factory()->create(['created_by' => $actor->id, 'created_at' => '2026-10-06 08:00:00']);
        $second = Order::factory()->create(['created_by' => $actor->id, 'created_at' => '2026-10-06 08:00:00']);
        Order::factory()->create(['created_by' => $actor->id, 'created_at' => '2026-10-06 10:00:00']);
        $this->staff($actor);
        $query = http_build_query(['created_from' => '2026-10-06T15:00:00+07:00', 'created_to' => '2026-10-06T08:00:00Z', 'status' => 'pending_payment', 'per_page' => 1]);
        $this->getJson('/api/v1/orders?'.$query)->assertOk()->assertJsonPath('meta.total', 2)->assertJsonPath('data.0.public_reference', $second->public_reference);
        $this->getJson('/api/v1/orders?'.$query.'&page=2')->assertOk()->assertJsonPath('data.0.public_reference', $first->public_reference);
        $this->getJson('/api/v1/orders?'.http_build_query(['created_from' => '2026-10-06T08:00:00.500Z', 'created_to' => '2026-10-06T10:00:00Z']))
            ->assertOk()->assertJsonPath('meta.total', 1);
        foreach (['created_from=2026-10-06', 'created_to=2026-02-30T00:00:00Z', 'created_to=2026-10-06T08:00:00', 'created_to=2026-10-06T08:00:60Z', 'created_from=2026-10-06T08:00:00%2B25:00', 'created_from=2026-10-06T08:00:00%2B01:99', 'created_from=2026-10-06T08:00:00%2B14:01', 'status=unknown', 'per_page=101', 'page=10001', 'sort=id', 'user_id=1', 'created_from[]=x'] as $invalid) {
            $this->getJson('/api/v1/orders?'.$invalid)->assertUnprocessable();
        }
        $this->getJson('/api/v1/orders?'.http_build_query(['created_from' => '2026-10-06T10:00:00Z', 'created_to' => '2026-10-06T08:00:00Z']))->assertUnprocessable();
    }

    public function test_resources_include_only_approved_snapshots_and_no_internal_replay_or_auth_data(): void
    {
        $item = OrderItem::factory()->create();
        $this->staff($item->order->creator);
        $response = $this->getJson('/api/v1/orders/'.$item->order->public_reference)->assertOk();
        $this->assertSame(['public_reference', 'status', 'currency', 'subtotal_minor', 'discount_minor', 'tax_minor', 'total_minor', 'inventory_tracked', 'created_at', 'creator', 'items'], array_keys($response->json('data')));
        $this->assertSame(['id', 'name'], array_keys($response->json('data.creator')));
        $this->assertSame(['line_number', 'product_id', 'product_name', 'product_sku', 'unit_price_minor', 'quantity', 'subtotal_minor', 'discount_minor', 'tax_minor', 'line_total_minor'], array_keys($response->json('data.items.0')));
        foreach (['subtotal_minor', 'discount_minor', 'tax_minor', 'total_minor'] as $field) {
            $this->assertIsString($response->json('data.'.$field));
        }
    }

    public function test_order_history_eager_loads_items_and_creators_without_n_plus_one(): void
    {
        OrderItem::factory()->count(20)->create();
        $this->staff(User::factory()->withRole(StaffRole::Manager)->create());
        DB::enableQueryLog();
        $counts = [];
        try {
            foreach ([1, 20] as $size) {
                Auth::forgetGuards();
                DB::flushQueryLog();
                $this->getJson('/api/v1/orders?per_page='.$size)->assertOk()->assertJsonCount($size, 'data');
                $queries = DB::getQueryLog();
                $counts[] = count(array_filter($queries, fn (array $entry) => str_starts_with($entry['query'], 'select ')));
                $this->assertLessThanOrEqual(9, count($queries));
            }
            $this->assertSame($counts[0], $counts[1]);
        } finally {
            DB::disableQueryLog();
        }
    }

    public function test_arbitrary_order_mutation_legacy_payment_refund_and_receipt_endpoints_are_absent(): void
    {
        $order = Order::factory()->create();
        $this->staff($order->creator);
        foreach (['PUT', 'PATCH', 'DELETE'] as $method) {
            $this->json($method, '/api/v1/orders/'.$order->public_reference, ['status' => 'paid'])->assertStatus(405);
        }
        foreach (['pay', 'refund', 'receipt'] as $path) {
            $this->postJson('/api/v1/orders/'.$order->public_reference.'/'.$path)->assertNotFound();
        }
        $this->assertDatabaseHas('orders', ['id' => $order->id, 'status' => 'pending_payment']);
    }

    public function test_unauthenticated_order_reads_are_denied(): void
    {
        $order = Order::factory()->create();
        $this->get('/api/v1/orders')->assertUnauthorized()->assertHeader('Content-Type', 'application/json');
        Auth::forgetGuards();
        $this->get('/api/v1/orders/'.$order->public_reference)->assertUnauthorized();
    }
}
