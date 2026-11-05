<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class CustomerManagementController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $query = User::query()
            ->where('role', 'customer')
            ->with(['addresses.neighborhood'])
            ->withCount('customerOrders')
            ->withSum(['customerOrders as total_spent' => fn ($q) => $q->where('status', 'delivered')], 'total_amount');

        if ($request->has('is_active') && $request->input('is_active') !== '') {
            $query->where('is_active', filter_var($request->input('is_active'), FILTER_VALIDATE_BOOLEAN));
        }

        if ($request->filled('search')) {
            $s = trim((string) $request->string('search'));
            $query->where(function ($q) use ($s) {
                $q->where('name', 'ILIKE', "%{$s}%")
                    ->orWhere('phone', 'ILIKE', "%{$s}%")
                    ->orWhere('email', 'ILIKE', "%{$s}%");
            });
        }

        $customers = $query->orderByDesc('total_spent')->latest()->get();

        return response()->json([
            'success' => true,
            'data' => $customers,
        ]);
    }

    public function show(User $customer): JsonResponse
    {
        $customer->load([
            'addresses.neighborhood',
            'favoriteStores:id,name_ku,name_en,cover_url',
            'customerOrders' => fn ($q) => $q->with(['store:id,name_ku,name_en', 'driver:id,name'])->latest()->limit(20),
        ]);

        return response()->json([
            'success' => true,
            'data' => $customer,
        ]);
    }

    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'name' => ['required', 'string', 'max:120'],
            'phone' => ['required', 'string', 'max:30', 'unique:users,phone'],
            'email' => ['nullable', 'email', 'max:150', 'unique:users,email'],
            'password' => ['nullable', 'string', 'min:6'],
        ]);

        $customer = User::create([
            'name' => $validated['name'],
            'phone' => preg_replace('/\s+/', '', $validated['phone']),
            'email' => $validated['email'] ?? null,
            'password' => $validated['password'] ?? 'password123',
            'role' => 'customer',
            'language' => 'ku',
            'is_active' => true,
        ]);

        return response()->json([
            'success' => true,
            'message' => 'کڕیار بە سەرکەوتوویی زیادکرا.',
            'data' => $customer,
        ], 201);
    }

    public function update(Request $request, User $customer): JsonResponse
    {
        $validated = $request->validate([
            'name' => ['sometimes', 'string', 'max:120'],
            'phone' => ['sometimes', 'string', 'max:30', 'unique:users,phone,' . $customer->id],
            'email' => ['nullable', 'email', 'max:150', 'unique:users,email,' . $customer->id],
            'is_active' => ['nullable', 'boolean'],
            'password' => ['nullable', 'string', 'min:6'],
        ]);

        if (empty($validated['password'])) {
            unset($validated['password']);
        }

        $customer->update($validated);

        return response()->json([
            'success' => true,
            'message' => 'زانیاری کڕیار نوێکرایەوە.',
            'data' => $customer->fresh(['addresses.neighborhood']),
        ]);
    }

    public function toggleActive(User $customer): JsonResponse
    {
        $customer->update(['is_active' => ! $customer->is_active]);

        if (! $customer->is_active) {
            $customer->tokens()->delete();
        }

        return response()->json([
            'success' => true,
            'message' => $customer->is_active ? 'هەژماری کڕیار چالاککرایەوە.' : 'هەژماری کڕیار ڕاگیرا.',
            'data' => $customer,
        ]);
    }

    public function destroy(User $customer): JsonResponse
    {
        if ($customer->customerOrders()->exists()) {
            $customer->update(['is_active' => false]);
            $customer->tokens()->delete();
            return response()->json([
                'success' => true,
                'message' => 'کڕیارەکە داواکاری پێشووی هەیە، بۆ پاراستنی تۆماری دارایی هەژمارەکەی ڕاگیرا لە جیاتی سڕینەوە.',
            ]);
        }

        $customer->addresses()->delete();
        $customer->tokens()->delete();
        $customer->delete();

        return response()->json([
            'success' => true,
            'message' => 'کڕیار بە سەرکەوتوویی سڕایەوە.',
        ]);
    }
}

