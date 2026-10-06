<?php

namespace App\Services;

use App\Enums\OrderStatus;
use App\Enums\PaymentStatus;
use App\Models\Order;
use App\Models\Payment;
use Illuminate\Support\Facades\DB;
use LogicException;
use Symfony\Component\HttpKernel\Exception\ConflictHttpException;

class OrderSettlementService
{
    public function __construct(private StockReservationService $stock) {}

    // The caller's transaction includes payment confirmation and all local finalization.
    public function finalize(Order $target, Payment $payment): void
    {
        if (DB::transactionLevel() < 1) {
            throw new LogicException('Settlement requires a payment workflow transaction.');
        }
        $order = Order::query()->whereKey($target->id)->lockForUpdate()->firstOrFail();
        $confirmed = Payment::query()->whereKey($payment->id)->lockForUpdate()->firstOrFail();
        if ($confirmed->order_id !== $order->id || $confirmed->status !== PaymentStatus::Confirmed || $confirmed->reconciliation_required
            || $confirmed->expected_amount_minor !== $order->total_minor || $confirmed->currency !== $order->currency
            || $order->status !== OrderStatus::PendingPayment || $order->accepted_payment_id !== null
            || ($order->active_payment_id !== null && $order->active_payment_id !== $confirmed->id)) {
            throw new ConflictHttpException('Order/payment is not eligible for settlement.');
        }
        $this->stock->consume($order, $confirmed);
        $order->acceptPayment($confirmed);
        $target->refresh();
    }
}
