<?php

namespace App\Services;

use App\Inventory\Quantity;
use App\Models\InventoryItem;
use App\Models\Order;
use App\Models\Payment;
use App\Models\StockMovement;
use App\Models\StockReservation;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;
use InvalidArgumentException;
use LogicException;
use OverflowException;
use Symfony\Component\HttpKernel\Exception\ConflictHttpException;

class StockReservationService
{
    /** Product shared locks must already be held; locking reads see the current recipe. */
    public function requirements(array $intent): array
    {
        $this->assertTransaction();
        $required = [];
        try {
            foreach ($intent as $line) {
                $recipe = DB::table('product_ingredients')->where('product_id', $line['product_id'])
                    ->orderBy('inventory_item_id')->sharedLock()->get();
                if ($recipe->isEmpty()) {
                    throw ValidationException::withMessages(['items' => 'A selected product has no inventory recipe.']);
                }
                foreach ($recipe as $ingredient) {
                    $quantity = Quantity::parse((string) $ingredient->quantity);
                    if ($quantity <= 0) {
                        throw new InvalidArgumentException('Invalid recipe quantity.');
                    }
                    $id = (int) $ingredient->inventory_item_id;
                    $required[$id] = Quantity::add($required[$id] ?? 0, Quantity::multiply($quantity, $line['quantity']));
                }
            }
        } catch (InvalidArgumentException|OverflowException) {
            throw ValidationException::withMessages(['items' => 'Inventory requirements exceed supported exact quantity bounds.']);
        }
        ksort($required, SORT_NUMERIC);

        return $required;
    }

    /** Lock before creating the order; IDs are always acquired in ascending order. */
    public function lockAvailable(array $required): void
    {
        $this->assertTransaction();
        foreach ($this->lockItems(array_keys($required)) as $id => $stock) {
            $available = Quantity::subtract(Quantity::parse($stock->on_hand), Quantity::parse($stock->reserved));
            if (! $stock->is_active || $required[$id] <= 0 || $available < $required[$id]) {
                throw ValidationException::withMessages(['items' => "Insufficient available stock for inventory item {$id}."]);
            }
        }
    }

    public function reserve(Order $order, array $required): void
    {
        $this->assertTransaction();
        if (! $order->inventory_tracked || $required === []) {
            throw new LogicException('Tracked checkout requires reservation quantities.');
        }
        foreach ($this->lockItems(array_keys($required)) as $id => $stock) {
            $onHand = Quantity::parse($stock->on_hand);
            $reserved = Quantity::add(Quantity::parse($stock->reserved), $required[$id]);
            if (! $stock->is_active || $required[$id] <= 0 || $reserved > $onHand) {
                throw ValidationException::withMessages(['items' => "Insufficient available stock for inventory item {$id}."]);
            }
            $reservation = new StockReservation;
            $reservation->forceFill(['order_id' => $order->id, 'inventory_item_id' => $id,
                'quantity' => Quantity::format($required[$id]), 'status' => 'reserved'])->save();
            $stock->writeBalances($onHand, $reserved);
        }
    }

    public function consume(Order $order, Payment $payment): void
    {
        $this->transition($order, 'consumed', $payment);
    }

    public function release(Order $order): void
    {
        $this->transition($order, 'released');
    }

    private function transition(Order $order, string $status, ?Payment $payment = null): void
    {
        $this->assertTransaction();
        if (! $order->inventory_tracked) {
            return;
        }
        // Order locks serialize all lifecycle changes; reservation quantities never change.
        $ids = DB::table('stock_reservations')->where('order_id', $order->id)->orderBy('inventory_item_id')
            ->pluck('inventory_item_id')->all();
        if ($ids === []) {
            throw new ConflictHttpException('Tracked order has no valid stock reservations.');
        }
        $stocks = $this->lockItems($ids);
        $reservations = StockReservation::query()->where('order_id', $order->id)->orderBy('inventory_item_id')->lockForUpdate()->get();
        foreach ($reservations as $reservation) {
            $stock = $stocks[$reservation->inventory_item_id];
            $quantity = Quantity::parse($reservation->quantity);
            $onHand = Quantity::parse($stock->on_hand);
            $reserved = Quantity::parse($stock->reserved);
            if ($reservation->status !== 'reserved' || $quantity <= 0 || $reserved < $quantity || $onHand < $reserved) {
                throw new ConflictHttpException('Stock reservation cannot be finalized; inventory review is required.');
            }
            if ($status === 'consumed') {
                $movement = new StockMovement;
                $movement->forceFill(['inventory_item_id' => $stock->id, 'order_id' => $order->id,
                    'actor_id' => $payment?->initiated_by, 'reason' => 'sale',
                    'quantity_delta' => Quantity::format(-$quantity),
                    'operation_key' => 'sale:'.$order->id.':'.$stock->id, 'created_at' => now()])->save();
                $onHand = Quantity::subtract($onHand, $quantity);
            }
            $stock->writeBalances($onHand, Quantity::subtract($reserved, $quantity));
            $reservation->transitionTo($status);
        }
    }

    private function lockItems(array $ids): array
    {
        sort($ids, SORT_NUMERIC);
        $stocks = [];
        foreach ($ids as $id) {
            $stock = InventoryItem::query()->whereKey($id)->lockForUpdate()->first();
            if (! $stock) {
                throw new ConflictHttpException('A required inventory item is missing.');
            }
            $stocks[(int) $id] = $stock;
        }

        return $stocks;
    }

    private function assertTransaction(): void
    {
        if (DB::transactionLevel() < 1) {
            throw new LogicException('Stock reservation changes require an owning workflow transaction.');
        }
    }
}
