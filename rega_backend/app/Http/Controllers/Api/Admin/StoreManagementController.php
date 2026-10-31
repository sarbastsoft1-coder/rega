<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Models\Store;
use App\Models\StoreCategory;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

class StoreManagementController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $query = Store::query()
            ->with([
                'owner:id,name,phone,email,is_active',
                'category:id,name_ku,name_ar,name_en,icon_name',
                'neighborhood:id,name_ku,name_en,delivery_fee',
            ])
            ->withCount(['products', 'orders'])
            ->withSum(['orders as gross_sales' => fn ($q) => $q->where('status', 'delivered')], 'total_amount')
            ->withSum(['orders as total_commission' => fn ($q) => $q->where('status', 'delivered')], 'commission_amount');

        if ($request->filled('category_id')) {
            $query->where('category_id', $request->integer('category_id'));
        }

        if ($request->has('is_online') && $request->input('is_online') !== '') {
            $query->where('is_online', filter_var($request->input('is_online'), FILTER_VALIDATE_BOOLEAN));
        }

        if ($request->has('is_approved') && $request->input('is_approved') !== '') {
            $query->where('is_approved', filter_var($request->input('is_approved'), FILTER_VALIDATE_BOOLEAN));
        }

        if ($request->filled('search')) {
            $s = trim((string) $request->string('search'));
            $query->where(function ($q) use ($s) {
                $q->where('name_ku', 'ILIKE', "%{$s}%")
                    ->orWhere('name_en', 'ILIKE', "%{$s}%")
                    ->orWhere('phone', 'ILIKE', "%{$s}%")
                    ->orWhere('address_ku', 'ILIKE', "%{$s}%");
            });
        }

        $stores = $query->orderByDesc('is_featured')->latest()->get();

        return response()->json([
            'success' => true,
            'data' => $stores,
        ]);
    }

    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'name_ku' => ['required', 'string', 'max:150'],
            'name_ar' => ['nullable', 'string', 'max:150'],
            'name_en' => ['nullable', 'string', 'max:150'],
            'category_id' => ['required', 'exists:categories,id'],
            'neighborhood_id' => ['nullable', 'exists:neighborhoods,id'],
            'phone' => ['required', 'string', 'max:30'],
            'address_ku' => ['required', 'string', 'max:255'],
            'address_ar' => ['nullable', 'string', 'max:255'],
            'address_en' => ['nullable', 'string', 'max:255'],
            'lat' => ['nullable', 'numeric'],
            'lng' => ['nullable', 'numeric'],
            'logo_url' => ['nullable', 'string', 'max:500'],
            'cover_url' => ['nullable', 'string', 'max:500'],
            'delivery_time' => ['nullable', 'string', 'max:60'],
            'base_delivery_fee' => ['nullable', 'integer', 'min:0'],
            'commission_rate' => ['nullable', 'numeric', 'min:0', 'max:50'],
            'discount_badge' => ['nullable', 'string', 'max:80'],
            'open_time' => ['nullable', 'string', 'max:20'],
            'close_time' => ['nullable', 'string', 'max:20'],
            'is_online' => ['nullable', 'boolean'],
            'is_approved' => ['nullable', 'boolean'],
            'is_featured' => ['nullable', 'boolean'],

            // Vendor owner account provisioning
            'owner_name' => ['nullable', 'string', 'max:120'],
            'owner_phone' => ['nullable', 'string', 'max:30'],
            'owner_email' => ['nullable', 'email', 'max:150'],
            'owner_password' => ['nullable', 'string', 'min:6'],
            'initial_categories' => ['nullable', 'array'],
            'initial_categories.*' => ['string', 'max:100'],
        ]);

        $createdStore = DB::transaction(function () use ($validated) {
            $ownerPhone = preg_replace('/\s+/', '', $validated['owner_phone'] ?? $validated['phone']);

            $owner = User::where('phone', $ownerPhone)->first();
            if (! $owner) {
                $owner = User::create([
                    'name' => $validated['owner_name'] ?? ('خاوەنی ' . $validated['name_ku']),
                    'phone' => $ownerPhone,
                    'email' => $validated['owner_email'] ?? null,
                    'password' => $validated['owner_password'] ?? 'password123',
                    'role' => 'vendor',
                    'language' => 'ku',
                    'is_active' => true,
                ]);
            }

            $baseSlug = Str::slug($validated['name_en'] ?? $validated['name_ku']) ?: 'store';
            $slug = $baseSlug . '-' . Str::lower(Str::random(5));

            $store = Store::create([
                'owner_id' => $owner->id,
                'category_id' => $validated['category_id'],
                'neighborhood_id' => $validated['neighborhood_id'] ?? null,
                'slug' => $slug,
                'name_ku' => $validated['name_ku'],
                'name_ar' => $validated['name_ar'] ?? $validated['name_ku'],
                'name_en' => $validated['name_en'] ?? $validated['name_ku'],
                'phone' => $validated['phone'],
                'address_ku' => $validated['address_ku'],
                'address_ar' => $validated['address_ar'] ?? $validated['address_ku'],
                'address_en' => $validated['address_en'] ?? null,
                'lat' => $validated['lat'] ?? 34.6836,
                'lng' => $validated['lng'] ?? 45.3189,
                'logo_url' => $validated['logo_url'] ?? null,
                'cover_url' => $validated['cover_url'] ?? 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?w=800&q=80',
                'delivery_time' => $validated['delivery_time'] ?? '20-30 خولەک',
                'base_delivery_fee' => $validated['base_delivery_fee'] ?? 1500,
                'commission_rate' => $validated['commission_rate'] ?? 12.00,
                'discount_badge' => $validated['discount_badge'] ?? null,
                'open_time' => $validated['open_time'] ?? '09:00 AM',
                'close_time' => $validated['close_time'] ?? '11:00 PM',
                'is_online' => $validated['is_online'] ?? true,
                'is_approved' => $validated['is_approved'] ?? true,
                'is_featured' => $validated['is_featured'] ?? false,
            ]);

            $cats = $validated['initial_categories'] ?? ['بەرهەمە سەرەکییەکان', 'خواردنەوەکان'];
            foreach ($cats as $idx => $catName) {
                StoreCategory::create([
                    'store_id' => $store->id,
                    'name_ku' => $catName,
                    'sort_order' => $idx,
                ]);
            }

            return $store->load(['owner', 'category', 'neighborhood', 'storeCategories']);
        });

        return response()->json([
            'success' => true,
            'message' => 'فرۆشگا و هەژماری فرۆشیار بە سەرکەوتوویی دروستکران.',
            'data' => $createdStore,
        ], 201);
    }

    public function show(Store $store): JsonResponse
    {
        $store->load([
            'owner',
            'category',
            'neighborhood',
            'storeCategories.products',
            'products.storeCategory',
        ]);

        $deliveredOrders = $store->orders()->where('status', 'delivered');
        $stats = [
            'gross_sales' => (int) (clone $deliveredOrders)->sum('total_amount'),
            'platform_commission' => (int) (clone $deliveredOrders)->sum('commission_amount'),
            'vendor_net_profit' => (int) (clone $deliveredOrders)->sum('vendor_net_amount'),
            'delivered_orders_count' => (clone $deliveredOrders)->count(),
            'active_orders_count' => $store->orders()->whereNotIn('status', ['delivered', 'cancelled', 'rejected'])->count(),
        ];

        return response()->json([
            'success' => true,
            'data' => $store,
            'stats' => $stats,
        ]);
    }

    public function update(Request $request, Store $store): JsonResponse
    {
        $validated = $request->validate([
            'name_ku' => ['sometimes', 'string', 'max:150'],
            'name_ar' => ['nullable', 'string', 'max:150'],
            'name_en' => ['nullable', 'string', 'max:150'],
            'category_id' => ['sometimes', 'exists:categories,id'],
            'neighborhood_id' => ['nullable', 'exists:neighborhoods,id'],
            'phone' => ['sometimes', 'string', 'max:30'],
            'address_ku' => ['sometimes', 'string', 'max:255'],
            'address_ar' => ['nullable', 'string', 'max:255'],
            'address_en' => ['nullable', 'string', 'max:255'],
            'lat' => ['nullable', 'numeric'],
            'lng' => ['nullable', 'numeric'],
            'logo_url' => ['nullable', 'string', 'max:500'],
            'cover_url' => ['nullable', 'string', 'max:500'],
            'delivery_time' => ['nullable', 'string', 'max:60'],
            'base_delivery_fee' => ['nullable', 'integer', 'min:0'],
            'commission_rate' => ['nullable', 'numeric', 'min:0', 'max:50'],
            'discount_badge' => ['nullable', 'string', 'max:80'],
            'open_time' => ['nullable', 'string', 'max:20'],
            'close_time' => ['nullable', 'string', 'max:20'],
            'is_online' => ['nullable', 'boolean'],
            'is_approved' => ['nullable', 'boolean'],
            'is_featured' => ['nullable', 'boolean'],
            'owner_password' => ['nullable', 'string', 'min:6'],
        ]);

        if (! empty($validated['owner_password']) && $store->owner) {
            $store->owner->update(['password' => $validated['owner_password']]);
        }
        unset($validated['owner_password']);

        $store->update($validated);

        return response()->json([
            'success' => true,
            'message' => 'زانیاری فرۆشگا بە سەرکەوتوویی نوێکرایەوە.',
            'data' => $store->fresh(['owner', 'category', 'neighborhood', 'storeCategories']),
        ]);
    }

    public function toggleStatus(Request $request, Store $store): JsonResponse
    {
        $validated = $request->validate([
            'field' => ['required', 'string', 'in:is_online,is_approved,is_featured'],
        ]);

        $field = $validated['field'];
        $store->update([$field => ! $store->{$field}]);

        return response()->json([
            'success' => true,
            'message' => 'بارودۆخی فرۆشگا گۆڕدرا.',
            'data' => $store->fresh(['owner', 'category', 'neighborhood']),
        ]);
    }

    public function destroy(Store $store): JsonResponse
    {
        if ($store->orders()->exists()) {
            $store->update(['is_online' => false, 'is_approved' => false]);

            return response()->json([
                'success' => true,
                'message' => 'فرۆشگاکە داواکاری پێشووی هەیە، بۆیە ناچالاککرا لەبری سڕینەوە.',
            ]);
        }

        $store->delete();

        return response()->json([
            'success' => true,
            'message' => 'فرۆشگا بە سەرکەوتوویی سڕایەوە.',
        ]);
    }

    public function addStoreCategory(Request $request, Store $store): JsonResponse
    {
        $validated = $request->validate([
            'name_ku' => ['required', 'string', 'max:100'],
            'name_ar' => ['nullable', 'string', 'max:100'],
            'name_en' => ['nullable', 'string', 'max:100'],
            'sort_order' => ['nullable', 'integer'],
        ]);

        $cat = $store->storeCategories()->create([
            'name_ku' => $validated['name_ku'],
            'name_ar' => $validated['name_ar'] ?? $validated['name_ku'],
            'name_en' => $validated['name_en'] ?? null,
            'sort_order' => $validated['sort_order'] ?? ($store->storeCategories()->count() + 1),
        ]);

        return response()->json([
            'success' => true,
            'message' => 'بەشی ناوخۆیی فرۆشگا زیادکرا.',
            'data' => $cat,
        ], 201);
    }

    public function deleteStoreCategory(StoreCategory $storeCategory): JsonResponse
    {
        $storeCategory->delete();

        return response()->json([
            'success' => true,
            'message' => 'بەشی ناوخۆیی سڕایەوە.',
        ]);
    }
}

