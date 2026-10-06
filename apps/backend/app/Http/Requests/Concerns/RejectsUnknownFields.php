<?php

namespace App\Http\Requests\Concerns;

use Illuminate\Validation\Validator;

trait RejectsUnknownFields
{
    /** @return list<\Closure> */
    public function after(): array
    {
        return [function (Validator $validator): void {
            $allowed = array_keys($this->rules());
            foreach (array_diff(array_keys($this->all()), $allowed) as $field) {
                $validator->errors()->add($field, 'This field is not allowed.');
            }

            if (in_array($this->method(), ['PUT', 'PATCH'], true)
                && array_intersect(array_keys($this->all()), $allowed) === []) {
                $validator->errors()->add('body', 'Provide at least one editable field.');
            }
        }];
    }
}
