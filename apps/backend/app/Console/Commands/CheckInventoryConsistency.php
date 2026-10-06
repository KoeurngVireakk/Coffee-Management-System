<?php

namespace App\Console\Commands;

use App\Services\InventoryConsistencyService;
use Illuminate\Console\Command;

class CheckInventoryConsistency extends Command
{
    protected $signature = 'inventory:check {--json : Emit bounded structured diagnostic results}';

    protected $description = 'Check stock balances, reservations, and sale movements without changing data';

    public function handle(InventoryConsistencyService $service): int
    {
        $report = $service->audit();
        if ($this->option('json')) {
            $this->line(json_encode($report, JSON_THROW_ON_ERROR));
        } else {
            $this->line('Checked '.$report['items_checked'].' inventory items and '.$report['orders_checked'].' orders.');
            foreach ($report['findings'] as $finding) {
                $this->line(json_encode($finding, JSON_THROW_ON_ERROR));
            }
            $this->line('Discrepancies: '.$report['finding_count'].'. No data was changed.');
        }

        return $report['finding_count'] === 0 ? self::SUCCESS : self::FAILURE;
    }
}
