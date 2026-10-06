<?php

namespace Tests\Feature;

use App\Enums\PaymentStatus;
use App\Models\Order;
use App\Models\Payment;
use App\Models\User;
use App\Payments\PaymentProvider;
use App\Payments\VerificationResult;
use App\Services\ExternalPaymentService;
use Illuminate\Foundation\Testing\DatabaseMigrations;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\DB;
use InvalidArgumentException;
use PHPUnit\Framework\Attributes\DataProvider;
use Tests\Support\FakePaymentProvider;
use Tests\TestCase;

class ExternalPaymentTest extends TestCase
{
    use DatabaseMigrations;

    private function setupOrder(bool $fake = true): array
    {
        $order = Order::factory()->create();
        Auth::forgetGuards();
        $this->withToken($order->creator->createToken('Synthetic external terminal', ['staff'], now()->addHour())->plainTextToken)
            ->withHeader('Idempotency-Key', 'external-attempt-key');
        $provider = new FakePaymentProvider(DB::transactionLevel());
        if ($fake) {
            $this->app->instance(PaymentProvider::class, $provider);
        }

        return [$order, $provider, '/api/v1/orders/'.$order->public_reference.'/payments'];
    }

    public function test_production_binding_fails_closed_without_inventing_a_real_provider(): void
    {
        [$order, , $uri] = $this->setupOrder(false);
        $this->postJson($uri.'/external', [])->assertStatus(503);
        $this->assertDatabaseCount('payments', 0);
        $this->assertSame('pending_payment', $order->fresh()->status->value);
    }

    public function test_qr_pending_then_server_verification_settles_once_and_replays_without_io(): void
    {
        [$order, $provider, $uri] = $this->setupOrder();
        $reply = $this->postJson($uri.'/external', [])->assertCreated()->assertJsonPath('data.status', 'pending');
        $id = $reply->json('data.id');
        $this->assertStringStartsWith('SYNTHETIC-QR-', $reply->json('data.qr_payload'));
        $this->assertSame('pending_payment', $order->fresh()->status->value);
        $this->assertSame($id, $order->fresh()->active_payment_id);
        $this->postJson($uri.'/external', [])->assertOk()->assertJsonPath('data.id', $id);
        $this->assertSame(1, $provider->initiations);
        $this->postJson($uri.'/cash', ['tender_minor' => '325'], ['Idempotency-Key' => 'cash-while-pending'])->assertConflict();
        $this->postJson($uri.'/'.$id.'/reconcile', [])->assertOk()->assertJsonPath('data.status', 'confirmed')->assertJsonPath('data.qr_payload', null);
        $this->postJson($uri.'/'.$id.'/reconcile', [])->assertOk(); // duplicate trusted notification/query
        $this->assertSame('paid', $order->fresh()->status->value);
        $this->assertSame($id, $order->fresh()->accepted_payment_id);
        $this->assertDatabaseCount('payment_evidence', 1);
        $this->assertDatabaseCount('payments', 1);
        $this->postJson($uri.'/external', [], ['Idempotency-Key' => 'another-external-key'])->assertConflict();
    }

    public function test_timeout_is_uncertain_and_manual_reconciliation_recovers_without_another_attempt(): void
    {
        [$order, $provider, $uri] = $this->setupOrder();
        $provider->timeoutInitiation = true;
        $id = $this->postJson($uri.'/external', [])->assertCreated()->assertJsonPath('data.status', 'uncertain')->json('data.id');
        $this->postJson($uri.'/external', [], ['Idempotency-Key' => 'blocked-second-key'])->assertConflict();
        $provider->timeoutVerification = true;
        $this->postJson($uri.'/'.$id.'/reconcile', [])->assertOk()->assertJsonPath('data.status', 'uncertain');
        $this->assertSame('pending_payment', $order->fresh()->status->value);
        $provider->timeoutVerification = false;
        $this->postJson($uri.'/'.$id.'/reconcile', [])->assertOk()->assertJsonPath('data.status', 'confirmed');
        $this->assertDatabaseCount('payments', 1);
    }

    public static function mismatches(): array
    {
        return ['amount' => [['amount' => 326]], 'currency' => [['currency' => 'KHR']], 'merchant' => [['merchant' => 'another-merchant']],
            'order' => [['order' => 'ORD-OTHER']], 'correlation' => [['correlation' => 'OTHER-CORRELATION']], 'provider' => [['provider' => 'another-provider']]];
    }

    #[DataProvider('mismatches')]
    public function test_wrong_verified_facts_never_settle_and_are_quarantined(array $facts): void
    {
        [$order, $provider, $uri] = $this->setupOrder();
        $id = $this->postJson($uri.'/external', [])->assertCreated()->json('data.id');
        $provider->facts = $facts;
        $this->postJson($uri.'/'.$id.'/reconcile', [])->assertOk()->assertJsonPath('data.reconciliation_required', true);
        $this->assertNull($order->fresh()->accepted_payment_id);
        $this->assertSame('pending_payment', $order->fresh()->status->value);
    }

    public function test_verified_failure_or_expiry_allows_cash_but_late_funds_are_retained_for_review(): void
    {
        foreach ([PaymentStatus::Failed, PaymentStatus::Expired] as $status) {
            [$order, $provider, $uri] = $this->setupOrder();
            $id = $this->postJson($uri.'/external', [])->assertCreated()->json('data.id');
            $provider->status = $status;
            $this->postJson($uri.'/'.$id.'/reconcile', [])->assertOk()->assertJsonPath('data.status', $status->value);
            $this->assertNull($order->fresh()->active_payment_id);
            $cashId = $this->postJson($uri.'/cash', ['tender_minor' => '325'], ['Idempotency-Key' => 'cash-after-verified-end'])->assertCreated()->json('data.id');
            $provider->status = PaymentStatus::Confirmed;
            $this->postJson($uri.'/'.$id.'/reconcile', [])->assertOk()->assertJsonPath('data.reconciliation_required', true);
            $this->assertSame($cashId, $order->fresh()->accepted_payment_id);
            $this->assertSame(1, Payment::find($id)->evidence()->count());
        }
    }

    public function test_second_distinct_transaction_on_same_attempt_is_not_discarded_or_reaccepted(): void
    {
        [$order, $provider, $uri] = $this->setupOrder();
        $id = $this->postJson($uri.'/external', [])->assertCreated()->json('data.id');
        $this->postJson($uri.'/'.$id.'/reconcile', [])->assertOk();
        $originalIdentity = Payment::find($id)->external_transaction_id;
        $provider->facts = ['transaction' => 'SECOND-REAL-OBSERVATION'];
        $this->postJson($uri.'/'.$id.'/reconcile', [])->assertOk()->assertJsonPath('data.reconciliation_required', true);
        $this->assertDatabaseCount('payment_evidence', 2);
        $this->assertSame($originalIdentity, Payment::find($id)->external_transaction_id);
        $this->assertSame($id, $order->fresh()->accepted_payment_id);
    }

    public function test_provider_identity_cannot_credit_two_orders(): void
    {
        [$first, $provider, $uri] = $this->setupOrder();
        $provider->facts = ['transaction' => 'UNIQUE-EXTERNAL-TX'];
        $id = $this->postJson($uri.'/external', [])->assertCreated()->json('data.id');
        $this->postJson($uri.'/'.$id.'/reconcile', [])->assertOk();
        [$second, $provider, $uri] = $this->setupOrder();
        $provider->facts = ['transaction' => 'UNIQUE-EXTERNAL-TX'];
        $id = $this->postJson($uri.'/external', [])->assertCreated()->json('data.id');
        $this->postJson($uri.'/'.$id.'/reconcile', [])->assertOk()->assertJsonPath('data.reconciliation_required', true);
        $this->assertSame('paid', $first->fresh()->status->value);
        $this->assertSame('pending_payment', $second->fresh()->status->value);
        $this->assertDatabaseCount('payment_evidence', 1);
    }

    public function test_unknown_proof_fields_bola_and_safe_serialization(): void
    {
        [$order, , $uri] = $this->setupOrder();
        $id = $this->postJson($uri.'/external', [])->assertCreated()->json('data.id');
        $this->postJson($uri.'/'.$id.'/reconcile', ['external_transaction_id' => 'SPOOF', 'status' => 'confirmed'])->assertUnprocessable();
        $this->postJson($uri.'/external', ['currency' => 'KHR', 'expected_amount_minor' => '1'])->assertUnprocessable();
        $body = $this->getJson($uri)->assertOk()->json('data.0');
        foreach (['attempt_key', 'request_hash', 'merchant_reference', 'external_transaction_id', 'signature', 'provider_secret'] as $field) {
            $this->assertArrayNotHasKey($field, $body);
        }
        $other = User::factory()->create();
        Auth::forgetGuards();
        $this->withToken($other->createToken('Other cashier', ['staff'], now()->addHour())->plainTextToken);
        $this->getJson($uri)->assertNotFound();
        $this->postJson($uri.'/'.$id.'/reconcile', [])->assertNotFound();
    }

    public function test_provider_value_object_rejects_fractional_amount_before_coercion(): void
    {
        $this->expectException(InvalidArgumentException::class);
        new VerificationResult(PaymentStatus::Confirmed, 'synthetic', 'ORD-X', 'PAY-X', 'merchant', 3.25, 'USD', 'TX-X');
    }

    public function test_pending_verification_and_crash_before_initiation_reply_are_recoverable(): void
    {
        [$order, $provider, $uri] = $this->setupOrder();
        $id = $this->postJson($uri.'/external', [])->assertCreated()->json('data.id');
        $provider->status = PaymentStatus::Pending;
        $this->postJson($uri.'/'.$id.'/reconcile', [])->assertOk()->assertJsonPath('data.status', 'pending');
        $this->assertSame('pending_payment', $order->fresh()->status->value);
        // Synthetic persisted state at the crash boundary: intent committed, reply not saved.
        DB::table('payments')->where('id', $id)->update(['status' => 'initiated', 'qr_payload' => null]);
        $provider->status = PaymentStatus::Confirmed;
        $this->postJson($uri.'/'.$id.'/reconcile', [])->assertOk()->assertJsonPath('data.status', 'confirmed');
        $this->assertSame(1, $provider->initiations);
    }

    public function test_mismatched_received_evidence_stays_quarantined_after_pending_or_failed_query(): void
    {
        [$order, $provider, $uri] = $this->setupOrder();
        $id = $this->postJson($uri.'/external', [])->assertCreated()->json('data.id');
        $provider->facts = ['amount' => 326];
        $this->postJson($uri.'/'.$id.'/reconcile', [])->assertOk()->assertJsonPath('data.reconciliation_required', true);
        $provider->facts = [];
        $provider->status = PaymentStatus::Pending;
        $this->postJson($uri.'/'.$id.'/reconcile', [])->assertOk()->assertJsonPath('data.reconciliation_required', true);
        $provider->status = PaymentStatus::Failed;
        $this->postJson($uri.'/'.$id.'/reconcile', [])->assertOk()->assertJsonPath('data.reconciliation_required', true);
        $this->assertSame($id, $order->fresh()->active_payment_id);
        $this->postJson($uri.'/cash', ['tender_minor' => '325'], ['Idempotency-Key' => 'blocked-cash-after-evidence'])->assertConflict();
    }

    public function test_local_failure_after_verification_rolls_back_acceptance_and_retry_requeries_evidence(): void
    {
        [$order, $provider, $uri] = $this->setupOrder();
        $id = $this->postJson($uri.'/external', [])->assertCreated()->json('data.id');
        $failed = false;
        DB::connection()->beforeExecuting(function (string $sql) use (&$failed): void {
            $normalized = str_replace(['`', '"'], '', $sql);
            if (! $failed && str_starts_with($sql, 'update') && str_contains($normalized, 'orders') && str_contains($normalized, 'status')) {
                $failed = true;
                throw new \RuntimeException('Synthetic post-verification local failure.');
            }
        });
        $this->postJson($uri.'/'.$id.'/reconcile', [])->assertStatus(500);
        $this->assertNull($order->fresh()->accepted_payment_id);
        $this->assertSame('pending', Payment::find($id)->status->value);
        $this->assertDatabaseCount('payment_evidence', 0);
        $this->postJson($uri.'/'.$id.'/reconcile', [])->assertOk()->assertJsonPath('data.status', 'confirmed');
        $this->assertDatabaseCount('payment_evidence', 1);
        $this->assertSame(1, $provider->initiations);
    }

    public function test_provider_io_rejects_outer_transactions_and_qr_expiry_does_not_mark_paid(): void
    {
        [$order, $provider, $uri] = $this->setupOrder();
        $id = $this->postJson($uri.'/external', [])->assertCreated()->json('data.id');
        DB::table('payments')->where('id', $id)->update(['expires_at' => now()->subMinute()]);
        $this->getJson($uri)->assertOk()->assertJsonPath('data.0.qr_payload', null)->assertJsonPath('data.0.status', 'pending');
        $this->assertSame('pending_payment', $order->fresh()->status->value);
        $this->expectException(\LogicException::class);
        DB::transaction(fn () => app(ExternalPaymentService::class)->reconcile(Payment::find($id)));
    }
}
