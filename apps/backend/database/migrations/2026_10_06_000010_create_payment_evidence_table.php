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
        Schema::create('payment_evidence', function (Blueprint $table) use ($mysql): void {
            $table->id();
            $table->foreignId('payment_id')->constrained()->restrictOnDelete();
            foreach (['provider' => 64, 'external_transaction_id' => 191, 'correlation_reference' => 191, 'merchant_reference' => 191, 'order_reference' => 40] as $name => $length) {
                $column = $table->string($name, $length);
                if ($mysql) {
                    $column->collation('utf8mb4_bin');
                }
            }
            $table->bigInteger('amount_minor');
            $table->char('currency', 3);
            $table->timestamp('verified_at');
            $table->timestamp('created_at');
            $table->unique(['provider', 'external_transaction_id']);
        });
        if ($mysql) {
            DB::statement('ALTER TABLE payment_evidence ADD CONSTRAINT payment_evidence_money_check CHECK (amount_minor >= 0)');
        }
    }

    public function down(): void
    {
        Schema::dropIfExists('payment_evidence');
    }
};
