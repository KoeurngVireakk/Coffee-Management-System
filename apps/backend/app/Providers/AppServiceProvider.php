<?php

namespace App\Providers;

use App\Enums\StaffRole;
use App\Models\User;
use App\Payments\PaymentProvider;
use App\Payments\UnconfiguredPaymentProvider;
use App\Policies\UserPolicy;
use Illuminate\Cache\RateLimiting\Limit;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Gate;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Support\ServiceProvider;
use Illuminate\Support\Str;

class AppServiceProvider extends ServiceProvider
{
    /**
     * Register any application services.
     */
    public function register(): void
    {
        $this->app->bind(PaymentProvider::class, UnconfiguredPaymentProvider::class);
    }

    /**
     * Bootstrap any application services.
     */
    public function boot(): void
    {
        Gate::policy(User::class, UserPolicy::class);
        RateLimiter::for('inventory-writes', fn (Request $request) => Limit::perMinute(60)->by(
            'inventory:'.($request->user()?->id ?? hash('sha256', $request->ip() ?? '')),
        ));
        RateLimiter::for('payment-operations', fn (Request $request) => Limit::perMinute(30)->by(
            'payment:'.($request->user()?->id ?? hash('sha256', $request->ip() ?? '')),
        ));

        foreach (StaffRole::Admin->permissions() as $permission) {
            Gate::define($permission, fn (User $user): bool => in_array($permission, $user->permissions(), true));
        }

        RateLimiter::for('staff-login', function (Request $request): array {
            $email = $request->input('email');
            $identity = is_string($email) ? Str::lower(trim(substr($email, 0, 255))) : '';

            return [
                Limit::perMinute(30)->by('ip:'.hash('sha256', $request->ip() ?? '')),
                Limit::perMinute(5)->by('identity:'.hash('sha256', $identity.'|'.$request->ip())),
            ];
        });
    }
}
