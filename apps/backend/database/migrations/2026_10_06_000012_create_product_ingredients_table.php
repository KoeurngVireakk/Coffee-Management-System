<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('product_ingredients', function (Blueprint $table): void {
            $table->foreignId('product_id')->constrained()->restrictOnDelete();
            $table->foreignId('inventory_item_id')->constrained()->restrictOnDelete();
            $table->decimal('quantity', 14, 4);
            $table->primary(['product_id', 'inventory_item_id']);
        });
        if (DB::getDriverName() === 'mysql') {
            DB::statement('ALTER TABLE product_ingredients ADD CONSTRAINT product_ingredients_quantity_check CHECK (quantity > 0)');
        }
    }

    public function down(): void
    {
        Schema::dropIfExists('product_ingredients');
    }
};
