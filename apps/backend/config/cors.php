<?php

return [
    'paths' => ['api/*', 'up'],
    'allowed_methods' => ['*'],
    'allowed_origins' => array_filter(array_map('trim', explode(',', env('CORS_ALLOWED_ORIGINS', 'http://localhost:5173,http://127.0.0.1:5173,http://localhost:8000,http://localhost:*,http://127.0.0.1:*')))),
    'allowed_origins_patterns' => array_filter(array_map('trim', explode(',', env('CORS_ALLOWED_ORIGINS_PATTERNS', '')))),
    'allowed_headers' => ['Accept', 'Authorization', 'Content-Type', 'Origin', 'X-Requested-With'],
    'exposed_headers' => [],
    'max_age' => 0,
    'supports_credentials' => false,
];
