<?php

namespace App\Services;

use App\Models\AuditEvent;
use App\Models\User;

class AuditService
{
    /**
     * Record an immutable administrative audit event.
     *
     * @param  array<string, mixed>|null  $metadata
     */
    public function record(
        ?User $actor,
        string $action,
        string $subjectType,
        ?int $subjectId,
        ?array $metadata = null
    ): AuditEvent {
        return AuditEvent::create([
            'actor_id' => $actor?->id,
            'action' => $action,
            'subject_type' => $subjectType,
            'subject_id' => $subjectId,
            'metadata' => $metadata,
            'created_at' => now(),
        ]);
    }
}
