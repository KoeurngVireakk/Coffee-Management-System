<?php

namespace App\Payments;

use App\Models\Payment;

readonly class PaymentIntent
{
    public function __construct(public int $paymentId, public string $orderReference, public string $correlation,
        public int $amountMinor, public string $currency, public string $merchant) {}

    public static function fromPayment(Payment $payment): self
    {
        return new self($payment->id, $payment->order->public_reference, $payment->correlation_reference,
            $payment->expected_amount_minor, $payment->currency, $payment->merchant_reference);
    }
}
