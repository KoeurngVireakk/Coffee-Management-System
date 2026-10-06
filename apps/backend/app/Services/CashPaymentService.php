<?php

namespace App\Services;

use App\Enums\OrderStatus;
use App\Models\Order;
use App\Models\Payment;
use App\Models\User;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Gate;
use Illuminate\Validation\ValidationException;
use Symfony\Component\HttpKernel\Exception\ConflictHttpException;

class CashPaymentService
{
    public function __construct(private OrderSettlementService $settlement) {}

    public function settle(User $actor, Order $target, mixed $tender, string $key): Payment
    {
        Gate::forUser($actor)->authorize('pay', $target);
        if (! is_int($tender)) {
            throw ValidationException::withMessages(['tender_minor' => 'Tender must be exact integer minor units.']);
        }
        $hash = hash('sha256', json_encode(['version' => 1, 'method' => 'cash', 'tender_minor' => (string) $tender], JSON_THROW_ON_ERROR));
        $payment = DB::transaction(function () use ($actor, $target, $tender, $key, $hash): Payment {
            $order = Order::query()->whereKey($target->id)->lockForUpdate()->firstOrFail();
            Gate::forUser($actor)->authorize('pay', $order);
            $existing = $order->payments()->where('attempt_key', $key)->lockForUpdate()->first();
            if ($existing) {
                if (! hash_equals($existing->request_hash, $hash)) {
                    throw new ConflictHttpException('This payment key was used for different intent.');
                }

                return $existing;
            }
            if ($order->status !== OrderStatus::PendingPayment || $order->accepted_payment_id !== null || $order->active_payment_id !== null) {
                throw new ConflictHttpException('Order is not eligible for a new settlement.');
            }
            if ($order->currency !== 'USD' || $order->total_minor < 0 || $order->total_minor > Order::MAX_SUBTOTAL_MINOR
                || $tender < $order->total_minor || $tender > Payment::MAX_TENDER_MINOR) {
                throw ValidationException::withMessages(['tender_minor' => 'Tender must cover the exact order amount within supported bounds.']);
            }
            $payment = new Payment;
            $payment->forceFill(['order_id' => $order->id, 'initiated_by' => $actor->id, 'attempt_key' => $key, 'request_hash' => $hash, 'method' => 'cash',
                'status' => 'confirmed', 'expected_amount_minor' => $order->total_minor, 'currency' => $order->currency,
                'tender_minor' => $tender, 'change_minor' => $tender - $order->total_minor, 'verified_at' => now(),
                'reconciliation_required' => false])->save();
            $this->settlement->finalize($order, $payment);

            return $payment;
        }, 3);

        return $payment->load('order');
    }
}
