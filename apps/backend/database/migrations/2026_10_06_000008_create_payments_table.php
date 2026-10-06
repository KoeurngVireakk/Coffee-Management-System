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
        Schema::create('payments', function (Blueprint $table) use ($mysql): void {
            $table->id();
            $table->foreignId('order_id')->constrained()->restrictOnDelete();
            $table->foreignId('initiated_by')->nullable()->constrained('users')->restrictOnDelete();
            foreach (['attempt_key' => 64, 'request_hash' => 64, 'method' => 16, 'status' => 24] as $name => $length) {
                $column = $table->string($name, $length);
                if ($mysql) {
                    $column->collation('utf8mb4_bin');
                }
            }
            foreach (['provider' => 64, 'external_transaction_id' => 191, 'correlation_reference' => 191, 'merchant_reference' => 191] as $name => $length) {
                $column = $table->string($name, $length)->nullable();
                if ($mysql) {
                    $column->collation('utf8mb4_bin');
                }
            }
            $table->bigInteger('expected_amount_minor');
            $currency = $table->char('currency', 3);
            if ($mysql) {
                $currency->collation('utf8mb4_bin');
            }
            $table->bigInteger('tender_minor')->nullable();
            $table->bigInteger('change_minor')->nullable();
            $table->boolean('reconciliation_required')->default(false);
            $table->string('reconciliation_reason', 64)->nullable();
            $table->text('qr_payload')->nullable();
            $table->timestamp('expires_at')->nullable();
            $table->timestamp('verified_at')->nullable();
            $table->timestamps();
            $table->unique(['order_id', 'attempt_key']);
            $table->unique(['provider', 'external_transaction_id']);
            $table->unique(['provider', 'correlation_reference']);
            $table->unique(['order_id', 'id']);
            $table->index(['status', 'updated_at', 'id']);
            $table->index(['reconciliation_required', 'updated_at', 'id']);
        });
        if ($mysql) {
            DB::statement("ALTER TABLE payments ADD CONSTRAINT payments_method_check CHECK (method IN ('cash','external'))");
            DB::statement("ALTER TABLE payments ADD CONSTRAINT payments_status_check CHECK (status IN ('initiated','pending','confirmed','failed','expired','uncertain'))");
            DB::statement("ALTER TABLE payments ADD CONSTRAINT payments_money_check CHECK (expected_amount_minor BETWEEN 0 AND 4949995050 AND currency='USD')");
            DB::statement("ALTER TABLE payments ADD CONSTRAINT payments_cash_check CHECK ((method='cash' AND tender_minor IS NOT NULL AND change_minor IS NOT NULL AND tender_minor BETWEEN expected_amount_minor AND 9999999999 AND change_minor=tender_minor-expected_amount_minor) OR (method='external' AND tender_minor IS NULL AND change_minor IS NULL))");
            DB::statement("ALTER TABLE payments ADD CONSTRAINT payments_confirmation_check CHECK (status<>'confirmed' OR (verified_at IS NOT NULL AND (method='cash' OR (provider IS NOT NULL AND external_transaction_id IS NOT NULL AND merchant_reference IS NOT NULL AND correlation_reference IS NOT NULL))))");
        }
    }

    public function down(): void
    {
        Schema::dropIfExists('payments');
    }
};
