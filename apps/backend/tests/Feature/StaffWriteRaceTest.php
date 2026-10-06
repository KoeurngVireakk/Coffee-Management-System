<?php

namespace Tests\Feature;

use App\Enums\StaffRole;
use App\Models\Role;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Event;
use Illuminate\Support\Facades\Hash;
use PHPUnit\Framework\Attributes\DataProvider;
use Tests\TestCase;

class StaffWriteRaceTest extends TestCase
{
    use RefreshDatabase;

    public static function methods(): array
    {
        return [
            'create race' => ['POST'],
            'update race' => ['PATCH'],
        ];
    }

    #[DataProvider('methods')]
    public function test_email_claimed_after_validation_returns_field_error_instead_of_500(string $method): void
    {
        $admin = User::factory()->withRole(StaffRole::Admin)->create();
        $target = User::factory()->withRole(StaffRole::Cashier)->create(['email' => 'original@example.com']);
        $this->withToken($admin->createToken('Synthetic race terminal', ['staff'], now()->addHour())->plainTextToken);

        $event = $method === 'POST' ? 'creating' : 'updating';

        // Interleave a competing write after FormRequest uniqueness validation
        Event::listen('eloquent.'.$event.': '.User::class, function (User $pending): void {
            if ($pending->email === 'concurrent@example.com') {
                $role = Role::firstOrCreate(
                    ['name' => StaffRole::Cashier->value],
                    ['label' => StaffRole::Cashier->label()]
                );
                DB::table('users')->insert([
                    'name' => 'Competing user',
                    'email' => 'concurrent@example.com',
                    'password' => Hash::make('Valid-passphrase!2026'),
                    'role_id' => $role->id,
                    'is_active' => true,
                    'created_at' => now(),
                    'updated_at' => now(),
                ]);
            }
        });

        $body = [
            'name' => 'Requested user',
            'email' => 'concurrent@example.com',
            'role' => 'cashier',
            'password' => 'Valid-passphrase!2026',
        ];
        if ($method === 'PATCH') {
            unset($body['password']);
        }

        $uri = '/api/v1/staff'.($method === 'PATCH' ? '/'.$target->id : '');
        $this->json($method, $uri, $body)->assertUnprocessable()->assertJsonValidationErrors(['email']);

        if ($method === 'PATCH') {
            $this->assertSame('original@example.com', $target->fresh()->email);
        } else {
            $this->assertSame(0, User::where('name', 'Requested user')->count());
        }
    }
}

