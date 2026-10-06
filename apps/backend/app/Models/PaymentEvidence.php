<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use LogicException;

class PaymentEvidence extends Model
{
    protected $table = 'payment_evidence';

    public $timestamps = false;

    protected function casts(): array
    {
        return ['amount_minor' => 'integer', 'verified_at' => 'datetime', 'created_at' => 'datetime'];
    }

    protected static function booted(): void
    {
        static::updating(fn () => throw new LogicException('Verified transaction observations are immutable.'));
        static::deleting(fn () => throw new LogicException('Verified transaction observations cannot be deleted.'));
    }

    public function payment(): BelongsTo
    {
        return $this->belongsTo(Payment::class);
    }
}
