<?php

namespace Tests\Feature;

use App\Models\InventoryItem;
use App\Models\Order;
use App\Models\StockReservation;
use Illuminate\Foundation\Testing\DatabaseMigrations;
use LogicException;
use Tests\TestCase;

class InventoryWorkflowGuardTest extends TestCase
{
    use DatabaseMigrations;

    public function test_balances_cannot_be_updated_outside_transaction(): void
    {
        $item = InventoryItem::factory()->create();
        $this->expectException(LogicException::class);
        $item->writeBalances(10000, 0);
    }

    public function test_reservations_cannot_transition_outside_transaction(): void
    {
        $reservation = new StockReservation;
        $reservation->forceFill(['order_id' => Order::factory()->create()->id,
            'inventory_item_id' => InventoryItem::factory()->create()->id,
            'quantity' => '1.0000', 'status' => 'reserved'])->save();
        $this->expectException(LogicException::class);
        $reservation->transitionTo('consumed');
    }
}
