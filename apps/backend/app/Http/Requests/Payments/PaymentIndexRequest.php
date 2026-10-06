<?php

namespace App\Http\Requests\Payments;

use App\Http\Requests\Concerns\RejectsUnknownFields;
use Illuminate\Foundation\Http\FormRequest;

class PaymentIndexRequest extends FormRequest
{
    use RejectsUnknownFields;

    public function authorize(): bool
    {
        return $this->user()->can('view-own-orders') || $this->user()->can('view-all-orders');
    }

    public function rules(): array
    {
        return ['page' => ['sometimes', 'integer', 'min:1', 'max:10000'], 'per_page' => ['sometimes', 'integer', 'min:1', 'max:100']];
    }
}
