<?php

namespace App\Http\Requests\Settings;

use App\Http\Requests\Concerns\RejectsUnknownFields;
use Illuminate\Foundation\Http\FormRequest;

class UpdateSettingRequest extends FormRequest
{
    use RejectsUnknownFields;

    public function authorize(): bool
    {
        return $this->user()?->can('manage-settings') ?? false;
    }

    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'value' => ['required'],
        ];
    }
}
