<?php

return [
    // Deployment cutover only; persisted orders keep their original tracking decision.
    'tracking_enabled' => env('INVENTORY_TRACKING_ENABLED', false),
];
