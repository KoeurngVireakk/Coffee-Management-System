<?php

declare(strict_types=1);
use App\Models\Role;
use App\Models\User;
use Dotenv\Exception\InvalidFileException;
use Illuminate\Contracts\Console\Kernel;
use Illuminate\Support\Facades\DB;

/** Local onboarding only. Never used by an HTTP route. */
final class DevSetup
{
    public function __construct(private readonly string $backend) {}

    public function environment(): array
    {
        $path = $this->backend.'/.env';
        if (! is_file($path)) {
            throw new RuntimeException('apps/backend/.env is missing. Run setup.ps1 first.');
        }
        $text = file_get_contents($path);
        foreach (['APP_ENV', 'APP_KEY', 'DB_CONNECTION', 'DB_HOST', 'DB_PORT', 'DB_DATABASE', 'DB_USERNAME', 'DB_PASSWORD', 'DB_URL', 'DB_SOCKET'] as $key) {
            if (preg_match_all('/^[ \t]*(?:export[ \t]+)?'.preg_quote($key, '/').'[ \t]*=/m', $text) > 1) {
                throw new RuntimeException("Duplicate $key entries in .env. Keep one entry and retry; no changes written.");
            }
        }
        try {
            $env = Dotenv\Dotenv::parse($text);
        } catch (InvalidFileException) {
            // The parser's original message can include a secret's value.
            throw new RuntimeException('apps/backend/.env has invalid dotenv syntax. Check closing quotes and escape backslashes; values have been omitted.');
        }
        foreach (['APP_ENV', 'APP_KEY', 'DB_CONNECTION', 'DB_HOST', 'DB_PORT', 'DB_DATABASE', 'DB_USERNAME', 'DB_PASSWORD'] as $key) {
            if (! array_key_exists($key, $env)) {
                throw new RuntimeException("Missing or malformed $key in .env. Restore the entry from .env.example and check its quotes; values omitted.");
            }
        }
        $env['DB_PASSWORD'] = self::decodePassword($env['DB_PASSWORD']);

        return $env;
    }

    private static function decodePassword(string $value): string
    {
        // Match Laravel Env::get: reserved words and an extra pair of literal quotes.
        return match (strtolower($value)) {
            'true', '(true)' => '1',
            'false', '(false)', 'empty', '(empty)', 'null', '(null)' => '',
            default => preg_match('/\A([\'"])(.*)\1\z/s', $value, $matches) ? $matches[2] : $value,
        };
    }

    public function assertLocal(array $env): void
    {
        foreach (['APP_ENV', 'DB_CONNECTION', 'DB_HOST', 'DB_PORT', 'DB_DATABASE', 'DB_USERNAME', 'DB_PASSWORD', 'DB_URL', 'DB_SOCKET', 'MYSQL_ATTR_SSL_CA', 'APP_KEY', 'APP_CONFIG_CACHE'] as $key) {
            if (getenv($key) !== false || array_key_exists($key, $_ENV)) {
                throw new RuntimeException("Inherited $key overrides local configuration. Remove that variable from this terminal and retry.");
            }
        }
        if (($env['APP_ENV'] ?? '') !== 'local' || ($env['DB_CONNECTION'] ?? '') !== 'mysql') {
            throw new RuntimeException('Setup requires APP_ENV=local and DB_CONNECTION=mysql. Use a dedicated development .env.');
        }
        if (! in_array($env['DB_HOST'] ?? '', ['127.0.0.1', 'localhost'], true) || ! empty($env['DB_URL']) || ! empty($env['DB_SOCKET'])) {
            throw new RuntimeException('Setup requires local MySQL at 127.0.0.1 or localhost, with no DB_URL or DB_SOCKET override. Shared/remote databases must be configured manually.');
        }
        $database = $env['DB_DATABASE'] ?? '';
        if (! preg_match('/\A[a-zA-Z][a-zA-Z0-9_]{0,63}\z/', $database)
            || in_array(strtolower($database), ['mysql', 'sys', 'information_schema', 'performance_schema', 'coffee_management_auth_test'], true)) {
            throw new RuntimeException('Choose a dedicated development DB_DATABASE using letters, numbers and underscores, excluding system and test databases.');
        }
        if (! ctype_digit((string) ($env['DB_PORT'] ?? '')) || (int) $env['DB_PORT'] < 1 || (int) $env['DB_PORT'] > 65535) {
            throw new RuntimeException('DB_PORT must be a number from 1 to 65535.');
        }
        if (empty($env['DB_USERNAME'])) {
            throw new RuntimeException('DB_USERNAME is empty. Run setup.ps1 -ConfigureDatabase.');
        }
    }

    public function inspect(): array
    {
        $env = $this->environment();
        $this->assertLocal($env);

        return array_intersect_key($env, array_flip(['DB_HOST', 'DB_PORT', 'DB_DATABASE', 'DB_USERNAME']))
            + ['hasAppKey' => ! empty($env['APP_KEY'])];
    }

    public static function quoteValue(string $value): string
    {
        if (preg_match('/[\r\n\x00]/', $value)) {
            throw new RuntimeException('Configuration values cannot contain newlines or NUL bytes.');
        }

        return '"'.strtr($value, ['\\' => '\\\\', '"' => '\\"', '$' => '\\$']).'"';
    }

    public function configure(array $input): array
    {
        $env = $this->environment();
        // Validate the current environment before any write, even when replacing DB settings.
        $this->assertLocal($env);
        $keys = ['DB_HOST', 'DB_PORT', 'DB_DATABASE', 'DB_USERNAME', 'DB_PASSWORD'];
        $updated = $env;
        foreach ($keys as $key) {
            if (! isset($input[$key]) || ! is_string($input[$key])) {
                throw new RuntimeException("Missing $key in database configuration.");
            }
            $updated[$key] = $input[$key];
        }
        $this->assertLocal($updated);
        $path = $this->backend.'/.env';
        $text = file_get_contents($path);
        $newline = str_contains($text, "\r\n") ? "\r\n" : "\n";
        foreach ($keys as $key) {
            // An extra literal quote pair prevents Laravel from interpreting password words such as "null".
            $value = $key === 'DB_PASSWORD' ? '"'.$updated[$key].'"' : $updated[$key];
            $line = $key.'='.self::quoteValue($value);
            $pattern = '/^[ \t]*(?:export[ \t]+)?'.preg_quote($key, '/').'[ \t]*=.*$/m';
            $count = preg_match_all($pattern, $text);
            if ($count > 1) {
                throw new RuntimeException("Duplicate $key entries in .env. Keep one entry and retry; no changes written.");
            }
            $text = $count === 1
                ? preg_replace_callback($pattern, static fn () => $line.(str_contains($text, "\r\n") ? "\r" : ''), $text)
                : rtrim($text, "\r\n").$newline.$line.$newline;
        }
        $parsed = Dotenv\Dotenv::parse($text);
        $parsed['DB_PASSWORD'] = self::decodePassword($parsed['DB_PASSWORD']);
        foreach ($keys as $key) {
            if (($parsed[$key] ?? null) !== $updated[$key]) {
                throw new RuntimeException("$key did not survive dotenv encoding; no changes written.");
            }
        }
        $backup = $path.'.setup-backup.'.gmdate('YmdHis').'.'.bin2hex(random_bytes(3));
        if (! copy($path, $backup) || file_put_contents($path, $text, LOCK_EX) === false) {
            throw new RuntimeException('Could not back up or write .env. Check folder permissions and free disk space.');
        }

        return ['message' => 'Database settings saved. Previous .env retained in an ignored backup.'];
    }

    private function connection(): PDO
    {
        $env = $this->environment();
        $this->assertLocal($env);
        $pdo = new PDO(
            'mysql:host='.$env['DB_HOST'].';port='.$env['DB_PORT'].';charset=utf8mb4',
            $env['DB_USERNAME'], $env['DB_PASSWORD'] ?? '',
            [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION, PDO::ATTR_TIMEOUT => 5],
        );
        $version = (string) $pdo->query('SELECT VERSION()')->fetchColumn();
        if (stripos($version, 'MariaDB') !== false || version_compare($version, '8.0.16', '<')) {
            throw new RuntimeException('MySQL 8.0.16+ is required for enforced CHECK constraints; detected '.$version.'.');
        }

        return $pdo;
    }

    public function database(bool $create = false, array $input = []): array
    {
        $env = $this->environment();
        $this->assertLocal($env);
        $pdo = $this->connection();
        if ($create) {
            if (($input['confirmation'] ?? '') !== $env['DB_DATABASE']) {
                throw new RuntimeException('Database name confirmation did not match. No database created.');
            }
            $pdo->exec('CREATE DATABASE IF NOT EXISTS `'.$env['DB_DATABASE'].'` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci');
        }
        try {
            $pdo->exec('USE `'.$env['DB_DATABASE'].'`');
        } catch (PDOException $error) {
            if (($error->errorInfo[1] ?? null) === 1049) {
                return ['exists' => false];
            }
            throw $error;
        }

        return ['exists' => true];
    }

    private function application(): void
    {
        $this->assertLocal($this->environment());
        if (is_file($this->backend.'/bootstrap/cache/config.php')) {
            throw new RuntimeException('Laravel config is cached. Run php artisan config:clear in apps/backend, then retry.');
        }
        $app = require $this->backend.'/bootstrap/app.php';
        $app->make(Kernel::class)->bootstrap();
    }

    public function adminStatus(): array
    {
        $this->application();

        return ['exists' => User::query()->where('is_active', true)
            ->whereHas('role', static fn ($query) => $query->where('name', 'admin'))->exists()];
    }

    public function ready(): array
    {
        $this->application();
        $migrator = app('migrator');
        if (! $migrator->repositoryExists()) {
            throw new RuntimeException('The database has no migration repository. Run setup.ps1 to migrate it.');
        }
        $pending = array_diff(array_keys($migrator->getMigrationFiles($this->backend.'/database/migrations')), $migrator->getRepository()->getRan());
        if ($pending !== []) {
            throw new RuntimeException(count($pending).' migrations are pending. Run setup.ps1 to apply them before starting the app.');
        }
        if (Role::query()->whereIn('name', ['cashier', 'manager', 'admin'])->count() !== 3) {
            throw new RuntimeException('Staff roles are missing. Run setup.ps1 to seed them.');
        }

        return ['message' => 'Database migrations and staff roles are ready.'];
    }

    public function createAdmin(array $input): array
    {
        $this->application();
        $email = strtolower(trim((string) ($input['email'] ?? '')));
        $name = trim((string) ($input['name'] ?? ''));
        $password = (string) ($input['password'] ?? '');
        if (! filter_var($email, FILTER_VALIDATE_EMAIL) || strlen($email) > 255 || $name === '' || mb_strlen($name) > 255
            || mb_strlen($password) < 12 || mb_strlen($password) > 1024 || preg_match('/[\r\n\x00]/', $password)) {
            throw new RuntimeException('Enter a valid email/name and a password of 12-1024 characters without newlines.');
        }
        DB::transaction(static function () use ($email, $name, $password) {
            $role = Role::query()->where('name', 'admin')->lockForUpdate()->firstOrFail();
            if (User::query()->where('role_id', $role->id)->where('is_active', true)->exists()) {
                throw new RuntimeException('An active admin already exists. Use staff management; no account changed.');
            }
            if (User::query()->where('email', $email)->exists()) {
                throw new RuntimeException('That email already exists. Setup will not replace its password or promote it. Choose a new local email.');
            }
            $user = new User;
            $user->name = $name;
            $user->email = $email;
            $user->password = $password;
            $user->role_id = $role->id;
            $user->is_active = true;
            $user->save();
        });

        return ['message' => 'First local admin created. Sign in with the email and password you entered.'];
    }
}
