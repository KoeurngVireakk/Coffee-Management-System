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
        if ($mysql) {
            $version = DB::selectOne('SELECT VERSION() AS version')->version;
            if (! preg_match('/^(\d+\.\d+\.\d+)/', $version, $matches)
                || version_compare($matches[1], '8.0.16', '<')) {
                throw new RuntimeException('Catalog requires MySQL 8.0.16+ with enforced CHECK constraints.');
            }
        }

        Schema::create('products', function (Blueprint $table) use ($mysql): void {
            $table->id();
            $table->foreignId('category_id')->constrained()->restrictOnDelete();
            $table->string('sku', 64)->collation($mysql ? 'utf8mb4_unicode_ci' : 'NOCASE')->unique();
            $table->string('name', 160);
            $table->text('description')->nullable();
            $table->bigInteger('price_minor');
            $currency = $table->char('currency', 3);
            if ($mysql) {
                $currency->collation('utf8mb4_bin');
            }
            $table->boolean('is_active')->default(true);
            $table->timestamps();
            $table->index(['category_id', 'is_active', 'name', 'id']);
            $table->index(['is_active', 'name', 'id']);
        });

        // Production constraints. SQLite mirrors fields/FKs/unique indexes for fast tests;
        // these CHECKs are tested separately on isolated MySQL, not assumed equivalent.
        if ($mysql) {
            DB::statement('ALTER TABLE products ADD CONSTRAINT products_price_minor_check CHECK (price_minor BETWEEN 0 AND 999999)');
            DB::statement("ALTER TABLE products ADD CONSTRAINT products_currency_check CHECK (currency = 'USD')");
        }
    }

    public function down(): void
    {
        Schema::dropIfExists('products');
    }
};
