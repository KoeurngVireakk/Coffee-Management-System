<?php

namespace App\Http\Requests\Orders;

use App\Models\Order;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Validator;

class CheckoutRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user()->can('create', Order::class);
    }

    public function rules(): array
    {
        $rules = ['items' => ['required', 'array', 'list', 'min:1', 'max:'.Order::MAX_LINES]];
        // Bound the list before Laravel expands nested wildcard validation.
        if (is_array($this->input('items')) && count($this->input('items')) <= Order::MAX_LINES) {
            $rules += [
                'items.*' => ['required', 'array:product_id,quantity'],
                'items.*.product_id' => ['required', 'integer:strict', 'min:1', 'distinct:strict'],
                'items.*.quantity' => ['required', 'integer:strict', 'min:1', 'max:'.Order::MAX_QUANTITY],
            ];
        }

        return $rules;
    }

    public function after(): array
    {
        return [function (Validator $validator): void {
            // Nested rule names are not additional allowed top-level body properties.
            foreach (array_diff(array_keys($this->all()), ['items']) as $field) {
                $validator->errors()->add($field, 'This field is not allowed.');
            }
            $keys = $this->headers->all('idempotency-key');
            if (count($keys) !== 1 || ! preg_match('/\A[A-Za-z0-9][A-Za-z0-9._-]{7,63}\z/', $keys[0])) {
                $validator->errors()->add('idempotency_key', 'Provide one valid Idempotency-Key header (8-64 ASCII characters).');
            }
        }];
    }
}
