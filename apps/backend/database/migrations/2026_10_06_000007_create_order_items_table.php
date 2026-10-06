<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('order_items', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('order_id')->constrained()->restrictOnDelete();
            $table->unsignedSmallInteger('line_number');
            $table->foreignId('product_id')->constrained()->restrictOnDelete();
            $table->string('product_name', 160);
            $table->string('product_sku', 64);
            $table->bigInteger('unit_price_minor');
            $table->unsignedSmallInteger('quantity');
            $table->bigInteger('subtotal_minor');
            $table->bigInteger('discount_minor')->default(0);
            $table->bigInteger('tax_minor')->default(0);
            $table->bigInteger('line_total_minor');
            $table->unique(['order_id', 'line_number']);
            $table->unique(['order_id', 'product_id']);
        });

        if (DB::getDriverName() === 'mysql') {
            DB::statement('ALTER TABLE order_items ADD CONSTRAINT order_items_quantity_check CHECK (quantity BETWEEN 1 AND 99 AND line_number BETWEEN 1 AND 50)');
            DB::statement('ALTER TABLE order_items ADD CONSTRAINT order_items_money_check CHECK (unit_price_minor BETWEEN 0 AND 999999 AND subtotal_minor = unit_price_minor * quantity AND discount_minor = 0 AND tax_minor = 0 AND line_total_minor = subtotal_minor)');
        }
    }

    public function down(): void
    {
        Schema::dropIfExists('order_items');
    }
};
