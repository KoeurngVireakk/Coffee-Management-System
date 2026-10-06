<?php

namespace App\Payments;

use Carbon\CarbonImmutable;

readonly class InitiationResult
{
    public function __construct(public string $correlation, public string $qrPayload, public ?CarbonImmutable $expiresAt = null) {}
}
