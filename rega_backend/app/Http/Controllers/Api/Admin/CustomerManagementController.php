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
        $this->normalizeCustomerPhoneInput($request);

        $validated = $request->validate([
            'name' => ['required', 'string', 'max:120'],
            'phone' => ['required', 'string', 'regex:/^07[0-9]{9}$/', 'unique:users,phone'],
            'email' => ['nullable', 'email', 'max:150', 'unique:users,email'],
            'password' => ['required', 'string', 'min:6'],
            'city' => ['nullable', 'string', 'max:80'],
            'is_active' => ['nullable', 'boolean'],
        ], [
            'phone.regex' => 'ژمارەی مۆبایل نادروستە — فۆرماتی عێراقی: 07501234567',
            'phone.unique' => 'ئەم ژمارەی مۆبایلە پێشتر تۆمارکراوە.',
            'password.required' => 'وشەی نهێنی پێویستە (لانیکەم ٦ پیت).',
            'password.min' => 'وشەی نهێنی دەبێت لانیکەم ٦ پیت بێت.',
        ]);

        $customer = User::create([
            'name' => $validated['name'],
            'phone' => $validated['phone'],
            'email' => $validated['email'] ?? null,
            'password' => $validated['password'],
            'role' => 'customer',
            'language' => 'ku',
            'city' => $validated['city'] ?? null,
            'is_active' => array_key_exists('is_active', $validated)
                ? (bool) $validated['is_active']
                : true,
        ]);

        return response()->json([
            'success' => true,
            'message' => 'کڕیار بە سەرکەوتوویی زیادکرا.',
            'data' => $customer,
        ], 201);
    }

    public function update(Request $request, User $customer): JsonResponse
    {
        $this->normalizeCustomerPhoneInput($request);

        $validated = $request->validate([
            'name' => ['sometimes', 'string', 'max:120'],
            'phone' => ['sometimes', 'string', 'regex:/^07[0-9]{9}$/', 'unique:users,phone,' . $customer->id],
            'email' => ['nullable', 'email', 'max:150', 'unique:users,email,' . $customer->id],
            'is_active' => ['nullable', 'boolean'],
            'password' => ['nullable', 'string', 'min:6'],
            'language' => ['nullable', 'string', 'in:ku,ar,en'],
            'city' => ['nullable', 'string', 'max:80'],
        ], [
            'phone.regex' => 'ژمارەی مۆبایل نادروستە — فۆرماتی عێراقی: 07501234567',
            'phone.unique' => 'ئەم ژمارەی مۆبایلە پێشتر تۆمارکراوە.',
        ]);

        if (empty($validated['password'])) {
            unset($validated['password']);
        }

        $customer->update($validated);

        if (array_key_exists('is_active', $validated) && ! $validated['is_active']) {
            $customer->tokens()->delete();
        }

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
            'message' => $customer->is_active
                ? 'هەژماری کڕیار چالاککرایەوە.'
                : 'هەژماری کڕیار مسدود کرا. دەبێت پەیوەندی بە ئادمین بکات.',
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

    /** Strip spaces / +964 country code so unique + regex rules see canonical 07XXXXXXXXX. */
    private function normalizeCustomerPhoneInput(Request $request): void
    {
        if (! $request->has('phone')) {
            return;
        }

        $raw = trim((string) $request->input('phone'));
        $digits = preg_replace('/\D+/', '', $raw) ?? '';
        if (str_starts_with($digits, '964') && strlen($digits) >= 3) {
            $digits = '0'.substr($digits, 3);
        }

        // Keep garbage like "sfs" so `regex` fails with a clear message (not empty→required).
        $request->merge(['phone' => $digits !== '' ? $digits : $raw]);
    }
}

