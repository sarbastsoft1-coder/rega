<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Models\Product;
use App\Models\Store;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class ProductManagementController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $query = Product::query()
            ->with([
                'store:id,name_ku,name_en,category_id',
                'store.category:id,name_ku',
                'storeCategory:id,name_ku,name_en',
            ]);

        if ($request->filled('store_id')) {
            $query->where('store_id', $request->integer('store_id'));
        }

        if ($request->filled('store_category_id')) {
            $query->where('store_category_id', $request->integer('store_category_id'));
        }

        if ($request->has('is_available') && $request->input('is_available') !== '') {
            $query->where('is_available', filter_var($request->input('is_available'), FILTER_VALIDATE_BOOLEAN));
        }

        if ($request->boolean('has_discount')) {
            $query->whereNotNull('discount_price')->whereColumn('discount_price', '<', 'price');
        }

        if ($request->filled('search')) {
            $s = trim((string) $request->string('search'));
            $query->where(function ($q) use ($s) {
                $q->where('name_ku', 'ILIKE', "%{$s}%")
                    ->orWhere('name_ar', 'ILIKE', "%{$s}%")
                    ->orWhere('name_en', 'ILIKE', "%{$s}%");
            });
        }

        $products = $query->orderByDesc('sold_count')->latest()->get();
        $products->each->makeVisible(['cost_price']);

        return response()->json([
            'success' => true,
            'data' => $products,
        ]);
    }

    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'store_id' => ['required', 'exists:stores,id'],
            'store_category_id' => ['nullable', 'exists:store_categories,id'],
            'name_ku' => ['required', 'string', 'max:150'],
            'name_ar' => ['nullable', 'string', 'max:150'],
            'name_en' => ['nullable', 'string', 'max:150'],
            'description_ku' => ['nullable', 'string'],
            'description_ar' => ['nullable', 'string'],
            'description_en' => ['nullable', 'string'],
            'price' => ['required', 'integer', 'min:0'],
            'cost_price' => ['required', 'integer', 'min:0'],
            'discount_price' => ['nullable', 'integer', 'min:0'],
            'image_url' => ['nullable', 'string', 'max:500'],
            'is_available' => ['nullable', 'boolean'],
            'is_featured' => ['nullable', 'boolean'],
        ]);

        if ((int) $validated['cost_price'] >= (int) $validated['price']) {
            return response()->json([
                'success' => false,
                'message' => 'نرخی فرۆشتن دەبێت لە نرخی کڕین زیاتر بێت.',
            ], 422);
        }

        $product = Product::create([
            ...$validated,
            'image_url' => $validated['image_url'] ?? 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=600&q=80',
            'is_available' => $validated['is_available'] ?? true,
            'is_featured' => $validated['is_featured'] ?? false,
        ]);

        Store::find($product->store_id)?->refreshDiscountBadge();

        return response()->json([
            'success' => true,
            'message' => 'بەرهەم بە سەرکەوتوویی زیادکرا.',
            'data' => $product->makeVisible(['cost_price'])->load(['store:id,name_ku,name_en', 'storeCategory:id,name_ku']),
        ], 201);
    }

    public function update(Request $request, Product $product): JsonResponse
    {
        $validated = $request->validate([
            'store_id' => ['sometimes', 'exists:stores,id'],
            'store_category_id' => ['nullable', 'exists:store_categories,id'],
            'name_ku' => ['sometimes', 'string', 'max:150'],
            'name_ar' => ['nullable', 'string', 'max:150'],
            'name_en' => ['nullable', 'string', 'max:150'],
            'description_ku' => ['nullable', 'string'],
            'description_ar' => ['nullable', 'string'],
            'description_en' => ['nullable', 'string'],
            'price' => ['sometimes', 'integer', 'min:0'],
            'cost_price' => ['sometimes', 'integer', 'min:0'],
            'discount_price' => ['nullable', 'integer', 'min:0'],
            'image_url' => ['nullable', 'string', 'max:500'],
            'is_available' => ['nullable', 'boolean'],
            'is_featured' => ['nullable', 'boolean'],
        ]);

        $sell = (int) ($validated['price'] ?? $product->price);
        $cost = (int) ($validated['cost_price'] ?? $product->cost_price);
        if ($cost >= $sell) {
            return response()->json([
                'success' => false,
                'message' => 'نرخی فرۆشتن دەبێت لە نرخی کڕین زیاتر بێت.',
            ], 422);
        }

        $product->update($validated);
        Store::find($product->store_id)?->refreshDiscountBadge();

        return response()->json([
            'success' => true,
            'message' => 'بەرهەم بە سەرکەوتوویی نوێکرایەوە.',
            'data' => $product->fresh(['store:id,name_ku,name_en', 'storeCategory:id,name_ku'])->makeVisible(['cost_price']),
        ]);
    }

    public function toggleAvailability(Product $product): JsonResponse
    {
        $product->update(['is_available' => ! $product->is_available]);
        Store::find($product->store_id)?->refreshDiscountBadge();

        return response()->json([
            'success' => true,
            'message' => 'بەردەستبوونی بەرهەم گۆڕدرا.',
            'data' => $product->fresh(['store:id,name_ku,name_en', 'storeCategory:id,name_ku']),
        ]);
    }

    public function destroy(Product $product): JsonResponse
    {
        $storeId = $product->store_id;
        $product->delete();
        Store::find($storeId)?->refreshDiscountBadge();

        return response()->json([
            'success' => true,
            'message' => 'بەرهەم سڕایەوە.',
        ]);
    }
}

