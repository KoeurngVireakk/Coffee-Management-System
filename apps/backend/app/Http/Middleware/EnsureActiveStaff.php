<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class EnsureActiveStaff
{
    public function handle(Request $request, Closure $next): Response
    {
        abort_unless($request->user()?->isActiveStaff(), 403, 'Staff access is unavailable.');

        return $next($request);
    }
}
