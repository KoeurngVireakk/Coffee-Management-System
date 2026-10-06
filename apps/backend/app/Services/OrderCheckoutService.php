<?php

namespace App\Services;

use App\Enums\OrderStatus;
use App\Models\Category;
use App\Models\Order;
use App\Models\OrderItem;
use App\Models\Product;
use App\Models\User;
use Illuminate\Database\UniqueConstraintViolationException;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Gate;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;
use Symfony\Component\HttpKernel\Exception\ConflictHttpException;

class OrderCheckoutService
{
    /** @param list<array{product_id:int, quantity:int}> $items Validated checkout intent */
    public function checkout(User $actor, array $items, string $key): Order
    {
        Gate::forUser($actor)->authorize('create', Order::class);
        usort($items, fn (array $a, array $b) => $a['product_id'] <=> $b['product_id']);
        $intent = array_map(fn (array $item) => ['product_id' => $item['product_id'], 'quantity' => $item['quantity']], $items);
        $hash = hash('sha256', json_encode(['version' => 1, 'currency' => Product::CURRENCY, 'items' => $intent], JSON_THROW_ON_ERROR));

        try {
            $order = DB::transaction(function () use ($actor, $intent, $key, $hash): Order {
                $existing = Order::query()->where('created_by', $actor->id)->where('checkout_key', $key)->first();
                if ($existing) {
                    return $this->replay($existing, $hash);
                }

                $products = [];
                $categoryIds = [];
                foreach ($intent as $item) {
                    $product = Product::query()->whereKey($item['product_id'])->sharedLock()->first();
                    if (! $product) {
                        throw ValidationException::withMessages(['items' => 'A selected product is unavailable.']);
                    }
                    $products[$product->id] = $product;
                    $categoryIds[$product->category_id] = $product->category_id;
                }
                sort($categoryIds, SORT_NUMERIC);
                $categories = [];
                foreach ($categoryIds as $id) {
                    $categories[$id] = Category::query()->whereKey($id)->sharedLock()->first();
                }

                $lines = [];
                $subtotal = 0;
                foreach ($intent as $index => $item) {
                    $product = $products[$item['product_id']];
                    if (! $product->is_active || ! ($categories[$product->category_id]?->is_active ?? false)
                        || $product->currency !== Product::CURRENCY || $product->price_minor < 0 || $product->price_minor > Product::MAX_PRICE_MINOR) {
                        throw ValidationException::withMessages(['items' => 'A selected product is unavailable.']);
                    }
                    if ($product->price_minor > intdiv(PHP_INT_MAX, $item['quantity'])) {
                        throw ValidationException::withMessages(['items' => 'The order amount exceeds supported bounds.']);
                    }
                    $lineTotal = $product->price_minor * $item['quantity'];
                    if ($subtotal > Order::MAX_SUBTOTAL_MINOR - $lineTotal) {
                        throw ValidationException::withMessages(['items' => 'The order amount exceeds supported bounds.']);
                    }
                    $subtotal += $lineTotal;
                    $lines[] = ['line_number' => $index + 1, 'product_id' => $product->id,
                        'product_name' => $product->name, 'product_sku' => $product->sku,
                        'unit_price_minor' => $product->price_minor, 'quantity' => $item['quantity'],
                        'subtotal_minor' => $lineTotal, 'discount_minor' => 0, 'tax_minor' => 0, 'line_total_minor' => $lineTotal];
                }

                $order = new Order;
                $order->forceFill(['public_reference' => 'ORD-'.Str::ulid(), 'created_by' => $actor->id,
                    'status' => OrderStatus::PendingPayment, 'currency' => Product::CURRENCY,
                    'subtotal_minor' => $subtotal, 'discount_minor' => 0, 'tax_minor' => 0, 'total_minor' => $subtotal,
                    'checkout_key' => $key, 'request_hash' => $hash, 'inventory_tracked' => false])->save();
                foreach ($lines as $line) {
                    $item = new OrderItem;
                    $item->forceFill($line);
                    $order->items()->save($item);
                }

                return $order;
            }, 3);
        } catch (UniqueConstraintViolationException|ValidationException $exception) {
            // Rollback ends the old read snapshot. A winner can also precede catalog retirement
            // while this request was waiting on shared locks; replay its immutable result.
            $winner = Order::query()->where('created_by', $actor->id)->where('checkout_key', $key)->first();
            if (! $winner) {
                throw $exception;
            }
            $order = $this->replay($winner, $hash);
        }

        return $order->load(['items', 'creator:id,name', 'acceptedPayment']);
    }

    private function replay(Order $order, string $hash): Order
    {
        if (! hash_equals($order->request_hash, $hash)) {
            throw new ConflictHttpException('This Idempotency-Key was already used for a different checkout intent.');
        }

        return $order;
    }
}
