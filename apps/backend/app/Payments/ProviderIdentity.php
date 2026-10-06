<?php

namespace App\Payments;

use InvalidArgumentException;

readonly class ProviderIdentity
{
    public function __construct(public string $name, public string $merchant)
    {
        if (! preg_match('/\A[A-Za-z0-9_-]{1,64}\z/', $name) || $merchant === '' || strlen($merchant) > 191) {
            throw new InvalidArgumentException('Invalid provider identity.');
        }
    }
}
