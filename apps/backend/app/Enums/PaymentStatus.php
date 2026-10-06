<?php

namespace App\Enums;

enum PaymentStatus: string
{
    case Initiated = 'initiated';
    case Pending = 'pending';
    case Confirmed = 'confirmed';
    case Failed = 'failed';
    case Expired = 'expired';
    case Uncertain = 'uncertain';
}
