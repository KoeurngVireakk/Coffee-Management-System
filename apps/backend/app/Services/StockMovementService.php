<?php

namespace App\Services;

use App\Inventory\Quantity;
use App\Models\InventoryItem;
use App\Models\StockMovement;
use App\Models\User;
use Illuminate\Database\UniqueConstraintViolationException;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Gate;
use Illuminate\Validation\ValidationException;
use Symfony\Component\HttpKernel\Exception\ConflictHttpException;

class StockMovementService
{
    public function append(User $actor, InventoryItem $target, array $input, string $key): StockMovement
    {
        Gate::forUser($actor)->authorize('movements', $target);
        if (array_diff(array_keys($input), ['reason', 'quantity_delta', 'note'])
            || ! preg_match('/\A[A-Za-z0-9][A-Za-z0-9._-]{7,63}\z/', $key)) {
            throw ValidationException::withMessages(['body' => 'Provide only supported movement fields and a valid idempotency key.']);
        }
        $reason = $input['reason'] ?? null;
        $note = $input['note'] ?? null;
        if ($note !== null && (! is_string($note) || mb_strlen($note) > 500)) {
            throw ValidationException::withMessages(['note' => 'The note must be a string of at most 500 characters.']);
        }
        $note = $note === null ? null : trim($note);
        try {
            $delta = Quantity::parse($input['quantity_delta'] ?? null, true);
        } catch (\InvalidArgumentException) {
            throw ValidationException::withMessages(['quantity_delta' => 'Provide an exact quantity string with at most four decimal places.']);
        }
        if ($delta === 0 || ! in_array($reason, ['opening_balance', 'receipt', 'waste', 'adjustment'], true)
            || (in_array($reason, ['opening_balance', 'receipt'], true) && $delta < 0)
            || ($reason === 'waste' && $delta > 0)) {
            throw ValidationException::withMessages(['quantity_delta' => 'The quantity sign must match a supported manual movement reason.']);
        }
        if ($reason === 'adjustment' && ($note === null || $note === '')) {
            throw ValidationException::withMessages(['note' => 'Describe why this adjustment is required.']);
        }
        $hash = hash('sha256', json_encode(['version' => 1, 'inventory_item_id' => $target->id, 'reason' => $reason,
            'quantity_delta' => Quantity::format($delta), 'note' => $note], JSON_THROW_ON_ERROR));
        try {
            return DB::transaction(function () use ($actor, $target, $key, $hash, $reason, $delta, $note): StockMovement {
                $item = InventoryItem::query()->whereKey($target->id)->lockForUpdate()->firstOrFail();
                Gate::forUser($actor)->authorize('movements', $item);
                $existing = StockMovement::query()->where('actor_id', $actor->id)->where('attempt_key', $key)->first();
                if ($existing) {
                    return $this->replay($existing, $hash);
                }
                if ($reason === 'opening_balance' && StockMovement::query()->where('inventory_item_id', $item->id)->exists()) {
                    throw new ConflictHttpException('Opening balance is allowed only before any stock movement history exists.');
                }
                try {
                    $onHand = Quantity::add(Quantity::parse($item->on_hand), $delta);
                } catch (\InvalidArgumentException) {
                    throw ValidationException::withMessages(['quantity_delta' => 'The resulting balance exceeds supported quantity bounds.']);
                }
                $reserved = Quantity::parse($item->reserved);
                if ($onHand < $reserved) {
                    throw new ConflictHttpException('This movement would use stock already reserved or make stock negative.');
                }
                $movement = new StockMovement;
                $movement->forceFill(['inventory_item_id' => $item->id, 'order_id' => null, 'actor_id' => $actor->id,
                    'quantity_delta' => Quantity::format($delta), 'reason' => $reason, 'note' => $note,
                    'operation_key' => 'manual:'.hash('sha256', $actor->id.'|'.$key),
                    'attempt_key' => $key, 'request_hash' => $hash, 'created_at' => now()])->save();
                $item->writeBalances($onHand, $reserved);

                return $movement;
            }, 3);
        } catch (UniqueConstraintViolationException $exception) {
            // Cross-item requests do not share a stock lock. Unique actor/key is the final arbiter.
            $existing = StockMovement::query()->where('actor_id', $actor->id)->where('attempt_key', $key)->first();
            if (! $existing) {
                throw $exception;
            }

            return $this->replay($existing, $hash);
        }
    }

    private function replay(StockMovement $movement, string $hash): StockMovement
    {
        if (! hash_equals($movement->request_hash, $hash)) {
            throw new ConflictHttpException('This movement key was used for different intent.');
        }

        return $movement;
    }
}
