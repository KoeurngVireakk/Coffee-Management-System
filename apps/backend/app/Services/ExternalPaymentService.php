<?php

namespace App\Services;

use App\Enums\OrderStatus;
use App\Enums\PaymentStatus;
use App\Models\Order;
use App\Models\Payment;
use App\Models\PaymentEvidence;
use App\Models\User;
use App\Payments\PaymentIntent;
use App\Payments\PaymentProvider;
use App\Payments\ProviderTimeout;
use App\Payments\VerificationResult;
use Illuminate\Database\UniqueConstraintViolationException;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Gate;
use Illuminate\Support\Str;
use InvalidArgumentException;
use LogicException;
use Symfony\Component\HttpKernel\Exception\ConflictHttpException;

class ExternalPaymentService
{
    public function __construct(private PaymentProvider $provider) {}

    public function initiate(User $actor, Order $target, string $key): Payment
    {
        $this->assertOutsideTransaction();
        Gate::forUser($actor)->authorize('pay', $target);
        $hash = hash('sha256', '{"version":1,"method":"external"}');
        $existing = $target->payments()->where('attempt_key', $key)->first();
        if ($existing) {
            return $this->replay($existing, $hash);
        }
        $identity = $this->provider->identity(); // Gate/configuration only, never network I/O.
        $payment = DB::transaction(function () use ($actor, $target, $key, $hash, $identity): Payment {
            $order = Order::query()->whereKey($target->id)->lockForUpdate()->firstOrFail();
            Gate::forUser($actor)->authorize('pay', $order);
            $existing = $order->payments()->where('attempt_key', $key)->lockForUpdate()->first();
            if ($existing) {
                return $this->replay($existing, $hash);
            }
            if ($order->status !== OrderStatus::PendingPayment || $order->accepted_payment_id !== null || $order->active_payment_id !== null || $order->inventory_tracked
                || $order->currency !== 'USD' || $order->total_minor < 0 || $order->total_minor > Order::MAX_SUBTOTAL_MINOR) {
                throw new ConflictHttpException('Order is not eligible for a new payment attempt.');
            }
            $payment = new Payment;
            $payment->forceFill(['order_id' => $order->id, 'initiated_by' => $actor->id, 'attempt_key' => $key, 'request_hash' => $hash,
                'method' => 'external', 'status' => 'initiated', 'provider' => $identity->name,
                'merchant_reference' => $identity->merchant, 'correlation_reference' => 'PAY-'.Str::ulid(),
                'expected_amount_minor' => $order->total_minor, 'currency' => $order->currency,
                'reconciliation_required' => false])->save();
            $order->selectActivePayment($payment);

            return $payment;
        }, 3);
        if (! $payment->wasRecentlyCreated) {
            return $payment;
        }
        // Intent exists before I/O; timeout/crash can be recovered by trusted status verification.
        try {
            $reply = $this->provider->initiate(PaymentIntent::fromPayment($payment->load('order')));
        } catch (ProviderTimeout|InvalidArgumentException $exception) {
            $result = $this->uncertain($payment, $exception instanceof ProviderTimeout ? 'provider_timeout' : 'invalid_provider_reply');
            $result->wasRecentlyCreated = true;

            return $result;
        }

        $result = DB::transaction(function () use ($payment, $reply): Payment {
            $order = Order::query()->whereKey($payment->order_id)->lockForUpdate()->firstOrFail();
            $current = Payment::query()->whereKey($payment->id)->lockForUpdate()->firstOrFail();
            if ($current->status !== PaymentStatus::Initiated) {
                return $current; // Verification may have settled while initiation was in flight.
            }
            if ($reply->correlation !== $current->correlation_reference || $reply->qrPayload === '' || strlen($reply->qrPayload) > 8192) {
                return $this->flag($current, 'invalid_initiation_reply');
            }
            $current->forceFill(['status' => 'pending', 'qr_payload' => $reply->qrPayload, 'expires_at' => $reply->expiresAt])->save();

            return $current;
        }, 3);
        $result->wasRecentlyCreated = true;

        return $result;
    }

    public function reconcile(Payment $target): Payment
    {
        $this->assertOutsideTransaction();
        if ($target->method->value !== 'external') {
            throw new ConflictHttpException('Cash payments do not use provider reconciliation.');
        }
        $identity = $this->provider->identity();
        if ($identity->name !== $target->provider || $identity->merchant !== $target->merchant_reference) {
            return $this->uncertain($target, 'provider_configuration_mismatch');
        }
        try {
            $reply = $this->provider->verify(PaymentIntent::fromPayment($target->load('order')));
        } catch (ProviderTimeout|InvalidArgumentException $exception) {
            return $this->uncertain($target, $exception instanceof ProviderTimeout ? 'provider_timeout' : 'invalid_provider_reply');
        }
        // Verification I/O ended before any order/payment locks are taken.
        try {
            return $this->applyVerifiedResult($target, $reply);
        } catch (UniqueConstraintViolationException) {
            // Another order claimed this provider identity. Never credit it a second time.
            return $this->uncertain($target, 'transaction_identity_reused');
        }
    }

    private function applyVerifiedResult(Payment $target, VerificationResult $reply): Payment
    {
        return DB::transaction(function () use ($target, $reply): Payment {
            $order = Order::query()->whereKey($target->order_id)->lockForUpdate()->firstOrFail();
            $payment = Payment::query()->whereKey($target->id)->lockForUpdate()->firstOrFail();
            $contextMatches = $reply->provider === $payment->provider && $reply->orderReference === $order->public_reference
                && $reply->correlation === $payment->correlation_reference && $reply->merchant === $payment->merchant_reference;
            if ($reply->status !== PaymentStatus::Confirmed) {
                if (! $contextMatches) {
                    return $this->flag($payment, 'verification_context_mismatch');
                }
                if (in_array($payment->status, [PaymentStatus::Confirmed, PaymentStatus::Failed, PaymentStatus::Expired], true)) {
                    return $payment; // Terminal outcomes never demote on a stale status query.
                }
                if (! in_array($reply->status, [PaymentStatus::Pending, PaymentStatus::Failed, PaymentStatus::Expired, PaymentStatus::Uncertain], true)) {
                    return $this->flag($payment, 'invalid_provider_status');
                }
                $hasEvidence = $payment->evidence()->exists();
                $needsReview = $reply->status === PaymentStatus::Uncertain || $hasEvidence;
                $payment->forceFill(['status' => $reply->status, 'reconciliation_required' => $needsReview,
                    'reconciliation_reason' => $hasEvidence ? $payment->reconciliation_reason : ($needsReview ? 'provider_uncertain' : null)])->save();
                if (! $hasEvidence && in_array($reply->status, [PaymentStatus::Failed, PaymentStatus::Expired], true)) {
                    $order->clearActivePayment($payment);
                }

                return $payment;
            }
            if ($reply->amountMinor === null || ! is_string($reply->currency) || ! preg_match('/\A[A-Z]{3}\z/', $reply->currency)
                || $reply->transactionId === null || $reply->transactionId === '' || strlen($reply->transactionId) > 191
                || $reply->provider !== $payment->provider || strlen($reply->merchant) > 191 || strlen($reply->correlation) > 191 || strlen($reply->orderReference) > 40) {
                return $this->flag($payment, 'invalid_verified_evidence');
            }
            $evidence = PaymentEvidence::query()->where('provider', $reply->provider)->where('external_transaction_id', $reply->transactionId)->first();
            if ($evidence) {
                if ($evidence->payment_id !== $payment->id) {
                    return $this->flag($payment, 'transaction_identity_reused');
                }
                if ($evidence->amount_minor !== $reply->amountMinor || $evidence->currency !== $reply->currency
                    || $evidence->merchant_reference !== $reply->merchant || $evidence->correlation_reference !== $reply->correlation
                    || $evidence->order_reference !== $reply->orderReference) {
                    return $this->flag($payment, 'conflicting_transaction_evidence');
                }
            } else {
                $evidence = new PaymentEvidence;
                $evidence->forceFill(['payment_id' => $payment->id, 'provider' => $reply->provider,
                    'external_transaction_id' => $reply->transactionId, 'correlation_reference' => $reply->correlation,
                    'merchant_reference' => $reply->merchant, 'order_reference' => $reply->orderReference,
                    'amount_minor' => $reply->amountMinor, 'currency' => $reply->currency, 'verified_at' => now(), 'created_at' => now()])->save();
            }
            if (! $contextMatches || $reply->amountMinor !== $payment->expected_amount_minor || $reply->currency !== $payment->currency) {
                return $this->flag($payment, 'verification_facts_mismatch');
            }
            if ($payment->status === PaymentStatus::Confirmed) {
                return $payment->external_transaction_id === $reply->transactionId ? $payment : $this->flag($payment, 'additional_received_payment');
            }
            // Late successful evidence is retained even after a verified failure/expiry or another settlement.
            $wasTerminal = in_array($payment->status, [PaymentStatus::Failed, PaymentStatus::Expired], true);
            $payment->forceFill(['status' => 'confirmed', 'external_transaction_id' => $reply->transactionId, 'verified_at' => now()])->save();
            if ($wasTerminal || $order->status !== OrderStatus::PendingPayment || $order->accepted_payment_id !== null
                || $order->inventory_tracked || ($order->active_payment_id !== null && $order->active_payment_id !== $payment->id)) {
                return $this->flag($payment, 'late_or_second_settlement');
            }
            $additionalEvidence = $payment->evidence()->count() > 1;
            $payment->forceFill(['reconciliation_required' => $additionalEvidence,
                'reconciliation_reason' => $additionalEvidence ? 'additional_received_payment' : null])->save();
            $order->acceptPayment($payment);

            return $payment;
        }, 3);
    }

    private function replay(Payment $payment, string $hash): Payment
    {
        if (! hash_equals($payment->request_hash, $hash)) {
            throw new ConflictHttpException('This payment key was used for different intent.');
        }

        return $payment;
    }

    private function uncertain(Payment $target, string $reason): Payment
    {
        return DB::transaction(function () use ($target, $reason): Payment {
            Order::query()->whereKey($target->order_id)->lockForUpdate()->firstOrFail();
            $current = Payment::query()->whereKey($target->id)->lockForUpdate()->firstOrFail();

            return $this->flag($current, $reason);
        }, 3);
    }

    private function flag(Payment $payment, string $reason): Payment
    {
        $changes = ['reconciliation_required' => true, 'reconciliation_reason' => $reason];
        if (! in_array($payment->status, [PaymentStatus::Confirmed, PaymentStatus::Failed, PaymentStatus::Expired], true)) {
            $changes['status'] = 'uncertain';
        }
        $payment->forceFill($changes)->save();

        return $payment;
    }

    private function assertOutsideTransaction(): void
    {
        if (DB::transactionLevel() !== 0) {
            throw new LogicException('External payment I/O cannot start inside an existing database transaction.');
        }
    }
}
