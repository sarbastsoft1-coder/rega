<?php

namespace App\Http\Middleware;

use App\Models\PlatformSetting;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class EnsureUserIsActive
{
    public function handle(Request $request, Closure $next): Response
    {
        $user = $request->user();
        if ($user && ! $user->is_active) {
            $user->tokens()->delete();

            return response()->json([
                'success' => false,
                'code' => 'account_blocked',
                'message' => 'هەژمارەکەت لەلایەن بەڕێوەبەرەوە مسدود کراوە. تکایە پەیوەندی بە یارمەتی پشتگیری بکە لە ڕێگەی واتسئاپ.',
                'contact' => self::supportContacts(),
            ], 403);
        }

        return $next($request);
    }

    public static function supportContacts(): array
    {
        $keys = ['support_phone', 'whatsapp_number', 'telegram_number', 'telegram_username', 'driver_hotline'];
        $out = [];
        foreach ($keys as $key) {
            $row = PlatformSetting::query()->where('key', $key)->first();
            if (! $row) {
                continue;
            }
            $val = $row->value;
            $flat = (is_array($val) && array_key_exists('val', $val) && count($val) === 1)
                ? $val['val']
                : $val;
            if ($flat !== null && $flat !== '') {
                $out[$key] = is_scalar($flat) ? (string) $flat : $flat;
            }
        }

        $out['support_phone'] = $out['support_phone'] ?? '0770 000 1122';
        $out['whatsapp_number'] = $out['whatsapp_number'] ?? '+9647700001122';
        $out['telegram_number'] = $out['telegram_number'] ?? ($out['support_phone'] ?? '0770 000 1122');
        $out['telegram_username'] = $out['telegram_username'] ?? 'rega_support';

        return $out;
    }
}
