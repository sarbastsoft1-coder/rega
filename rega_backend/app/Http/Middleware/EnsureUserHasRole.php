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
            $user->tokens()->delete();

            return response()->json([
                'success' => false,
                'code' => 'account_blocked',
                'message' => 'هەژمارەکەت لەلایەن بەڕێوەبەرەوە مسدود کراوە. تکایە پەیوەندی بە یارمەتی پشتگیری بکە لە ڕێگەی واتسئاپ.',
                'contact' => EnsureUserIsActive::supportContacts(),
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

