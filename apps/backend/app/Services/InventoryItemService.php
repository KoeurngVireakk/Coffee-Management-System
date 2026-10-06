<?php

namespace App\Services;

use App\Inventory\Quantity;
use App\Models\InventoryItem;
use App\Models\User;
use Illuminate\Database\UniqueConstraintViolationException;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Gate;
use Illuminate\Validation\ValidationException;

class InventoryItemService
{
    public function create(User $actor, array $input): InventoryItem
    {
        Gate::forUser($actor)->authorize('create', InventoryItem::class);
        if (array_diff(array_keys($input), ['sku', 'name', 'base_unit', 'reorder_level', 'is_active'])) {
            throw ValidationException::withMessages(['body' => 'Only inventory metadata may be provided.']);
        }
        $input['reorder_level'] = Quantity::format(Quantity::parse($input['reorder_level'] ?? '0'));
        try {
            $item = new InventoryItem;
            $item->forceFill([...$input, 'on_hand' => '0.0000', 'reserved' => '0.0000', 'is_active' => $input['is_active'] ?? true])->save();

            return $item->refresh();
        } catch (UniqueConstraintViolationException) {
            throw ValidationException::withMessages(['sku' => 'The SKU is already in use.']);
        }
    }

    public function update(User $actor, InventoryItem $target, array $input): InventoryItem
    {
        Gate::forUser($actor)->authorize('update', $target);
        if (array_diff(array_keys($input), ['sku', 'name', 'reorder_level', 'is_active'])) {
            throw ValidationException::withMessages(['body' => 'Only editable inventory metadata may be provided.']);
        }
        if (isset($input['reorder_level'])) {
            $input['reorder_level'] = Quantity::format(Quantity::parse($input['reorder_level']));
        }
        try {
            return DB::transaction(function () use ($actor, $target, $input): InventoryItem {
                $item = InventoryItem::query()->whereKey($target->id)->lockForUpdate()->firstOrFail();
                Gate::forUser($actor)->authorize('update', $item);
                $item->forceFill($input)->save();

                return $item;
            }, 3);
        } catch (UniqueConstraintViolationException) {
            throw ValidationException::withMessages(['sku' => 'The SKU is already in use.']);
        }
    }
}
