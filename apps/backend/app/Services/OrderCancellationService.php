<?php

namespace App\Services;

use App\Enums\OrderStatus;
use App\Enums\PaymentStatus;
use App\Models\Order;
use App\Models\User;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Gate;
use Symfony\Component\HttpKernel\Exception\ConflictHttpException;

class OrderCancellationService
{
    public function __construct(private StockReservationService $stock) {}

    public function cancel(User $actor, Order $target): Order
    {
        Gate::forUser($actor)->authorize('cancel', $target);
        $order = DB::transaction(function () use ($actor, $target): Order {
            $order = Order::query()->whereKey($target->id)->lockForUpdate()->firstOrFail();
            Gate::forUser($actor)->authorize('cancel', $order);
            if ($order->status === OrderStatus::Cancelled) {
                return $order;
            }
            if ($order->status !== OrderStatus::PendingPayment || $order->accepted_payment_id !== null || $order->active_payment_id !== null) {
                throw new ConflictHttpException('Order cannot be safely cancelled.');
            }
            $payments = $order->payments()->orderBy('id')->lockForUpdate()->get();
            foreach ($payments as $payment) {
                if ($payment->reconciliation_required || in_array($payment->status,
                    [PaymentStatus::Initiated, PaymentStatus::Pending, PaymentStatus::Uncertain, PaymentStatus::Confirmed], true)) {
                    throw new ConflictHttpException('Payment outcome must be resolved before cancellation.');
                }
            }
            $this->stock->release($order);
            $order->cancelPending();

            return $order;
        }, 3);

        return $order->load(['items', 'creator:id,name', 'acceptedPayment']);
    }
}
