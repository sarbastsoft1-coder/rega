<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Support\Facades\Storage;
use Symfony\Component\HttpFoundation\StreamedResponse;

class MediaController extends Controller
{
    /**
     * Stream a public-disk file through the API so CORS middleware applies
     * (needed by Flutter web CanvasKit Image.network cross-origin loads).
     */
    public function show(string $path): StreamedResponse
    {
        $path = ltrim(str_replace('\\', '/', $path), '/');
        if ($path === '' || str_contains($path, '..')) {
            abort(404);
        }

        $disk = Storage::disk('public');
        if (! $disk->exists($path)) {
            abort(404);
        }

        $mime = $disk->mimeType($path) ?: 'application/octet-stream';
        $stream = $disk->readStream($path);
        if ($stream === false) {
            abort(404);
        }

        return response()->stream(function () use ($stream): void {
            fpassthru($stream);
            if (is_resource($stream)) {
                fclose($stream);
            }
        }, 200, [
            'Content-Type' => $mime,
            'Cache-Control' => 'public, max-age=604800',
        ]);
    }
}
