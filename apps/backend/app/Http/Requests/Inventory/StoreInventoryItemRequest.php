<?php

namespace App\Http\Requests\Inventory;

use App\Http\Requests\Concerns\RejectsUnknownFields;
use App\Models\InventoryItem;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Support\Str;
use Illuminate\Validation\Rule;

class StoreInventoryItemRequest extends FormRequest
{
    use RejectsUnknownFields;

    public function authorize(): bool
    {
        return $this->user()->can('create', InventoryItem::class);
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
            'sku' => ['required', 'string', 'max:64', 'regex:/\A[A-Z0-9][A-Z0-9_-]*\z/', Rule::unique('inventory_items', 'sku')],
            'name' => ['required', 'string', 'max:160'],
            'base_unit' => ['required', 'string', Rule::in(['g', 'ml', 'unit'])],
            'reorder_level' => ['sometimes', 'required', 'string', 'regex:/\A(?:0|[1-9][0-9]{0,9})(?:\.[0-9]{1,4})?\z/'],
            'is_active' => ['sometimes', 'boolean:strict'],
        ];
    }
}
