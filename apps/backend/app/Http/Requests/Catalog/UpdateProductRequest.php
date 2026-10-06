<?php

namespace App\Http\Requests\Catalog;

use App\Http\Requests\Concerns\RejectsUnknownFields;
use App\Models\Product;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Support\Str;
use Illuminate\Validation\Rule;

class UpdateProductRequest extends FormRequest
{
    use RejectsUnknownFields;

    public function authorize(): bool
    {
        return $this->user()->can('update', $this->route('product'));
    }

    protected function prepareForValidation(): void
    {
        if (is_string($this->input('sku'))) {
            $this->merge(['sku' => Str::upper(trim($this->input('sku')))]);
        }
    }

    public function rules(): array
    {
        return [
            'category_id' => ['sometimes', 'required', 'integer', 'min:1', Rule::exists('categories', 'id')],
            'sku' => ['sometimes', 'required', 'string', 'max:64', 'regex:/\A[A-Z0-9][A-Z0-9_-]*\z/', Rule::unique('products', 'sku')->ignore($this->route('product'))],
            'name' => ['sometimes', 'required', 'string', 'max:160'],
            'description' => ['sometimes', 'nullable', 'string', 'max:2000'],
            'price_minor' => ['sometimes', 'required', 'string', 'regex:/\A(?:0|[1-9][0-9]{0,5})\z/'],
            'currency' => ['sometimes', 'required', 'string', Rule::in([Product::CURRENCY])],
            'is_active' => ['sometimes', 'boolean:strict'],
        ];
    }
}
