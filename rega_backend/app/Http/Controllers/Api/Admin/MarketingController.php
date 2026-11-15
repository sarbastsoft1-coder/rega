<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Models\AppNotification;
use App\Models\Banner;
use App\Models\Coupon;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Str;

class MarketingController extends Controller
{
    // --- Coupons ---
    public function couponsIndex(): JsonResponse
    {
        $coupons = Coupon::query()
            ->with('store:id,name_ku,name_en')
            ->latest()
            ->get();

        return response()->json([
            'success' => true,
            'data' => $coupons,
        ]);
    }

    public function couponsStore(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'code' => ['required', 'string', 'max:40', 'unique:coupons,code'],
            'store_id' => ['nullable', 'exists:stores,id'],
            'title_ku' => ['required', 'string', 'max:150'],
            'title_ar' => ['nullable', 'string', 'max:150'],
            'title_en' => ['nullable', 'string', 'max:150'],
            'discount_type' => ['required', 'string', 'in:percentage,fixed,free_delivery'],
            'discount_value' => ['required', 'integer', 'min:0'],
            'min_order_amount' => ['nullable', 'integer', 'min:0'],
            'max_discount_amount' => ['nullable', 'integer', 'min:0'],
            'usage_limit' => ['nullable', 'integer', 'min:1'],
            'expires_at' => ['nullable', 'date'],
            'is_active' => ['nullable', 'boolean'],
        ]);

        $validated['code'] = strtoupper(trim($validated['code']));

        $coupon = Coupon::create([
            ...$validated,
            'min_order_amount' => $validated['min_order_amount'] ?? 0,
            'is_active' => $validated['is_active'] ?? true,
        ]);

        return response()->json([
            'success' => true,
            'message' => 'کۆدی داشکاندن بە سەرکەوتوویی دروستکرا.',
            'data' => $coupon->load('store:id,name_ku,name_en'),
        ], 201);
    }

    public function couponsUpdate(Request $request, Coupon $coupon): JsonResponse
    {
        $validated = $request->validate([
            'code' => ['sometimes', 'string', 'max:40', 'unique:coupons,code,' . $coupon->id],
            'store_id' => ['nullable', 'exists:stores,id'],
            'title_ku' => ['sometimes', 'string', 'max:150'],
            'title_ar' => ['nullable', 'string', 'max:150'],
            'title_en' => ['nullable', 'string', 'max:150'],
            'discount_type' => ['sometimes', 'string', 'in:percentage,fixed,free_delivery'],
            'discount_value' => ['sometimes', 'integer', 'min:0'],
            'min_order_amount' => ['nullable', 'integer', 'min:0'],
            'max_discount_amount' => ['nullable', 'integer', 'min:0'],
            'usage_limit' => ['nullable', 'integer', 'min:1'],
            'expires_at' => ['nullable', 'date'],
            'is_active' => ['nullable', 'boolean'],
        ]);

        if (isset($validated['code'])) {
            $validated['code'] = strtoupper(trim($validated['code']));
        }

        $coupon->update($validated);

        return response()->json([
            'success' => true,
            'message' => 'کۆدی داشکاندن نوێکرایەوە.',
            'data' => $coupon->fresh('store:id,name_ku,name_en'),
        ]);
    }

    public function couponsDestroy(Coupon $coupon): JsonResponse
    {
        $coupon->delete();

        return response()->json([
            'success' => true,
            'message' => 'کۆدی داشکاندن سڕایەوە.',
        ]);
    }

    // --- Banners ---
    public function bannersIndex(): JsonResponse
    {
        $banners = Banner::query()
            ->with(['store:id,name_ku,name_en', 'category:id,name_ku,name_en'])
            ->orderBy('sort_order')
            ->latest()
            ->get();

        return response()->json([
            'success' => true,
            'data' => $banners,
        ]);
    }

    public function bannersStore(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'title_ku' => ['required', 'string', 'max:150'],
            'title_ar' => ['nullable', 'string', 'max:150'],
            'title_en' => ['nullable', 'string', 'max:150'],
            'subtitle_ku' => ['nullable', 'string', 'max:255'],
            'badge_text' => ['nullable', 'string', 'max:80'],
            'image_url' => ['required', 'string', 'max:500'],
            'target_type' => ['nullable', 'string', 'in:store,category,none'],
            'store_id' => ['nullable', 'exists:stores,id'],
            'category_id' => ['nullable', 'exists:categories,id'],
            'is_active' => ['nullable', 'boolean'],
            'sort_order' => ['nullable', 'integer'],
        ]);

        $banner = Banner::create([
            ...$validated,
            'target_type' => $validated['target_type'] ?? 'none',
            'is_active' => $validated['is_active'] ?? true,
            'sort_order' => $validated['sort_order'] ?? (Banner::count() + 1),
        ]);

        return response()->json([
            'success' => true,
            'message' => 'بانەری ڕێکلام بە سەرکەوتوویی زیادکرا.',
            'data' => $banner->load(['store:id,name_ku,name_en', 'category:id,name_ku,name_en']),
        ], 201);
    }

    public function bannersUpdate(Request $request, Banner $banner): JsonResponse
    {
        $validated = $request->validate([
            'title_ku' => ['sometimes', 'string', 'max:150'],
            'title_ar' => ['nullable', 'string', 'max:150'],
            'title_en' => ['nullable', 'string', 'max:150'],
            'subtitle_ku' => ['nullable', 'string', 'max:255'],
            'badge_text' => ['nullable', 'string', 'max:80'],
            'image_url' => ['sometimes', 'string', 'max:500'],
            'target_type' => ['nullable', 'string', 'in:store,category,none'],
            'store_id' => ['nullable', 'exists:stores,id'],
            'category_id' => ['nullable', 'exists:categories,id'],
            'is_active' => ['nullable', 'boolean'],
            'sort_order' => ['nullable', 'integer'],
        ]);

        $banner->update($validated);

        return response()->json([
            'success' => true,
            'message' => 'بانەری ڕێکلام نوێکرایەوە.',
            'data' => $banner->fresh(['store:id,name_ku,name_en', 'category:id,name_ku,name_en']),
        ]);
    }

    public function bannersDestroy(Banner $banner): JsonResponse
    {
        $banner->delete();

        return response()->json([
            'success' => true,
            'message' => 'بانەر سڕایەوە.',
        ]);
    }

    // --- Outbound customer / broadcast notifications (admin → apps) ---
    public function notificationsIndex(): JsonResponse
    {
        // Outbound marketing only — exclude operational alerts (e.g. driver order assigns).
        $rows = AppNotification::query()
            ->with(['user:id,name,phone', 'store:id,name_ku,name_en'])
            ->where(function ($q) {
                $q->whereNotNull('campaign_id')
                    ->orWhere(function ($broadcast) {
                        $broadcast->whereNull('user_id')
                            ->whereIn('target_audience', ['all', 'customers', 'vendors', 'drivers']);
                    })
                    ->orWhere(function ($selected) {
                        $selected->where('target_audience', 'specific_user')
                            ->where('type', '!=', 'order');
                    });
            })
            ->latest()
            ->limit(800)
            ->get();

        // Group fan-out rows by campaign so admin history shows one send per campaign.
        $grouped = [];
        foreach ($rows as $n) {
            $key = $n->campaign_id ?: ('single_'.$n->id);
            // Broadcast companion (user_id null) is for public inbox — don't inflate recipient_count.
            $countsAsRecipient = $n->user_id !== null || $n->campaign_id === null;
            if (! isset($grouped[$key])) {
                $payload = $n->toArray();
                $payload['recipient_count'] = $countsAsRecipient ? 1 : 0;
                $payload['campaign_id'] = $n->campaign_id;
                $grouped[$key] = $payload;
            } elseif ($countsAsRecipient) {
                $grouped[$key]['recipient_count']++;
            }
        }

        return response()->json([
            'success' => true,
            'data' => array_values($grouped),
        ]);
    }

    public function notificationsSend(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'target_audience' => ['required', 'string', 'in:all,customers,vendors,drivers,specific_user,selected'],
            'user_id' => ['nullable', 'exists:users,id'],
            'user_ids' => ['nullable', 'array', 'max:500'],
            'user_ids.*' => ['integer', 'exists:users,id'],
            'title_ku' => ['required', 'string', 'max:150'],
            'title_ar' => ['nullable', 'string', 'max:150'],
            'title_en' => ['nullable', 'string', 'max:150'],
            'body_ku' => ['required', 'string'],
            'body_ar' => ['nullable', 'string'],
            'body_en' => ['nullable', 'string'],
            'tag' => ['nullable', 'string', 'max:60'],
            'type' => ['nullable', 'string', 'in:store,category,order,general,discount,other'],
            'store_id' => ['nullable', 'exists:stores,id'],
            'category_name' => ['nullable', 'string', 'max:120'],
            'discount_badge' => ['nullable', 'string', 'max:80'],
        ]);

        [$type, $tag] = $this->normalizeNotificationTypeAndTag(
            $validated['type'] ?? 'general',
            $validated['tag'] ?? null,
        );

        $base = [
            'title_ku' => $validated['title_ku'],
            'title_ar' => $validated['title_ar'] ?? null,
            'title_en' => $validated['title_en'] ?? null,
            'body_ku' => $validated['body_ku'],
            'body_ar' => $validated['body_ar'] ?? null,
            'body_en' => $validated['body_en'] ?? null,
            'tag' => $tag,
            'type' => $type,
            'store_id' => $validated['store_id'] ?? null,
            'category_name' => $validated['category_name'] ?? null,
            'discount_badge' => $validated['discount_badge'] ?? null,
            'is_read' => false,
        ];

        $audience = $validated['target_audience'];
        $selectedIds = collect($validated['user_ids'] ?? [])
            ->when(! empty($validated['user_id']), fn ($c) => $c->push((int) $validated['user_id']))
            ->map(fn ($id) => (int) $id)
            ->unique()
            ->values();

        // Selected customers (or specific_user with ids): one personal inbox row each.
        if ($audience === 'selected' || ($audience === 'specific_user' && $selectedIds->isNotEmpty())) {
            if ($selectedIds->isEmpty()) {
                return response()->json([
                    'success' => false,
                    'message' => 'تکایە لانیکەم یەک کڕیار هەڵبژێرە.',
                ], 422);
            }

            $campaignId = (string) Str::uuid();
            $created = [];
            foreach ($selectedIds as $uid) {
                $created[] = AppNotification::create([
                    ...$base,
                    'campaign_id' => $campaignId,
                    'user_id' => $uid,
                    'target_audience' => 'specific_user',
                ]);
            }

            $first = $created[0]->load(['user:id,name,phone', 'store:id,name_ku,name_en']);

            return response()->json([
                'success' => true,
                'message' => 'ئاگادارکردنەوە بۆ کڕیارە هەڵبژێردراوەکان نێردرا.',
                'data' => $first,
                'recipient_count' => count($created),
                'campaign_id' => $campaignId,
            ], 201);
        }

        // All customers: fan-out personal rows so each can mark-read independently.
        if ($audience === 'customers') {
            $customerIds = User::query()
                ->where('role', 'customer')
                ->where('is_active', true)
                ->pluck('id');

            if ($customerIds->isEmpty()) {
                // Still persist a broadcast row so admin history / future customers can see it.
                $notification = AppNotification::create([
                    ...$base,
                    'user_id' => null,
                    'target_audience' => 'customers',
                ]);

                return response()->json([
                    'success' => true,
                    'message' => 'ئاگادارکردنەوە تۆمارکرا (هیچ کڕیارێکی چالاک نەدۆزرایەوە).',
                    'data' => $notification->load(['user:id,name,phone', 'store:id,name_ku,name_en']),
                    'recipient_count' => 0,
                ], 201);
            }

            $campaignId = (string) Str::uuid();
            $now = now();
            // Broadcast companion so guests / new customers still see the campaign via public inbox.
            $rows = [[
                ...$base,
                'campaign_id' => $campaignId,
                'user_id' => null,
                'target_audience' => 'customers',
                'created_at' => $now,
                'updated_at' => $now,
            ]];
            foreach ($customerIds as $uid) {
                $rows[] = [
                    ...$base,
                    'campaign_id' => $campaignId,
                    'user_id' => $uid,
                    'target_audience' => 'customers',
                    'created_at' => $now,
                    'updated_at' => $now,
                ];
            }

            foreach (array_chunk($rows, 200) as $chunk) {
                AppNotification::insert($chunk);
            }

            $sample = AppNotification::query()
                ->where('campaign_id', $campaignId)
                ->whereNull('user_id')
                ->with(['user:id,name,phone', 'store:id,name_ku,name_en'])
                ->first();

            return response()->json([
                'success' => true,
                'message' => 'ئاگادارکردنەوە بۆ هەموو کڕیاران نێردرا.',
                'data' => $sample,
                'recipient_count' => $customerIds->count(),
                'campaign_id' => $campaignId,
            ], 201);
        }

        // Legacy single-row broadcast (all / vendors / drivers / specific_user without list).
        $notification = AppNotification::create([
            ...$base,
            'user_id' => $validated['user_id'] ?? null,
            'target_audience' => $audience,
        ]);

        return response()->json([
            'success' => true,
            'message' => 'ئاگادارکردنەوە بە سەرکەوتوویی نێردرا.',
            'data' => $notification->load(['user:id,name,phone', 'store:id,name_ku,name_en']),
            'recipient_count' => 1,
        ], 201);
    }

    public function notificationsDestroy(AppNotification $notification): JsonResponse
    {
        if ($notification->campaign_id) {
            AppNotification::query()
                ->where('campaign_id', $notification->campaign_id)
                ->delete();
        } else {
            $notification->delete();
        }

        return response()->json([
            'success' => true,
            'message' => 'ئاگادارکردنەوە سڕایەوە.',
        ]);
    }

    /**
     * Map UI types (discount/general/other) onto stored type + Kurdish tag.
     *
     * @return array{0: string, 1: string}
     */
    private function normalizeNotificationTypeAndTag(string $type, ?string $tag): array
    {
        $type = strtolower(trim($type));
        $tag = $tag !== null && trim($tag) !== '' ? trim($tag) : null;

        return match ($type) {
            'discount' => ['general', $tag ?? 'داشکاندن'],
            'other' => ['general', $tag ?? 'ئەویتر'],
            'store', 'category', 'order', 'general' => [$type, $tag ?? ($type === 'general' ? 'ئاگاداری' : $type)],
            default => ['general', $tag ?? 'ئاگاداری'],
        };
    }
}

