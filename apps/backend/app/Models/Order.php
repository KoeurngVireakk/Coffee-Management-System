<?php

namespace App\Models;

use App\Enums\OrderStatus;
use App\Enums\PaymentStatus;
use Database\Factories\OrderFactory;
use Illuminate\Database\Eloquent\Attributes\Hidden;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Support\Facades\DB;
use LogicException;

#[Hidden(['checkout_key', 'request_hash'])]
class Order extends Model
{
    /** @use HasFactory<OrderFactory> */
    use HasFactory;

    public const int MAX_LINES = 50;

    public const int MAX_QUANTITY = 99;

    public const int MAX_SUBTOTAL_MINOR = 4949995050;

    protected function casts(): array
    {
        return ['status' => OrderStatus::class, 'subtotal_minor' => 'integer', 'discount_minor' => 'integer',
            'tax_minor' => 'integer', 'total_minor' => 'integer', 'inventory_tracked' => 'boolean', 'paid_at' => 'datetime'];
    }

    protected static function booted(): void
    {
        static::updating(fn () => throw new LogicException('Order mutations require a future approved lifecycle workflow.'));
        static::deleting(fn () => throw new LogicException('Order history cannot be deleted.'));
    }

    /** @return BelongsTo<User, $this> */
    public function creator(): BelongsTo
    {
        return $this->belongsTo(User::class, 'created_by');
    }

    /** @return HasMany<OrderItem, $this> */
    public function items(): HasMany
    {
        return $this->hasMany(OrderItem::class)->orderBy('line_number');
    }

    public function scopeVisibleTo(Builder $query, User $user): Builder
    {
        return $user->can('view-all-orders') ? $query : $query->where('created_by', $user->id);
    }

    public function payments(): HasMany
    {
        return $this->hasMany(Payment::class);
    }

    public function acceptedPayment(): BelongsTo
    {
        return $this->belongsTo(Payment::class, 'accepted_payment_id');
    }

    public function selectActivePayment(Payment $payment): void
    {
        $this->assertPaymentTransaction($payment);
        if ($this->status !== OrderStatus::PendingPayment || $this->accepted_payment_id !== null || $this->active_payment_id !== null) {
            throw new LogicException('Order cannot select another active payment.');
        }
        $changed = DB::table('orders')->where('id', $this->id)->where('status', 'pending_payment')
            ->whereNull('accepted_payment_id')->whereNull('active_payment_id')
            ->update(['active_payment_id' => $payment->id, 'updated_at' => now()]);
        if ($changed !== 1) {
            throw new LogicException('Order payment selection changed concurrently.');
        }
        $this->refresh();
    }

    public function clearActivePayment(Payment $payment): void
    {
        $this->assertPaymentTransaction($payment);
        DB::table('orders')->where('id', $this->id)->where('status', 'pending_payment')->where('active_payment_id', $payment->id)
            ->update(['active_payment_id' => null, 'updated_at' => now()]);
        $this->refresh();
    }

    public function acceptPayment(Payment $payment): void
    {
        $this->assertPaymentTransaction($payment);
        if ($this->status !== OrderStatus::PendingPayment || $this->accepted_payment_id !== null || $this->inventory_tracked
            || ($this->active_payment_id !== null && $this->active_payment_id !== $payment->id)
            || $payment->status !== PaymentStatus::Confirmed || $payment->expected_amount_minor !== $this->total_minor
            || $payment->currency !== $this->currency) {
            throw new LogicException('Order/payment is not eligible for acceptance.');
        }
        $changed = DB::table('orders')->where('id', $this->id)->where('status', 'pending_payment')->whereNull('accepted_payment_id')
            ->where('inventory_tracked', false)->where('total_minor', $payment->expected_amount_minor)->where('currency', $payment->currency)
            ->where(fn ($query) => $query->whereNull('active_payment_id')->orWhere('active_payment_id', $payment->id))
            ->update(['status' => 'paid', 'accepted_payment_id' => $payment->id,
                'active_payment_id' => null, 'paid_at' => now(), 'updated_at' => now()]);
        if ($changed !== 1) {
            throw new LogicException('Order was already settled or changed concurrently.');
        }
        $this->refresh();
    }

    private function assertPaymentTransaction(Payment $payment): void
    {
        if (DB::transactionLevel() < 1 || $payment->order_id !== $this->id) {
            throw new LogicException('Payment selection requires an owning-order transaction.');
        }
    }
}
