<?php

namespace Tests\Feature;

use App\Models\Order;
use App\Models\Payment;
use Illuminate\Database\QueryException;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use PHPUnit\Framework\Attributes\DataProvider;
use Tests\TestCase;

class PaymentSchemaTest extends TestCase
{
    use RefreshDatabase;

    public static function integrityCases(): array
    {
        return ['attempt key' => ['key'], 'order FK' => ['order'], 'accepted pair' => ['accepted'], 'active pair' => ['active'], 'external identity' => ['identity']];
    }

    #[DataProvider('integrityCases')]
    public function test_payment_foreign_keys_unique_keys_and_order_selection(string $case): void
    {
        $payment = Payment::factory()->create();
        $other = Order::factory()->create();
        if ($case === 'identity') {
            Payment::factory()->create(['provider' => 'synthetic', 'external_transaction_id' => 'TX-1']);
        }
        $this->expectException(QueryException::class);
        match ($case) {
            'key' => Payment::factory()->create(['order_id' => $payment->order_id, 'attempt_key' => $payment->attempt_key]),
            'order' => Payment::factory()->create(['order_id' => 999999]),
            'accepted' => DB::table('orders')->where('id', $other->id)->update(['status' => 'paid', 'accepted_payment_id' => $payment->id, 'paid_at' => now()]),
            'active' => DB::table('orders')->where('id', $other->id)->update(['active_payment_id' => $payment->id]),
            'identity' => Payment::factory()->create(['provider' => 'synthetic', 'external_transaction_id' => 'TX-1']),
        };
    }

    public static function moneyCases(): array
    {
        return ['negative amount' => [['expected_amount_minor' => -1]], 'wrong currency' => [['currency' => 'KHR']],
            'under tender' => [['tender_minor' => 100]], 'wrong change' => [['change_minor' => 1]],
            'wrong status' => [['status' => 'paid']], 'no verified time' => [['verified_at' => null]]];
    }

    #[DataProvider('moneyCases')]
    public function test_mysql_money_method_status_and_confirmation_checks(array $changes): void
    {
        if (DB::getDriverName() !== 'mysql') {
            $this->markTestSkipped('Payment CHECK constraints require isolated MySQL.');
        }
        $payment = Payment::factory()->create();
        $this->expectException(QueryException::class);
        DB::table('payments')->where('id', $payment->id)->update($changes);
    }

    public function test_stale_order_cannot_replace_an_accepted_payment(): void
    {
        $first = Payment::factory()->create();
        $stale = $first->order;
        $second = Payment::factory()->create(['order_id' => $stale->id]);
        DB::transaction(fn () => $first->order->acceptPayment($first));
        $this->expectException(\LogicException::class);
        DB::transaction(fn () => $stale->acceptPayment($second));
    }

    public function test_confirmed_payment_intent_and_identity_are_immutable(): void
    {
        $payment = Payment::factory()->create();
        $this->expectException(\LogicException::class);
        $payment->forceFill(['expected_amount_minor' => 1])->save();
    }
}
