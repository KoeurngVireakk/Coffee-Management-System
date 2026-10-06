<?php

namespace App\Http\Requests\Inventory;

use App\Http\Requests\Concerns\RejectsUnknownFields;
use Illuminate\Foundation\Http\FormRequest;

class StockMovementIndexRequest extends FormRequest
{
    use RejectsUnknownFields;

    public function authorize(): bool
    {
        return $this->user()->can('movements', $this->route('inventoryItem'));
    }

    public function rules(): array
    {
        return [
            'page' => ['sometimes', 'integer', 'min:1', 'max:10000'],
            'per_page' => ['sometimes', 'integer', 'min:1', 'max:100'],
        ];
    }
}
