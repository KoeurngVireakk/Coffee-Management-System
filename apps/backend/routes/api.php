<?php

use App\Http\Controllers\Api\V1\AuthController;
use App\Http\Controllers\Api\V1\CategoryController;
use App\Http\Controllers\Api\V1\InventoryItemController;
use App\Http\Controllers\Api\V1\OrderController;
use App\Http\Controllers\Api\V1\PaymentController;
use App\Http\Controllers\Api\V1\ProductController;
use App\Http\Controllers\Api\V1\RecipeController;
use App\Http\Controllers\Api\V1\StockMovementController;
use App\Http\Middleware\EnsureActiveStaff;
use Illuminate\Support\Facades\Route;
use Laravel\Sanctum\Http\Middleware\CheckAbilities;

Route::prefix('v1')->group(function (): void {
    Route::middleware(['auth:sanctum', EnsureActiveStaff::class, CheckAbilities::class.':staff'])->group(function (): void {
        Route::apiResource('categories', CategoryController::class)->only(['index', 'show', 'store', 'update'])->whereNumber('category');
        Route::apiResource('products', ProductController::class)->only(['index', 'show', 'store', 'update'])->whereNumber('product');
        Route::get('inventory/items', [InventoryItemController::class, 'index']);
        Route::get('inventory/items/{inventoryItem}', [InventoryItemController::class, 'show'])->whereNumber('inventoryItem');
        Route::get('inventory/items/{inventoryItem}/movements', [StockMovementController::class, 'index'])->whereNumber('inventoryItem');
        Route::get('products/{product}/recipe', [RecipeController::class, 'show'])->whereNumber('product');
        Route::middleware('throttle:inventory-writes')->group(function (): void {
            Route::post('inventory/items', [InventoryItemController::class, 'store']);
            Route::match(['PUT', 'PATCH'], 'inventory/items/{inventoryItem}', [InventoryItemController::class, 'update'])->whereNumber('inventoryItem');
            Route::post('inventory/items/{inventoryItem}/movements', [StockMovementController::class, 'store'])->whereNumber('inventoryItem');
            Route::put('products/{product}/recipe', [RecipeController::class, 'update'])->whereNumber('product');
        });
        Route::post('orders', [OrderController::class, 'store'])->name('orders.store');
        Route::get('orders', [OrderController::class, 'index'])->name('orders.index');
        Route::get('orders/{order}', [OrderController::class, 'show'])->where('order', 'ORD-[0-9A-HJKMNP-TV-Z]{26}')->name('orders.show');
        Route::post('orders/{order}/cancel', [OrderController::class, 'cancel'])->where('order', 'ORD-[0-9A-HJKMNP-TV-Z]{26}')
            ->middleware('throttle:inventory-writes')->name('orders.cancel');
        Route::prefix('orders/{order}/payments')->where(['order' => 'ORD-[0-9A-HJKMNP-TV-Z]{26}'])->middleware('throttle:payment-operations')->group(function (): void {
            Route::post('cash', [PaymentController::class, 'cash'])->name('payments.cash');
            Route::post('external', [PaymentController::class, 'external'])->name('payments.external');
            Route::get('/', [PaymentController::class, 'index'])->name('payments.index');
            Route::post('{payment}/reconcile', [PaymentController::class, 'reconcile'])->whereNumber('payment')->name('payments.reconcile');
        });
    });

    Route::prefix('auth')->name('auth.')->group(function (): void {
        Route::post('login', [AuthController::class, 'login'])
            ->middleware('throttle:staff-login')->name('login');

        Route::middleware(['auth:sanctum', EnsureActiveStaff::class, CheckAbilities::class.':staff'])->group(function (): void {
            Route::get('me', [AuthController::class, 'me'])->name('me');
            Route::post('logout', [AuthController::class, 'logout'])->name('logout');
        });
    });
});
