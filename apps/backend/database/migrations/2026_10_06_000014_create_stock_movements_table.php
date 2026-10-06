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
        Schema::create('stock_movements', function (Blueprint $table) use ($mysql): void {
            $table->id();
            $table->foreignId('inventory_item_id')->constrained()->restrictOnDelete();
            $table->foreignId('order_id')->nullable()->constrained()->restrictOnDelete();
            $table->foreignId('actor_id')->nullable()->constrained('users')->restrictOnDelete();
            $table->decimal('quantity_delta', 14, 4);
            foreach (['reason' => 24, 'operation_key' => 100, 'request_hash' => 64, 'attempt_key' => 64] as $name => $length) {
                $column = $table->string($name, $length);
                if (in_array($name, ['request_hash', 'attempt_key'], true)) {
                    $column->nullable();
                }
                if ($mysql) {
                    $column->collation('utf8mb4_bin');
                }
            }
            $table->string('note', 500)->nullable();
            $table->timestamp('created_at');
            $table->unique('operation_key');
            $table->unique(['actor_id', 'attempt_key']);
            $table->index(['inventory_item_id', 'created_at', 'id']);
            $table->index(['order_id', 'inventory_item_id']);
        });
        if ($mysql) {
            DB::statement("ALTER TABLE stock_movements ADD CONSTRAINT stock_movements_reason_check CHECK (reason IN ('opening_balance','receipt','waste','adjustment','sale'))");
            DB::statement("ALTER TABLE stock_movements ADD CONSTRAINT stock_movements_sign_check CHECK ((reason IN ('opening_balance','receipt') AND quantity_delta > 0) OR (reason IN ('waste','sale') AND quantity_delta < 0) OR (reason='adjustment' AND quantity_delta <> 0 AND note IS NOT NULL AND CHAR_LENGTH(TRIM(note)) > 0))");
            DB::statement("ALTER TABLE stock_movements ADD CONSTRAINT stock_movements_origin_check CHECK ((reason='sale' AND order_id IS NOT NULL AND attempt_key IS NULL AND request_hash IS NULL) OR (reason<>'sale' AND order_id IS NULL AND actor_id IS NOT NULL AND attempt_key IS NOT NULL AND request_hash IS NOT NULL))");
        }
    }

    public function down(): void
    {
        Schema::dropIfExists('stock_movements');
    }
};
