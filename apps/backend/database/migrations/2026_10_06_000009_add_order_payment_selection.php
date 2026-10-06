<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('orders', function (Blueprint $table): void {
            $table->unsignedBigInteger('accepted_payment_id')->nullable()->unique();
            $table->unsignedBigInteger('active_payment_id')->nullable()->unique();
            $table->timestamp('paid_at')->nullable();
            $table->index(['id', 'accepted_payment_id']);
            $table->index(['id', 'active_payment_id']);
            $table->foreign(['id', 'accepted_payment_id'])->references(['order_id', 'id'])->on('payments')->restrictOnDelete();
            $table->foreign(['id', 'active_payment_id'])->references(['order_id', 'id'])->on('payments')->restrictOnDelete();
        });
        if (DB::getDriverName() === 'mysql') {
            DB::statement("ALTER TABLE orders ADD CONSTRAINT orders_paid_selection_check CHECK ((status='paid' AND accepted_payment_id IS NOT NULL AND paid_at IS NOT NULL AND active_payment_id IS NULL) OR (status<>'paid' AND accepted_payment_id IS NULL AND paid_at IS NULL))");
        }
    }

    public function down(): void
    {
        if (DB::getDriverName() === 'mysql') {
            DB::statement('ALTER TABLE orders DROP CHECK orders_paid_selection_check');
        }
        Schema::table('orders', function (Blueprint $table): void {
            $table->dropForeign(['id', 'accepted_payment_id']);
            $table->dropForeign(['id', 'active_payment_id']);
            $table->dropIndex(['id', 'accepted_payment_id']);
            $table->dropIndex(['id', 'active_payment_id']);
            $table->dropUnique(['accepted_payment_id']);
            $table->dropUnique(['active_payment_id']);
            $table->dropColumn(['accepted_payment_id', 'active_payment_id', 'paid_at']);
        });
    }
};
