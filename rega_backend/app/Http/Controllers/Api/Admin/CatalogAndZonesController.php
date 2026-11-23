<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Models\Category;
use App\Models\Neighborhood;
use App\Models\ServiceCity;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Str;
use Illuminate\Validation\Rule;

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
            'secondary_image_url' => ['nullable', 'string', 'max:500'],
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
            'image_url' => $validated['image_url'] ?? null,
            'secondary_image_url' => $validated['secondary_image_url'] ?? null,
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
            'secondary_image_url' => ['nullable', 'string', 'max:500'],
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

    public function categoriesReorder(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'order' => ['required', 'array', 'min:1'],
            'order.*' => ['integer', 'exists:categories,id'],
        ]);

        foreach (array_values($validated['order']) as $index => $id) {
            Category::where('id', $id)->update(['sort_order' => $index + 1]);
        }

        $categories = Category::query()
            ->withCount('stores')
            ->orderBy('sort_order')
            ->orderBy('id')
            ->get();

        return response()->json([
            'success' => true,
            'message' => 'ڕیزبەندی بەشەکان نوێکرایەوە.',
            'data' => $categories,
        ]);
    }

    public function serviceCitiesIndex(): JsonResponse
    {
        $cities = ServiceCity::query()
            ->withCount(['neighborhoods', 'stores'])
            ->orderBy('sort_order')
            ->orderBy('id')
            ->get();

        return response()->json([
            'success' => true,
            'data' => $cities,
        ]);
    }

    public function serviceCitiesStore(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'code' => ['nullable', 'string', 'max:30', 'unique:service_cities,code'],
            'name_ku' => ['required', 'string', 'max:120'],
            'name_ar' => ['nullable', 'string', 'max:120'],
            'name_en' => ['nullable', 'string', 'max:120'],
            'center_lat' => ['required', 'numeric'],
            'center_lng' => ['required', 'numeric'],
            'radius_km' => ['nullable', 'integer', Rule::in([5, 10, 15, 20])],
            'is_active' => ['nullable', 'boolean'],
            'sort_order' => ['nullable', 'integer'],
        ]);

        $code = $validated['code']
            ?? Str::slug($validated['name_en'] ?? $validated['name_ku'], '_');
        if ($code === '') {
            $code = 'city_' . random_int(100, 999);
        }

        $city = ServiceCity::create([
            'code' => $code,
            'name_ku' => $validated['name_ku'],
            'name_ar' => $validated['name_ar'] ?? $validated['name_ku'],
            'name_en' => $validated['name_en'] ?? $validated['name_ku'],
            'center_lat' => $validated['center_lat'],
            'center_lng' => $validated['center_lng'],
            'radius_km' => $validated['radius_km'] ?? 10,
            'is_active' => $validated['is_active'] ?? true,
            'sort_order' => $validated['sort_order'] ?? (ServiceCity::count() + 1),
        ]);

        return response()->json([
            'success' => true,
            'message' => 'شاری کار زیادکرا.',
            'data' => $city,
        ], 201);
    }

    public function serviceCitiesUpdate(Request $request, ServiceCity $serviceCity): JsonResponse
    {
        $validated = $request->validate([
            'name_ku' => ['sometimes', 'string', 'max:120'],
            'name_ar' => ['nullable', 'string', 'max:120'],
            'name_en' => ['nullable', 'string', 'max:120'],
            'center_lat' => ['sometimes', 'numeric'],
            'center_lng' => ['sometimes', 'numeric'],
            'radius_km' => ['nullable', 'integer', Rule::in([5, 10, 15, 20])],
            'is_active' => ['nullable', 'boolean'],
            'sort_order' => ['nullable', 'integer'],
        ]);

        $serviceCity->update($validated);

        return response()->json([
            'success' => true,
            'message' => 'شاری کار نوێکرایەوە.',
            'data' => $serviceCity->fresh(),
        ]);
    }

    public function serviceCitiesDestroy(ServiceCity $serviceCity): JsonResponse
    {
        if ($serviceCity->neighborhoods()->exists() || $serviceCity->stores()->exists()) {
            return response()->json([
                'success' => false,
                'message' => 'ناتوانرێت شار بسڕدرێتەوە لەکاتێکدا گەڕەک یان فرۆشگای هەیە. یەکەم نەچالاکی بکە.',
            ], 422);
        }

        $serviceCity->delete();

        return response()->json([
            'success' => true,
            'message' => 'شار سڕایەوە.',
        ]);
    }

    public function neighborhoodsIndex(Request $request): JsonResponse
    {
        $query = Neighborhood::query()
            ->with(['serviceCity:id,code,name_ku,name_en'])
            ->withCount(['stores', 'orders']);

        if ($request->filled('service_city_id')) {
            $query->where('service_city_id', (int) $request->query('service_city_id'));
        }

        $zones = $query->orderBy('sort_order')->orderBy('id')->get();

        return response()->json([
            'success' => true,
            'data' => $zones,
        ]);
    }

    public function neighborhoodsStore(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'service_city_id' => ['nullable', 'exists:service_cities,id'],
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

        $city = null;
        if (! empty($validated['service_city_id'])) {
            $city = ServiceCity::find($validated['service_city_id']);
        }
        if ($city === null) {
            $city = ServiceCity::query()->where('code', 'kalar')->first()
                ?? ServiceCity::query()->orderBy('sort_order')->first();
        }

        $code = $validated['code'] ?? ('n' . (Neighborhood::count() + 1) . '_' . random_int(10, 99));

        $zone = Neighborhood::create([
            'service_city_id' => $city?->id,
            'code' => $code,
            'name_ku' => $validated['name_ku'],
            'name_ar' => $validated['name_ar'] ?? $validated['name_ku'],
            'name_en' => $validated['name_en'] ?? $validated['name_ku'],
            'delivery_fee' => $validated['delivery_fee'],
            'center_lat' => $validated['center_lat'] ?? $city?->center_lat ?? 34.6295,
            'center_lng' => $validated['center_lng'] ?? $city?->center_lng ?? 45.3159,
            'estimated_minutes' => $validated['estimated_minutes'] ?? 25,
            'is_active' => $validated['is_active'] ?? true,
            'sort_order' => $validated['sort_order'] ?? (Neighborhood::count() + 1),
        ]);

        return response()->json([
            'success' => true,
            'message' => 'گەڕەک / ناوچەی نوێ زیادکرا.',
            'data' => $zone->load('serviceCity:id,code,name_ku,name_en'),
        ], 201);
    }

    public function neighborhoodsUpdate(Request $request, Neighborhood $neighborhood): JsonResponse
    {
        $validated = $request->validate([
            'service_city_id' => ['nullable', 'exists:service_cities,id'],
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
            'data' => $neighborhood->fresh()->load('serviceCity:id,code,name_ku,name_en'),
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

