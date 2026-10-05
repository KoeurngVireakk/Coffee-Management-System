<?php

namespace Tests\Feature;

use Tests\TestCase;

class BootstrapTest extends TestCase
{
    public function test_health_endpoint_boots_without_a_database(): void
    {
        $this->get('/up')->assertOk();
    }

    public function test_unknown_versioned_api_routes_return_json(): void
    {
        $this->get('/api/v1/not-implemented')
            ->assertNotFound()
            ->assertHeader('Content-Type', 'application/json');
    }

    public function test_local_browser_preflight_is_allowed(): void
    {
        $this->withHeaders([
            'Origin' => 'http://localhost:5173',
            'Access-Control-Request-Method' => 'GET',
            'Access-Control-Request-Headers' => 'Authorization, Content-Type',
        ])->options('/api/v1/not-implemented')
            ->assertNoContent()
            ->assertHeader('Access-Control-Allow-Origin', 'http://localhost:5173');
    }
}
