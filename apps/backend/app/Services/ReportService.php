<?php

namespace App\Services;

use App\DTOs\ReportPeriod;
use App\Enums\OrderStatus;
use App\Enums\PaymentStatus;
use App\Models\InventoryItem;
use App\Models\Payment;
use App\Models\Setting;
use App\Settings\SettingRegistry;
use Carbon\CarbonImmutable;
use DateTimeZone;
use Illuminate\Support\Facades\DB;

class ReportService
{
    public function resolvePeriod(?string $fromDate, ?string $toDate): ReportPeriod
    {
        $setting = Setting::query()->where('key', SettingRegistry::SHOP_TIMEZONE)->first();
        $tzName = $setting?->value;

        if (! is_string($tzName) || ! in_array($tzName, DateTimeZone::listIdentifiers(), true)) {
            abort(409, 'The shop timezone is not configured. An administrator must set shop_timezone before generating reports.');
        }

        if ($fromDate === null && $toDate === null) {
            $now = CarbonImmutable::now($tzName);
            $toDate = $now->format('Y-m-d');
            $fromDate = $now->subDays(29)->format('Y-m-d');
        } elseif ($fromDate !== null && $toDate === null) {
            $toDate = $fromDate;
        } elseif ($fromDate === null && $toDate !== null) {
            $fromDate = $toDate;
        }

        $fromUtc = CarbonImmutable::createFromFormat('!Y-m-d', $fromDate, $tzName)->startOfDay()->utc();
        $toExclusiveUtc = CarbonImmutable::createFromFormat('!Y-m-d', $toDate, $tzName)->addDay()->startOfDay()->utc();

        return new ReportPeriod(
            fromDate: $fromDate,
            toDate: $toDate,
            timezone: $tzName,
            fromUtc: $fromUtc,
            toExclusiveUtc: $toExclusiveUtc,
        );
    }

    /**
     * @return array<string, mixed>
     */
    public function getOverview(ReportPeriod $period): array
    {
        $ordersAgg = DB::table('orders')
            ->where('status', OrderStatus::Paid->value)
            ->where('paid_at', '>=', $period->fromUtc)
            ->where('paid_at', '<', $period->toExclusiveUtc)
            ->whereNotNull('accepted_payment_id')
            ->selectRaw('COUNT(*) as paid_orders, COALESCE(SUM(total_minor), 0) as revenue_minor')
            ->first();

        $paidOrders = (int) ($ordersAgg->paid_orders ?? 0);
        $revenueMinor = (string) ($ordersAgg->revenue_minor ?? '0');
        $aovMinor = $paidOrders > 0 ? (string) intdiv((int) $revenueMinor, $paidOrders) : '0';

        $lowStockItems = InventoryItem::query()
            ->where('is_active', true)
            ->whereRaw('(on_hand - reserved) <= reorder_level')
            ->count();

        $reconciliationRequired = Payment::query()
            ->where('reconciliation_required', true)
            ->count();

        return [
            'period' => $period->toArray(),
            'revenue_minor' => $revenueMinor,
            'currency' => 'USD',
            'paid_orders' => $paidOrders,
            'average_order_value_minor' => $aovMinor,
            'low_stock_items' => $lowStockItems,
            'reconciliation_required' => $reconciliationRequired,
        ];
    }

    /**
     * @return array<string, mixed>
     */
    public function getSalesTrend(ReportPeriod $period): array
    {
        $buckets = [];
        $current = CarbonImmutable::createFromFormat('!Y-m-d', $period->fromDate, $period->timezone);
        $end = CarbonImmutable::createFromFormat('!Y-m-d', $period->toDate, $period->timezone);

        while ($current <= $end) {
            $dStr = $current->format('Y-m-d');
            $buckets[$dStr] = [
                'date' => $dStr,
                'revenue_minor' => '0',
                'paid_orders' => 0,
            ];
            $current = $current->addDay();
        }

        $orders = DB::table('orders')
            ->where('status', OrderStatus::Paid->value)
            ->where('paid_at', '>=', $period->fromUtc)
            ->where('paid_at', '<', $period->toExclusiveUtc)
            ->whereNotNull('accepted_payment_id')
            ->select(['id', 'total_minor', 'paid_at'])
            ->get();

        foreach ($orders as $order) {
            $paidAtUtc = CarbonImmutable::parse($order->paid_at, 'UTC');
            $localDate = $paidAtUtc->setTimezone($period->timezone)->format('Y-m-d');
            if (isset($buckets[$localDate])) {
                $buckets[$localDate]['paid_orders']++;
                $buckets[$localDate]['revenue_minor'] = (string) ((int) $buckets[$localDate]['revenue_minor'] + (int) $order->total_minor);
            }
        }

        return [
            'period' => $period->toArray(),
            'data' => array_values($buckets),
        ];
    }

    /**
     * @return array<string, mixed>
     */
    public function getPaymentMethods(ReportPeriod $period): array
    {
        $results = DB::table('orders')
            ->join('payments', 'payments.id', '=', 'orders.accepted_payment_id')
            ->where('orders.status', OrderStatus::Paid->value)
            ->where('orders.paid_at', '>=', $period->fromUtc)
            ->where('orders.paid_at', '<', $period->toExclusiveUtc)
            ->whereNotNull('orders.accepted_payment_id')
            ->select([
                'payments.method',
                DB::raw('COUNT(orders.id) as paid_orders'),
                DB::raw('COALESCE(SUM(orders.total_minor), 0) as amount_minor'),
            ])
            ->groupBy('payments.method')
            ->orderBy('amount_minor', 'desc')
            ->get();

        $data = $results->map(fn ($row): array => [
            'method' => (string) $row->method,
            'paid_orders' => (int) $row->paid_orders,
            'amount_minor' => (string) $row->amount_minor,
        ])->all();

        return [
            'period' => $period->toArray(),
            'currency' => 'USD',
            'data' => $data,
        ];
    }

    /**
     * @return array<string, mixed>
     */
    public function getTopProducts(ReportPeriod $period, int $limit = 10): array
    {
        $results = DB::table('order_items')
            ->join('orders', 'orders.id', '=', 'order_items.order_id')
            ->where('orders.status', OrderStatus::Paid->value)
            ->where('orders.paid_at', '>=', $period->fromUtc)
            ->where('orders.paid_at', '<', $period->toExclusiveUtc)
            ->whereNotNull('orders.accepted_payment_id')
            ->select([
                'order_items.product_id',
                DB::raw('MAX(order_items.product_sku) as sku'),
                DB::raw('MAX(order_items.product_name) as name'),
                DB::raw('SUM(order_items.quantity) as quantity_sold'),
                DB::raw('COALESCE(SUM(order_items.line_total_minor), 0) as revenue_minor'),
            ])
            ->groupBy('order_items.product_id')
            ->orderBy('revenue_minor', 'desc')
            ->orderBy('quantity_sold', 'desc')
            ->orderBy('order_items.product_id', 'asc')
            ->limit($limit)
            ->get();

        $data = $results->map(fn ($row): array => [
            'product_id' => (int) $row->product_id,
            'sku' => (string) $row->sku,
            'name' => (string) $row->name,
            'quantity_sold' => (int) $row->quantity_sold,
            'revenue_minor' => (string) $row->revenue_minor,
        ])->all();

        return [
            'period' => $period->toArray(),
            'currency' => 'USD',
            'data' => $data,
        ];
    }

    /**
     * @return array<string, mixed>
     */
    public function getInventorySummary(?string $status, ?string $search, int $page = 1, int $perPage = 25): array
    {
        $totalItems = InventoryItem::query()->count();
        $lowStockItems = InventoryItem::query()
            ->where('is_active', true)
            ->whereRaw('(on_hand - reserved) <= reorder_level')
            ->count();

        $query = InventoryItem::query();
        if ($status === 'low') {
            $query->where('is_active', true)->whereRaw('(on_hand - reserved) <= reorder_level');
        }

        if ($search !== null && $search !== '') {
            $query->where(function ($q) use ($search): void {
                $pattern = '%'.addcslashes($search, '%_').'%';
                $q->where('name', 'like', $pattern)
                    ->orWhere('sku', 'like', $pattern);
            });
        }

        $paginator = $query->orderBy('name', 'asc')->orderBy('id', 'asc')->paginate($perPage, ['*'], 'page', $page);

        $data = collect($paginator->items())->map(function (InventoryItem $item): array {
            $available = bcsub((string) $item->on_hand, (string) $item->reserved, 4);
            $isLow = $item->is_active && bccomp($available, (string) $item->reorder_level, 4) <= 0;

            return [
                'id' => $item->id,
                'sku' => $item->sku,
                'name' => $item->name,
                'base_unit' => $item->base_unit,
                'on_hand' => (string) $item->on_hand,
                'reserved' => (string) $item->reserved,
                'available' => $available,
                'reorder_level' => (string) $item->reorder_level,
                'is_low_stock' => $isLow,
                'is_active' => $item->is_active,
            ];
        })->all();

        return [
            'summary' => [
                'total_items' => $totalItems,
                'low_stock_items' => $lowStockItems,
            ],
            'data' => $data,
            'meta' => [
                'current_page' => $paginator->currentPage(),
                'last_page' => $paginator->lastPage(),
                'per_page' => $paginator->perPage(),
                'total' => $paginator->total(),
            ],
        ];
    }

    /**
     * @return array<string, mixed>
     */
    public function getReconciliationSummary(int $page = 1, int $perPage = 25): array
    {
        $reconciliationRequiredCount = Payment::query()->where('reconciliation_required', true)->count();
        $unresolvedAttemptsCount = Payment::query()->whereIn('status', [PaymentStatus::Pending->value, PaymentStatus::Uncertain->value])->count();

        $query = Payment::query()
            ->with('order:id,public_reference')
            ->where(function ($q): void {
                $q->where('reconciliation_required', true)
                    ->orWhereIn('status', [PaymentStatus::Pending->value, PaymentStatus::Uncertain->value]);
            })
            ->orderBy('updated_at', 'desc')
            ->orderBy('id', 'desc');

        $paginator = $query->paginate($perPage, ['*'], 'page', $page);

        $data = collect($paginator->items())->map(function (Payment $payment): array {
            return [
                'id' => $payment->id,
                'order_id' => $payment->order_id,
                'order_reference' => $payment->order?->public_reference,
                'method' => $payment->method instanceof \BackedEnum ? $payment->method->value : (string) $payment->method,
                'status' => $payment->status instanceof \BackedEnum ? $payment->status->value : (string) $payment->status,
                'expected_amount_minor' => (string) $payment->expected_amount_minor,
                'currency' => $payment->currency,
                'tender_minor' => $payment->tender_minor !== null ? (string) $payment->tender_minor : null,
                'change_minor' => $payment->change_minor !== null ? (string) $payment->change_minor : null,
                'reconciliation_required' => $payment->reconciliation_required,
                'reconciliation_reason' => $payment->reconciliation_reason,
                'created_at' => $payment->created_at?->toISOString(),
                'updated_at' => $payment->updated_at?->toISOString(),
            ];
        })->all();

        return [
            'summary' => [
                'reconciliation_required_count' => $reconciliationRequiredCount,
                'unresolved_attempts_count' => $unresolvedAttemptsCount,
            ],
            'data' => $data,
            'meta' => [
                'current_page' => $paginator->currentPage(),
                'last_page' => $paginator->lastPage(),
                'per_page' => $paginator->perPage(),
                'total' => $paginator->total(),
            ],
        ];
    }
}
