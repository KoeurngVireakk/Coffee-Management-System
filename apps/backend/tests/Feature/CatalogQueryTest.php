<?php

namespace Tests\Feature;

use App\Enums\StaffRole;
use App\Models\Category;
use App\Models\Product;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class CatalogQueryTest extends TestCase
{
    use RefreshDatabase;

    private function staff(StaffRole $role = StaffRole::Cashier): void
    {
        $user = User::factory()->withRole($role)->create();
        Auth::forgetGuards();
        $this->withToken($user->createToken('Synthetic catalog query', ['staff'], now()->addHour())->plainTextToken);
    }

    public function test_product_category_filter_and_stable_pagination(): void
    {
        $category = Category::factory()->create();
        $first = Product::factory()->create(['category_id' => $category->id, 'name' => 'Coffee']);
        $second = Product::factory()->create(['category_id' => $category->id, 'name' => 'Coffee']);
        Product::factory()->create(['name' => 'A different category']);
        $this->staff();
        $this->getJson('/api/v1/products?category_id='.$category->id.'&per_page=1')->assertOk()
            ->assertJsonPath('data.0.id', $first->id)->assertJsonPath('meta.total', 2);
        $this->getJson('/api/v1/products?category_id='.$category->id.'&per_page=1&page=2')->assertOk()->assertJsonPath('data.0.id', $second->id);
        $this->getJson('/api/v1/products?category_id=999999')->assertOk()->assertJsonCount(0, 'data');
    }

    public function test_search_is_bounded_literal_text_across_product_names_and_skus(): void
    {
        $category = Category::factory()->create(['name' => '100% coffee_!']);
        $special = Product::factory()->create(['category_id' => $category->id, 'name' => '100% coffee_!', 'sku' => 'LITERAL-0']);
        Product::factory()->create(['name' => 'Other', 'sku' => 'OTHER']);
        $this->staff();
        foreach (['%', '_', '!', 'LITERAL'] as $search) {
            $this->getJson('/api/v1/products?search='.urlencode($search))->assertOk()->assertJsonCount(1, 'data')->assertJsonPath('data.0.id', $special->id);
        }
        $this->getJson('/api/v1/products?search=0')->assertOk()->assertJsonCount(1, 'data')->assertJsonPath('data.0.id', $special->id);
        $this->getJson('/api/v1/categories?search=0')->assertOk()->assertJsonCount(1, 'data')->assertJsonPath('data.0.id', $category->id);
        $this->getJson('/api/v1/products?search='.urlencode("' OR 1=1 --"))->assertOk()->assertJsonCount(0, 'data');
    }

    public function test_unknown_sort_filters_query_types_and_excessive_limits_are_rejected(): void
    {
        $this->staff(StaffRole::Manager);
        foreach (['sort=price_minor', 'sort=name%3BDELETE', 'per_page=101', 'per_page=0', 'page=10001', 'page=0', 'category_id=0', 'category_id[]=1', 'search[]=x', 'search='.str_repeat('a', 81), 'status=bad', 'is_active=true', 'role=admin', 'created_by=1'] as $query) {
            $this->getJson('/api/v1/products?'.$query)->assertUnprocessable();
        }
    }

    public function test_manager_filters_cannot_leak_inactive_rows_into_cashier_results(): void
    {
        $active = Product::factory()->create();
        Product::factory()->inactive()->create();
        $this->staff(StaffRole::Manager);
        $this->getJson('/api/v1/products?status=all')->assertOk()->assertJsonCount(2, 'data');
        $this->staff();
        $this->getJson('/api/v1/products')->assertOk()->assertJsonCount(1, 'data')->assertJsonPath('data.0.id', $active->id);
        $this->getJson('/api/v1/products?status=all')->assertForbidden();
    }

    public function test_non_numeric_path_identifiers_cannot_alias_existing_mysql_ids(): void
    {
        $product = Product::factory()->create();
        $this->staff(StaffRole::Manager);
        foreach (['/api/v1/products/'.$product->id.'suffix', '/api/v1/categories/'.$product->category_id.'suffix'] as $uri) {
            $this->getJson($uri)->assertNotFound();
            $this->patchJson($uri, ['is_active' => false])->assertNotFound();
        }
        $this->assertTrue($product->fresh()->is_active);
        $this->assertTrue($product->category->fresh()->is_active);
    }

    public function test_product_listing_eager_loads_category_once_as_page_size_grows(): void
    {
        Product::factory()->count(20)->create();
        $this->staff();
        DB::enableQueryLog();
        $counts = [];
        try {
            foreach ([1, 20] as $pageSize) {
                Auth::forgetGuards();
                DB::flushQueryLog();
                $this->getJson('/api/v1/products?per_page='.$pageSize)->assertOk()->assertJsonCount($pageSize, 'data');
                $queries = DB::getQueryLog();
                $categoryQueries = array_filter($queries, function (array $entry): bool {
                    return preg_match('/^select .*? from [`"]?([a-z_]+)[`"]?(?:\s|$)/i', $entry['query'], $matches)
                        && $matches[1] === 'categories';
                });
                $this->assertCount(1, $categoryQueries);
                $counts[] = count(array_filter($queries, fn (array $entry) => str_starts_with($entry['query'], 'select ')));
                $this->assertLessThanOrEqual(8, count($queries));
            }
            $this->assertSame($counts[0], $counts[1], 'Query count must stay constant as the page grows.');
            $this->assertLessThanOrEqual(8, $counts[1]);
        } finally {
            DB::disableQueryLog();
        }
    }
}
