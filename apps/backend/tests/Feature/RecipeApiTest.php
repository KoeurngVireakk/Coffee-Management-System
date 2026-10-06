<?php

namespace Tests\Feature;

use App\Enums\StaffRole;
use App\Models\InventoryItem;
use App\Models\Product;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\DB;
use PHPUnit\Framework\Attributes\DataProvider;
use Tests\TestCase;

class RecipeApiTest extends TestCase
{
    use RefreshDatabase;

    private function staff(StaffRole $role = StaffRole::Manager): void
    {
        $user = User::factory()->withRole($role)->create();
        Auth::forgetGuards();
        $this->withToken($user->createToken('Synthetic recipe terminal', ['staff'], now()->addHour())->plainTextToken);
    }

    public function test_management_replaces_complete_recipe_returns_exact_sorted_snapshot_and_clears_it(): void
    {
        $product = Product::factory()->create();
        $beans = InventoryItem::factory()->create(['base_unit' => 'g']);
        $milk = InventoryItem::factory()->create(['base_unit' => 'ml']);
        foreach ([StaffRole::Manager, StaffRole::Admin] as $role) {
            $this->staff($role);
            $uri = '/api/v1/products/'.$product->id.'/recipe';
            $this->putJson($uri, ['ingredients' => [['inventory_item_id' => $milk->id, 'quantity' => '180'], ['inventory_item_id' => $beans->id, 'quantity' => '18.25']]])
                ->assertOk()->assertJsonPath('data.product_id', $product->id)->assertJsonPath('data.ingredients.0.inventory_item_id', $beans->id)
                ->assertJsonPath('data.ingredients.0.quantity', '18.2500')->assertJsonPath('data.ingredients.1.quantity', '180.0000');
            $this->getJson($uri)->assertOk()->assertJsonCount(2, 'data.ingredients');
            $this->putJson($uri, ['ingredients' => [['inventory_item_id' => $beans->id, 'quantity' => '20']]])->assertOk()->assertJsonCount(1, 'data.ingredients');
            $this->assertDatabaseMissing('product_ingredients', ['product_id' => $product->id, 'inventory_item_id' => $milk->id]);
            $this->putJson($uri, ['ingredients' => []])->assertOk()->assertJsonCount(0, 'data.ingredients');
        }
    }

    public function test_recipe_auth_roles_unknown_items_and_inactive_items(): void
    {
        $product = Product::factory()->create();
        $item = InventoryItem::factory()->create();
        $uri = '/api/v1/products/'.$product->id.'/recipe';
        $this->getJson($uri)->assertUnauthorized();
        $this->staff(StaffRole::Cashier);
        $this->getJson($uri)->assertForbidden();
        $this->putJson($uri, ['ingredients' => []])->assertForbidden();
        $this->staff();
        $this->putJson($uri, ['ingredients' => [['inventory_item_id' => $item->id, 'quantity' => '18']]])->assertOk();
        $item->forceFill(['is_active' => false])->save();
        $this->getJson($uri)->assertOk()->assertJsonPath('data.ingredients.0.is_active', false);
        foreach ([$item->id, 999999] as $id) {
            $this->putJson($uri, ['ingredients' => [['inventory_item_id' => $id, 'quantity' => '20']]])->assertUnprocessable();
        }
        $this->assertDatabaseHas('product_ingredients', ['product_id' => $product->id, 'quantity' => '18']);
    }

    public static function invalidIngredients(): array
    {
        return ['zero' => ['0'], 'negative' => ['-1'], 'float' => [18.5], 'integer' => [18], 'precision' => ['0.00001'],
            'huge' => ['10000000000'], 'leading zero' => ['018'], 'exponent' => ['1e3'], 'missing' => [null]];
    }

    #[DataProvider('invalidIngredients')]
    public function test_invalid_exact_quantity_is_rejected_without_recipe_change(mixed $quantity): void
    {
        $this->staff();
        $product = Product::factory()->create();
        $item = InventoryItem::factory()->create();
        $this->putJson('/api/v1/products/'.$product->id.'/recipe', ['ingredients' => [['inventory_item_id' => $item->id, 'quantity' => $quantity]]])->assertUnprocessable();
        $this->assertDatabaseCount('product_ingredients', 0);
    }

    public function test_duplicates_nested_injection_and_excessive_list_are_rejected(): void
    {
        $this->staff();
        $product = Product::factory()->create();
        $item = InventoryItem::factory()->create();
        $line = ['inventory_item_id' => $item->id, 'quantity' => '18'];
        $uri = '/api/v1/products/'.$product->id.'/recipe';
        foreach ([['ingredients' => [$line, $line]], ['ingredients' => [[...$line, 'on_hand' => '100']]], ['ingredients' => [$line], 'product_id' => 1],
            ['ingredients' => array_fill(0, 101, $line)], ['ingredients' => [['inventory_item_id' => (string) $item->id, 'quantity' => '18']]], []] as $body) {
            $this->putJson($uri, $body)->assertUnprocessable();
        }
        $this->assertDatabaseCount('product_ingredients', 0);
    }

    public function test_failure_after_recipe_deletion_restores_previous_complete_recipe(): void
    {
        $this->staff();
        $product = Product::factory()->create();
        $item = InventoryItem::factory()->create();
        $other = InventoryItem::factory()->create();
        $uri = '/api/v1/products/'.$product->id.'/recipe';
        $this->putJson($uri, ['ingredients' => [['inventory_item_id' => $item->id, 'quantity' => '18']]])->assertOk();
        DB::listen(function ($query): void {
            if (str_starts_with(strtolower($query->sql), 'delete from') && str_contains($query->sql, 'product_ingredients')) {
                throw new \RuntimeException('Synthetic recipe persistence failure');
            }
        });
        $this->putJson($uri, ['ingredients' => [['inventory_item_id' => $other->id, 'quantity' => '25']]])->assertStatus(500);
        $this->assertDatabaseCount('product_ingredients', 1);
        $this->assertDatabaseHas('product_ingredients', ['product_id' => $product->id, 'inventory_item_id' => $item->id, 'quantity' => '18']);
    }
}
