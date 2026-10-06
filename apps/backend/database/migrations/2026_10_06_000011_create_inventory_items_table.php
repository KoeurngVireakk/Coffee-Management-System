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
        Schema::create('inventory_items', function (Blueprint $table) use ($mysql): void {
            $table->id();
            $table->string('sku', 64)->collation($mysql ? 'utf8mb4_unicode_ci' : 'NOCASE')->unique();
            $table->string('name', 160);
            $unit = $table->string('base_unit', 8);
            if ($mysql) {
                $unit->collation('utf8mb4_bin');
            }
            $table->decimal('on_hand', 14, 4)->default(0);
            $table->decimal('reserved', 14, 4)->default(0);
            $table->decimal('reorder_level', 14, 4)->default(0);
            $table->boolean('is_active')->default(true);
            $table->timestamps();
            $table->index(['is_active', 'name', 'id']);
            $table->index(['name', 'id']);
        });
        if ($mysql) {
            DB::statement("ALTER TABLE inventory_items ADD CONSTRAINT inventory_items_unit_check CHECK (base_unit IN ('g','ml','unit'))");
            DB::statement('ALTER TABLE inventory_items ADD CONSTRAINT inventory_items_balances_check CHECK (on_hand >= 0 AND reserved >= 0 AND reserved <= on_hand AND reorder_level >= 0)');
        }
    }

    public function down(): void
    {
        Schema::dropIfExists('inventory_items');
    }
};
