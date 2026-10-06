<?php

namespace App\Http\Requests\Catalog;

use App\Http\Requests\Concerns\RejectsUnknownFields;
use App\Models\Category;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class CategoryIndexRequest extends FormRequest
{
    use RejectsUnknownFields;

    public function authorize(): bool
    {
        return $this->user()->can('viewAny', Category::class)
            && (! in_array($this->input('status'), ['inactive', 'all'], true)
                || $this->user()->can('manage-catalog'));
    }

    public function rules(): array
    {
        return [
            'status' => ['sometimes', 'string', Rule::in(['active', 'inactive', 'all'])],
            'search' => ['sometimes', 'nullable', 'string', 'max:80'],
            'page' => ['sometimes', 'integer', 'min:1', 'max:10000'],
            'per_page' => ['sometimes', 'integer', 'min:1', 'max:100'],
        ];
    }
}
