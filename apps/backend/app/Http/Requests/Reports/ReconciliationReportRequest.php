<?php

namespace App\Http\Requests\Reports;

use App\Http\Requests\Concerns\RejectsUnknownFields;
use Illuminate\Foundation\Http\FormRequest;

class ReconciliationReportRequest extends FormRequest
{
    use RejectsUnknownFields;

    public function authorize(): bool
    {
        return (bool) ($this->user()?->isActiveStaff() && $this->user()->can('view-reports'));
    }

    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'page' => ['nullable', 'integer', 'min:1'],
            'per_page' => ['nullable', 'integer', 'min:1', 'max:100'],
        ];
    }
}
