<?php

namespace App\Services;

use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Str;

/**
 * Outbound SMS via optional HTTP webhook (Iraqi gateway, Twilio proxy, n8n, etc.).
 * Payload: { phone, message, type } — same shape for all OTP flows.
 */
class RegaSmsDispatcher
{
    public function send(string $phone, string $message, string $type = 'sms'): bool
    {
        $webhook = config('services.rega_sms.webhook_url');

        if (! is_string($webhook) || $webhook === '') {
            Log::info('rega.sms.skipped', [
                'phone' => Str::mask($phone, '*', 3, 5),
                'type' => $type,
                'hint' => 'Set REGA_SMS_WEBHOOK_URL to deliver SMS.',
            ]);

            return false;
        }

        try {
            $response = Http::timeout(8)
                ->acceptJson()
                ->asJson()
                ->post($webhook, [
                    'phone' => $phone,
                    'message' => $message,
                    'type' => $type,
                ]);

            if ($response->successful()) {
                Log::info('rega.sms.sent', [
                    'phone' => Str::mask($phone, '*', 3, 5),
                    'type' => $type,
                    'status' => $response->status(),
                ]);

                return true;
            }

            Log::warning('rega.sms.webhook_rejected', [
                'phone' => Str::mask($phone, '*', 3, 5),
                'type' => $type,
                'status' => $response->status(),
                'body' => Str::limit($response->body(), 500),
            ]);
        } catch (\Throwable $e) {
            Log::warning('rega.sms.webhook_failed', [
                'phone' => Str::mask($phone, '*', 3, 5),
                'type' => $type,
                'error' => $e->getMessage(),
            ]);
        }

        return false;
    }
}