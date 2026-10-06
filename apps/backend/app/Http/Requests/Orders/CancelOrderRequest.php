<?php

namespace App\Http\Requests\Orders;

use App\Http\Requests\Concerns\RejectsUnknownFields;
use Illuminate\Foundation\Http\FormRequest;

class CancelOrderRequest extends FormRequest
{
    use RejectsUnknownFields;

    public function authorize(): bool
    {
        return $this->user()->can('process-pos');
    }

    public function rules(): array
    {
        return [];
    }
}
