<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Inventory\InventoryItemIndexRequest;
use App\Http\Requests\Inventory\StoreInventoryItemRequest;
use App\Http\Requests\Inventory\UpdateInventoryItemRequest;
use App\Http\Resources\InventoryItemResource;
use App\Models\InventoryItem;
use App\Services\InventoryItemService;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Support\Facades\Gate;

class InventoryItemController extends Controller
{
    public function index(InventoryItemIndexRequest $request): AnonymousResourceCollection
    {
        $input = $request->validated();
        $query = InventoryItem::query();
        $status = $input['status'] ?? 'active';
        if ($status !== 'all') {
            $query->where('is_active', $status === 'active');
        }
        if (isset($input['low_stock'])) {
            $query->whereRaw('on_hand - reserved '.($input['low_stock'] === '1' ? '<=' : '>').' reorder_level');
        }
        $search = $input['search'] ?? null;
        if ($search !== null && $search !== '') {
            $pattern = '%'.str_replace(['!', '%', '_'], ['!!', '!%', '!_'], $search).'%';
            $query->where(fn (Builder $items) => $items->whereRaw("name LIKE ? ESCAPE '!'", [$pattern])
                ->orWhereRaw("sku LIKE ? ESCAPE '!'", [$pattern]));
        }

        return InventoryItemResource::collection($query->orderBy('name')->orderBy('id')
            ->paginate($input['per_page'] ?? 25, ['*'], 'page', $input['page'] ?? 1)->withQueryString());
    }

    public function show(InventoryItem $inventoryItem): InventoryItemResource
    {
        Gate::authorize('view', $inventoryItem);

        return new InventoryItemResource($inventoryItem);
    }

    public function store(StoreInventoryItemRequest $request, InventoryItemService $service): JsonResponse
    {
        return (new InventoryItemResource($service->create($request->user(), $request->validated())))->response()->setStatusCode(201);
    }

    public function update(UpdateInventoryItemRequest $request, InventoryItem $inventoryItem, InventoryItemService $service): InventoryItemResource
    {
        return new InventoryItemResource($service->update($request->user(), $inventoryItem, $request->validated()));
    }
}
