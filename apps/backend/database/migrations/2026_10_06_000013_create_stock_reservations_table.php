<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        $mysql = DB::getDriverName() === 'mysql';
        Schema::create('stock_reservations', function (Blueprint $table) use ($mysql): void {
            $table->foreignId('order_id')->constrained()->restrictOnDelete();
            $table->foreignId('inventory_item_id')->constrained()->restrictOnDelete();
            $table->decimal('quantity', 14, 4);
            $status = $table->string('status', 16)->default('reserved');
            if ($mysql) {
                $status->collation('utf8mb4_bin');
            }
            $table->timestamps();
            $table->primary(['order_id', 'inventory_item_id']);
            $table->index(['inventory_item_id', 'status', 'order_id']);
        });
        if ($mysql) {
            DB::statement('ALTER TABLE stock_reservations ADD CONSTRAINT stock_reservations_quantity_check CHECK (quantity > 0)');
            DB::statement("ALTER TABLE stock_reservations ADD CONSTRAINT stock_reservations_status_check CHECK (status IN ('reserved','consumed','released'))");
        }
    }

    public function down(): void
    {
        Schema::dropIfExists('stock_reservations');
    }
};
