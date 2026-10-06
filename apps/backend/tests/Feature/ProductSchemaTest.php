<?php

namespace Tests\Feature;

use App\Models\Category;
use App\Models\Product;
use Illuminate\Database\QueryException;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use PHPUnit\Framework\Attributes\DataProvider;
use Tests\TestCase;

class ProductSchemaTest extends TestCase
{
    use RefreshDatabase;

    public function test_product_has_category_relationship_exact_price_and_nullable_description(): void
    {
        $product = Product::factory()->create(['price_minor' => '325'])->fresh();
        $this->assertSame(325, $product->price_minor);
        $this->assertSame('USD', $product->currency);
        $this->assertNull($product->description);
        $this->assertTrue($product->isSellable());
        $this->assertTrue($product->category->products->sole()->is($product));
    }

    public function test_product_and_category_retirement_affect_sellability_without_deletion(): void
    {
        $product = Product::factory()->create();
        $product->category->update(['is_active' => false]);
        $this->assertFalse($product->fresh()->isSellable());
        $this->assertSame(0, Product::query()->sellable()->count());
        $product->category->update(['is_active' => true]);
        $product->update(['is_active' => false]);
        $this->assertFalse($product->fresh()->isSellable());
        $this->assertDatabaseCount('products', 1);
        $product->update(['is_active' => true]);
        $this->assertTrue($product->fresh()->isSellable());
    }

    public function test_duplicate_sku_is_rejected_case_insensitively_by_the_database(): void
    {
        Product::factory()->create(['sku' => 'COFFEE-01']);
        $this->expectException(QueryException::class);
        Product::factory()->create(['sku' => 'coffee-01']);
    }

    public function test_nonexistent_category_is_rejected_by_foreign_key(): void
    {
        $this->expectException(QueryException::class);
        Product::factory()->create(['category_id' => 999999]);
    }

    public function test_category_with_products_cannot_be_hard_deleted(): void
    {
        $product = Product::factory()->create();
        $this->expectException(QueryException::class);
        $product->category->delete();
    }

    public function test_both_browse_indexes_match_filtered_and_unfiltered_menu_queries(): void
    {
        $columns = array_column(Schema::getIndexes('products'), 'columns');
        $this->assertContains(['category_id', 'is_active', 'name', 'id'], $columns);
        $this->assertContains(['is_active', 'name', 'id'], $columns);
    }

    public static function invalidDatabaseMoney(): array
    {
        return ['negative price' => [['price_minor' => -1]], 'excessive price' => [['price_minor' => 1000000]],
            'unsupported currency' => [['currency' => 'KHR']], 'case-sensitive currency' => [['currency' => 'usd']]];
    }

    #[DataProvider('invalidDatabaseMoney')]
    public function test_mysql_enforces_price_and_currency_checks_even_without_request_validation(array $state): void
    {
        if (DB::getDriverName() !== 'mysql') {
            $this->markTestSkipped('Production CHECK constraints require the isolated MySQL suite.');
        }

        $this->expectException(QueryException::class);
        Product::factory()->create($state);
    }

    public function test_database_preserves_other_products_when_a_category_is_retired(): void
    {
        $category = Category::factory()->create();
        Product::factory()->count(2)->create(['category_id' => $category->id]);
        $category->update(['is_active' => false]);
        $this->assertSame(2, $category->products()->count());
    }

    public function test_product_mass_assignment_excludes_internal_fields(): void
    {
        $product = new Product;
        $product->fill(['name' => 'Coffee', 'price_minor' => '325', 'id' => 999, 'created_by' => 9, 'is_sellable' => true, 'role' => 'admin']);
        $this->assertSame(['name' => 'Coffee', 'price_minor' => '325'], $product->getAttributes());
    }
}
