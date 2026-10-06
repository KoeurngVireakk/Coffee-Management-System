<?php

namespace App\Policies;

use App\Models\Product;
use App\Models\User;
use Illuminate\Auth\Access\Response;

class ProductPolicy
{
    public function viewAny(User $user): bool
    {
        return $user->can('view-catalog');
    }

    public function view(User $user, Product $product): Response
    {
        if (! $user->can('view-catalog')) {
            return Response::deny();
        }

        return $user->can('manage-catalog') || $product->isSellable()
            ? Response::allow() : Response::denyAsNotFound();
    }

    public function create(User $user): bool
    {
        return $user->can('manage-catalog');
    }

    public function update(User $user, Product $product): bool
    {
        return $user->can('manage-catalog');
    }
}
