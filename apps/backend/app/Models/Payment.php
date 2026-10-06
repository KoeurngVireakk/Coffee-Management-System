<?php

namespace App\Models;

use App\Enums\PaymentMethod;
use App\Enums\PaymentStatus;
use Database\Factories\PaymentFactory;
use Illuminate\Database\Eloquent\Attributes\Hidden;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use LogicException;

#[Hidden(['attempt_key', 'request_hash', 'merchant_reference', 'external_transaction_id', 'initiated_by'])]
class Payment extends Model
{
    /** @use HasFactory<PaymentFactory> */
    use HasFactory;

    public const int MAX_TENDER_MINOR = 9999999999;

    protected function casts(): array
    {
        return ['method' => PaymentMethod::class, 'status' => PaymentStatus::class, 'expected_amount_minor' => 'integer',
            'tender_minor' => 'integer', 'change_minor' => 'integer', 'reconciliation_required' => 'boolean',
            'expires_at' => 'datetime', 'verified_at' => 'datetime'];
    }

    protected static function booted(): void
    {
        static::updating(function (Payment $payment): void {
            if ($payment->isDirty(['order_id', 'initiated_by', 'attempt_key', 'request_hash', 'method', 'provider', 'correlation_reference', 'merchant_reference', 'expected_amount_minor', 'currency', 'tender_minor', 'change_minor', 'created_at'])) {
                throw new LogicException('Payment intent facts are immutable.');
            }
            if ($payment->getRawOriginal('status') === 'confirmed' && $payment->isDirty(['status', 'external_transaction_id', 'verified_at'])) {
                throw new LogicException('Confirmed payment identity is immutable.');
            }
            if ($payment->isDirty('status') && ($payment->status === PaymentStatus::Initiated
                || (in_array($payment->getRawOriginal('status'), ['failed', 'expired'], true) && $payment->status !== PaymentStatus::Confirmed))) {
                throw new LogicException('Payment state cannot transition backward.');
            }
        });
        static::deleting(fn () => throw new LogicException('Payment history cannot be deleted.'));
    }

    public function order(): BelongsTo
    {
        return $this->belongsTo(Order::class);
    }

    public function evidence(): HasMany
    {
        return $this->hasMany(PaymentEvidence::class);
    }
}
