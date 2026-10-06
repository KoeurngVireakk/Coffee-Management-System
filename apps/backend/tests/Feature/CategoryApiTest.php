<?php

namespace Tests\Feature;

use App\Enums\StaffRole;
use App\Models\Category;
use App\Models\Role;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Auth;
use PHPUnit\Framework\Attributes\DataProvider;
use Tests\TestCase;

class CategoryApiTest extends TestCase
{
    use RefreshDatabase;

    private function staff(StaffRole $role = StaffRole::Cashier, array $state = []): User
    {
        $user = User::factory()->withRole($role)->create($state);
        Auth::forgetGuards();
        $this->withToken($user->createToken('Synthetic category terminal', ['staff'], now()->addHour())->plainTextToken);

        return $user;
    }

    public function test_unauthenticated_catalog_reads_and_writes_are_json_401(): void
    {
        $category = Category::factory()->create();
        $this->get('/api/v1/categories')->assertUnauthorized()->assertHeader('Content-Type', 'application/json');
        Auth::forgetGuards();
        $this->postJson('/api/v1/categories', ['name' => 'Coffee'])->assertUnauthorized();
        Auth::forgetGuards();
        $this->patchJson('/api/v1/categories/'.$category->id, ['is_active' => false])->assertUnauthorized();
    }

    public function test_all_staff_roles_can_read_active_categories_in_stable_pages(): void
    {
        $first = Category::factory()->create(['name' => 'Coffee']);
        $second = Category::factory()->create(['name' => 'Coffee']);
        Category::factory()->inactive()->create(['name' => 'A retired category']);
        foreach (StaffRole::cases() as $role) {
            $this->staff($role);
            $this->getJson('/api/v1/categories?per_page=1')->assertOk()
                ->assertJsonPath('data.0.id', $first->id)->assertJsonPath('meta.total', 2)->assertJsonPath('meta.per_page', 1);
            $this->getJson('/api/v1/categories?per_page=1&page=2')->assertOk()->assertJsonPath('data.0.id', $second->id);
            $this->getJson('/api/v1/categories/'.$first->id)->assertOk()->assertJsonPath('data.id', $first->id);
        }
    }

    public function test_cashier_cannot_write_or_enumerate_retired_categories(): void
    {
        $active = Category::factory()->create();
        $retired = Category::factory()->inactive()->create();
        $this->staff();
        $this->postJson('/api/v1/categories', ['name' => 'Injected'])->assertForbidden();
        $this->patchJson('/api/v1/categories/'.$active->id, ['name' => 'Injected'])->assertForbidden();
        $this->putJson('/api/v1/categories/'.$retired->id, ['is_active' => true])->assertForbidden();
        $this->getJson('/api/v1/categories?status=all')->assertForbidden();
        $this->getJson('/api/v1/categories?status=inactive')->assertForbidden();
        $this->getJson('/api/v1/categories/'.$retired->id)->assertNotFound();
        $this->assertDatabaseCount('categories', 2);
        $this->assertDatabaseHas('categories', ['id' => $active->id, 'name' => $active->name]);
        $this->assertFalse($retired->fresh()->is_active);
    }

    public function test_managers_and_admins_create_update_retire_and_reactivate_without_deleting(): void
    {
        foreach ([StaffRole::Manager, StaffRole::Admin] as $role) {
            $this->staff($role);
            $response = $this->postJson('/api/v1/categories', ['name' => '  Coffee  '])->assertCreated()->assertJsonPath('data.is_active', true);
            $id = $response->json('data.id');
            $this->patchJson('/api/v1/categories/'.$id, ['name' => 'Coffee and tea', 'is_active' => false])->assertOk()->assertJsonPath('data.is_active', false);
            $this->getJson('/api/v1/categories/'.$id)->assertOk();
            $this->getJson('/api/v1/categories?status=inactive')->assertOk();
            $this->putJson('/api/v1/categories/'.$id, ['is_active' => true])->assertOk()->assertJsonPath('data.name', 'Coffee and tea');
            $this->assertDatabaseHas('categories', ['id' => $id, 'is_active' => true]);
        }
    }

    public function test_inactive_unassigned_unknown_role_and_restricted_tokens_are_denied(): void
    {
        $unknown = Role::query()->create(['name' => 'catalog-superuser', 'label' => 'Unknown']);
        foreach ([['is_active' => false], ['role_id' => null], ['role_id' => $unknown->id]] as $state) {
            $this->staff(StaffRole::Admin, $state);
            $this->getJson('/api/v1/categories')->assertForbidden();
            $this->postJson('/api/v1/categories', ['name' => 'Denied'])->assertForbidden();
        }
        $user = $this->staff();
        Auth::forgetGuards();
        $this->withToken($user->createToken('Restricted', [], now()->addHour())->plainTextToken)
            ->getJson('/api/v1/categories')->assertForbidden();
    }

    public static function invalidBodies(): array
    {
        return [
            'missing name' => [[], ['name']],
            'blank name' => [['name' => '  '], ['name']],
            'oversize name' => [['name' => str_repeat('a', 121)], ['name']],
            'invalid type' => [['name' => []], ['name']],
            'flag must be boolean' => [['name' => 'Coffee', 'is_active' => 'false'], ['is_active']],
            'privilege and ownership injection' => [['name' => 'Coffee', 'role' => 'admin', 'permissions' => ['*'], 'created_by' => 999, 'id' => 999, 'created_at' => '2020-01-01'], ['role', 'permissions', 'created_by', 'id', 'created_at']],
        ];
    }

    #[DataProvider('invalidBodies')]
    public function test_invalid_and_unknown_write_fields_are_rejected(array $body, array $fields): void
    {
        $this->staff(StaffRole::Manager);
        $this->postJson('/api/v1/categories', $body)->assertUnprocessable()->assertJsonValidationErrors($fields);
        $this->assertDatabaseCount('categories', 0);
    }

    public function test_invalid_update_and_query_fields_have_no_side_effects(): void
    {
        $category = Category::factory()->create();
        $this->staff(StaffRole::Manager);
        $this->patchJson('/api/v1/categories/'.$category->id, [])->assertUnprocessable()->assertJsonValidationErrors(['body']);
        $this->patchJson('/api/v1/categories/'.$category->id, ['name' => null, 'system' => true])->assertUnprocessable()->assertJsonValidationErrors(['name', 'system']);
        foreach (['per_page=101', 'per_page=0', 'page=10001', 'search='.str_repeat('a', 81), 'status=bad', 'sort=name', 'created_by=9'] as $query) {
            $this->getJson('/api/v1/categories?'.$query)->assertUnprocessable();
        }
        $this->assertDatabaseHas('categories', ['id' => $category->id, 'name' => $category->name]);
    }

    public function test_literal_search_does_not_expand_sql_wildcards_or_execute_sql(): void
    {
        $matching = Category::factory()->create(['name' => '100% coffee_!']);
        Category::factory()->create(['name' => '100 other coffee']);
        $this->staff();
        $this->getJson('/api/v1/categories?search='.urlencode('%'))->assertOk()->assertJsonCount(1, 'data')->assertJsonPath('data.0.id', $matching->id);
        $this->getJson('/api/v1/categories?search='.urlencode("' OR 1=1 --"))->assertOk()->assertJsonCount(0, 'data');
    }

    public function test_resources_are_allow_listed_and_delete_is_not_exposed(): void
    {
        $category = Category::factory()->create();
        $this->staff(StaffRole::Admin);
        $response = $this->getJson('/api/v1/categories/'.$category->id)->assertOk();
        $this->assertSame(['id', 'name', 'is_active', 'created_at', 'updated_at'], array_keys($response->json('data')));
        $this->deleteJson('/api/v1/categories/'.$category->id)->assertStatus(405);
        $this->getJson('/api/v1/categories/999999')->assertNotFound();
        $this->assertDatabaseCount('categories', 1);
    }
}
