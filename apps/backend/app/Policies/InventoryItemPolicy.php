<?php

namespace App\Policies;

use App\Models\InventoryItem;
use App\Models\User;

class InventoryItemPolicy
{
    public function viewAny(User $user): bool
    {
        return $user->can('view-inventory');
    }

    public function view(User $user, InventoryItem $item): bool
    {
        return $user->can('view-inventory');
    }

    public function create(User $user): bool
    {
        return $user->can('adjust-inventory');
    }

    public function update(User $user, InventoryItem $item): bool
    {
        return $user->can('adjust-inventory');
    }

    public function movements(User $user, InventoryItem $item): bool
    {
        return $user->can('adjust-inventory');
    }
}
