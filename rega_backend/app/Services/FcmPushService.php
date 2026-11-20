<?php

namespace App\Services;

use App\Models\AppNotification;
use App\Models\User;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use Throwable;

/**
 * Firebase Cloud Messaging (HTTP v1) for REGA customer lock-screen push.
 * Requires FIREBASE_CREDENTIALS (service-account JSON path) and FCM_PROJECT_ID.
 */
class FcmPushService
{
    private ?array $serviceAccount = null;

    private ?string $accessToken = null;

    private ?int $tokenExpiresAt = null;

    public function isConfigured(): bool
    {
        $path = (string) config('services.fcm.credentials');
        $projectId = (string) config('services.fcm.project_id');

        return $path !== '' && is_readable($path) && $projectId !== '';
    }

    /**
     * Push from an AppNotification model (title/body + data extras).
     */
    public function sendForNotification(AppNotification $notification, iterable $userIds): int
    {
        $title = $this->pickLocale(
            $notification->title_ku,
            $notification->title_ar,
            $notification->title_en,
        );
        $body = $this->pickLocale(
            $notification->body_ku,
            $notification->body_ar,
            $notification->body_en,
        );

        $data = array_filter([
            'notification_id' => (string) $notification->id,
            'campaign_id' => (string) ($notification->campaign_id ?? ''),
            'type' => (string) ($notification->type ?? 'general'),
            'tag' => (string) ($notification->tag ?? ''),
            'store_id' => $notification->store_id !== null ? (string) $notification->store_id : null,
            'category_name' => (string) ($notification->category_name ?? ''),
            'title' => $title,
            'body' => $body,
            'title_ku' => (string) ($notification->title_ku ?? ''),
            'body_ku' => (string) ($notification->body_ku ?? ''),
        ], fn ($v) => $v !== null && $v !== '');

        return $this->sendToUserIds($userIds, $title, $body, $data);
    }

    /**
     * @param  iterable<int|string>  $userIds
     */
    public function sendToUserIds(iterable $userIds, string $title, string $body, array $data = []): int
    {
        if (! $this->isConfigured()) {
            Log::debug('FCM skipped: credentials not configured');

            return 0;
        }

        $ids = collect($userIds)
            ->map(fn ($id) => (int) $id)
            ->filter(fn ($id) => $id > 0)
            ->unique()
            ->values();

        if ($ids->isEmpty()) {
            return 0;
        }

        $tokens = User::query()
            ->whereIn('id', $ids)
            ->whereNotNull('fcm_token')
            ->where('fcm_token', '!=', '')
            ->pluck('fcm_token', 'id');

        return $this->sendToTokenMap($tokens, $title, $body, $data);
    }

    /**
     * @param  Collection<int, string>  $tokenByUserId
     */
    public function sendToTokenMap(Collection $tokenByUserId, string $title, string $body, array $data = []): int
    {
        if (! $this->isConfigured() || $tokenByUserId->isEmpty()) {
            return 0;
        }

        $sent = 0;
        foreach ($tokenByUserId as $userId => $token) {
            try {
                $ok = $this->sendToToken((string) $token, $title, $body, $data);
                if ($ok) {
                    $sent++;
                }
            } catch (Throwable $e) {
                Log::warning('FCM send failed', [
                    'user_id' => $userId,
                    'error' => $e->getMessage(),
                ]);
            }
        }

        return $sent;
    }

    public function sendToToken(string $token, string $title, string $body, array $data = []): bool
    {
        $projectId = (string) config('services.fcm.project_id');
        $accessToken = $this->accessToken();
        if ($accessToken === null) {
            return false;
        }

        // FCM data values must be strings.
        $stringData = [];
        foreach ($data as $k => $v) {
            $stringData[(string) $k] = is_scalar($v) || $v === null ? (string) $v : json_encode($v);
        }

        $payload = [
            'message' => [
                'token' => $token,
                'notification' => [
                    'title' => $title,
                    'body' => $body,
                ],
                'data' => $stringData,
                'android' => [
                    'priority' => 'high',
                    'notification' => [
                        'channel_id' => 'rega_customer_push',
                        'sound' => 'default',
                    ],
                ],
                'apns' => [
                    'headers' => [
                        'apns-priority' => '10',
                    ],
                    'payload' => [
                        'aps' => [
                            'sound' => 'default',
                            'badge' => 1,
                        ],
                    ],
                ],
            ],
        ];

        $url = "https://fcm.googleapis.com/v1/projects/{$projectId}/messages:send";
        $response = Http::withToken($accessToken)
            ->acceptJson()
            ->timeout(12)
            ->post($url, $payload);

        if ($response->successful()) {
            return true;
        }

        $error = $response->json('error.status') ?? $response->json('error.message') ?? $response->body();
        $code = $response->json('error.details.0.errorCode')
            ?? $response->json('error.status');

        if (in_array($code, ['UNREGISTERED', 'INVALID_ARGUMENT', 'NOT_FOUND'], true)
            || str_contains(strtoupper((string) $error), 'UNREGISTERED')
            || str_contains(strtoupper((string) $error), 'NOT_FOUND')) {
            User::query()->where('fcm_token', $token)->update(['fcm_token' => null]);
        }

        Log::warning('FCM HTTP error', [
            'status' => $response->status(),
            'error' => $error,
        ]);

        return false;
    }

    private function pickLocale(?string $ku, ?string $ar, ?string $en): string
    {
        foreach ([$ku, $ar, $en] as $v) {
            if (is_string($v) && trim($v) !== '') {
                return trim($v);
            }
        }

        return 'REGA';
    }

    private function loadServiceAccount(): ?array
    {
        if ($this->serviceAccount !== null) {
            return $this->serviceAccount;
        }

        $path = (string) config('services.fcm.credentials');
        if ($path === '' || ! is_readable($path)) {
            return null;
        }

        $json = json_decode((string) file_get_contents($path), true);
        if (! is_array($json) || empty($json['client_email']) || empty($json['private_key'])) {
            Log::error('FCM credentials JSON invalid', ['path' => $path]);

            return null;
        }

        return $this->serviceAccount = $json;
    }

    private function accessToken(): ?string
    {
        if ($this->accessToken && $this->tokenExpiresAt && time() < $this->tokenExpiresAt - 60) {
            return $this->accessToken;
        }

        $sa = $this->loadServiceAccount();
        if ($sa === null) {
            return null;
        }

        $now = time();
        $jwtHeader = $this->base64UrlEncode(json_encode(['alg' => 'RS256', 'typ' => 'JWT']));
        $jwtClaim = $this->base64UrlEncode(json_encode([
            'iss' => $sa['client_email'],
            'scope' => 'https://www.googleapis.com/auth/firebase.messaging',
            'aud' => 'https://oauth2.googleapis.com/token',
            'iat' => $now,
            'exp' => $now + 3600,
        ]));

        $unsigned = $jwtHeader.'.'.$jwtClaim;
        $privateKey = openssl_pkey_get_private($sa['private_key']);
        if ($privateKey === false) {
            Log::error('FCM: invalid private key in service account');

            return null;
        }

        $signature = '';
        $ok = openssl_sign($unsigned, $signature, $privateKey, OPENSSL_ALGO_SHA256);
        if (! $ok) {
            Log::error('FCM: openssl_sign failed');

            return null;
        }

        $jwt = $unsigned.'.'.$this->base64UrlEncode($signature);

        $tokenRes = Http::asForm()
            ->timeout(12)
            ->post('https://oauth2.googleapis.com/token', [
                'grant_type' => 'urn:ietf:params:oauth:grant-type:jwt-bearer',
                'assertion' => $jwt,
            ]);

        if (! $tokenRes->successful()) {
            Log::error('FCM OAuth token failed', [
                'status' => $tokenRes->status(),
                'body' => $tokenRes->body(),
            ]);

            return null;
        }

        $this->accessToken = (string) $tokenRes->json('access_token');
        $expiresIn = (int) ($tokenRes->json('expires_in') ?? 3600);
        $this->tokenExpiresAt = time() + max(60, $expiresIn);

        return $this->accessToken !== '' ? $this->accessToken : null;
    }

    private function base64UrlEncode(string $data): string
    {
        return rtrim(strtr(base64_encode($data), '+/', '-_'), '=');
    }
}
