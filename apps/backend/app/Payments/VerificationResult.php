<?php

namespace App\Payments;

use App\Enums\PaymentStatus;
use InvalidArgumentException;

readonly class VerificationResult
{
    public ?int $amountMinor;

    public function __construct(public PaymentStatus $status, public string $provider, public string $orderReference,
        public string $correlation, public string $merchant, mixed $amountMinor = null,
        public ?string $currency = null, public ?string $transactionId = null)
    {
        // Do not let weak PHP scalar coercion silently truncate a provider float/string.
        if ($amountMinor !== null && (! is_int($amountMinor) || $amountMinor < 0)) {
            throw new InvalidArgumentException('Provider amount must be exact integer minor units.');
        }
        $this->amountMinor = $amountMinor;
    }
}
