<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Audit\AuditEventIndexRequest;
use App\Http\Resources\AuditEventResource;
use App\Models\AuditEvent;
use Carbon\CarbonImmutable;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Support\Facades\Gate;

class AuditEventController extends Controller
{
    public function index(AuditEventIndexRequest $request): AnonymousResourceCollection
    {
        Gate::authorize('manage-staff');

        $query = AuditEvent::query()->with('actor:id,name');

        if ($request->filled('actor_id')) {
            $query->where('actor_id', (int) $request->input('actor_id'));
        }

        if ($request->filled('action')) {
            $query->where('action', (string) $request->input('action'));
        }

        if ($request->filled('subject_type')) {
            $query->where('subject_type', (string) $request->input('subject_type'));
        }

        if ($request->filled('subject_id')) {
            $query->where('subject_id', (int) $request->input('subject_id'));
        }

        if ($request->filled('created_from')) {
            $boundary = CarbonImmutable::parse((string) $request->input('created_from'))->utc()->format('Y-m-d H:i:s.u');
            $query->where('created_at', '>=', rtrim(rtrim($boundary, '0'), '.'));
        }

        if ($request->filled('created_to')) {
            $boundary = CarbonImmutable::parse((string) $request->input('created_to'))->utc()->format('Y-m-d H:i:s.u');
            $query->where('created_at', '<=', rtrim(rtrim($boundary, '0'), '.'));
        }

        $query->orderByDesc('created_at')->orderByDesc('id');

        $perPage = (int) $request->input('per_page', 25);
        $page = (int) $request->input('page', 1);

        return AuditEventResource::collection($query->paginate($perPage, ['*'], 'page', $page)->withQueryString());
    }
}

