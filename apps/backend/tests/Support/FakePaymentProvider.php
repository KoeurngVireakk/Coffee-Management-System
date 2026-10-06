<?php

namespace Tests\Support;

use App\Enums\PaymentStatus;
use App\Payments\InitiationResult;
use App\Payments\PaymentIntent;
use App\Payments\PaymentProvider;
use App\Payments\ProviderIdentity;
use App\Payments\ProviderTimeout;
use App\Payments\VerificationResult;
use Carbon\CarbonImmutable;
use Illuminate\Support\Facades\DB;
use LogicException;

class FakePaymentProvider implements PaymentProvider
{
    public int $initiations = 0;

    public bool $timeoutInitiation = false;

    public bool $timeoutVerification = false;

    public PaymentStatus $status = PaymentStatus::Confirmed;

    public array $facts = [];

    public function __construct(private int $ambientTransactions = 0) {}

    public function identity(): ProviderIdentity
    {
        return new ProviderIdentity('synthetic', 'synthetic-merchant');
    }

    public function initiate(PaymentIntent $intent): InitiationResult
    {
        $this->assertOutsideWorkflowTransaction();
        $this->initiations++;
        if ($this->timeoutInitiation) {
            throw new ProviderTimeout('Synthetic initiation timeout.');
        }

        return new InitiationResult($intent->correlation, 'SYNTHETIC-QR-'.$intent->correlation, CarbonImmutable::now()->addMinutes(15));
    }

    public function verify(PaymentIntent $intent): VerificationResult
    {
        $this->assertOutsideWorkflowTransaction();
        if ($this->timeoutVerification) {
            throw new ProviderTimeout('Synthetic verification timeout.');
        }

        return new VerificationResult($this->status, $this->facts['provider'] ?? 'synthetic', $this->facts['order'] ?? $intent->orderReference,
            $this->facts['correlation'] ?? $intent->correlation, $this->facts['merchant'] ?? $intent->merchant,
            $this->facts['amount'] ?? $intent->amountMinor, $this->facts['currency'] ?? $intent->currency,
            $this->facts['transaction'] ?? 'SYNTHETIC-TX-'.$intent->paymentId);
    }

    private function assertOutsideWorkflowTransaction(): void
    {
        if (DB::transactionLevel() !== $this->ambientTransactions) {
            throw new LogicException('Provider I/O occurred inside a workflow transaction.');
        }
    }
}
