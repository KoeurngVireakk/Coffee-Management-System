<?php

namespace Tests\Feature;

use App\Enums\StaffRole;
use App\Models\Order;
use App\Models\OrderItem;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\DB;
use PHPUnit\Framework\Attributes\DataProvider;
use RuntimeException;
use Tests\TestCase;

class CashPaymentTest extends TestCase
{
    use RefreshDatabase;

    private function staff(User $user): void
    {
        Auth::forgetGuards();
        $this->withToken($user->createToken('Synthetic cash terminal', ['staff'], now()->addHour())->plainTextToken);
        $this->withHeader('Idempotency-Key', 'cash-attempt-key');
    }

    public function test_cash_is_exact_atomic_and_replay_safe_for_every_staff_role(): void
    {
        foreach (StaffRole::cases() as $role) {
            $actor = User::factory()->withRole($role)->create();
            $item = OrderItem::factory()->create(['order_id' => Order::factory()->create(['created_by' => $actor->id])->id]);
            $order = $item->order;
            $before = $item->fresh()->getAttributes();
            $this->staff($actor);
            $uri = '/api/v1/orders/'.$order->public_reference.'/payments/cash';
            $initial = $this->postJson($uri, ['tender_minor' => '1000'])->assertCreated()
                ->assertJsonPath('data.status', 'confirmed')->assertJsonPath('data.expected_amount_minor', '325')
                ->assertJsonPath('data.change_minor', '675')->assertJsonPath('data.provider', null)->json();
            $this->postJson($uri, ['tender_minor' => '1000'])->assertOk()->assertExactJson($initial);
            $this->postJson($uri, ['tender_minor' => '1001'])->assertConflict();
            $this->postJson($uri, ['tender_minor' => '1000'], ['Idempotency-Key' => 'second-cash-attempt'])->assertConflict();
            $this->assertSame('paid', $order->fresh()->status->value);
            $this->assertSame($initial['data']['id'], $order->fresh()->accepted_payment_id);
            $this->assertSame($actor->id, $order->payments()->sole()->initiated_by);
            $this->assertNotNull($order->fresh()->paid_at);
            $this->assertNull($order->fresh()->active_payment_id);
            $this->assertSame($before, $item->fresh()->getAttributes());
            $this->getJson('/api/v1/orders/'.$order->public_reference)->assertOk()->assertJsonPath('data.accepted_payment.id', $initial['data']['id']);
        }
        $this->assertDatabaseCount('payments', 3);
    }

    public function test_unauthenticated_other_cashier_and_disabled_staff_cannot_settle(): void
    {
        $order = Order::factory()->create();
        $uri = '/api/v1/orders/'.$order->public_reference.'/payments/cash';
        $this->postJson($uri, ['tender_minor' => '325'])->assertUnauthorized();
        $this->staff(User::factory()->create());
        $this->postJson($uri, ['tender_minor' => '325'])->assertNotFound();
        $this->staff(User::factory()->withRole(StaffRole::Admin)->inactive()->create());
        $this->postJson($uri, ['tender_minor' => '325'])->assertForbidden();
        $this->assertDatabaseCount('payments', 0);
    }

    public function test_manager_settles_other_staff_order_and_exact_tender_has_zero_change(): void
    {
        $order = Order::factory()->create();
        $this->staff(User::factory()->withRole(StaffRole::Manager)->create());
        $this->postJson('/api/v1/orders/'.$order->public_reference.'/payments/cash', ['tender_minor' => '325'])
            ->assertCreated()->assertJsonPath('data.change_minor', '0');
    }

    public static function invalidTender(): array
    {
        return ['missing' => [[]], 'negative' => [['tender_minor' => '-1']], 'fractional' => [['tender_minor' => '3.25']],
            'float' => [['tender_minor' => 3.25]], 'integer' => [['tender_minor' => 1000]], 'too large' => [['tender_minor' => '10000000000']],
            'leading zeros' => [['tender_minor' => '0325']], 'underpayment' => [['tender_minor' => '324']],
            'injection' => [['tender_minor' => '325', 'expected_amount_minor' => '1', 'total_minor' => '1', 'currency' => 'KHR', 'status' => 'confirmed', 'change_minor' => '0', 'created_by' => 1, 'paid_at' => '2026-10-06', 'external_transaction_id' => 'FAKE']]];
    }

    #[DataProvider('invalidTender')]
    public function test_invalid_tender_and_client_authority_are_rejected(array $body): void
    {
        $order = Order::factory()->create();
        $this->staff($order->creator);
        $this->postJson('/api/v1/orders/'.$order->public_reference.'/payments/cash', $body)->assertUnprocessable();
        $this->assertDatabaseCount('payments', 0);
        $this->assertSame('pending_payment', $order->fresh()->status->value);
    }

    public function test_key_required_and_failure_after_payment_insert_leaves_no_partial_settlement(): void
    {
        $order = Order::factory()->create();
        $this->staff($order->creator);
        $uri = '/api/v1/orders/'.$order->public_reference.'/payments/cash';
        $this->withoutHeader('Idempotency-Key')->postJson($uri, ['tender_minor' => '325'])->assertUnprocessable();
        DB::connection()->beforeExecuting(function (string $sql): void {
            if (str_starts_with($sql, 'update') && str_contains($sql, 'orders')) {
                throw new RuntimeException('Synthetic settlement failure.');
            }
        });
        $this->postJson($uri, ['tender_minor' => '325'], ['Idempotency-Key' => 'rollback-cash-key'])->assertStatus(500);
        $this->assertDatabaseCount('payments', 0);
        $this->assertNull($order->fresh()->accepted_payment_id);
        $this->assertSame('pending_payment', $order->fresh()->status->value);
    }

    public function test_payment_read_is_bounded_and_operations_are_throttled(): void
    {
        $order = Order::factory()->create();
        $this->staff($order->creator);
        $uri = '/api/v1/orders/'.$order->public_reference.'/payments';
        $this->getJson($uri.'?per_page=101')->assertUnprocessable();
        for ($request = 1; $request < 30; $request++) {
            $this->getJson($uri)->assertOk();
        }
        $this->getJson($uri)->assertTooManyRequests()->assertHeader('Retry-After');
    }
}
