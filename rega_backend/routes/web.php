<?php

use Illuminate\Support\Facades\Route;

Route::get('/', function () {
    return response()->json([
        'name' => 'REGA Platform Backend API',
        'city' => 'Kalar (کەلار)',
        'framework' => 'Laravel ' . app()->version(),
        'database' => 'PostgreSQL',
        'api_base' => url('/api/v1'),
        'health_endpoint' => url('/api/health'),
        'apps_supported' => [
            'rega_admin (Flutter Admin Panel)',
            'rega (Customer App)',
            'rega_froshyar (Vendor App)',
            'rega_delivery (Driver App)',
        ],
    ]);
});
