<?php

namespace App\Payments;

use Symfony\Component\HttpKernel\Exception\ServiceUnavailableHttpException;

class UnconfiguredPaymentProvider implements PaymentProvider
{
    public function identity(): ProviderIdentity
    {
        throw new ServiceUnavailableHttpException(null, 'External payments are not configured.');
    }

    public function initiate(PaymentIntent $intent): InitiationResult
    {
        throw new ServiceUnavailableHttpException(null, 'External payments are not configured.');
    }

    public function verify(PaymentIntent $intent): VerificationResult
    {
        throw new ServiceUnavailableHttpException(null, 'External payments are not configured.');
    }
}
