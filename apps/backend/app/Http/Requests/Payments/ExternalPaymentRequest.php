<?php

namespace App\Http\Requests\Payments;

use App\Http\Requests\Concerns\RejectsUnknownFields;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Validator;

class ExternalPaymentRequest extends FormRequest
{
    use RejectsUnknownFields {
        after as unknownFieldChecks;
    }

    public function authorize(): bool
    {
        return $this->user()->can('process-pos');
    }

    public function rules(): array
    {
        return [];
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
