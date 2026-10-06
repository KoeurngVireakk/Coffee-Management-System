<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Staff\CreateStaffRequest;
use App\Http\Requests\Staff\ResetStaffPasswordRequest;
use App\Http\Requests\Staff\RevokeStaffTokensRequest;
use App\Http\Requests\Staff\StaffIndexRequest;
use App\Http\Requests\Staff\UpdateStaffRequest;
use App\Http\Resources\StaffResource;
use App\Models\User;
use App\Services\StaffManagementService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Support\Facades\Gate;

class StaffController extends Controller
{
    public function index(StaffIndexRequest $request): AnonymousResourceCollection
    {
        Gate::authorize('viewAny', User::class);

        $query = User::query()->with('role');

        if ($request->filled('search')) {
            $search = '%'.addcslashes((string) $request->input('search'), '%_\\').'%';
            $query->where(function ($q) use ($search): void {
                $q->where('name', 'like', $search)
                    ->orWhere('email', 'like', $search);
            });
        }

        if ($request->filled('role')) {
            $roleName = (string) $request->input('role');
            $query->whereHas('role', function ($q) use ($roleName): void {
                $q->where('name', $roleName);
            });
        }

        if ($request->has('is_active') && $request->input('is_active') !== null) {
            $query->where('is_active', (bool) $request->input('is_active'));
        }

        $query->orderBy('name', 'asc')->orderBy('id', 'asc');

        $perPage = (int) $request->input('per_page', 25);
        $page = (int) $request->input('page', 1);

        return StaffResource::collection($query->paginate($perPage, ['*'], 'page', $page)->withQueryString());
    }

    public function store(CreateStaffRequest $request, StaffManagementService $service): JsonResponse
    {
        $user = $service->createStaff($request->user(), $request->validated());

        return (new StaffResource($user))->response()->setStatusCode(201);
    }

    public function show(Request $request, User $user): StaffResource
    {
        Gate::authorize('view', $user);

        return new StaffResource($user->load('role'));
    }

    public function update(UpdateStaffRequest $request, User $user, StaffManagementService $service): StaffResource
    {
        $updated = $service->updateStaff($request->user(), $user, $request->validated());

        return new StaffResource($updated);
    }

    public function resetPassword(ResetStaffPasswordRequest $request, User $user, StaffManagementService $service): JsonResponse
    {
        $updated = $service->resetPassword($request->user(), $user, (string) $request->validated('password'));

        return (new StaffResource($updated))
            ->additional(['message' => 'Password reset successfully.'])
            ->response();
    }

    public function revokeTokens(RevokeStaffTokensRequest $request, User $user, StaffManagementService $service): JsonResponse
    {
        $updated = $service->revokeTokens($request->user(), $user, (string) $request->validated('reason'));

        return (new StaffResource($updated))
            ->additional(['message' => 'Tokens revoked successfully.'])
            ->response();
    }
}

