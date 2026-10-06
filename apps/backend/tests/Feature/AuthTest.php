<?php

namespace Tests\Feature;

use App\Enums\StaffRole;
use App\Models\Role;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Hash;
use Laravel\Sanctum\PersonalAccessToken;
use PHPUnit\Framework\Attributes\DataProvider;
use Tests\TestCase;

class AuthTest extends TestCase
{
    use RefreshDatabase;

    private const string PASSWORD = 'Test-only-passphrase!2026';

    /** @return array<string, string> */
    private function credentials(string $email): array
    {
        return ['email' => $email, 'password' => self::PASSWORD, 'device_name' => 'Synthetic test terminal'];
    }

    private function bearer(string $token): static
    {
        // Separate HTTP requests must resolve identity again, as in a fresh API request.
        Auth::forgetGuards();

        return $this->withToken($token);
    }

    public function test_login_returns_current_role_and_hashes_an_expiring_token(): void
    {
        $user = User::factory()->withRole(StaffRole::Manager)->create();
        $this->freezeSecond();

        $response = $this->postJson('/api/v1/auth/login', $this->credentials('  '.strtoupper($user->email).'  '))
            ->assertOk()->assertJsonPath('data.id', $user->id)
            ->assertJsonPath('data.role', 'manager')
            ->assertJsonPath('token_type', 'Bearer');

        $this->assertContains('manage-catalog', $response->json('data.permissions'));
        $this->assertNotContains('manage-staff', $response->json('data.permissions'));
        $this->assertStringContainsString('no-store', $response->headers->get('Cache-Control'));
        $stored = PersonalAccessToken::query()->sole();
        $this->assertSame($user->id, $stored->tokenable_id);
        $this->assertSame('Synthetic test terminal', $stored->name);
        $this->assertSame(['staff'], $stored->abilities);
        $this->assertTrue($stored->expires_at->equalTo(now()->addHours(8)));
        $this->assertSame(now()->addHours(8)->toIso8601String(), $response->json('expires_at'));
        $plainSecret = explode('|', $response->json('token'), 2)[1];
        $this->assertSame(hash('sha256', $plainSecret), $stored->token);
        $this->assertTrue(Hash::check(self::PASSWORD, $user->password));
        $this->assertNotSame(self::PASSWORD, $user->password);
    }

    public function test_invalid_credentials_and_missing_identity_have_the_same_response_and_no_token(): void
    {
        $user = User::factory()->create();
        $wrong = [...$this->credentials($user->email), 'password' => 'Incorrect-synthetic-password'];
        $first = $this->postJson('/api/v1/auth/login', $wrong)->assertUnauthorized()->json();
        $second = $this->postJson('/api/v1/auth/login', $this->credentials('missing@example.test'))
            ->assertUnauthorized()->json();

        $this->assertSame($first, $second);
        $this->assertDatabaseCount('personal_access_tokens', 0);
    }

    public function test_inactive_unassigned_and_unknown_role_users_cannot_login(): void
    {
        $unknown = Role::query()->create(['name' => 'unrecognized', 'label' => 'Unrecognized']);
        $users = [
            User::factory()->inactive()->create(),
            User::factory()->create(['role_id' => null]),
            User::factory()->create(['role_id' => $unknown->id]),
        ];

        foreach ($users as $user) {
            $this->postJson('/api/v1/auth/login', $this->credentials($user->email))
                ->assertUnauthorized()->assertExactJson(['message' => 'The provided credentials are incorrect.']);
        }

        $this->assertDatabaseCount('personal_access_tokens', 0);
    }

    public static function invalidInputs(): array
    {
        return [
            'missing fields' => [[], ['email', 'password', 'device_name']],
            'wrong types' => [['email' => [], 'password' => [], 'device_name' => []], ['email', 'password', 'device_name']],
            'invalid email' => [['email' => 'invalid', 'password' => 'x', 'device_name' => 'test'], ['email']],
            'bounded input' => [['email' => str_repeat('a', 256).'@example.test', 'password' => str_repeat('a', 1025), 'device_name' => str_repeat('a', 101)], ['email', 'password', 'device_name']],
        ];
    }

    #[DataProvider('invalidInputs')]
    public function test_invalid_input_returns_validation_errors(array $input, array $fields): void
    {
        $this->postJson('/api/v1/auth/login', $input)->assertUnprocessable()->assertJsonValidationErrors($fields);
        $this->assertDatabaseCount('personal_access_tokens', 0);
    }

    public function test_privilege_and_ownership_fields_are_rejected_without_changes(): void
    {
        $user = User::factory()->create();
        $input = [...$this->credentials($user->email), 'role' => 'admin', 'role_id' => 99, 'permissions' => ['*'],
            'is_active' => true, 'user_id' => 99, 'price' => 0, 'payment_status' => 'paid', 'unexpected' => 'value'];

        $this->postJson('/api/v1/auth/login', $input)->assertUnprocessable()
            ->assertJsonValidationErrors(['role', 'role_id', 'permissions', 'is_active', 'user_id', 'price', 'payment_status', 'unexpected']);

        $this->assertSame('cashier', $user->fresh()->role->name);
        $this->assertDatabaseCount('personal_access_tokens', 0);
    }

    public function test_protected_endpoints_are_json_401_without_bearer_authentication(): void
    {
        $this->get('/api/v1/auth/me')->assertUnauthorized()->assertHeader('Content-Type', 'application/json');
        Auth::forgetGuards();
        $this->post('/api/v1/auth/logout')->assertUnauthorized();
        $this->bearer('invalid-token')->get('/api/v1/auth/me')->assertUnauthorized();
    }

    public function test_current_user_serializes_only_public_identity_fields(): void
    {
        $user = User::factory()->create();
        $login = $this->postJson('/api/v1/auth/login', $this->credentials($user->email))->assertOk();
        $response = $this->bearer($login->json('token'))->get('/api/v1/auth/me')
            ->assertOk()->assertJsonPath('data.id', $user->id);

        foreach ([$login->json('data'), $response->json('data')] as $data) {
            $this->assertSame(['id', 'name', 'email', 'role', 'permissions'], array_keys($data));
            foreach (['password', 'remember_token', 'role_id', 'tokens', 'token', 'is_active'] as $key) {
                $this->assertArrayNotHasKey($key, $data);
            }
        }

        $this->assertSame(['data'], array_keys($response->json()));
        $this->assertArrayNotHasKey('password', $user->toArray());
        $this->assertArrayNotHasKey('remember_token', $user->toArray());
        $this->assertStringContainsString('no-store', $response->headers->get('Cache-Control'));
    }

    public function test_logout_invalidates_only_calling_token(): void
    {
        $user = User::factory()->create();
        $first = $this->postJson('/api/v1/auth/login', $this->credentials($user->email))->assertOk()->json('token');
        $other = $user->createToken('Other synthetic terminal', ['staff'], now()->addHour())->plainTextToken;

        $this->bearer($first)->post('/api/v1/auth/logout')->assertNoContent();
        $this->assertNull(PersonalAccessToken::findToken($first));
        $this->assertDatabaseCount('personal_access_tokens', 1);
        $this->bearer($first)->get('/api/v1/auth/me')->assertUnauthorized();
        $this->bearer($first)->post('/api/v1/auth/logout')->assertUnauthorized();
        $this->bearer($other)->get('/api/v1/auth/me')->assertOk()->assertJsonPath('data.id', $user->id);
    }

    public function test_expired_and_globally_overage_tokens_are_rejected(): void
    {
        $user = User::factory()->create();
        $expired = $user->createToken('Expired', ['staff'], now()->subSecond())->plainTextToken;
        $this->bearer($expired)->get('/api/v1/auth/me')->assertUnauthorized();
        $login = $this->postJson('/api/v1/auth/login', $this->credentials($user->email))->assertOk();
        $this->travel(8)->hours();
        $this->travel(1)->seconds();
        $this->bearer($login->json('token'))->get('/api/v1/auth/me')->assertUnauthorized();

        $old = $user->createToken('Overage', ['staff'], now()->addDay());
        $old->accessToken->forceFill(['created_at' => now()->subHours(9)])->save();
        $this->bearer($old->plainTextToken)->get('/api/v1/auth/me')->assertUnauthorized();
    }

    public function test_account_and_role_changes_apply_to_existing_token_on_next_request(): void
    {
        $user = User::factory()->withRole(StaffRole::Admin)->create();
        $token = $this->postJson('/api/v1/auth/login', $this->credentials($user->email))->assertOk()->json('token');
        $cashier = Role::query()->firstOrCreate(['name' => 'cashier'], ['label' => 'Cashier']);
        $user->forceFill(['role_id' => $cashier->id])->save();
        $response = $this->bearer($token)->get('/api/v1/auth/me')->assertOk()->assertJsonPath('data.role', 'cashier');
        $this->assertNotContains('manage-staff', $response->json('data.permissions'));

        $user->forceFill(['is_active' => false])->save();
        $this->bearer($token)->get('/api/v1/auth/me')->assertForbidden();
        $user->forceFill(['is_active' => true, 'role_id' => null])->save();
        $this->bearer($token)->get('/api/v1/auth/me')->assertForbidden();
        $unknown = Role::query()->create(['name' => 'unknown', 'label' => 'Unknown']);
        $user->forceFill(['role_id' => $unknown->id])->save();
        $this->bearer($token)->get('/api/v1/auth/me')->assertForbidden();
    }

    public function test_identity_rate_limit_normalizes_email_and_recovers_after_window(): void
    {
        $user = User::factory()->create();
        $this->freezeTime();
        for ($attempt = 0; $attempt < 5; $attempt++) {
            $email = $attempt % 2 ? strtoupper($user->email) : ' '.$user->email.' ';
            $this->postJson('/api/v1/auth/login', [...$this->credentials($email), 'password' => 'Wrong-test-password'])
                ->assertUnauthorized();
        }

        $this->postJson('/api/v1/auth/login', $this->credentials($user->email))
            ->assertTooManyRequests()->assertHeader('Retry-After');
        $this->assertDatabaseCount('personal_access_tokens', 0);
        $this->travel(61)->seconds();
        $this->postJson('/api/v1/auth/login', $this->credentials($user->email))->assertOk();
    }

    public function test_ip_rate_limit_also_covers_rotating_identities_and_invalid_requests(): void
    {
        for ($attempt = 0; $attempt < 30; $attempt++) {
            $this->postJson('/api/v1/auth/login', ['email' => "synthetic{$attempt}@example.test"])->assertUnprocessable();
        }

        $this->postJson('/api/v1/auth/login', ['email' => 'another@example.test'])
            ->assertTooManyRequests()->assertHeader('Retry-After');
    }

    public function test_cookie_guard_cannot_replace_a_bearer_token(): void
    {
        $user = User::factory()->create();
        $this->actingAs($user, 'web')->get('/api/v1/auth/me')->assertUnauthorized();
        $this->get('/sanctum/csrf-cookie')->assertNotFound();
        $this->postJson('/api/v1/auth/register', $this->credentials($user->email))->assertNotFound();
    }

    public function test_tokens_without_staff_ability_cannot_access_protected_auth_endpoints(): void
    {
        $user = User::factory()->withRole(StaffRole::Admin)->create();
        $token = $user->createToken('Restricted synthetic token', [], now()->addHour())->plainTextToken;
        $this->bearer($token)->get('/api/v1/auth/me')->assertForbidden();
        $this->bearer($token)->post('/api/v1/auth/logout')->assertForbidden();
    }

    public function test_successful_login_rehashes_password_when_cost_changes(): void
    {
        $user = User::factory()->create();
        $before = $user->password;
        config(['hashing.bcrypt.rounds' => 5]);
        Hash::forgetDrivers();

        $this->postJson('/api/v1/auth/login', $this->credentials($user->email))->assertOk();
        $after = $user->fresh()->password;
        $this->assertNotSame($before, $after);
        $this->assertTrue(Hash::check(self::PASSWORD, $after));
        $this->assertFalse(Hash::needsRehash($after));
    }

    public function test_current_user_cannot_be_redirected_to_another_identity_by_query_input(): void
    {
        $caller = User::factory()->create();
        $other = User::factory()->withRole(StaffRole::Admin)->create();
        $token = $caller->createToken('Synthetic identity test', ['staff'], now()->addHour())->plainTextToken;

        $this->bearer($token)->getJson('/api/v1/auth/me?user_id='.$other->id)
            ->assertOk()->assertJsonPath('data.id', $caller->id)->assertJsonPath('data.role', 'cashier');
    }
}
