<?php

namespace Tests\Feature;

use App\Enums\OrderStatus;
use App\Enums\PaymentStatus;
use App\Enums\StaffRole;
use App\Models\Order;
use App\Models\Payment;
use App\Models\Setting;
use App\Models\User;
use App\Settings\SettingRegistry;
use Carbon\CarbonImmutable;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Tests\TestCase;

class ReportTimezoneTest extends TestCase
{
    use RefreshDatabase;

    private function staff(StaffRole $role = StaffRole::Manager): User
    {
        $user = User::factory()->withRole($role)->create();
        Auth::forgetGuards();
        $this->withToken($user->createToken('Synthetic timezone terminal', ['staff'], now()->addHour())->plainTextToken);

        return $user;
    }

    private function setTimezone(?string $timezone): void
    {
        if ($timezone === null) {
            Setting::query()->where('key', SettingRegistry::SHOP_TIMEZONE)->delete();
        } else {
            Setting::query()->updateOrCreate(
                ['key' => SettingRegistry::SHOP_TIMEZONE],
                ['value' => $timezone]
            );
        }
    }

    private function createPaidOrder(int $totalMinor, CarbonImmutable $paidAtUtc): Order
    {
        $creator = User::factory()->create();

        $order = Order::factory()->create([
            'created_by' => $creator->id,
            'total_minor' => $totalMinor,
            'subtotal_minor' => $totalMinor,
            'discount_minor' => 0,
            'tax_minor' => 0,
            'currency' => 'USD',
            'status' => OrderStatus::PendingPayment,
            'paid_at' => null,
            'accepted_payment_id' => null,
            'active_payment_id' => null,
            'created_at' => $paidAtUtc,
            'updated_at' => $paidAtUtc,
        ]);

        $payment = new Payment;
        $payment->forceFill([
            'order_id' => $order->id,
            'initiated_by' => $creator->id,
            'attempt_key' => (string) Str::uuid(),
            'request_hash' => hash('sha256', (string) Str::uuid()),
            'method' => 'cash',
            'status' => PaymentStatus::Confirmed->value,
            'expected_amount_minor' => $totalMinor,
            'currency' => 'USD',
            'tender_minor' => $totalMinor,
            'change_minor' => 0,
            'reconciliation_required' => false,
            'verified_at' => $paidAtUtc,
            'created_at' => $paidAtUtc,
            'updated_at' => $paidAtUtc,
        ])->save();

        DB::table('orders')->where('id', $order->id)->update([
            'status' => OrderStatus::Paid->value,
            'accepted_payment_id' => $payment->id,
            'paid_at' => $paidAtUtc,
            'updated_at' => $paidAtUtc,
        ]);

        return $order->fresh();
    }

    public function test_missing_shop_timezone_returns_409_conflict_on_all_endpoints(): void
    {
        $this->setTimezone(null);
        $this->staff(StaffRole::Manager);

        $endpoints = [
            '/api/v1/reports/overview',
            '/api/v1/reports/sales-trend',
            '/api/v1/reports/payment-methods',
            '/api/v1/reports/top-products',
        ];

        foreach ($endpoints as $uri) {
            $response = $this->getJson($uri)->assertStatus(409);
            $this->assertStringContainsString(
                'The shop timezone is not configured. An administrator must set shop_timezone before generating reports.',
                $response->json('message')
            );
        }
    }

    public function test_invalid_timezone_in_database_returns_409_conflict(): void
    {
        // Directly set an invalid timezone string in settings
        DB::table('settings')->updateOrInsert(
            ['key' => SettingRegistry::SHOP_TIMEZONE],
            ['value' => json_encode('Invalid/Nonexistent_Timezone'), 'created_at' => now(), 'updated_at' => now()]
        );
        $this->staff(StaffRole::Manager);

        $this->getJson('/api/v1/reports/overview')->assertStatus(409);
    }

    public function test_phnom_penh_business_day_boundaries_across_utc_midnight(): void
    {
        // Asia/Phnom_Penh is UTC+7 (no DST)
        // 2026-10-06 00:00:00 +07:00 is 2026-10-05 17:00:00 UTC
        // 2026-10-06 23:59:59 +07:00 is 2026-10-06 16:59:59 UTC
        $this->setTimezone('Asia/Phnom_Penh');
        $this->staff(StaffRole::Manager);

        // 1. Paid at 2026-10-05 16:59:59 UTC -> 2026-10-05 23:59:59 +07:00 (Belongs to Oct 5)
        $this->createPaidOrder(100, CarbonImmutable::parse('2026-10-05 16:59:59', 'UTC'));

        // 2. Paid at 2026-10-05 17:00:00 UTC -> 2026-10-06 00:00:00 +07:00 (Belongs to Oct 6 start)
        $this->createPaidOrder(200, CarbonImmutable::parse('2026-10-05 17:00:00', 'UTC'));

        // 3. Paid at 2026-10-06 12:00:00 UTC -> 2026-10-06 19:00:00 +07:00 (Belongs to Oct 6 midday)
        $this->createPaidOrder(300, CarbonImmutable::parse('2026-10-06 12:00:00', 'UTC'));

        // 4. Paid at 2026-10-06 16:59:59 UTC -> 2026-10-06 23:59:59 +07:00 (Belongs to Oct 6 end)
        $this->createPaidOrder(400, CarbonImmutable::parse('2026-10-06 16:59:59', 'UTC'));

        // 5. Paid at 2026-10-06 17:00:00 UTC -> 2026-10-07 00:00:00 +07:00 (Belongs to Oct 7 start)
        $this->createPaidOrder(500, CarbonImmutable::parse('2026-10-06 17:00:00', 'UTC'));

        // Query overview strictly for Oct 6: should include orders 2, 3, 4 (200 + 300 + 400 = 900 minor)
        $overview = $this->getJson('/api/v1/reports/overview?from_date=2026-10-06&to_date=2026-10-06')
            ->assertOk();

        $overview->assertJson([
            'data' => [
                'period' => [
                    'from_date' => '2026-10-06',
                    'to_date' => '2026-10-06',
                    'timezone' => 'Asia/Phnom_Penh',
                ],
                'revenue_minor' => '900',
                'paid_orders' => 3,
                'average_order_value_minor' => '300',
            ],
        ]);

        // Query sales-trend across Oct 5 - Oct 7: verify exact daily bucketing
        $trend = $this->getJson('/api/v1/reports/sales-trend?from_date=2026-10-05&to_date=2026-10-07')
            ->assertOk();

        $data = $trend->json('data');
        $this->assertCount(3, $data);

        // 2026-10-05 has order 1 (100 minor)
        $this->assertSame('2026-10-05', $data[0]['date']);
        $this->assertSame('100', $data[0]['revenue_minor']);
        $this->assertSame(1, $data[0]['paid_orders']);

        // 2026-10-06 has orders 2, 3, 4 (900 minor)
        $this->assertSame('2026-10-06', $data[1]['date']);
        $this->assertSame('900', $data[1]['revenue_minor']);
        $this->assertSame(3, $data[1]['paid_orders']);

        // 2026-10-07 has order 5 (500 minor)
        $this->assertSame('2026-10-07', $data[2]['date']);
        $this->assertSame('500', $data[2]['revenue_minor']);
        $this->assertSame(1, $data[2]['paid_orders']);
    }

    public function test_dst_observing_timezone_calculates_correct_utc_boundaries(): void
    {
        // America/New_York DST change: 2026-11-01 02:00 EDT -> 01:00 EST
        $this->setTimezone('America/New_York');
        $this->staff(StaffRole::Manager);

        // On 2026-10-31 (EDT is UTC-4): 00:00 EDT = 04:00 UTC
        $this->createPaidOrder(1000, CarbonImmutable::parse('2026-10-31 12:00:00', 'America/New_York')->utc());

        // On 2026-11-01 (DST transition day)
        $this->createPaidOrder(2000, CarbonImmutable::parse('2026-11-01 12:00:00', 'America/New_York')->utc());

        // On 2026-11-02 (EST is UTC-5): 00:00 EST = 05:00 UTC
        $this->createPaidOrder(3000, CarbonImmutable::parse('2026-11-02 12:00:00', 'America/New_York')->utc());

        $response = $this->getJson('/api/v1/reports/sales-trend?from_date=2026-10-31&to_date=2026-11-02')
            ->assertOk();

        $data = $response->json('data');
        $this->assertCount(3, $data);

        $this->assertSame('2026-10-31', $data[0]['date']);
        $this->assertSame('1000', $data[0]['revenue_minor']);
        $this->assertSame(1, $data[0]['paid_orders']);

        $this->assertSame('2026-11-01', $data[1]['date']);
        $this->assertSame('2000', $data[1]['revenue_minor']);
        $this->assertSame(1, $data[1]['paid_orders']);

        $this->assertSame('2026-11-02', $data[2]['date']);
        $this->assertSame('3000', $data[2]['revenue_minor']);
        $this->assertSame(1, $data[2]['paid_orders']);
    }

    public function test_default_date_range_uses_30_business_days_ending_today_in_shop_timezone(): void
    {
        $this->setTimezone('Asia/Phnom_Penh');
        $this->staff(StaffRole::Manager);

        $response = $this->getJson('/api/v1/reports/overview')->assertOk();

        $nowLocal = CarbonImmutable::now('Asia/Phnom_Penh');
        $expectedTo = $nowLocal->format('Y-m-d');
        $expectedFrom = $nowLocal->subDays(29)->format('Y-m-d');

        $this->assertSame($expectedFrom, $response->json('data.period.from_date'));
        $this->assertSame($expectedTo, $response->json('data.period.to_date'));
        $this->assertSame('Asia/Phnom_Penh', $response->json('data.period.timezone'));
    }
}
