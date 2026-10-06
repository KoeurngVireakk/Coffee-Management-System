<?php

use App\Http\Controllers\Api\V1\AuthController;
use App\Http\Controllers\Api\V1\CategoryController;
use App\Http\Controllers\Api\V1\OrderController;
use App\Http\Controllers\Api\V1\PaymentController;
use App\Http\Controllers\Api\V1\ProductController;
use App\Http\Middleware\EnsureActiveStaff;
use Illuminate\Support\Facades\Route;
use Laravel\Sanctum\Http\Middleware\CheckAbilities;

Route::prefix('v1')->group(function (): void {
    Route::middleware(['auth:sanctum', EnsureActiveStaff::class, CheckAbilities::class.':staff'])->group(function (): void {
        Route::apiResource('categories', CategoryController::class)->only(['index', 'show', 'store', 'update'])->whereNumber('category');
        Route::apiResource('products', ProductController::class)->only(['index', 'show', 'store', 'update'])->whereNumber('product');
        Route::post('orders', [OrderController::class, 'store'])->name('orders.store');
        Route::get('orders', [OrderController::class, 'index'])->name('orders.index');
        Route::get('orders/{order}', [OrderController::class, 'show'])->where('order', 'ORD-[0-9A-HJKMNP-TV-Z]{26}')->name('orders.show');
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
