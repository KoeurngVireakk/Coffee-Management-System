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

    public function test_flutter_web_browser_preflight_is_allowed(): void
    {
        $this->withHeaders([
            'Origin' => 'http://localhost:58221',
            'Access-Control-Request-Method' => 'POST',
            'Access-Control-Request-Headers' => 'Authorization, Content-Type',
        ])->options('/api/v1/auth/login')
            ->assertNoContent()
            ->assertHeader('Access-Control-Allow-Origin', 'http://localhost:58221');
    }

    public function test_untrusted_origin_preflight_is_rejected(): void
    {
        $this->withHeaders([
            'Origin' => 'http://evil.com',
            'Access-Control-Request-Method' => 'POST',
            'Access-Control-Request-Headers' => 'Authorization, Content-Type',
        ])->options('/api/v1/auth/login')
            ->assertHeaderMissing('Access-Control-Allow-Origin');
    }
}
