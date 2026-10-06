<?php

namespace App\Http\Requests\Inventory;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Validator;

class ReplaceRecipeRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user()->can('manage-catalog');
    }

    public function rules(): array
    {
        $rules = ['ingredients' => ['present', 'array', 'list', 'max:100']];
        if (is_array($this->input('ingredients')) && count($this->input('ingredients')) <= 100) {
            $rules += [
                'ingredients.*' => ['required', 'array:inventory_item_id,quantity'],
                'ingredients.*.inventory_item_id' => ['required', 'integer:strict', 'min:1', 'distinct:strict'],
                'ingredients.*.quantity' => ['required', 'string', 'regex:/\A(?:0|[1-9][0-9]{0,9})(?:\.[0-9]{1,4})?\z/'],
            ];
        }

        return $rules;
    }

    public function after(): array
    {
        return [function (Validator $validator): void {
            foreach (array_diff(array_keys($this->all()), ['ingredients']) as $field) {
                $validator->errors()->add($field, 'This field is not allowed.');
            }
        }];
    }
}
