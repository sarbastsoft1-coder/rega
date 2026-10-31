<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Models\AppNotification;
use App\Models\Banner;
use App\Models\Coupon;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

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

    // --- Broadcast Notifications ---
    public function notificationsIndex(): JsonResponse
    {
        $notifications = AppNotification::query()
            ->with(['user:id,name,phone', 'store:id,name_ku,name_en'])
            ->latest()
            ->limit(100)
            ->get();

        return response()->json([
            'success' => true,
            'data' => $notifications,
        ]);
    }

    public function notificationsSend(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'target_audience' => ['required', 'string', 'in:all,customers,vendors,drivers,specific_user'],
            'user_id' => ['nullable', 'exists:users,id'],
            'title_ku' => ['required', 'string', 'max:150'],
            'title_ar' => ['nullable', 'string', 'max:150'],
            'title_en' => ['nullable', 'string', 'max:150'],
            'body_ku' => ['required', 'string'],
            'body_ar' => ['nullable', 'string'],
            'body_en' => ['nullable', 'string'],
            'tag' => ['nullable', 'string', 'max:60'],
            'type' => ['nullable', 'string', 'in:store,category,order,general'],
            'store_id' => ['nullable', 'exists:stores,id'],
            'category_name' => ['nullable', 'string', 'max:120'],
            'discount_badge' => ['nullable', 'string', 'max:80'],
        ]);

        $notification = AppNotification::create([
            ...$validated,
            'tag' => $validated['tag'] ?? 'ئاگاداری',
            'type' => $validated['type'] ?? 'general',
        ]);

        return response()->json([
            'success' => true,
            'message' => 'ئاگادارکردنەوە بە سەرکەوتوویی نێردرا.',
            'data' => $notification->load(['user:id,name,phone', 'store:id,name_ku,name_en']),
        ], 201);
    }

    public function notificationsDestroy(AppNotification $notification): JsonResponse
    {
        $notification->delete();

        return response()->json([
            'success' => true,
            'message' => 'ئاگادارکردنەوە سڕایەوە.',
        ]);
    }
}

