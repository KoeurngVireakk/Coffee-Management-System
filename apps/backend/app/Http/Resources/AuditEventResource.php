<?php

namespace App\Http\Resources;

use App\Models\AuditEvent;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** @mixin AuditEvent */
class AuditEventResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'actor' => $this->actor ? [
                'id' => $this->actor->id,
                'name' => $this->actor->name,
            ] : null,
            'action' => $this->action,
            'subject_type' => $this->subject_type,
            'subject_id' => $this->subject_id,
            'metadata' => $this->metadata,
            'created_at' => $this->created_at?->toIso8601String(),
        ];
    }
}
