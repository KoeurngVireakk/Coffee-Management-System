<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Payments\CashPaymentRequest;
use App\Http\Requests\Payments\ExternalPaymentRequest;
use App\Http\Requests\Payments\PaymentIndexRequest;
use App\Http\Requests\Payments\ReconcilePaymentRequest;
use App\Http\Resources\PaymentResource;
use App\Models\Order;
use App\Services\CashPaymentService;
use App\Services\ExternalPaymentService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Support\Facades\Gate;

class PaymentController extends Controller
{
    public function cash(CashPaymentRequest $request, string $order, CashPaymentService $cash): JsonResponse
    {
        $target = $this->order($request, $order);
        $payment = $cash->settle($request->user(), $target, (int) $request->validated('tender_minor'), $request->header('Idempotency-Key'));

        return (new PaymentResource($payment))->response()->setStatusCode($payment->wasRecentlyCreated ? 201 : 200);
    }

    private function order(Request $request, string $reference): Order
    {
        $order = Order::query()->visibleTo($request->user())->where('public_reference', $reference)->firstOrFail();
        Gate::authorize('pay', $order);

        return $order;
    }

    public function external(ExternalPaymentRequest $request, string $order, ExternalPaymentService $external): JsonResponse
    {
        $payment = $external->initiate($request->user(), $this->order($request, $order), $request->header('Idempotency-Key'));

        return (new PaymentResource($payment))->response()->setStatusCode($payment->wasRecentlyCreated ? 201 : 200);
    }

    public function reconcile(ReconcilePaymentRequest $request, string $order, int $payment, ExternalPaymentService $external): PaymentResource
    {
        $target = $this->order($request, $order)->payments()->whereKey($payment)->firstOrFail();
        Gate::authorize('reconcile', $target);

        return new PaymentResource($external->reconcile($target));
    }

    public function index(PaymentIndexRequest $request, string $order): AnonymousResourceCollection
    {
        $target = $this->order($request, $order);
        $input = $request->validated();

        return PaymentResource::collection($target->payments()->orderByDesc('created_at')->orderByDesc('id')
            ->paginate($input['per_page'] ?? 25, ['*'], 'page', $input['page'] ?? 1)->withQueryString());
    }
}
