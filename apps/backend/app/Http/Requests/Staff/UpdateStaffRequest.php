<?php

namespace App\Http\Requests\Staff;

use App\Enums\StaffRole;
use App\Http\Requests\Concerns\RejectsUnknownFields;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Support\Str;
use Illuminate\Validation\Rule;

class UpdateStaffRequest extends FormRequest
{
    use RejectsUnknownFields;

    public function authorize(): bool
    {
        return $this->user()?->can('update', $this->route('user')) ?? false;
    }

    protected function prepareForValidation(): void
    {
        $merge = [];
        if (is_string($this->input('email'))) {
            $merge['email'] = Str::lower(trim($this->input('email')));
        }
        if (is_string($this->input('name'))) {
            $merge['name'] = trim($this->input('name'));
        }
        if ($merge !== []) {
            $this->merge($merge);
        }
    }

    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'name' => ['sometimes', 'required', 'string', 'max:255'],
            'email' => ['sometimes', 'required', 'string', 'email:rfc', 'max:255', Rule::unique('users', 'email')->ignore($this->route('user'))],
            'role' => ['sometimes', 'required', 'string', Rule::enum(StaffRole::class)],
            'is_active' => ['sometimes', 'boolean:strict'],
        ];
    }
}

