<?php

namespace App\Policies;

use App\Models\User;

class UserPolicy
{
    public function viewAny(User $actor): bool
    {
        return $actor->isActiveStaff() && $actor->can('manage-staff');
    }

    public function view(User $actor, User $subject): bool
    {
        return $actor->isActiveStaff()
            && ($actor->is($subject) || $actor->can('manage-staff'));
    }

    public function create(User $actor): bool
    {
        return $actor->isActiveStaff() && $actor->can('manage-staff');
    }

    public function update(User $actor, User $subject): bool
    {
        return $actor->isActiveStaff() && $actor->can('manage-staff');
    }

    public function resetPassword(User $actor, User $subject): bool
    {
        return $actor->isActiveStaff() && $actor->can('manage-staff');
    }

    public function revokeTokens(User $actor, User $subject): bool
    {
        return $actor->isActiveStaff() && $actor->can('manage-staff');
    }
}
