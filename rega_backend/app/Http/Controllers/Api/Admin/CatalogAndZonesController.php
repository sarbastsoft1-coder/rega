<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Models\Category;
use App\Models\Neighborhood;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Str;

class CatalogAndZonesController extends Controller
{
    public function categoriesIndex(): JsonResponse
    {
        $categories = Category::query()
            ->withCount('stores')
            ->orderBy('sort_order')
            ->orderBy('id')
            ->get();

        return response()->json([
            'success' => true,
            'data' => $categories,
        ]);
    }

    public function categoriesStore(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'name_ku' => ['required', 'string', 'max:120'],
            'name_ar' => ['nullable', 'string', 'max:120'],
            'name_en' => ['nullable', 'string', 'max:120'],
            'icon_name' => ['nullable', 'string', 'max:60'],
            'image_url' => ['nullable', 'string', 'max:500'],
            'is_active' => ['nullable', 'boolean'],
            'is_featured_home' => ['nullable', 'boolean'],
            'sort_order' => ['nullable', 'integer'],
        ]);

        $slug = Str::slug($validated['name_en'] ?? $validated['name_ku']) ?: 'category';
        if (Category::where('slug', $slug)->exists()) {
            $slug .= '-' . Str::lower(Str::random(4));
        }

        $category = Category::create([
            'slug' => $slug,
            'name_ku' => $validated['name_ku'],
            'name_ar' => $validated['name_ar'] ?? $validated['name_ku'],
            'name_en' => $validated['name_en'] ?? $validated['name_ku'],
            'icon_name' => $validated['icon_name'] ?? 'storefront',
            'image_url' => $validated['image_url'] ?? 'https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=600&q=80',
            'is_active' => $validated['is_active'] ?? true,
            'is_featured_home' => $validated['is_featured_home'] ?? true,
            'sort_order' => $validated['sort_order'] ?? (Category::count() + 1),
        ]);

        return response()->json([
            'success' => true,
            'message' => 'بەشی نوێ زیادکرا.',
            'data' => $category,
        ], 201);
    }

    public function categoriesUpdate(Request $request, Category $category): JsonResponse
    {
        $validated = $request->validate([
            'name_ku' => ['sometimes', 'string', 'max:120'],
            'name_ar' => ['nullable', 'string', 'max:120'],
            'name_en' => ['nullable', 'string', 'max:120'],
            'icon_name' => ['nullable', 'string', 'max:60'],
            'image_url' => ['nullable', 'string', 'max:500'],
            'is_active' => ['nullable', 'boolean'],
            'is_featured_home' => ['nullable', 'boolean'],
            'sort_order' => ['nullable', 'integer'],
        ]);

        $category->update($validated);

        return response()->json([
            'success' => true,
            'message' => 'بەش نوێکرایەوە.',
            'data' => $category->fresh(),
        ]);
    }

    public function categoriesDestroy(Category $category): JsonResponse
    {
        if ($category->stores()->exists()) {
            return response()->json([
                'success' => false,
                'message' => 'ناتوانرێت بسڕدرێتەوە چونکە فرۆشگا لەسەر ئەم بەشە تۆمارکراوە.',
            ], 422);
        }

        $category->delete();

        return response()->json([
            'success' => true,
            'message' => 'بەش سڕایەوە.',
        ]);
    }

    public function neighborhoodsIndex(): JsonResponse
    {
        $zones = Neighborhood::query()
            ->withCount(['stores', 'orders'])
            ->orderBy('sort_order')
            ->orderBy('id')
            ->get();

        return response()->json([
            'success' => true,
            'data' => $zones,
        ]);
    }

    public function neighborhoodsStore(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'code' => ['nullable', 'string', 'max:30', 'unique:neighborhoods,code'],
            'name_ku' => ['required', 'string', 'max:120'],
            'name_ar' => ['nullable', 'string', 'max:120'],
            'name_en' => ['nullable', 'string', 'max:120'],
            'delivery_fee' => ['required', 'integer', 'min:0'],
            'center_lat' => ['nullable', 'numeric'],
            'center_lng' => ['nullable', 'numeric'],
            'estimated_minutes' => ['nullable', 'integer', 'min:5', 'max:180'],
            'is_active' => ['nullable', 'boolean'],
            'sort_order' => ['nullable', 'integer'],
        ]);

        $code = $validated['code'] ?? ('n' . (Neighborhood::count() + 1) . '_' . random_int(10, 99));

        $zone = Neighborhood::create([
            'code' => $code,
            'name_ku' => $validated['name_ku'],
            'name_ar' => $validated['name_ar'] ?? $validated['name_ku'],
            'name_en' => $validated['name_en'] ?? $validated['name_ku'],
            'delivery_fee' => $validated['delivery_fee'],
            'center_lat' => $validated['center_lat'] ?? 34.6836,
            'center_lng' => $validated['center_lng'] ?? 45.3189,
            'estimated_minutes' => $validated['estimated_minutes'] ?? 25,
            'is_active' => $validated['is_active'] ?? true,
            'sort_order' => $validated['sort_order'] ?? (Neighborhood::count() + 1),
        ]);

        return response()->json([
            'success' => true,
            'message' => 'گەڕەک / ناوچەی نوێ زیادکرا.',
            'data' => $zone,
        ], 201);
    }

    public function neighborhoodsUpdate(Request $request, Neighborhood $neighborhood): JsonResponse
    {
        $validated = $request->validate([
            'name_ku' => ['sometimes', 'string', 'max:120'],
            'name_ar' => ['nullable', 'string', 'max:120'],
            'name_en' => ['nullable', 'string', 'max:120'],
            'delivery_fee' => ['sometimes', 'integer', 'min:0'],
            'center_lat' => ['nullable', 'numeric'],
            'center_lng' => ['nullable', 'numeric'],
            'estimated_minutes' => ['nullable', 'integer', 'min:5', 'max:180'],
            'is_active' => ['nullable', 'boolean'],
            'sort_order' => ['nullable', 'integer'],
        ]);

        $neighborhood->update($validated);

        return response()->json([
            'success' => true,
            'message' => 'زانیاری گەڕەک و کرێی گەیاندن نوێکرایەوە.',
            'data' => $neighborhood->fresh(),
        ]);
    }

    public function neighborhoodsDestroy(Neighborhood $neighborhood): JsonResponse
    {
        $neighborhood->delete();

        return response()->json([
            'success' => true,
            'message' => 'گەڕەک سڕایەوە.',
        ]);
    }
}

