<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Settings\UpdateSettingRequest;
use App\Http\Resources\SettingResource;
use App\Services\SettingService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Support\Facades\Gate;

class SettingController extends Controller
{
    public function index(Request $request, SettingService $service): AnonymousResourceCollection
    {
        Gate::authorize('view-settings');

        return SettingResource::collection($service->getSettings());
    }

    public function show(Request $request, string $key, SettingService $service): SettingResource
    {
        Gate::authorize('view-settings');

        return new SettingResource($service->getSetting($key));
    }

    public function update(UpdateSettingRequest $request, string $key, SettingService $service): JsonResponse
    {
        Gate::authorize('manage-settings');

        $updated = $service->updateSetting($request->user(), $key, $request->input('value'));

        return (new SettingResource($updated))->response()->setStatusCode(200);
    }
}
