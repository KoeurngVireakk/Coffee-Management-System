<?php

namespace Tests\Feature;

use App\Models\Category;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Schema;
use Tests\TestCase;

class CategorySchemaTest extends TestCase
{
    use RefreshDatabase;

    public function test_category_defaults_and_fields_match_the_approved_model(): void
    {
        $category = Category::query()->create(['name' => 'Coffee'])->fresh();
        $this->assertTrue($category->is_active);
        $this->assertNotNull($category->created_at);
        $this->assertSame(['id', 'name', 'is_active', 'created_at', 'updated_at'], Schema::getColumnListing('categories'));
    }

    public function test_retirement_and_reactivation_preserve_the_record(): void
    {
        $category = Category::factory()->create();
        $category->update(['is_active' => false]);
        $this->assertFalse($category->fresh()->is_active);
        $this->assertDatabaseCount('categories', 1);
        $category->update(['is_active' => true]);
        $this->assertTrue($category->fresh()->is_active);
        $this->assertDatabaseHas('categories', ['id' => $category->id, 'name' => $category->name]);
    }

    public function test_active_browse_has_a_deterministic_name_and_id_order(): void
    {
        $first = Category::factory()->create(['name' => 'Coffee']);
        $second = Category::factory()->create(['name' => 'Coffee']);
        Category::factory()->inactive()->create(['name' => 'A retired category']);
        $third = Category::factory()->create(['name' => 'Tea']);
        $this->assertSame([$first->id, $second->id, $third->id], Category::query()->active()->orderBy('name')->orderBy('id')->pluck('id')->all());
    }

    public function test_browse_index_matches_the_active_ordered_query(): void
    {
        $indexes = Schema::getIndexes('categories');
        $this->assertContains(['is_active', 'name', 'id'], array_column($indexes, 'columns'));
    }

    public function test_only_approved_category_fields_are_mass_assignable(): void
    {
        $category = new Category;
        $category->fill(['name' => 'Coffee', 'is_active' => true, 'id' => 999, 'created_by' => 99, 'role' => 'admin']);
        $this->assertSame(['name' => 'Coffee', 'is_active' => true], $category->getAttributes());
    }
}
