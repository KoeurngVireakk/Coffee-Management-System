<?php

namespace Tests\Feature;

use App\Enums\StaffRole;
use App\Models\Category;
use App\Models\Product;
use App\Models\Role;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Auth;
use PHPUnit\Framework\Attributes\DataProvider;
use Tests\TestCase;

class ProductApiTest extends TestCase
{
    use RefreshDatabase;

    private function staff(StaffRole $role = StaffRole::Cashier, array $state = []): User
    {
        $user = User::factory()->withRole($role)->create($state);
        Auth::forgetGuards();
        $this->withToken($user->createToken('Synthetic product terminal', ['staff'], now()->addHour())->plainTextToken);

        return $user;
    }

    private function body(array $overrides = []): array
    {
        return [...['category_id' => Category::factory()->create()->id, 'sku' => 'coffee-01', 'name' => 'Coffee', 'price_minor' => '325', 'currency' => 'USD'], ...$overrides];
    }

    public function test_unauthenticated_read_create_and_update_are_json_401(): void
    {
        $product = Product::factory()->create();
        $this->get('/api/v1/products')->assertUnauthorized()->assertHeader('Content-Type', 'application/json');
        Auth::forgetGuards();
        $this->getJson('/api/v1/products/'.$product->id)->assertUnauthorized();
        Auth::forgetGuards();
        $this->postJson('/api/v1/products', $this->body())->assertUnauthorized();
        Auth::forgetGuards();
        $this->patchJson('/api/v1/products/'.$product->id, ['is_active' => false])->assertUnauthorized();
    }

    public function test_all_staff_can_browse_sellable_products_and_view_exact_price_resources(): void
    {
        $product = Product::factory()->create(['price_minor' => '325']);
        foreach (StaffRole::cases() as $role) {
            $this->staff($role);
            $this->getJson('/api/v1/products')->assertOk()->assertJsonCount(1, 'data')->assertJsonPath('data.0.id', $product->id);
            $response = $this->getJson('/api/v1/products/'.$product->id)->assertOk()
                ->assertJsonPath('data.price_minor', '325')->assertJsonPath('data.currency', 'USD')->assertJsonPath('data.is_sellable', true);
            $this->assertSame(['id', 'category_id', 'category', 'sku', 'name', 'description', 'price_minor', 'currency', 'is_active', 'is_sellable', 'created_at', 'updated_at'], array_keys($response->json('data')));
            $this->assertSame(['id', 'name', 'is_active'], array_keys($response->json('data.category')));
        }
    }

    public function test_cashier_cannot_create_update_reprice_retire_or_reactivate_any_product(): void
    {
        $active = Product::factory()->create();
        $retired = Product::factory()->inactive()->create();
        $this->staff();
        $this->postJson('/api/v1/products', $this->body())->assertForbidden();
        $this->patchJson('/api/v1/products/'.$active->id, ['name' => 'Injected', 'price_minor' => '0'])->assertForbidden();
        $this->putJson('/api/v1/products/'.$active->id, ['is_active' => false])->assertForbidden();
        $this->patchJson('/api/v1/products/'.$retired->id, ['is_active' => true])->assertForbidden();
        $this->assertDatabaseCount('products', 2);
        $this->assertDatabaseHas('products', ['id' => $active->id, 'name' => $active->name, 'price_minor' => $active->price_minor, 'is_active' => true]);
        $this->assertFalse($retired->fresh()->is_active);
    }

    public function test_managers_and_admins_manage_products_and_clear_nullable_description(): void
    {
        foreach ([StaffRole::Manager, StaffRole::Admin] as $role) {
            $this->staff($role);
            $response = $this->postJson('/api/v1/products', $this->body(['sku' => $role->value.'-01', 'description' => 'Sample description']))
                ->assertCreated()->assertJsonPath('data.sku', strtoupper($role->value).'-01')->assertJsonPath('data.is_active', true);
            $id = $response->json('data.id');
            $category = Category::factory()->create();
            $this->patchJson('/api/v1/products/'.$id, ['name' => 'Coffee revised', 'category_id' => $category->id, 'price_minor' => '450', 'description' => null])->assertOk()
                ->assertJsonPath('data.price_minor', '450')->assertJsonPath('data.description', null)->assertJsonPath('data.category.id', $category->id);
            $this->patchJson('/api/v1/products/'.$id, ['is_active' => false])->assertOk()->assertJsonPath('data.is_sellable', false);
            $this->putJson('/api/v1/products/'.$id, ['is_active' => true])->assertOk()->assertJsonPath('data.is_sellable', true);
            $this->assertDatabaseHas('products', ['id' => $id, 'is_active' => true]);
        }
    }

    public function test_retired_product_and_retired_category_are_hidden_from_cashier_and_default_menu(): void
    {
        $active = Product::factory()->create();
        $retired = Product::factory()->inactive()->create();
        $hidden = Product::factory()->create(['category_id' => Category::factory()->inactive()->create()->id]);
        $this->staff();
        $this->getJson('/api/v1/products')->assertOk()->assertJsonCount(1, 'data')->assertJsonPath('data.0.id', $active->id);
        $this->getJson('/api/v1/products/'.$retired->id)->assertNotFound();
        $this->getJson('/api/v1/products/'.$hidden->id)->assertNotFound();
        $this->getJson('/api/v1/products?status=inactive')->assertForbidden();
        $this->getJson('/api/v1/products?status=all')->assertForbidden();

        $this->staff(StaffRole::Manager);
        $this->getJson('/api/v1/products')->assertOk()->assertJsonCount(1, 'data');
        $this->getJson('/api/v1/products?status=inactive')->assertOk()->assertJsonCount(2, 'data');
        $this->getJson('/api/v1/products?status=all')->assertOk()->assertJsonCount(3, 'data');
        $this->getJson('/api/v1/products/'.$hidden->id)->assertOk()->assertJsonPath('data.is_active', true)->assertJsonPath('data.is_sellable', false);
    }

    public function test_reactivating_product_alone_does_not_bypass_inactive_category(): void
    {
        $category = Category::factory()->inactive()->create();
        $product = Product::factory()->inactive()->create(['category_id' => $category->id]);
        $this->staff(StaffRole::Manager);
        $this->patchJson('/api/v1/products/'.$product->id, ['is_active' => true])->assertOk()->assertJsonPath('data.is_sellable', false);
        $this->patchJson('/api/v1/categories/'.$category->id, ['is_active' => true])->assertOk();
        $this->getJson('/api/v1/products/'.$product->id)->assertOk()->assertJsonPath('data.is_sellable', true);
    }

    public function test_inactive_unassigned_unknown_role_or_ability_cannot_use_product_apis(): void
    {
        $unknown = Role::query()->create(['name' => 'product-superuser', 'label' => 'Unknown']);
        foreach ([['is_active' => false], ['role_id' => null], ['role_id' => $unknown->id]] as $state) {
            $this->staff(StaffRole::Admin, $state);
            $this->getJson('/api/v1/products')->assertForbidden();
            $this->postJson('/api/v1/products', $this->body())->assertForbidden();
        }
        $user = $this->staff();
        Auth::forgetGuards();
        $this->withToken($user->createToken('Restricted', [], now()->addHour())->plainTextToken)->getJson('/api/v1/products')->assertForbidden();
    }

    public static function invalidWrites(): array
    {
        return [
            'nonexistent category' => [['category_id' => 999999], ['category_id']],
            'category wrong type' => [['category_id' => []], ['category_id']],
            'negative cents' => [['price_minor' => '-1'], ['price_minor']],
            'fractional cents' => [['price_minor' => '3.25'], ['price_minor']],
            'float input' => [['price_minor' => 3.25], ['price_minor']],
            'integer JSON input' => [['price_minor' => 325], ['price_minor']],
            'excessive cents' => [['price_minor' => '1000000'], ['price_minor']],
            'overflow string' => [['price_minor' => '999999999999999999999999999999'], ['price_minor']],
            'leading zeros' => [['price_minor' => '0325'], ['price_minor']],
            'scientific notation' => [['price_minor' => '3e2'], ['price_minor']],
            'unsupported currency' => [['currency' => 'KHR'], ['currency']],
            'malformed currency' => [['currency' => ['USD']], ['currency']],
            'lowercase currency' => [['currency' => 'usd'], ['currency']],
            'oversize name/description/sku' => [['name' => str_repeat('a', 161), 'description' => str_repeat('a', 2001), 'sku' => str_repeat('a', 65)], ['name', 'description', 'sku']],
            'empty name' => [['name' => ' '], ['name']],
            'malformed sku' => [['sku' => 'bad sku!'], ['sku']],
            'flag wrong type' => [['is_active' => 1], ['is_active']],
            'internal fields' => [['id' => 999, 'role' => 'admin', 'permissions' => ['*'], 'created_by' => 9, 'is_sellable' => true, 'payment_status' => 'paid', 'stock_quantity' => 100, 'created_at' => '2020-01-01'], ['id', 'role', 'permissions', 'created_by', 'is_sellable', 'payment_status', 'stock_quantity', 'created_at']],
        ];
    }

    #[DataProvider('invalidWrites')]
    public function test_invalid_prices_currency_identifiers_and_injected_properties_are_rejected(array $overrides, array $fields): void
    {
        $this->staff(StaffRole::Manager);
        $body = $this->body($overrides);
        $this->postJson('/api/v1/products', $body)->assertUnprocessable()->assertJsonValidationErrors($fields);
        $this->assertDatabaseCount('products', 0);
        $product = Product::factory()->create();
        $this->patchJson('/api/v1/products/'.$product->id, $overrides)->assertUnprocessable()->assertJsonValidationErrors($fields);
        $this->assertDatabaseHas('products', ['id' => $product->id, 'sku' => $product->sku, 'price_minor' => $product->price_minor]);
    }

    public function test_missing_required_fields_empty_updates_and_duplicate_sku_are_422(): void
    {
        $product = Product::factory()->create(['sku' => 'EXISTING']);
        $other = Product::factory()->create(['sku' => 'OTHER']);
        $this->staff(StaffRole::Admin);
        $this->postJson('/api/v1/products', [])->assertUnprocessable()->assertJsonValidationErrors(['category_id', 'sku', 'name', 'price_minor', 'currency']);
        $this->patchJson('/api/v1/products/'.$product->id, [])->assertUnprocessable()->assertJsonValidationErrors(['body']);
        $this->postJson('/api/v1/products', $this->body(['sku' => ' existing ']))->assertUnprocessable()->assertJsonValidationErrors(['sku']);
        $this->patchJson('/api/v1/products/'.$other->id, ['sku' => 'existing'])->assertUnprocessable()->assertJsonValidationErrors(['sku']);
        $this->patchJson('/api/v1/products/'.$product->id, ['sku' => 'existing'])->assertOk()->assertJsonPath('data.sku', 'EXISTING');
    }

    public function test_zero_and_maximum_cents_are_accepted_as_exact_strings(): void
    {
        $this->staff(StaffRole::Manager);
        foreach (['0', '999999'] as $price) {
            $this->postJson('/api/v1/products', $this->body(['sku' => 'PRICE-'.$price, 'price_minor' => $price]))
                ->assertCreated()->assertJsonPath('data.price_minor', $price);
        }
    }

    public function test_retired_records_remain_and_delete_is_not_exposed(): void
    {
        $product = Product::factory()->create();
        $this->staff(StaffRole::Admin);
        $this->patchJson('/api/v1/products/'.$product->id, ['is_active' => false])->assertOk();
        $this->deleteJson('/api/v1/products/'.$product->id)->assertStatus(405);
        $this->getJson('/api/v1/products/999999')->assertNotFound();
        $this->assertDatabaseHas('products', ['id' => $product->id, 'is_active' => false]);
    }
}
