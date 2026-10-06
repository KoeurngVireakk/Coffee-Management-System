<?php

namespace App\Http\Requests\Reports;

use Carbon\CarbonImmutable;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Validator;

class TopProductsReportRequest extends FormRequest
{
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
            'from_date' => ['nullable', 'date_format:Y-m-d', 'required_with:to_date'],
            'to_date' => ['nullable', 'date_format:Y-m-d', 'required_with:from_date', 'after_or_equal:from_date'],
            'limit' => ['nullable', 'integer', 'min:1', 'max:50'],
        ];
    }

    /**
     * @return list<\Closure>
     */
    public function after(): array
    {
        return [
            function (Validator $validator): void {
                $allowed = array_keys($this->rules());
                foreach (array_diff(array_keys($this->all()), $allowed) as $field) {
                    $validator->errors()->add($field, 'This field is not allowed.');
                }

                if ($validator->errors()->isNotEmpty()) {
                    return;
                }

                $from = $this->query('from_date');
                $to = $this->query('to_date');

                if ($from && $to) {
                    $fromDate = CarbonImmutable::createFromFormat('!Y-m-d', $from);
                    $toDate = CarbonImmutable::createFromFormat('!Y-m-d', $to);
                    if ($fromDate && $toDate && $fromDate->diffInDays($toDate) > 366) {
                        $validator->errors()->add('to_date', 'The reporting date range must not exceed 366 days.');
                    }
                }
            },
        ];
    }
}
