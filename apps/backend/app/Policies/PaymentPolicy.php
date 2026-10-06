<?php

namespace App\Policies;

use App\Models\Payment;
use App\Models\User;

class PaymentPolicy
{
    public function view(User $user, Payment $payment): bool
    {
        return $user->can('view', $payment->order);
    }

    public function reconcile(User $user, Payment $payment): bool
    {
        return $user->can('pay', $payment->order);
    }
}
