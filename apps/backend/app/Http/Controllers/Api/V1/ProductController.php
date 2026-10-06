<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Catalog\ProductIndexRequest;
use App\Http\Requests\Catalog\StoreProductRequest;
use App\Http\Requests\Catalog\UpdateProductRequest;
use App\Http\Resources\ProductResource;
use App\Models\Product;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\UniqueConstraintViolationException;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Support\Facades\Gate;
use Illuminate\Validation\ValidationException;

class ProductController extends Controller
{
    public function index(ProductIndexRequest $request): AnonymousResourceCollection
    {
        $input = $request->validated();
        $query = Product::query()->with('category:id,name,is_active');
        $status = $input['status'] ?? 'active';
        if ($status === 'active') {
            $query->sellable();
        } elseif ($status === 'inactive') {
            $query->where(fn (Builder $products) => $products->where('is_active', false)
                ->orWhereHas('category', fn (Builder $categories) => $categories->where('is_active', false)));
        }
        if (isset($input['category_id'])) {
            $query->where('category_id', $input['category_id']);
        }
        $search = $input['search'] ?? null;
        if ($search !== null && $search !== '') {
            $pattern = '%'.str_replace(['!', '%', '_'], ['!!', '!%', '!_'], $search).'%';
            $query->where(fn (Builder $products) => $products->whereRaw("name LIKE ? ESCAPE '!'", [$pattern])
                ->orWhereRaw("sku LIKE ? ESCAPE '!'", [$pattern]));
        }

        return ProductResource::collection($query->orderBy('name')->orderBy('id')
            ->paginate($input['per_page'] ?? 25, ['*'], 'page', $input['page'] ?? 1)->withQueryString());
    }

    public function show(Product $product): ProductResource
    {
        Gate::authorize('view', $product);

        return new ProductResource($product->loadMissing('category:id,name,is_active'));
    }

    public function store(StoreProductRequest $request): JsonResponse
    {
        try {
            $product = Product::query()->create($request->validated());
        } catch (UniqueConstraintViolationException) {
            // Another writer may claim the SKU after validation; the DB is authoritative.
            throw ValidationException::withMessages(['sku' => 'The SKU is already in use.']);
        }

        return (new ProductResource($product->refresh()->load('category:id,name,is_active')))->response()->setStatusCode(201);
    }

    public function update(UpdateProductRequest $request, Product $product): ProductResource
    {
        try {
            $product->update($request->validated());
        } catch (UniqueConstraintViolationException) {
            throw ValidationException::withMessages(['sku' => 'The SKU is already in use.']);
        }

        return new ProductResource($product->refresh()->load('category:id,name,is_active'));
    }
}
