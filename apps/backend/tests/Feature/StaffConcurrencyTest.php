<?php

namespace Tests\Feature;

use App\Enums\StaffRole;
use App\Models\Role;
use App\Models\User;
use Illuminate\Foundation\Testing\DatabaseMigrations;
use Illuminate\Support\Facades\DB;
use Symfony\Component\Process\InputStream;
use Symfony\Component\Process\Process;
use Tests\TestCase;

class StaffConcurrencyTest extends TestCase
{
    use DatabaseMigrations;

    private array $workers = [];

    protected function beforeRefreshingDatabase(): void
    {
        if (DB::getDriverName() !== 'mysql') {
            $this->markTestSkipped('Real independent-connection lock/race tests require MySQL.');
        }
    }

    protected function tearDown(): void
    {
        foreach ($this->workers as [$process, $input]) {
            $input->close();
            if ($process->isRunning()) {
                $process->stop(0);
            }
        }
        if (isset($this->app) && DB::transactionLevel()) {
            DB::rollBack();
        }
        parent::tearDown();
    }

    private function worker(array $payload): array
    {
        $input = new InputStream;
        $payload += [
            'connection' => DB::connection()->getConfig(),
            'datadir' => DB::selectOne('SELECT @@datadir AS directory')->directory,
        ];
        $input->write(json_encode($payload, JSON_THROW_ON_ERROR)."\n");
        $process = new Process([PHP_BINARY, base_path('tests/Support/staff-worker.php')], base_path(), input: $input, timeout: 15);
        $process->start();
        $worker = [$process, $input];
        $this->workers[] = $worker;

        return $worker;
    }

    private function ready(array $worker): int
    {
        [$process] = $worker;
        $deadline = microtime(true) + 10;
        while (! preg_match('/READY (\d+)/', $process->getOutput(), $match)) {
            if (! $process->isRunning() || microtime(true) >= $deadline) {
                $this->fail('Worker failed to reach barrier: '.$process->getErrorOutput());
            }
            usleep(10000);
        }

        return (int) $match[1];
    }

    private function release(array $worker): void
    {
        $worker[1]->write("GO\n");
    }

    private function finish(array $worker): array
    {
        [$process] = $worker;
        $process->wait();
        $output = trim($process->getOutput());
        $lines = explode("\n", $output);
        $lastLine = end($lines);

        return json_decode($lastLine, true, flags: JSON_THROW_ON_ERROR);
    }

    public function test_concurrent_last_admin_deactivation_race_preserves_one_operational_admin(): void
    {
        $adminA = User::factory()->withRole(StaffRole::Admin)->create(['name' => 'Admin A', 'is_active' => true]);
        $adminB = User::factory()->withRole(StaffRole::Admin)->create(['name' => 'Admin B', 'is_active' => true]);

        $workerA = $this->worker([
            'admin_id' => $adminA->id,
            'target_id' => $adminB->id,
            'action' => 'deactivate',
            'barrier' => 'start',
        ]);

        $workerB = $this->worker([
            'admin_id' => $adminB->id,
            'target_id' => $adminA->id,
            'action' => 'deactivate',
            'barrier' => 'start',
        ]);

        $this->ready($workerA);
        $this->ready($workerB);

        $this->release($workerA);
        $this->release($workerB);

        $resA = $this->finish($workerA);
        $resB = $this->finish($workerB);

        $results = [$resA, $resB];
        $successes = array_filter($results, fn ($r) => ($r['status'] ?? '') === 'success');
        $conflicts = array_filter($results, fn ($r) => ($r['http_status'] ?? 0) === 409);

        $this->assertCount(1, $successes, 'Exactly one concurrent deactivation should succeed');
        $this->assertCount(1, $conflicts, 'The competing deactivation must receive 409 Conflict');

        // Verify remaining operational admins count in database is exactly 1
        $adminRole = Role::where('name', StaffRole::Admin->value)->firstOrFail();
        $activeAdminCount = User::where('role_id', $adminRole->id)->where('is_active', true)->count();
        $this->assertSame(1, $activeAdminCount, 'Exactly one operational admin must remain');
    }

    public function test_concurrent_last_admin_demotion_race_preserves_one_operational_admin(): void
    {
        $adminA = User::factory()->withRole(StaffRole::Admin)->create(['name' => 'Admin A', 'is_active' => true]);
        $adminB = User::factory()->withRole(StaffRole::Admin)->create(['name' => 'Admin B', 'is_active' => true]);

        $workerA = $this->worker([
            'admin_id' => $adminA->id,
            'target_id' => $adminB->id,
            'action' => 'demote',
            'barrier' => 'start',
        ]);

        $workerB = $this->worker([
            'admin_id' => $adminB->id,
            'target_id' => $adminA->id,
            'action' => 'demote',
            'barrier' => 'start',
        ]);

        $this->ready($workerA);
        $this->ready($workerB);

        $this->release($workerA);
        $this->release($workerB);

        $resA = $this->finish($workerA);
        $resB = $this->finish($workerB);

        $results = [$resA, $resB];
        $successes = array_filter($results, fn ($r) => ($r['status'] ?? '') === 'success');
        $conflicts = array_filter($results, fn ($r) => ($r['http_status'] ?? 0) === 409);

        $this->assertCount(1, $successes, 'Exactly one concurrent demotion should succeed');
        $this->assertCount(1, $conflicts, 'The competing demotion must receive 409 Conflict');

        $adminRole = Role::where('name', StaffRole::Admin->value)->firstOrFail();
        $activeAdminCount = User::where('role_id', $adminRole->id)->where('is_active', true)->count();
        $this->assertSame(1, $activeAdminCount, 'Exactly one operational admin must remain');
    }

    public function test_concurrent_duplicate_email_creation_race_rejects_loser(): void
    {
        $admin = User::factory()->withRole(StaffRole::Admin)->create(['name' => 'Creator Admin']);

        $workerA = $this->worker([
            'admin_id' => $admin->id,
            'action' => 'create',
            'name' => 'Concurrent Staff A',
            'email' => 'race.condition@example.com',
            'role' => 'cashier',
            'barrier' => 'start',
        ]);

        $workerB = $this->worker([
            'admin_id' => $admin->id,
            'action' => 'create',
            'name' => 'Concurrent Staff B',
            'email' => 'race.condition@example.com',
            'role' => 'cashier',
            'barrier' => 'start',
        ]);

        $this->ready($workerA);
        $this->ready($workerB);

        $this->release($workerA);
        $this->release($workerB);

        $resA = $this->finish($workerA);
        $resB = $this->finish($workerB);

        $results = [$resA, $resB];
        $successes = array_filter($results, fn ($r) => ($r['status'] ?? '') === 'success');
        $failures = array_filter($results, fn ($r) => ($r['status'] ?? '') === 'error');

        $this->assertCount(1, $successes, 'Exactly one worker should succeed creating user');
        $this->assertCount(1, $failures, 'One worker should fail due to unique email');

        $this->assertSame(1, User::where('email', 'race.condition@example.com')->count());
    }
}
