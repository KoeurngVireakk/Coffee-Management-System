<?php

namespace App\Policies;

use App\Models\Order;
use App\Models\User;
use Illuminate\Auth\Access\Response;

class OrderPolicy
{
    public function create(User $user): bool
    {
        return $user->can('process-pos');
    }

    public function viewAny(User $user): bool
    {
        return $user->can('view-own-orders') || $user->can('view-all-orders');
    }

    public function view(User $user, Order $order): Response
    {
        return $user->can('view-all-orders') || ($user->id === $order->created_by && $user->can('view-own-orders'))
            ? Response::allow() : Response::denyAsNotFound();
    }

    public function pay(User $user, Order $order): Response
    {
        return $user->can('process-pos') && $this->view($user, $order)->allowed()
            ? Response::allow() : Response::denyAsNotFound();
    }
}
