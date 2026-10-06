<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Inventory\StockMovementIndexRequest;
use App\Http\Requests\Inventory\StoreStockMovementRequest;
use App\Http\Resources\StockMovementResource;
use App\Models\InventoryItem;
use App\Models\StockMovement;
use App\Services\StockMovementService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;

class StockMovementController extends Controller
{
    public function index(StockMovementIndexRequest $request, InventoryItem $inventoryItem): AnonymousResourceCollection
    {
        $input = $request->validated();

        return StockMovementResource::collection(StockMovement::query()->where('inventory_item_id', $inventoryItem->id)
            ->orderByDesc('created_at')->orderByDesc('id')
            ->paginate($input['per_page'] ?? 25, ['*'], 'page', $input['page'] ?? 1)->withQueryString());
    }

    public function store(StoreStockMovementRequest $request, InventoryItem $inventoryItem, StockMovementService $service): JsonResponse
    {
        $movement = $service->append($request->user(), $inventoryItem, $request->validated(), $request->header('Idempotency-Key'));

        return (new StockMovementResource($movement))->response()->setStatusCode($movement->wasRecentlyCreated ? 201 : 200);
    }
}
