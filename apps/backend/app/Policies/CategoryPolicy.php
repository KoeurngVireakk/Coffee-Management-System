<?php

namespace App\Policies;

use App\Models\Category;
use App\Models\User;
use Illuminate\Auth\Access\Response;

class CategoryPolicy
{
    public function viewAny(User $user): bool
    {
        return $user->can('view-catalog');
    }

    public function view(User $user, Category $category): Response
    {
        if (! $user->can('view-catalog')) {
            return Response::deny();
        }

        return $category->is_active || $user->can('manage-catalog')
            ? Response::allow() : Response::denyAsNotFound();
    }

    public function create(User $user): bool
    {
        return $user->can('manage-catalog');
    }

    public function update(User $user, Category $category): bool
    {
        return $user->can('manage-catalog');
    }
}
