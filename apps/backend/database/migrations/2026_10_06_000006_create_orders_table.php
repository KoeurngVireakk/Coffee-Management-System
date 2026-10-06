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
        Schema::create('orders', function (Blueprint $table) use ($mysql): void {
            $table->id();
            $reference = $table->string('public_reference', 40)->unique();
            $table->foreignId('created_by')->constrained('users')->restrictOnDelete();
            $status = $table->string('status', 24)->default('pending_payment');
            $currency = $table->char('currency', 3);
            $table->bigInteger('subtotal_minor');
            $table->bigInteger('discount_minor')->default(0);
            $table->bigInteger('tax_minor')->default(0);
            $table->bigInteger('total_minor');
            $key = $table->string('checkout_key', 64);
            $hash = $table->char('request_hash', 64);
            if ($mysql) {
                foreach ([$reference, $status, $currency, $key, $hash] as $column) {
                    $column->collation('utf8mb4_bin');
                }
            }
            $table->boolean('inventory_tracked')->default(false);
            $table->timestamps();
            $table->unique(['created_by', 'checkout_key']);
            $table->index(['created_by', 'created_at', 'id']);
            $table->index(['created_at', 'id']);
            $table->index(['status', 'created_at', 'id']);
        });

        if ($mysql) {
            DB::statement("ALTER TABLE orders ADD CONSTRAINT orders_status_check CHECK (status IN ('pending_payment','paid','cancelled','expired'))");
            DB::statement("ALTER TABLE orders ADD CONSTRAINT orders_currency_check CHECK (currency = 'USD')");
            DB::statement('ALTER TABLE orders ADD CONSTRAINT orders_money_check CHECK (subtotal_minor BETWEEN 0 AND 4949995050 AND discount_minor = 0 AND tax_minor = 0 AND total_minor = subtotal_minor)');
            DB::statement('ALTER TABLE orders ADD CONSTRAINT orders_inventory_flag_check CHECK (inventory_tracked IN (0,1))');
        }
    }

    public function down(): void
    {
        Schema::dropIfExists('orders');
    }
};
