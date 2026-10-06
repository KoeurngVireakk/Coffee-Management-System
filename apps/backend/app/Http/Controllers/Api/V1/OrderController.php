<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Orders\CheckoutRequest;
use App\Http\Requests\Orders\OrderIndexRequest;
use App\Http\Resources\OrderResource;
use App\Models\Order;
use App\Services\OrderCheckoutService;
use Carbon\CarbonImmutable;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Support\Facades\Gate;

class OrderController extends Controller
{
    public function store(CheckoutRequest $request, OrderCheckoutService $checkout): JsonResponse
    {
        $order = $checkout->checkout($request->user(), $request->validated('items'), $request->header('Idempotency-Key'));

        return (new OrderResource($order))->response()->setStatusCode($order->wasRecentlyCreated ? 201 : 200);
    }

    public function index(OrderIndexRequest $request): AnonymousResourceCollection
    {
        $input = $request->validated();
        $query = Order::query()->visibleTo($request->user())->with(['items', 'creator:id,name']);
        if (isset($input['status'])) {
            $query->where('status', $input['status']);
        }
        foreach (['created_from' => '>=', 'created_to' => '<='] as $field => $operator) {
            if (isset($input[$field])) {
                $boundary = CarbonImmutable::parse($input[$field])->utc()->format('Y-m-d H:i:s.u');
                // Keep second-precision equality consistent with SQLite's timestamp text.
                $query->where('created_at', $operator, rtrim(rtrim($boundary, '0'), '.'));
            }
        }

        return OrderResource::collection($query->orderByDesc('created_at')->orderByDesc('id')
            ->paginate($input['per_page'] ?? 25, ['*'], 'page', $input['page'] ?? 1)->withQueryString());
    }

    public function show(Request $request, string $order): OrderResource
    {
        Gate::authorize('viewAny', Order::class);
        $record = Order::query()->visibleTo($request->user())->where('public_reference', $order)
            ->with(['items', 'creator:id,name'])->firstOrFail();
        Gate::authorize('view', $record);

        return new OrderResource($record);
    }
}
