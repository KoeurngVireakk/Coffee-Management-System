<?php

namespace App\Http\Requests\Audit;

use App\Http\Requests\Concerns\RejectsUnknownFields;
use App\Rules\AbsoluteTimestamp;
use Carbon\CarbonImmutable;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Validator;

class AuditEventIndexRequest extends FormRequest
{
    use RejectsUnknownFields {
        after as unknownFieldChecks;
    }

    public function authorize(): bool
    {
        return $this->user()?->can('manage-staff') ?? false;
    }

    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'actor_id' => ['sometimes', 'integer', 'min:1'],
            'action' => ['sometimes', 'string', 'max:64'],
            'subject_type' => ['sometimes', 'string', 'max:64'],
            'subject_id' => ['sometimes', 'integer', 'min:1'],
            'created_from' => ['sometimes', 'string', 'max:32', new AbsoluteTimestamp],
            'created_to' => ['sometimes', 'string', 'max:32', new AbsoluteTimestamp],
            'page' => ['sometimes', 'integer', 'min:1', 'max:10000'],
            'per_page' => ['sometimes', 'integer', 'min:1', 'max:100'],
        ];
    }

    /**
     * @return list<\Closure>
     */
    public function after(): array
    {
        return [...$this->unknownFieldChecks(), function (Validator $validator): void {
            if ($this->has(['created_from', 'created_to'])
                && ! $validator->errors()->hasAny(['created_from', 'created_to'])
                && CarbonImmutable::parse($this->input('created_from'))->greaterThan(CarbonImmutable::parse($this->input('created_to')))) {
                $validator->errors()->add('created_to', 'The upper boundary must be at or after created_from.');
            }
        }];
    }
}
