<?php

namespace App\Settings;

use DateTimeZone;
use Illuminate\Validation\ValidationException;

class SettingRegistry
{
    public const string SHOP_NAME = 'shop_name';

    public const string SHOP_TIMEZONE = 'shop_timezone';

    /**
     * @var list<string>
     */
    public const array ALLOWED_KEYS = [
        self::SHOP_NAME,
        self::SHOP_TIMEZONE,
    ];

    public static function isAllowed(string $key): bool
    {
        return in_array($key, self::ALLOWED_KEYS, true);
    }

    /**
     * Validate and normalize a setting value.
     *
     * @throws ValidationException
     */
    public static function validate(string $key, mixed $value): mixed
    {
        if (! self::isAllowed($key)) {
            throw ValidationException::withMessages([
                'key' => ["The setting key [{$key}] is not supported."],
            ]);
        }

        return match ($key) {
            self::SHOP_NAME => self::validateShopName($value),
            self::SHOP_TIMEZONE => self::validateShopTimezone($value),
        };
    }

    /**
     * @throws ValidationException
     */
    private static function validateShopName(mixed $value): string
    {
        if (! is_string($value) || trim($value) === '') {
            throw ValidationException::withMessages([
                'value' => ['The shop name must be a non-empty string.'],
            ]);
        }

        $trimmed = trim($value);

        if (mb_strlen($trimmed) > 120) {
            throw ValidationException::withMessages([
                'value' => ['The shop name must not exceed 120 characters.'],
            ]);
        }

        return $trimmed;
    }

    /**
     * @throws ValidationException
     */
    private static function validateShopTimezone(mixed $value): string
    {
        if (! is_string($value) || trim($value) === '') {
            throw ValidationException::withMessages([
                'value' => ['The shop timezone must be a valid non-empty string.'],
            ]);
        }

        $trimmed = trim($value);

        if (! in_array($trimmed, DateTimeZone::listIdentifiers(), true)) {
            throw ValidationException::withMessages([
                'value' => ['The shop timezone must be a valid IANA timezone identifier.'],
            ]);
        }

        return $trimmed;
    }
}

