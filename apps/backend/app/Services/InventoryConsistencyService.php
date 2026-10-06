<?php

namespace App\Services;

use App\Inventory\Quantity;
use Illuminate\Support\Facades\DB;
use LogicException;
use Throwable;

/** Read-only diagnostics. Corrections require a separate approved workflow. */
class InventoryConsistencyService
{
    public function audit(): array
    {
        if (DB::transactionLevel() !== 0) {
            throw new LogicException('Inventory consistency checks require an independent database snapshot.');
        }
        if (DB::getDriverName() === 'mysql') {
            DB::statement('SET TRANSACTION ISOLATION LEVEL REPEATABLE READ, READ ONLY');
        }

        return DB::transaction(function (): array {
            $report = ['items_checked' => 0, 'orders_checked' => 0, 'finding_count' => 0, 'findings' => []];
            $finding = function (string $code, array $ids) use (&$report): void {
                $report['finding_count']++;
                // Bound command output, while retaining the full number of discrepancies.
                if (count($report['findings']) < 100) {
                    $report['findings'][] = ['code' => $code, ...$ids];
                }
            };
            DB::table('inventory_items')->orderBy('id')->chunkById(200, function ($items) use (&$report, $finding): void {
                $ids = $items->pluck('id')->all();
                $ledgers = $reserved = [];
                foreach ($ids as $id) {
                    $ledgers[$id] = $reserved[$id] = 0;
                }
                foreach (DB::table('stock_movements')->whereIn('inventory_item_id', $ids)->orderBy('id')->cursor() as $movement) {
                    try {
                        $ledgers[$movement->inventory_item_id] = Quantity::add($ledgers[$movement->inventory_item_id], Quantity::parse((string) $movement->quantity_delta, true));
                    } catch (Throwable) {
                        $finding('invalid_movement_quantity', ['movement_id' => $movement->id, 'inventory_item_id' => $movement->inventory_item_id]);
                    }
                }
                foreach (DB::table('stock_reservations')->whereIn('inventory_item_id', $ids)->where('status', 'reserved')->orderBy('order_id')->orderBy('inventory_item_id')->cursor() as $reservation) {
                    try {
                        $reserved[$reservation->inventory_item_id] = Quantity::add($reserved[$reservation->inventory_item_id], Quantity::parse((string) $reservation->quantity));
                    } catch (Throwable) {
                        $finding('invalid_reserved_quantity', ['order_id' => $reservation->order_id, 'inventory_item_id' => $reservation->inventory_item_id]);
                    }
                }
                foreach ($items as $item) {
                    $report['items_checked']++;
                    try {
                        $onHand = Quantity::parse((string) $item->on_hand);
                        $balanceReserved = Quantity::parse((string) $item->reserved);
                        Quantity::parse((string) $item->reorder_level);
                        if ($onHand < $balanceReserved) {
                            $finding('negative_available', ['inventory_item_id' => $item->id]);
                        }
                        if ($onHand !== $ledgers[$item->id]) {
                            $finding('on_hand_ledger_mismatch', ['inventory_item_id' => $item->id]);
                        }
                        if ($balanceReserved !== $reserved[$item->id]) {
                            $finding('reserved_balance_mismatch', ['inventory_item_id' => $item->id]);
                        }
                    } catch (Throwable) {
                        $finding('invalid_item_quantity', ['inventory_item_id' => $item->id]);
                    }
                }
            });

            DB::table('orders')->orderBy('id')->chunkById(200, function ($orders) use (&$report, $finding): void {
                $ids = $orders->pluck('id')->all();
                $reservations = DB::table('stock_reservations')->whereIn('order_id', $ids)->orderBy('inventory_item_id')->get()->groupBy('order_id');
                $sales = DB::table('stock_movements')->whereIn('order_id', $ids)->orderBy('id')->get()->groupBy('order_id');
                foreach ($orders as $order) {
                    $report['orders_checked']++;
                    $requirements = $reservations->get($order->id, collect());
                    $orderSales = $sales->get($order->id, collect());
                    if (! $order->inventory_tracked) {
                        if ($requirements->isNotEmpty() || $orderSales->isNotEmpty()) {
                            $finding('untracked_order_inventory_effect', ['order_id' => $order->id]);
                        }

                        continue;
                    }
                    if ($requirements->isEmpty()) {
                        $finding('tracked_order_missing_reservations', ['order_id' => $order->id]);
                    }
                    $expectedState = match ($order->status) {
                        'pending_payment' => 'reserved', 'paid' => 'consumed', 'cancelled' => 'released', default => null,
                    };
                    if ($expectedState === null) {
                        $finding('tracked_order_invalid_lifecycle', ['order_id' => $order->id]);
                    }
                    foreach ($requirements as $reservation) {
                        $context = ['order_id' => $order->id, 'inventory_item_id' => $reservation->inventory_item_id];
                        if ($reservation->status !== $expectedState) {
                            $finding('reservation_order_state_mismatch', $context);
                        }
                        $matchingSales = $orderSales->where('inventory_item_id', $reservation->inventory_item_id);
                        if ($order->status === 'paid') {
                            $valid = $matchingSales->count() === 1;
                            if ($valid) {
                                $sale = $matchingSales->first();
                                try {
                                    $valid = Quantity::parse((string) $reservation->quantity) > 0 && $sale->reason === 'sale'
                                        && $sale->operation_key === 'sale:'.$order->id.':'.$reservation->inventory_item_id
                                        && Quantity::parse((string) $sale->quantity_delta, true) === -Quantity::parse((string) $reservation->quantity);
                                } catch (Throwable) {
                                    $valid = false;
                                }
                            }
                            if (! $valid) {
                                $finding('consumption_sale_mismatch', $context);
                            }
                        } elseif ($matchingSales->isNotEmpty()) {
                            $finding('nonpaid_order_sale', $context);
                        }
                    }
                    foreach ($orderSales as $sale) {
                        if (! $requirements->contains('inventory_item_id', $sale->inventory_item_id)) {
                            $finding('sale_without_reservation', ['order_id' => $order->id, 'inventory_item_id' => $sale->inventory_item_id]);
                        }
                    }
                }
            });
            foreach (DB::table('stock_movements')->where('reason', 'sale')->whereNull('order_id')->orderBy('id')->cursor() as $sale) {
                $finding('sale_missing_order', ['movement_id' => $sale->id, 'inventory_item_id' => $sale->inventory_item_id]);
            }

            return $report;
        });
    }
}
