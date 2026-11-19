<?php

namespace App\Services;

use App\Models\User;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;

class CustomerPasswordResetService
{
    public function __construct(
        private readonly RegaSmsDispatcher $sms,
    ) {
    }
    private const OTP_TTL_SECONDS = 600;

    private const COOLDOWN_SECONDS = 60;

    private const MAX_VERIFY_ATTEMPTS = 5;

    public function requestOtp(string $rawPhone): array
    {
        $phone = $this->normalizePhone($rawPhone);
        if ($phone === null) {
            return [
                'ok' => false,
                'status' => 422,
                'message' => 'ژمارەی مۆبایل نادروستە — فۆرماتی عێراقی: 0750 000 0000',
            ];
        }

        $user = User::query()->where('phone', $phone)->first();
        if (! $user) {
            return [
                'ok' => false,
                'status' => 404,
                'message' => 'ئەم ژمارەیە تۆمار نەکراوە.',
            ];
        }

        if (! $user->is_active) {
            return [
                'ok' => false,
                'status' => 403,
                'message' => 'هەژمارەکەت لەلایەن بەڕێوەبەرەوە مسدود کراوە. تکایە پەیوەندی بە پشتگیری بکە.',
            ];
        }

        if (! $user->isCustomer()) {
            return [
                'ok' => false,
                'status' => 403,
                'message' => 'نوێکردنەوەی وشەی نهێنی تەنها بۆ هەژماری کڕیارە.',
            ];
        }

        $cooldownKey = $this->cooldownCacheKey($phone);
        if (Cache::has($cooldownKey)) {
            return [
                'ok' => false,
                'status' => 429,
                'message' => 'تکایە چەند چرکەیەک چاوەڕێ بکە پێش داواکردنی کۆدی نوێ.',
            ];
        }

        $otp = (string) random_int(100000, 999999);
        $payload = [
            'otp_hash' => Hash::make($otp),
            'attempts' => 0,
            'user_id' => $user->id,
        ];

        Cache::put($this->otpCacheKey($phone), $payload, self::OTP_TTL_SECONDS);
        Cache::put($cooldownKey, true, self::COOLDOWN_SECONDS);

        $this->dispatchOtpSms($phone, $otp);

        $response = [
            'ok' => true,
            'status' => 200,
            'message' => 'کۆدی پشتڕاستکردنەوە نێردرا بۆ ژمارەی تەلەفۆنەکەت.',
            'expires_in' => self::OTP_TTL_SECONDS,
        ];

        if (! app()->environment('production') && app()->hasDebugModeEnabled()) {
            $response['debug_otp'] = $otp;
        }

        return $response;
    }

    public function resetWithOtp(string $rawPhone, string $otp, string $newPassword): array
    {
        $phone = $this->normalizePhone($rawPhone);
        if ($phone === null) {
            return [
                'ok' => false,
                'status' => 422,
                'message' => 'ژمارەی مۆبایل نادروستە — فۆرماتی عێراقی: 0750 000 0000',
            ];
        }

        $otpDigits = preg_replace('/\D+/', '', $otp) ?? '';
        if (strlen($otpDigits) !== 6) {
            return [
                'ok' => false,
                'status' => 422,
                'message' => 'کۆدی پشتڕاستکردنەوە دەبێت ٦ ژمارە بێت.',
            ];
        }

        if (strlen($newPassword) < 6) {
            return [
                'ok' => false,
                'status' => 422,
                'message' => 'وشەی نهێنی دەبێت لانیکەم ٦ پیت بێت.',
            ];
        }

        $cacheKey = $this->otpCacheKey($phone);
        /** @var array<string, mixed>|null $stored */
        $stored = Cache::get($cacheKey);
        if (! is_array($stored) || empty($stored['otp_hash'])) {
            return [
                'ok' => false,
                'status' => 410,
                'message' => 'کۆدەکە بەسەرچووە یان داواکاری نەکراوە. دووبارە کۆد داوابکە.',
            ];
        }

        $attempts = (int) ($stored['attempts'] ?? 0);
        if ($attempts >= self::MAX_VERIFY_ATTEMPTS) {
            Cache::forget($cacheKey);

            return [
                'ok' => false,
                'status' => 429,
                'message' => 'زۆر هەوڵی هەڵە. تکایە کۆدێکی نوێ داوابکە.',
            ];
        }

        if (! Hash::check($otpDigits, (string) $stored['otp_hash'])) {
            $stored['attempts'] = $attempts + 1;
            Cache::put($cacheKey, $stored, self::OTP_TTL_SECONDS);

            return [
                'ok' => false,
                'status' => 422,
                'message' => 'کۆدی پشتڕاستکردنەوە هەڵەیە.',
            ];
        }

        $userId = (int) ($stored['user_id'] ?? 0);
        $user = $userId > 0 ? User::query()->find($userId) : null;
        if (! $user || $user->phone !== $phone) {
            Cache::forget($cacheKey);

            return [
                'ok' => false,
                'status' => 404,
                'message' => 'هەژمار نەدۆزرایەوە.',
            ];
        }

        $user->update(['password' => $newPassword]);
        $user->tokens()->delete();
        Cache::forget($cacheKey);

        return [
            'ok' => true,
            'status' => 200,
            'message' => 'وشەی نهێنی بە سەرکەوتوویی نوێکرایەوە. ئێستا دەتوانیت بچیتە ژوورەوە.',
        ];
    }

    private function normalizePhone(string $raw): ?string
    {
        $phone = preg_replace('/\s+/', '', trim($raw)) ?? '';
        if (! preg_match('/^07\d{9}$/', $phone)) {
            return null;
        }

        return $phone;
    }

    private function otpCacheKey(string $phone): string
    {
        return 'rega_pw_reset_otp:' . $phone;
    }

    private function cooldownCacheKey(string $phone): string
    {
        return 'rega_pw_reset_cd:' . $phone;
    }

    private function dispatchOtpSms(string $phone, string $otp): void
    {
        $template = (string) config('services.rega_sms.otp_template', 'کۆدی نوێکردنەوەی هەژمار REGA: {otp}');
        $message = str_replace('{otp}', $otp, $template);

        $this->sms->send($phone, $message, 'password_reset_otp');
    }
}