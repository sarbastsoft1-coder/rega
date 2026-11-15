<?php

/**
 * PHP built-in server router for local REGA backend.
 * Serves static files (incl. /storage) with CORS so Flutter web CanvasKit
 * can load cross-origin product images from port 8081 → 8001.
 *
 * IMPORTANT: Do NOT set CORS headers before requiring index.php — Laravel's
 * HandleCors middleware already adds Access-Control-Allow-Origin. Duplicate
 * ACAO headers make browsers reject every cross-origin API call from the
 * Flutter web apps (8080–8083 → 8001), which shows up as "server offline".
 */

function rega_cors_headers(): void
{
    header('Access-Control-Allow-Origin: *');
    header('Access-Control-Allow-Methods: GET, POST, PUT, PATCH, DELETE, OPTIONS');
    header('Access-Control-Allow-Headers: *');
    header('Access-Control-Expose-Headers: Content-Type, Content-Length');
}

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    rega_cors_headers();
    http_response_code(204);
    exit;
}

$uri = urldecode(parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH) ?? '/');
$file = __DIR__.$uri;

// Serve existing public files ourselves so CORS headers are kept
// (`return false` lets the built-in server strip custom headers on some PHP builds).
if ($uri !== '/' && is_file($file)) {
    rega_cors_headers();
    $ext = strtolower(pathinfo($file, PATHINFO_EXTENSION));
    $mimes = [
        'jpg' => 'image/jpeg',
        'jpeg' => 'image/jpeg',
        'png' => 'image/png',
        'gif' => 'image/gif',
        'webp' => 'image/webp',
        'pdf' => 'application/pdf',
        'css' => 'text/css',
        'js' => 'application/javascript',
        'json' => 'application/json',
        'svg' => 'image/svg+xml',
        'ico' => 'image/x-icon',
        'wasm' => 'application/wasm',
    ];
    $mime = $mimes[$ext] ?? (function_exists('mime_content_type') ? (mime_content_type($file) ?: 'application/octet-stream') : 'application/octet-stream');
    header('Content-Type: '.$mime);
    header('Content-Length: '.filesize($file));
    header('Cache-Control: public, max-age=604800');
    readfile($file);
    exit;
}

require_once __DIR__.'/index.php';
