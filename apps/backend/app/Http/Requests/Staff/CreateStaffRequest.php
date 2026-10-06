<?php

namespace App\Http\Requests\Staff;

use App\Enums\StaffRole;
use App\Http\Requests\Concerns\RejectsUnknownFields;
use App\Models\User;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Support\Str;
use Illuminate\Validation\Rule;

class CreateStaffRequest extends FormRequest
{
    use RejectsUnknownFields;

    public function authorize(): bool
    {
        return $this->user()?->can('create', User::class) ?? false;
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
            'name' => ['required', 'string', 'max:255'],
            'email' => ['required', 'string', 'email:rfc', 'max:255', Rule::unique('users', 'email')],
            'role' => ['required', 'string', Rule::enum(StaffRole::class)],
            'is_active' => ['sometimes', 'boolean:strict'],
            'password' => ['required', 'string', 'min:12', 'max:1024'],
        ];
    }
}

