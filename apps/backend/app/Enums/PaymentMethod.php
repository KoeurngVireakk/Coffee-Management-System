<?php

namespace App\Enums;

enum PaymentMethod: string
{
    case Cash = 'cash';
    case External = 'external';
}
