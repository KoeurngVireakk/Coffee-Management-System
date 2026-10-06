<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Inventory\ReplaceRecipeRequest;
use App\Models\Product;
use App\Services\RecipeService;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Gate;

class RecipeController extends Controller
{
    public function show(Product $product, RecipeService $service): JsonResponse
    {
        Gate::authorize('manage-catalog');

        return response()->json(['data' => $service->read($product)]);
    }

    public function update(ReplaceRecipeRequest $request, Product $product, RecipeService $service): JsonResponse
    {
        return response()->json(['data' => $service->replace($request->user(), $product, $request->validated('ingredients'))]);
    }
}
