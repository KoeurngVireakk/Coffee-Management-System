<?php

namespace App\Payments;

interface PaymentProvider
{
    public function identity(): ProviderIdentity;

    public function initiate(PaymentIntent $intent): InitiationResult;

    // Must query/authenticate trusted server-side evidence per the approved provider contract.
    public function verify(PaymentIntent $intent): VerificationResult;
}
