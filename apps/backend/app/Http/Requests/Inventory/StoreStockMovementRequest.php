<?php

namespace App\Http\Requests\Inventory;

use App\Http\Requests\Concerns\RejectsUnknownFields;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;
use Illuminate\Validation\Validator;

class StoreStockMovementRequest extends FormRequest
{
    use RejectsUnknownFields {
        after as unknownFieldChecks;
    }

    public function authorize(): bool
    {
        return $this->user()->can('movements', $this->route('inventoryItem'));
    }

    public function rules(): array
    {
        return [
            'reason' => ['required', 'string', Rule::in(['opening_balance', 'receipt', 'waste', 'adjustment'])],
            'quantity_delta' => ['required', 'string', 'regex:/\A-?(?:0|[1-9][0-9]{0,9})(?:\.[0-9]{1,4})?\z/'],
            'note' => ['sometimes', 'nullable', 'string', 'max:500', 'required_if:reason,adjustment'],
        ];
    }

    public function after(): array
    {
        return [...$this->unknownFieldChecks(), function (Validator $validator): void {
            $keys = $this->headers->all('idempotency-key');
            if (count($keys) !== 1 || ! preg_match('/\A[A-Za-z0-9][A-Za-z0-9._-]{7,63}\z/', $keys[0])) {
                $validator->errors()->add('idempotency_key', 'Provide one valid Idempotency-Key header (8-64 ASCII characters).');
            }
        }];
    }
}
