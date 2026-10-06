<?php

namespace App\Http\Resources;

use App\Enums\PaymentStatus;
use App\Models\Payment;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** @mixin Payment */
class PaymentResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return ['id' => $this->id, 'method' => $this->method->value, 'status' => $this->status->value,
            'expected_amount_minor' => (string) $this->expected_amount_minor, 'currency' => $this->currency,
            'tender_minor' => $this->tender_minor === null ? null : (string) $this->tender_minor,
            'change_minor' => $this->change_minor === null ? null : (string) $this->change_minor,
            'provider' => $this->provider, 'reconciliation_required' => $this->reconciliation_required,
            'expires_at' => $this->expires_at?->toIso8601String(), 'verified_at' => $this->verified_at?->toIso8601String(),
            'created_at' => $this->created_at?->toIso8601String(),
            'qr_payload' => $this->status === PaymentStatus::Pending && (! $this->expires_at || now()->lessThan($this->expires_at)) ? $this->qr_payload : null];
    }
}
