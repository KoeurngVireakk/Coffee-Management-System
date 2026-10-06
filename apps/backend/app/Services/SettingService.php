<?php

namespace App\Services;

use App\Models\Setting;
use App\Models\User;
use App\Settings\SettingRegistry;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class SettingService
{
    public function __construct(
        protected AuditService $audit,
    ) {}

    /**
     * Get all allow-listed settings.
     *
     * @return Collection<int, Setting>
     */
    public function getSettings(): Collection
    {
        $existing = Setting::query()->with('updater:id,name')->get()->keyBy('key');

        return collect(SettingRegistry::ALLOWED_KEYS)->map(function (string $key) use ($existing): Setting {
            if ($existing->has($key)) {
                return $existing->get($key);
            }

            $unconfigured = new Setting;
            $unconfigured->key = $key;
            $unconfigured->value = null;
            $unconfigured->updated_by = null;

            return $unconfigured;
        });
    }

    /**
     * Get a single allow-listed setting.
     */
    public function getSetting(string $key): Setting
    {
        if (! SettingRegistry::isAllowed($key)) {
            abort(404, "Setting [{$key}] not found.");
        }

        $setting = Setting::query()->with('updater:id,name')->where('key', $key)->first();

        if ($setting !== null) {
            return $setting;
        }

        $unconfigured = new Setting;
        $unconfigured->key = $key;
        $unconfigured->value = null;
        $unconfigured->updated_by = null;

        return $unconfigured;
    }

    /**
     * Update an allow-listed setting and record an audit event atomically.
     *
     * @throws ValidationException
     */
    public function updateSetting(User $admin, string $key, mixed $rawValue): Setting
    {
        if (! SettingRegistry::isAllowed($key)) {
            abort(404, "Setting [{$key}] not found.");
        }

        $validatedValue = SettingRegistry::validate($key, $rawValue);

        return DB::transaction(function () use ($admin, $key, $validatedValue): Setting {
            /** @var Setting|null $setting */
            $setting = Setting::query()->where('key', $key)->lockForUpdate()->first();
            $oldValue = $setting?->value;

            if ($setting === null) {
                $setting = new Setting;
                $setting->key = $key;
            }

            $setting->value = $validatedValue;
            $setting->updated_by = $admin->id;
            $setting->save();

            $this->audit->record($admin, 'setting.updated', 'setting', null, [
                'key' => $key,
                'from' => $oldValue,
                'to' => $validatedValue,
            ]);

            return $setting->load('updater:id,name');
        });
    }
}
