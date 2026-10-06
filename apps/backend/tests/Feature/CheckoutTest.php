<?php

namespace Tests\Feature;

use App\Enums\StaffRole;
use App\Models\Category;
use App\Models\Order;
use App\Models\OrderItem;
use App\Models\Product;
use App\Models\Role;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Event;
use Illuminate\Support\Str;
use PHPUnit\Framework\Attributes\DataProvider;
use RuntimeException;
use Tests\TestCase;

class CheckoutTest extends TestCase
{
    use RefreshDatabase;

    private function staff(StaffRole $role = StaffRole::Cashier, array $state = []): User
    {
        $user = User::factory()->withRole($role)->create($state);
        Auth::forgetGuards();
        $this->withToken($user->createToken('Synthetic checkout terminal', ['staff'], now()->addHour())->plainTextToken);
        $this->withHeader('Idempotency-Key', (string) Str::uuid());

        return $user;
    }

    private function cart(Product $product, int $quantity = 1): array
    {
        return ['items' => [['product_id' => $product->id, 'quantity' => $quantity]]];
    }

    public function test_every_staff_role_creates_pending_untracked_orders_with_exact_snapshots(): void
    {
        $product = Product::factory()->create(['name' => 'Coffee', 'sku' => 'COFFEE-01', 'price_minor' => 325]);
        foreach (StaffRole::cases() as $role) {
            $user = $this->staff($role);
            $response = $this->postJson('/api/v1/orders', $this->cart($product, 2))->assertCreated()
                ->assertJsonPath('data.status', 'pending_payment')->assertJsonPath('data.currency', 'USD')
                ->assertJsonPath('data.total_minor', '650')->assertJsonPath('data.subtotal_minor', '650')
                ->assertJsonPath('data.tax_minor', '0')->assertJsonPath('data.discount_minor', '0')
                ->assertJsonPath('data.inventory_tracked', false)->assertJsonPath('data.creator.id', $user->id)
                ->assertJsonPath('data.items.0.unit_price_minor', '325')->assertJsonPath('data.items.0.quantity', 2)
                ->assertJsonPath('data.items.0.product_name', 'Coffee')->assertJsonPath('data.items.0.product_sku', 'COFFEE-01');
            $this->assertMatchesRegularExpression('/^ORD-[0-9A-HJKMNP-TV-Z]{26}$/', $response->json('data.public_reference'));
            $this->assertDatabaseHas('orders', ['public_reference' => $response->json('data.public_reference'), 'created_by' => $user->id, 'total_minor' => 650]);
        }
        $this->assertDatabaseCount('orders', 3);
        $this->assertDatabaseCount('order_items', 3);
    }

    public function test_multiple_lines_use_only_authoritative_prices_and_zero_price_is_valid(): void
    {
        $first = Product::factory()->create(['price_minor' => 325]);
        $second = Product::factory()->create(['price_minor' => 199]);
        $free = Product::factory()->create(['price_minor' => 0]);
        $this->staff();
        $this->postJson('/api/v1/orders', ['items' => [['product_id' => $second->id, 'quantity' => 3], ['product_id' => $free->id, 'quantity' => 1], ['product_id' => $first->id, 'quantity' => 2]]])
            ->assertCreated()->assertJsonPath('data.total_minor', '1247')->assertJsonCount(3, 'data.items')
            ->assertJsonPath('data.items.0.line_total_minor', '650')->assertJsonPath('data.items.1.line_total_minor', '597');
    }

    public function test_maximum_cart_stays_exact_above_32_bit_and_uses_no_float(): void
    {
        $category = Category::factory()->create();
        $products = Product::factory()->count(50)->create(['category_id' => $category->id, 'price_minor' => Product::MAX_PRICE_MINOR]);
        $this->staff();
        $cart = ['items' => $products->map(fn (Product $product) => ['product_id' => $product->id, 'quantity' => 99])->all()];
        $this->postJson('/api/v1/orders', $cart)->assertCreated()->assertJsonPath('data.total_minor', '4949995050');
        $this->assertSame(Order::MAX_SUBTOTAL_MINOR, Order::query()->sole()->subtotal_minor);
    }

    public function test_same_intent_reordered_under_same_actor_key_replays_original_after_catalog_changes(): void
    {
        $first = Product::factory()->create(['price_minor' => 325, 'name' => 'Original coffee']);
        $second = Product::factory()->create(['price_minor' => 200]);
        $this->staff();
        $cart = ['items' => [['product_id' => $first->id, 'quantity' => 2], ['product_id' => $second->id, 'quantity' => 1]]];
        $initial = $this->postJson('/api/v1/orders', $cart, ['Idempotency-Key' => 'checkout-replay-001'])->assertCreated()->json();
        $first->update(['name' => 'Renamed coffee', 'price_minor' => 700, 'is_active' => false]);
        $first->category->update(['is_active' => false]);
        $cart['items'] = array_reverse($cart['items']);
        $this->postJson('/api/v1/orders', $cart, ['Idempotency-Key' => 'checkout-replay-001'])->assertOk()->assertExactJson($initial);
        $this->assertDatabaseCount('orders', 1);
        $this->assertDatabaseCount('order_items', 2);
    }

    public function test_same_key_with_changed_cart_conflicts_without_mutating_existing_order(): void
    {
        $product = Product::factory()->create();
        $this->staff();
        $this->postJson('/api/v1/orders', $this->cart($product), ['Idempotency-Key' => 'checkout-conflict-001'])->assertCreated();
        $before = Order::query()->sole()->getAttributes();
        $this->postJson('/api/v1/orders', $this->cart($product, 2), ['Idempotency-Key' => 'checkout-conflict-001'])->assertConflict();
        $this->assertSame($before, Order::query()->sole()->getAttributes());
        $this->assertDatabaseCount('order_items', 1);
    }

    public function test_key_is_scoped_to_actor_and_new_checkout_uses_latest_price_without_rewriting_history(): void
    {
        $product = Product::factory()->create(['price_minor' => 325]);
        $this->staff();
        $initial = $this->postJson('/api/v1/orders', $this->cart($product), ['Idempotency-Key' => 'shared-actor-key'])->assertCreated()->json('data.public_reference');
        $product->update(['price_minor' => 450, 'name' => 'Changed', 'sku' => 'CHANGED']);
        $this->postJson('/api/v1/orders', $this->cart($product), ['Idempotency-Key' => 'new-checkout-key'])->assertCreated()->assertJsonPath('data.total_minor', '450');
        $this->staff();
        $this->postJson('/api/v1/orders', $this->cart($product), ['Idempotency-Key' => 'shared-actor-key'])->assertCreated();
        $old = Order::query()->where('public_reference', $initial)->with('items')->first();
        $this->assertSame(325, $old->subtotal_minor);
        $this->assertSame(325, $old->items->sole()->unit_price_minor);
        $this->assertNotSame('Changed', $old->items->sole()->product_name);
        $this->assertDatabaseCount('orders', 3);
    }

    public static function invalidCarts(): array
    {
        return ['missing items' => [[]], 'empty' => [['items' => []]], 'not array' => [['items' => 'invalid']],
            'too many' => [['items' => array_fill(0, 51, ['product_id' => 1, 'quantity' => 1])]],
            'duplicate' => [['items' => [['product_id' => 1, 'quantity' => 1], ['product_id' => 1, 'quantity' => 2]]]],
            'zero' => [['items' => [['product_id' => 1, 'quantity' => 0]]]], 'negative' => [['items' => [['product_id' => 1, 'quantity' => -1]]]],
            'excessive quantity' => [['items' => [['product_id' => 1, 'quantity' => 100]]]],
            'fractional quantity' => [['items' => [['product_id' => 1, 'quantity' => 1.5]]]],
            'boolean quantity' => [['items' => [['product_id' => 1, 'quantity' => true]]]],
            'string quantity' => [['items' => [['product_id' => 1, 'quantity' => '2']]]],
            'malformed ID' => [['items' => [['product_id' => '1suffix', 'quantity' => 1]]]],
            'string ID' => [['items' => [['product_id' => '1', 'quantity' => 1]]]],
            'zero ID' => [['items' => [['product_id' => 0, 'quantity' => 1]]]],
            'missing quantity' => [['items' => [['product_id' => 1]]]],
            'scalar line' => [['items' => ['invalid']]],
            'price/owner/status injection' => [['items' => [['product_id' => 1, 'quantity' => 1]], 'price_minor' => '0', 'subtotal_minor' => '0', 'total_minor' => '0', 'discount_minor' => '0', 'tax_minor' => '0', 'created_by' => 99, 'status' => 'paid', 'currency' => 'KHR', 'inventory_tracked' => true, 'role' => 'admin', 'paid' => true, 'checkout_key' => 'body-key']],
            'nested snapshot injection' => [['items' => [['product_id' => 1, 'quantity' => 1, 'product_name' => 'Forged', 'product_sku' => 'FAKE', 'unit_price_minor' => 0, 'size' => 'large']]]]];
    }

    #[DataProvider('invalidCarts')]
    public function test_invalid_or_injected_cart_is_rejected_before_order_writes(array $body): void
    {
        $this->staff();
        $this->postJson('/api/v1/orders', $body)->assertUnprocessable()->assertJsonStructure(['message', 'errors']);
        $this->assertDatabaseCount('orders', 0);
        $this->assertDatabaseCount('order_items', 0);
    }

    public function test_missing_and_invalid_idempotency_headers_are_rejected(): void
    {
        $product = Product::factory()->create();
        $this->staff();
        $this->withoutHeader('Idempotency-Key')->postJson('/api/v1/orders', $this->cart($product))->assertUnprocessable()->assertJsonValidationErrors(['idempotency_key']);
        foreach (['short', str_repeat('a', 65), 'key with spaces', 'valid-key,another-key', ' key-with-padding'] as $key) {
            $this->postJson('/api/v1/orders', $this->cart($product), ['Idempotency-Key' => $key])->assertUnprocessable()->assertJsonValidationErrors(['idempotency_key']);
        }
        $this->assertDatabaseCount('orders', 0);
    }

    public function test_top_level_properties_resembling_nested_rule_names_are_still_rejected(): void
    {
        $product = Product::factory()->create();
        $this->staff();
        $response = $this->postJson('/api/v1/orders', [...$this->cart($product), 'items.*.quantity' => 99, 'items.*' => []])->assertUnprocessable();
        $this->assertArrayHasKey('items.*.quantity', $response->json('errors'));
        $this->assertArrayHasKey('items.*', $response->json('errors'));
        $this->assertDatabaseCount('orders', 0);
    }

    public function test_unavailable_product_or_category_cannot_create_order(): void
    {
        $inactive = Product::factory()->inactive()->create();
        $hidden = Product::factory()->create(['category_id' => Category::factory()->inactive()->create()->id]);
        $this->staff();
        foreach ([$inactive->id, $hidden->id, 999999] as $id) {
            $this->postJson('/api/v1/orders', ['items' => [['product_id' => $id, 'quantity' => 1]]])->assertUnprocessable()->assertJsonValidationErrors(['items']);
        }
        $this->assertDatabaseCount('orders', 0);
    }

    public function test_invalid_authoritative_catalog_money_fails_closed_on_sqlite_as_well(): void
    {
        if (config('database.default') !== 'sqlite') {
            $this->markTestSkipped('MySQL already rejects corrupt catalog money through its CHECKs.');
        }
        $this->staff();
        foreach ([['price_minor' => -1], ['price_minor' => 1000000], ['currency' => 'KHR']] as $state) {
            $product = Product::factory()->create($state);
            $this->postJson('/api/v1/orders', $this->cart($product))->assertUnprocessable();
        }
        $this->assertDatabaseCount('orders', 0);
    }

    public function test_controlled_item_failure_rolls_back_every_write_and_does_not_consume_key(): void
    {
        $products = Product::factory()->count(2)->create();
        $this->staff();
        $writes = 0;
        Event::listen('eloquent.creating: '.OrderItem::class, function () use (&$writes): void {
            if (++$writes === 2) {
                throw new RuntimeException('Synthetic controlled item failure.');
            }
        });
        $cart = ['items' => $products->map(fn (Product $product) => ['product_id' => $product->id, 'quantity' => 1])->all()];
        $this->postJson('/api/v1/orders', $cart, ['Idempotency-Key' => 'rollback-test-key'])->assertStatus(500);
        $this->assertDatabaseCount('orders', 0);
        $this->assertDatabaseCount('order_items', 0);
        $this->postJson('/api/v1/orders', $cart, ['Idempotency-Key' => 'rollback-test-key'])->assertCreated();
    }

    public function test_unauthenticated_or_disabled_unassigned_unknown_role_and_ability_are_denied(): void
    {
        $product = Product::factory()->create();
        $this->postJson('/api/v1/orders', $this->cart($product))->assertUnauthorized();
        $unknown = Role::query()->create(['name' => 'pos-superuser', 'label' => 'Unknown']);
        foreach ([['is_active' => false], ['role_id' => null], ['role_id' => $unknown->id]] as $state) {
            $this->staff(StaffRole::Admin, $state);
            $this->postJson('/api/v1/orders', $this->cart($product))->assertForbidden();
            $this->getJson('/api/v1/orders')->assertForbidden();
        }
        $user = $this->staff();
        Auth::forgetGuards();
        $this->withToken($user->createToken('Restricted', [], now()->addHour())->plainTextToken)->postJson('/api/v1/orders', $this->cart($product))->assertForbidden();
        $this->assertDatabaseCount('orders', 0);
    }
}
