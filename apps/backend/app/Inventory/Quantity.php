<?php

namespace App\Inventory;

use InvalidArgumentException;

/** Exact DECIMAL(14,4) arithmetic; scaled values always fit native 64-bit integers. */
final class Quantity
{
    public const int SCALE = 10000;

    public const int MAX_SCALED = 99999999999999;

    public static function parse(mixed $value, bool $signed = false): int
    {
        $pattern = $signed ? '/\A(-?)(0|[1-9][0-9]{0,9})(?:\.([0-9]{1,4}))?\z/' : '/\A()(0|[1-9][0-9]{0,9})(?:\.([0-9]{1,4}))?\z/';
        if (! is_string($value) || ! preg_match($pattern, $value, $parts)) {
            throw new InvalidArgumentException('Quantity must be an exact decimal string with at most four decimal places.');
        }
        $scaled = ((int) $parts[2] * self::SCALE) + (int) str_pad($parts[3] ?? '', 4, '0');
        if ($parts[1] === '-') {
            if ($scaled === 0) {
                throw new InvalidArgumentException('Negative zero is not a canonical quantity.');
            }
            $scaled = -$scaled;
        }

        return self::checked($scaled);
    }

    public static function format(mixed $scaled): string
    {
        self::checked($scaled);
        $absolute = abs($scaled);

        return ($scaled < 0 ? '-' : '').intdiv($absolute, self::SCALE).'.'.str_pad((string) ($absolute % self::SCALE), 4, '0', STR_PAD_LEFT);
    }

    public static function add(mixed $left, mixed $right): int
    {
        self::checked($left);
        self::checked($right);

        return self::checked($left + $right);
    }

    public static function subtract(mixed $left, mixed $right): int
    {
        self::checked($left);
        self::checked($right);

        return self::checked($left - $right);
    }

    public static function multiply(mixed $quantity, mixed $wholeUnits): int
    {
        self::checked($quantity);
        if (! is_int($wholeUnits) || $wholeUnits < 0 || ($quantity !== 0 && $wholeUnits > intdiv(self::MAX_SCALED, abs($quantity)))) {
            throw new InvalidArgumentException('Quantity multiplication exceeds DECIMAL(14,4) capacity.');
        }

        return self::checked($quantity * $wholeUnits);
    }

    private static function checked(mixed $scaled): int
    {
        if (! is_int($scaled) || $scaled < -self::MAX_SCALED || $scaled > self::MAX_SCALED) {
            throw new InvalidArgumentException('Quantity exceeds DECIMAL(14,4) capacity.');
        }

        return $scaled;
    }
}
