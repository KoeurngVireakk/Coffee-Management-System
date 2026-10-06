<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use LogicException;

#[Fillable(['actor_id', 'action', 'subject_type', 'subject_id', 'metadata', 'created_at'])]
class AuditEvent extends Model
{
    /** @var bool */
    public $timestamps = false;

    protected static function booted(): void
    {
        static::updating(function (): void {
            throw new LogicException('Audit events are immutable and cannot be updated.');
        });

        static::deleting(function (): void {
            throw new LogicException('Audit events are immutable and cannot be deleted.');
        });
    }

    /**
     * @return BelongsTo<User, $this>
     */
    public function actor(): BelongsTo
    {
        return $this->belongsTo(User::class, 'actor_id');
    }

    /**
     * Get the attributes that should be cast.
     *
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'metadata' => 'json',
            'created_at' => 'immutable_datetime',
        ];
    }
}
