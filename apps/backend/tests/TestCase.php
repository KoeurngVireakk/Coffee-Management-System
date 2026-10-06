<?php

namespace Tests;

use Illuminate\Foundation\Application;
use Illuminate\Foundation\Testing\TestCase as BaseTestCase;
use Illuminate\Support\Facades\Http;
use RuntimeException;

abstract class TestCase extends BaseTestCase
{
    protected function setUp(): void
    {
        parent::setUp();
        Http::preventStrayRequests();
    }

    public function createApplication(): Application
    {
        $app = parent::createApplication();
        $connection = $app['config']->get('database.default');
        $database = $app['config']->get("database.connections.{$connection}.database");
        $url = $app['config']->get("database.connections.{$connection}.url");
        $host = $app['config']->get("database.connections.{$connection}.host");
        $socket = $app['config']->get("database.connections.{$connection}.unix_socket");

        $isolated = ($connection === 'sqlite' && $database === ':memory:')
            || ($connection === 'mysql' && $database === 'coffee_management_auth_test'
                && in_array($host, ['127.0.0.1', 'localhost'], true));

        // Runs before RefreshDatabase can issue any destructive migration command.
        if (! $app->environment('testing') || ! $isolated || $url || $socket) {
            throw new RuntimeException('Tests require SQLite :memory: or the dedicated local coffee_management_auth_test database, without DB_URL.');
        }

        return $app;
    }
}
