<?php

namespace App\Http\Requests\Inventory;

use App\Http\Requests\Concerns\RejectsUnknownFields;
use App\Models\InventoryItem;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class InventoryItemIndexRequest extends FormRequest
{
    use RejectsUnknownFields;

    public function authorize(): bool
    {
        return $this->user()->can('viewAny', InventoryItem::class);
    }

    public function rules(): array
    {
        return [
            'status' => ['sometimes', 'string', Rule::in(['active', 'inactive', 'all'])],
            'search' => ['sometimes', 'nullable', 'string', 'max:80'],
            'low_stock' => ['sometimes', 'string', Rule::in(['0', '1'])],
            'page' => ['sometimes', 'integer', 'min:1', 'max:10000'],
            'per_page' => ['sometimes', 'integer', 'min:1', 'max:100'],
        ];
    }
}
