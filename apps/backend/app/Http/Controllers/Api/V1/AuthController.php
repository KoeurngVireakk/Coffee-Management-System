<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Auth\LoginRequest;
use App\Http\Resources\UserResource;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Response;
use Illuminate\Support\Facades\Gate;
use Illuminate\Support\Facades\Hash;

class AuthController extends Controller
{
    // Non-credential hash used to perform password work for unknown identities.
    private const string DUMMY_PASSWORD_HASH = '$2y$12$AChKMNde0I6pq6k0ew3T6OrVte2f5p3Efz9XzgmPCJw1aWULmu2Py';

    public function login(LoginRequest $request): JsonResponse
    {
        $input = $request->validated();
        $user = User::query()->with('role')->where('email', $input['email'])->first();
        $validPassword = Hash::check($input['password'], $user?->password ?? self::DUMMY_PASSWORD_HASH);

        if (! $validPassword || ! $user?->isActiveStaff()) {
            return response()->json(['message' => 'The provided credentials are incorrect.'], 401)
                ->header('Cache-Control', 'no-store, private');
        }

        if (Hash::needsRehash($user->password)) {
            $user->password = $input['password'];
            $user->save();
        }

        $expiresAt = now()->addMinutes(config('sanctum.expiration'));
        $token = $user->createToken($input['device_name'], ['staff'], $expiresAt);

        return (new UserResource($user))->additional([
            'token' => $token->plainTextToken,
            'token_type' => 'Bearer',
            'expires_at' => $expiresAt->toIso8601String(),
        ])->response()->header('Cache-Control', 'no-store, private');
    }

    public function me(Request $request): JsonResponse
    {
        Gate::authorize('view', $request->user());

        return (new UserResource($request->user()))->response()
            ->header('Cache-Control', 'no-store, private');
    }

    public function logout(Request $request): Response
    {
        $request->user()->currentAccessToken()->delete();

        return response()->noContent()->header('Cache-Control', 'no-store, private');
    }
}
