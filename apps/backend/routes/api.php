<?php

use App\Http\Controllers\Api\V1\AuthController;
use App\Http\Middleware\EnsureActiveStaff;
use Illuminate\Support\Facades\Route;
use Laravel\Sanctum\Http\Middleware\CheckAbilities;

Route::prefix('v1')->group(function (): void {
    Route::prefix('auth')->name('auth.')->group(function (): void {
        Route::post('login', [AuthController::class, 'login'])
            ->middleware('throttle:staff-login')->name('login');

        Route::middleware(['auth:sanctum', EnsureActiveStaff::class, CheckAbilities::class.':staff'])->group(function (): void {
            Route::get('me', [AuthController::class, 'me'])->name('me');
            Route::post('logout', [AuthController::class, 'logout'])->name('logout');
        });
    });
});
