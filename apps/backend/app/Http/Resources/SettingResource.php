<?php

namespace App\Http\Resources;

use App\Models\Setting;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** @mixin Setting */
class SettingResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'key' => $this->key,
            'value' => $this->value,
            'updated_by' => $this->updater ? [
                'id' => $this->updater->id,
                'name' => $this->updater->name,
            ] : null,
            'updated_at' => $this->updated_at?->toIso8601String(),
        ];
    }
}
