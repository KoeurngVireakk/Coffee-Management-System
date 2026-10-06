<?php

namespace Tests\Feature;

use App\Enums\StaffRole;
use App\Models\InventoryItem;
use App\Models\StockMovement;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\DB;
use PHPUnit\Framework\Attributes\DataProvider;
use Tests\TestCase;

class MovementApiTest extends TestCase
{
    use RefreshDatabase;

    private function staff(StaffRole $role = StaffRole::Manager): User
    {
        $user = User::factory()->withRole($role)->create();
        Auth::forgetGuards();
        $this->withToken($user->createToken('Synthetic stock terminal', ['staff'], now()->addHour())->plainTextToken);
        $this->withHeader('Idempotency-Key', 'movement-test-key');

        return $user;
    }

    public function test_opening_receipt_waste_adjustments_are_exact_audited_and_replayed_once(): void
    {
        $actor = $this->staff();
        $item = InventoryItem::factory()->create();
        $uri = '/api/v1/inventory/items/'.$item->id.'/movements';
        $initial = $this->postJson($uri, ['reason' => 'opening_balance', 'quantity_delta' => '100.0001'])
            ->assertCreated()->assertJsonPath('data.actor_id', $actor->id)->assertJsonPath('data.order_id', null)
            ->assertJsonPath('data.quantity_delta', '100.0001')->json();
        $this->postJson($uri, ['reason' => 'opening_balance', 'quantity_delta' => '100.0001'])->assertOk()->assertExactJson($initial);
        $this->postJson($uri, ['reason' => 'opening_balance', 'quantity_delta' => '101'])->assertConflict();
        $this->assertSame(['id', 'inventory_item_id', 'order_id', 'actor_id', 'quantity_delta', 'reason', 'note', 'created_at'], array_keys($initial['data']));
        foreach ([['receipt', '0.1', null], ['waste', '-0.0001', null], ['adjustment', '-1.25', 'Measured shortfall'], ['adjustment', '2', 'Correct count']] as $index => [$reason, $delta, $note]) {
            $this->postJson($uri, ['reason' => $reason, 'quantity_delta' => $delta, 'note' => $note], ['Idempotency-Key' => 'movement-next-'.$index])->assertCreated();
        }
        $this->assertSame('100.8500', $item->fresh()->on_hand);
        $this->assertSame('0.0000', $item->fresh()->reserved);
        $this->assertDatabaseCount('stock_movements', 5);
        $this->getJson($uri.'?per_page=2')->assertOk()->assertJsonPath('meta.total', 5)->assertJsonPath('data.0.reason', 'adjustment')->assertJsonPath('data.0.quantity_delta', '2.0000');
        $this->postJson($uri, ['reason' => 'opening_balance', 'quantity_delta' => '5'], ['Idempotency-Key' => 'opening-second-key'])->assertConflict();
    }

    public function test_short_decimal_replays_canonical_semantics_global_actor_keys_conflict_on_changed_item_and_note(): void
    {
        $actor = $this->staff();
        $first = InventoryItem::factory()->create();
        $other = InventoryItem::factory()->create();
        $uri = '/api/v1/inventory/items/'.$first->id.'/movements';
        $initial = $this->postJson($uri, ['reason' => 'receipt', 'quantity_delta' => '1.5', 'note' => 'Delivery'])->assertCreated()->json();
        $this->postJson($uri, ['reason' => 'receipt', 'quantity_delta' => '1.5000', 'note' => 'Delivery'])->assertOk()->assertExactJson($initial);
        $this->postJson($uri, ['reason' => 'receipt', 'quantity_delta' => '1.5', 'note' => 'Different'])->assertConflict();
        $this->postJson('/api/v1/inventory/items/'.$other->id.'/movements', ['reason' => 'receipt', 'quantity_delta' => '1.5', 'note' => 'Delivery'])->assertConflict();
        $this->assertSame('0.0000', $other->fresh()->on_hand);
        $this->staff(StaffRole::Admin);
        $this->postJson($uri, ['reason' => 'receipt', 'quantity_delta' => '1.5', 'note' => 'Delivery'])->assertCreated();
        $this->assertSame('3.0000', $first->fresh()->on_hand);
        $this->assertDatabaseCount('stock_movements', 2);
        $this->assertSame($actor->id, StockMovement::query()->orderBy('id')->first()->actor_id);
    }

    public static function invalidMovement(): array
    {
        return [
            'injected balances' => [['reason' => 'receipt', 'quantity_delta' => '10', 'on_hand' => '10', 'reserved' => '0', 'available' => '10']],
            'injected identity' => [['reason' => 'receipt', 'quantity_delta' => '10', 'actor_id' => 1, 'order_id' => 1, 'operation_key' => 'fake', 'request_hash' => 'fake']],
            'forged sale' => [['reason' => 'sale', 'quantity_delta' => '-1']],
            'fake release' => [['reason' => 'release', 'quantity_delta' => '1']],
            'negative opening' => [['reason' => 'opening_balance', 'quantity_delta' => '-1']],
            'negative receipt' => [['reason' => 'receipt', 'quantity_delta' => '-1']],
            'positive waste' => [['reason' => 'waste', 'quantity_delta' => '1']],
            'zero' => [['reason' => 'receipt', 'quantity_delta' => '0']],
            'negative zero' => [['reason' => 'adjustment', 'quantity_delta' => '-0.0000', 'note' => 'Wrong']],
            'float' => [['reason' => 'receipt', 'quantity_delta' => 1.5]],
            'integer' => [['reason' => 'receipt', 'quantity_delta' => 1]],
            'precision' => [['reason' => 'receipt', 'quantity_delta' => '0.00001']],
            'overflow' => [['reason' => 'receipt', 'quantity_delta' => '10000000000']],
            'exponent' => [['reason' => 'receipt', 'quantity_delta' => '1e2']],
            'leading zero' => [['reason' => 'receipt', 'quantity_delta' => '01']],
            'blank adjustment note' => [['reason' => 'adjustment', 'quantity_delta' => '1', 'note' => ' ']],
            'missing adjustment note' => [['reason' => 'adjustment', 'quantity_delta' => '1']],
            'long note' => [['reason' => 'receipt', 'quantity_delta' => '1', 'note' => str_repeat('x', 501)]],
        ];
    }

    #[DataProvider('invalidMovement')]
    public function test_invalid_movement_and_property_injection_cannot_mutate_stock(array $body): void
    {
        $this->staff();
        $item = InventoryItem::factory()->create();
        $this->postJson('/api/v1/inventory/items/'.$item->id.'/movements', $body)->assertUnprocessable();
        $this->assertSame('0.0000', $item->fresh()->on_hand);
        $this->assertDatabaseCount('stock_movements', 0);
    }

    public function test_negative_movement_protects_reserved_stock_and_capacity_overflow_is_422(): void
    {
        $this->staff();
        $item = InventoryItem::factory()->create(['on_hand' => '10', 'reserved' => '7']);
        $uri = '/api/v1/inventory/items/'.$item->id.'/movements';
        $this->postJson($uri, ['reason' => 'waste', 'quantity_delta' => '-3.0001'])->assertConflict();
        $this->postJson($uri, ['reason' => 'waste', 'quantity_delta' => '-3'])->assertCreated();
        $this->assertSame('7.0000', $item->fresh()->on_hand);
        $this->postJson($uri, ['reason' => 'receipt', 'quantity_delta' => '9999999999.9999'], ['Idempotency-Key' => 'overflow-stock-key'])->assertUnprocessable();
        $this->assertDatabaseCount('stock_movements', 1);
    }

    public function test_zero_balance_with_normal_history_cannot_be_reopened_and_retired_item_history_remains(): void
    {
        $this->staff();
        $item = InventoryItem::factory()->create();
        $uri = '/api/v1/inventory/items/'.$item->id.'/movements';
        $this->postJson($uri, ['reason' => 'receipt', 'quantity_delta' => '1'])->assertCreated();
        $this->postJson($uri, ['reason' => 'waste', 'quantity_delta' => '-1'], ['Idempotency-Key' => 'waste-stock-key'])->assertCreated();
        $item->forceFill(['is_active' => false])->save();
        $this->postJson($uri, ['reason' => 'opening_balance', 'quantity_delta' => '1'], ['Idempotency-Key' => 'reopen-stock-key'])->assertConflict();
        $this->getJson($uri)->assertOk()->assertJsonCount(2, 'data');
    }

    public function test_missing_key_and_unbounded_history_query_are_rejected(): void
    {
        $this->staff();
        $item = InventoryItem::factory()->create();
        $uri = '/api/v1/inventory/items/'.$item->id.'/movements';
        $this->flushHeaders();
        $user = User::factory()->withRole(StaffRole::Manager)->create();
        Auth::forgetGuards();
        $this->withToken($user->createToken('Synthetic no-key', ['staff'], now()->addHour())->plainTextToken);
        $this->postJson($uri, ['reason' => 'receipt', 'quantity_delta' => '1'])->assertUnprocessable()->assertJsonValidationErrors('idempotency_key');
        $this->getJson($uri.'?per_page=101')->assertUnprocessable();
    }

    public function test_failure_after_movement_insert_rolls_back_ledger_and_balance(): void
    {
        $this->staff();
        $item = InventoryItem::factory()->create();
        DB::listen(function ($query): void {
            if (str_starts_with(strtolower($query->sql), 'insert into') && str_contains($query->sql, 'stock_movements')) {
                throw new \RuntimeException('Synthetic stock persistence failure');
            }
        });
        $this->postJson('/api/v1/inventory/items/'.$item->id.'/movements', ['reason' => 'receipt', 'quantity_delta' => '10'])->assertStatus(500);
        $this->assertDatabaseCount('stock_movements', 0);
        $this->assertSame('0.0000', $item->fresh()->on_hand);
    }

    public function test_repeated_movement_requests_are_throttled_without_duplicate_stock_effects(): void
    {
        $this->staff();
        $item = InventoryItem::factory()->create();
        $uri = '/api/v1/inventory/items/'.$item->id.'/movements';
        for ($index = 0; $index < 60; $index++) {
            $this->postJson($uri, ['reason' => 'receipt', 'quantity_delta' => '1'])->assertStatus($index === 0 ? 201 : 200);
        }
        $this->postJson($uri, ['reason' => 'receipt', 'quantity_delta' => '1'])->assertTooManyRequests()->assertHeader('Retry-After');
        $this->assertDatabaseCount('stock_movements', 1);
        $this->assertSame('1.0000', $item->fresh()->on_hand);
    }
}
