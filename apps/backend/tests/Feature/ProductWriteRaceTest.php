<?php

namespace Tests\Feature;

use App\Enums\StaffRole;
use App\Models\Category;
use App\Models\Product;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Event;
use PHPUnit\Framework\Attributes\DataProvider;
use Tests\TestCase;

class ProductWriteRaceTest extends TestCase
{
    use RefreshDatabase;

    public static function methods(): array
    {
        return ['create race' => ['POST'], 'update race' => ['PATCH']];
    }

    #[DataProvider('methods')]
    public function test_sku_claimed_after_validation_returns_field_error_instead_of_500(string $method): void
    {
        $category = Category::factory()->create();
        $product = Product::factory()->create(['category_id' => $category->id, 'sku' => 'ORIGINAL']);
        $user = User::factory()->withRole(StaffRole::Manager)->create();
        $this->withToken($user->createToken('Synthetic race test', ['staff'], now()->addHour())->plainTextToken);
        $event = $method === 'POST' ? 'creating' : 'updating';

        // Interleave a competing write after FormRequest uniqueness validation.
        Event::listen('eloquent.'.$event.': '.Product::class, function (Product $pending) use ($category): void {
            DB::table('products')->insert(['category_id' => $category->id, 'sku' => $pending->sku, 'name' => 'Competing synthetic write', 'price_minor' => 100, 'currency' => 'USD', 'is_active' => true]);
        });

        $body = ['category_id' => $category->id, 'sku' => 'CONCURRENT', 'name' => 'Requested write', 'price_minor' => '325', 'currency' => 'USD'];
        $uri = '/api/v1/products'.($method === 'PATCH' ? '/'.$product->id : '');
        $this->json($method, $uri, $body)->assertUnprocessable()->assertJsonValidationErrors(['sku']);
        $this->assertSame(1, Product::query()->where('sku', 'CONCURRENT')->count());
        $this->assertSame('ORIGINAL', $product->fresh()->sku);
    }
}
