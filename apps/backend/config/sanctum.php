<?php

return [
    // Phase 1 supports native bearer tokens. Browser cookie/CSRF auth comes later.
    'stateful' => [],
    'guard' => [],
    'routes' => false,
    'expiration' => 480,
    'token_prefix' => '',
];
