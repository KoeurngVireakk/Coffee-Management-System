<?php

declare(strict_types=1);
use Illuminate\Support\Env;

require dirname(__DIR__, 2).'/apps/backend/vendor/autoload.php';
require dirname(__DIR__).'/lib/dev-setup.php';

$directory = sys_get_temp_dir().'/coffee-setup-unit-'.bin2hex(random_bytes(8));
mkdir($directory);
$setup = new DevSetup($directory);
$template = "# preserve comments\r\nAPP_ENV=local\r\nAPP_KEY=original-test-key\r\nDB_CONNECTION=mysql\r\nDB_HOST=127.0.0.1\r\nDB_PORT=3306\r\nDB_DATABASE=coffee_dev\r\nDB_USERNAME=root\r\nDB_PASSWORD=\r\nINVENTORY_TRACKING_ENABLED=false\r\n";
$checks = 0;
function check(bool $condition, string $label): void
{
    global $checks;
    if (! $condition) {
        throw new RuntimeException('Failed: '.$label);
    }
    $checks++;
}
function rejects(callable $operation, string $expected): void
{
    try {
        $operation();
    } catch (RuntimeException $error) {
        check(str_contains($error->getMessage(), $expected), 'expected rejection: '.$expected);

        return;
    }
    throw new RuntimeException('Expected rejection: '.$expected);
}
try {
    foreach (['', 'space # hash', '"double" and \'single\'', '\\path\\ending\\', '${APP_ENV} $cash', 'ខ្មែរ café', 'null', 'false'] as $value) {
        check(Dotenv\Dotenv::parse('VALUE='.DevSetup::quoteValue($value))['VALUE'] === $value, 'dotenv password round trip');
    }
    rejects(static fn () => DevSetup::quoteValue("password\nAPP_ENV=production"), 'newlines');
    file_put_contents($directory.'/.env', $template);
    $settings = ['DB_HOST' => 'localhost', 'DB_PORT' => '3307', 'DB_DATABASE' => 'coffee_dev', 'DB_USERNAME' => 'developer', 'DB_PASSWORD' => 'ខ្មែរ $money \\ "quote" # special'];
    $setup->configure($settings);
    $configured = $setup->environment();
    check($configured['DB_PASSWORD'] === $settings['DB_PASSWORD'], 'saved password preserved exactly');
    check($configured['APP_KEY'] === 'original-test-key', 'existing app key preserved');
    check($configured['INVENTORY_TRACKING_ENABLED'] === 'false', 'unrelated settings preserved');
    check(str_starts_with(file_get_contents($directory.'/.env'), '# preserve comments'), 'comments preserved');
    $backups = glob($directory.'/.env.setup-backup.*');
    check(count($backups) === 1 && file_get_contents($backups[0]) === $template, 'exact original backup');
    check(! array_key_exists('DB_PASSWORD', $setup->inspect()), 'inspect never returns password');
    foreach (['null', 'false', 'true', '(empty)', '"quoted"', "'single'", ''] as $password) {
        $setup->configure(array_replace($settings, ['DB_PASSWORD' => $password]));
        check($setup->environment()['DB_PASSWORD'] === $password, 'helper password semantics');
        $raw = Dotenv\Dotenv::parse(file_get_contents($directory.'/.env'))['DB_PASSWORD'];
        Env::getRepository()->set('COFFEE_SETUP_PASSWORD_TEST', $raw);
        check(Env::get('COFFEE_SETUP_PASSWORD_TEST') === $password, 'actual Laravel password semantics');
    }
    $before = file_get_contents($directory.'/.env');
    rejects(static fn () => $setup->configure(array_replace($settings, ['DB_DATABASE' => 'bad`; DROP DATABASE x; --'])), 'dedicated development');
    check(file_get_contents($directory.'/.env') === $before, 'invalid input cannot change file');
    $valid = $setup->environment();
    foreach ([['APP_ENV' => 'production'], ['DB_HOST' => 'remote.example.test'], ['DB_URL' => 'mysql://remote'], ['DB_SOCKET' => '/tmp/mysql.sock'], ['DB_DATABASE' => 'mysql'], ['DB_DATABASE' => 'coffee_management_auth_test'], ['DB_PORT' => '65536']] as $override) {
        rejects(static fn () => $setup->assertLocal(array_replace($valid, $override)), '');
    }
    putenv('DB_HOST=remote.example.test');
    rejects(static fn () => $setup->assertLocal($valid), 'Inherited DB_HOST');
    putenv('DB_HOST');
    file_put_contents($directory.'/.env', $template."export DB_HOST=127.0.0.1\r\n");
    rejects(static fn () => $setup->environment(), 'Duplicate DB_HOST');
    file_put_contents($directory.'/.env', $template."BROKEN=\"do-not-print-this-secret\\q\"\r\n");
    try {
        $setup->environment();
        throw new LogicException('Invalid syntax was accepted');
    } catch (RuntimeException $error) {
        check(str_contains($error->getMessage(), 'invalid dotenv syntax') && ! str_contains($error->getMessage(), 'do-not-print'), 'invalid dotenv error redacted');
    }
    unlink($directory.'/.env');
    rejects(static fn () => $setup->environment(), '.env is missing');
    echo "$checks PHP setup checks passed (isolated files; no database mutations).", PHP_EOL;
} finally {
    putenv('DB_HOST');
    // Only this test's explicitly created files, without recursive removal.
    foreach (glob($directory.'/.env*') as $file) {
        unlink($file);
    }
    rmdir($directory);
}
