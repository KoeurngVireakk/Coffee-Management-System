<?php

namespace App\Http\Requests\Orders;

use App\Enums\OrderStatus;
use App\Http\Requests\Concerns\RejectsUnknownFields;
use App\Models\Order;
use App\Rules\AbsoluteTimestamp;
use Carbon\CarbonImmutable;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;
use Illuminate\Validation\Validator;

class OrderIndexRequest extends FormRequest
{
    use RejectsUnknownFields {
        after as unknownFieldChecks;
    }

    public function authorize(): bool
    {
        return $this->user()->can('viewAny', Order::class);
    }

    public function rules(): array
    {
        return ['status' => ['sometimes', Rule::enum(OrderStatus::class)],
            'created_from' => ['sometimes', 'string', 'max:32', new AbsoluteTimestamp],
            'created_to' => ['sometimes', 'string', 'max:32', new AbsoluteTimestamp],
            'page' => ['sometimes', 'integer', 'min:1', 'max:10000'],
            'per_page' => ['sometimes', 'integer', 'min:1', 'max:100']];
    }

    public function after(): array
    {
        return [...$this->unknownFieldChecks(), function (Validator $validator): void {
            if ($this->has(['created_from', 'created_to']) && ! $validator->errors()->hasAny(['created_from', 'created_to'])
                && CarbonImmutable::parse($this->input('created_from'))->greaterThan(CarbonImmutable::parse($this->input('created_to')))) {
                $validator->errors()->add('created_to', 'The upper boundary must be at or after created_from.');
            }
        }];
    }
}
