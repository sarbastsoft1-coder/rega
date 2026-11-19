<?php

namespace App\Support;

/**
 * Public upload URLs for Flutter web (CanvasKit requires CORS).
 * Prefer /api/v1/media/* (Laravel middleware) over /storage/* (artisan serve bypasses CORS).
 */
final class PublicMedia
{
    public static function url(string $path): string
    {
        $path = ltrim(str_replace('\\', '/', $path), '/');

        // Path-absolute (no host): Flutter web apps rewrite via same-origin
        // nginx /api proxy. Avoids baking APP_URL=localhost into stored URLs.
        return '/api/v1/media/'.$path;
    }

    public static function relativePathFromUrl(?string $fileUrl): ?string
    {
        if ($fileUrl === null || trim($fileUrl) === '') {
            return null;
        }

        foreach (['/api/v1/media/', '/storage/'] as $marker) {
            $pos = strpos($fileUrl, $marker);
            if ($pos !== false) {
                return ltrim(rawurldecode(substr($fileUrl, $pos + strlen($marker))), '/');
            }
        }

        return null;
    }
}
