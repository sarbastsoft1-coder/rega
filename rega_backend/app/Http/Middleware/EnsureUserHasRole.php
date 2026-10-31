<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class EnsureUserHasRole
{
    public function handle(Request $request, Closure $next, string ...$roles): Response
    {
        $user = $request->user();

        if (! $user) {
            return response()->json([
                'success' => false,
                'message' => 'تکایە چوونە ژوورەوە ئەنجام بدە (Unauthenticated).',
            ], 401);
        }

        if (! $user->is_active) {
            return response()->json([
                'success' => false,
                'message' => 'هەژمارەکەت ڕاگیراوە (Account suspended).',
            ], 403);
        }

        if (! empty($roles) && ! in_array($user->role, $roles, true)) {
            return response()->json([
                'success' => false,
                'message' => 'ڕێگەت پێ نەدراوە بۆ ئەم کردارە (Forbidden).',
            ], 403);
        }

        return $next($request);
    }
}

