<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Cache;
use Symfony\Component\HttpFoundation\Response;

/**
 * Replays identical successful/client-error responses for the same user + route + Idempotency-Key.
 * Prevents double-settlement / double-status under flaky mobile networks.
 */
class EnforceIdempotency
{
    public function handle(Request $request, Closure $next): Response
    {
        $key = trim((string) $request->header('Idempotency-Key', ''));
        $user = $request->user();

        if ($key === '' || $user === null || ! in_array($request->method(), ['POST', 'PATCH', 'PUT'], true)) {
            return $next($request);
        }

        if (strlen($key) > 128 || ! preg_match('/^[A-Za-z0-9._:-]+$/', $key)) {
            return response()->json([
                'success' => false,
                'message' => 'Invalid Idempotency-Key.',
            ], 400);
        }

        $cacheKey = sprintf(
            'rega_idem:%d:%s',
            $user->id,
            hash('sha256', strtoupper($request->method()).'|'.$request->path().'|'.$key)
        );

        $cached = Cache::get($cacheKey);
        if (is_array($cached) && isset($cached['status'], $cached['body'])) {
            return response()->json($cached['body'], (int) $cached['status']);
        }

        /** @var Response $response */
        $response = $next($request);

        $status = $response->getStatusCode();
        if ($status >= 200 && $status < 500) {
            $payload = json_decode($response->getContent() ?: 'null', true);
            if (is_array($payload)) {
                Cache::put($cacheKey, [
                    'status' => $status,
                    'body' => $payload,
                ], now()->addDay());
            }
        }

        return $response;
    }
}
