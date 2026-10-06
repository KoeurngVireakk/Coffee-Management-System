<?php

namespace App\Http\Requests\Catalog;

use App\Http\Requests\Concerns\RejectsUnknownFields;
use Illuminate\Foundation\Http\FormRequest;

class UpdateCategoryRequest extends FormRequest
{
    use RejectsUnknownFields;

    public function authorize(): bool
    {
        return $this->user()->can('update', $this->route('category'));
    }

    public function rules(): array
    {
        return ['name' => ['sometimes', 'required', 'string', 'max:120'], 'is_active' => ['sometimes', 'boolean:strict']];
    }
}
