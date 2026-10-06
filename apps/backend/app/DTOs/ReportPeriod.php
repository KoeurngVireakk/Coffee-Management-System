<?php

namespace App\DTOs;

use Carbon\CarbonImmutable;

final class ReportPeriod
{
    public function __construct(
        public readonly string $fromDate,
        public readonly string $toDate,
        public readonly string $timezone,
        public readonly CarbonImmutable $fromUtc,
        public readonly CarbonImmutable $toExclusiveUtc,
    ) {}

    /**
     * @return array{from_date: string, to_date: string, timezone: string}
     */
    public function toArray(): array
    {
        return [
            'from_date' => $this->fromDate,
            'to_date' => $this->toDate,
            'timezone' => $this->timezone,
        ];
    }
}
