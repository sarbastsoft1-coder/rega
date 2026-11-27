<?php

$defaultOrigins = implode(',', [
    'http://127.0.0.1:8080',
    'http://127.0.0.1:8081',
    'http://127.0.0.1:8082',
    'http://127.0.0.1:8083',
    'http://localhost:8080',
    'http://localhost:8081',
    'http://localhost:8082',
    'http://localhost:8083',
]);

$origins = array_values(array_filter(array_map(
    static fn (string $o) => trim($o),
    explode(',', (string) env('CORS_ALLOWED_ORIGINS', $defaultOrigins))
)));

return [
    'paths' => ['api/*', 'sanctum/csrf-cookie', 'storage/*'],
    'allowed_methods' => ['*'],
    'allowed_origins' => $origins,
    'allowed_origins_patterns' => array_values(array_filter(array_map(
        static fn (string $o) => trim($o),
        explode(',', (string) env('CORS_ALLOWED_ORIGINS_PATTERNS', ''))
    ))),
    'allowed_headers' => ['*'],
    'exposed_headers' => [],
    'max_age' => 0,
    'supports_credentials' => false,
];

