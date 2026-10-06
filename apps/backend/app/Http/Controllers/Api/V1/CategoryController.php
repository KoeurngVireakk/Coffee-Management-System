<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Catalog\CategoryIndexRequest;
use App\Http\Requests\Catalog\StoreCategoryRequest;
use App\Http\Requests\Catalog\UpdateCategoryRequest;
use App\Http\Resources\CategoryResource;
use App\Models\Category;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Support\Facades\Gate;

class CategoryController extends Controller
{
    public function index(CategoryIndexRequest $request): AnonymousResourceCollection
    {
        $input = $request->validated();
        $query = Category::query();
        if (($input['status'] ?? 'active') !== 'all') {
            $query->where('is_active', ($input['status'] ?? 'active') === 'active');
        }

        $search = $input['search'] ?? null;
        if ($search !== null && $search !== '') {
            $pattern = '%'.str_replace(['!', '%', '_'], ['!!', '!%', '!_'], $search).'%';
            $query->whereRaw("name LIKE ? ESCAPE '!'", [$pattern]);
        }

        return CategoryResource::collection($query->orderBy('name')->orderBy('id')
            ->paginate($input['per_page'] ?? 25, ['*'], 'page', $input['page'] ?? 1)->withQueryString());
    }

    public function show(Category $category): CategoryResource
    {
        Gate::authorize('view', $category);

        return new CategoryResource($category);
    }

    public function store(StoreCategoryRequest $request): JsonResponse
    {
        $category = Category::query()->create($request->validated());

        return (new CategoryResource($category->refresh()))->response()->setStatusCode(201);
    }

    public function update(UpdateCategoryRequest $request, Category $category): CategoryResource
    {
        $category->update($request->validated());

        return new CategoryResource($category->refresh());
    }
}
