<?php

namespace App\Rules;

use Closure;
use DateTimeImmutable;
use Illuminate\Contracts\Validation\ValidationRule;

class AbsoluteTimestamp implements ValidationRule
{
    public function validate(string $attribute, mixed $value, Closure $fail): void
    {
        if (! is_string($value) || ! preg_match('/\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,6})?(?:Z|[+-](?:0[0-9]|1[0-4]):[0-5][0-9])\z/', $value)) {
            $fail('Use an ISO 8601 timestamp with seconds and an explicit UTC offset.');

            return;
        }
        $format = '!Y-m-d\TH:i:s'.(str_contains($value, '.') ? '.u' : '').'P';
        $date = DateTimeImmutable::createFromFormat($format, $value);
        $errors = DateTimeImmutable::getLastErrors();
        if (! $date || ($errors && ($errors['warning_count'] || $errors['error_count'])) || abs($date->getOffset()) > 14 * 3600) {
            $fail('Use a valid calendar timestamp and UTC offset.');
        }
    }
}
