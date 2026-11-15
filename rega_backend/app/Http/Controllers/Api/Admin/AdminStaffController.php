<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class AdminStaffController extends Controller
{
    /** Staff UI manages only the `admin` role (single role). */
    private const MANAGED_ROLE = 'admin';

    public function index(Request $request): JsonResponse
    {
        // Staff management lists only `admin` accounts (no multi-role filtering).
        $query = User::query()
            ->where('role', self::MANAGED_ROLE)
            ->orderBy('name');

        if ($request->filled('search')) {
            $s = trim((string) $request->string('search'));
            $query->where(function ($q) use ($s) {
                $q->where('name', 'ILIKE', "%{$s}%")
                    ->orWhere('phone', 'ILIKE', "%{$s}%")
                    ->orWhere('email', 'ILIKE', "%{$s}%");
            });
        }

        return response()->json([
            'success' => true,
            'data' => $query->get(['id', 'name', 'phone', 'email', 'role', 'language', 'is_active', 'last_login_at', 'created_at']),
        ]);
    }

    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'name' => ['required', 'string', 'max:120'],
            'phone' => ['required', 'string', 'max:30', 'unique:users,phone'],
            'email' => ['required', 'email', 'max:150', 'unique:users,email'],
            'password' => ['required', 'string', 'min:6'],
            'language' => ['nullable', 'string', 'in:ku,ar,en'],
            'is_active' => ['nullable', 'boolean'],
        ]);

        $email = strtolower(trim((string) $validated['email']));
        $phone = preg_replace('/\s+/', '', $validated['phone']) ?? $validated['phone'];

        $admin = User::create([
            'name' => $validated['name'],
            'phone' => $phone,
            'email' => $email,
            'password' => $validated['password'], // hashed via User casts
            'role' => self::MANAGED_ROLE,
            'language' => $validated['language'] ?? 'ku',
            'is_active' => $validated['is_active'] ?? true,
        ]);

        return response()->json([
            'success' => true,
            'message' => 'هەژماری ئەدمین بە سەرکەوتوویی دروستکرا.',
            'data' => $admin->only(['id', 'name', 'phone', 'email', 'role', 'language', 'is_active', 'created_at']),
        ], 201);
    }

    public function update(Request $request, User $adminUser): JsonResponse
    {
        if ($adminUser->role !== self::MANAGED_ROLE) {
            return response()->json([
                'success' => false,
                'message' => 'تەنها هەژماری ئەدمین دەستکاری دەکرێت.',
            ], 404);
        }

        $validated = $request->validate([
            'name' => ['sometimes', 'string', 'max:120'],
            'phone' => ['sometimes', 'string', 'max:30', 'unique:users,phone,' . $adminUser->id],
            'email' => ['sometimes', 'required', 'email', 'max:150', 'unique:users,email,' . $adminUser->id],
            'password' => ['nullable', 'string', 'min:6'],
            'language' => ['nullable', 'string', 'in:ku,ar,en'],
            'is_active' => ['nullable', 'boolean'],
        ]);

        if (isset($validated['phone'])) {
            $validated['phone'] = preg_replace('/\s+/', '', $validated['phone']);
        }
        if (isset($validated['email'])) {
            $validated['email'] = strtolower(trim((string) $validated['email']));
        }
        if (empty($validated['password'])) {
            unset($validated['password']);
        }

        // Always keep managed staff as `admin` (ignore any client role).
        $validated['role'] = self::MANAGED_ROLE;

        $adminUser->update($validated);

        if (array_key_exists('is_active', $validated) && ! $adminUser->is_active) {
            $adminUser->tokens()->delete();
        }

        return response()->json([
            'success' => true,
            'message' => 'هەژماری ئەدمین نوێکرایەوە.',
            'data' => $adminUser->fresh()->only(['id', 'name', 'phone', 'email', 'role', 'language', 'is_active', 'last_login_at', 'created_at']),
        ]);
    }

    public function toggleActive(Request $request, User $adminUser): JsonResponse
    {
        if ($adminUser->role !== self::MANAGED_ROLE) {
            return response()->json([
                'success' => false,
                'message' => 'تەنها هەژماری ئەدمین دەستکاری دەکرێت.',
            ], 404);
        }

        if ($request->user()?->id === $adminUser->id) {
            return response()->json([
                'success' => false,
                'message' => 'ناتوانیت هەژماری خۆت ناچالاک بکەیت.',
            ], 422);
        }

        $adminUser->update(['is_active' => ! $adminUser->is_active]);
        if (! $adminUser->is_active) {
            $adminUser->tokens()->delete();
        }

        return response()->json([
            'success' => true,
            'message' => $adminUser->is_active ? 'هەژمار چالاککرایەوە.' : 'هەژمار ناچالاککرا.',
            'data' => $adminUser,
        ]);
    }

    public function destroy(Request $request, User $adminUser): JsonResponse
    {
        if ($adminUser->role !== self::MANAGED_ROLE) {
            return response()->json([
                'success' => false,
                'message' => 'تەنها هەژماری ئەدمین دەسڕدرێتەوە.',
            ], 404);
        }

        if ($request->user()?->id === $adminUser->id) {
            return response()->json([
                'success' => false,
                'message' => 'ناتوانیت هەژماری خۆت بسڕیتەوە.',
            ], 422);
        }

        $adminUser->tokens()->delete();
        $adminUser->delete();

        return response()->json([
            'success' => true,
            'message' => 'هەژماری ئەدمین بە تەواوی سڕایەوە.',
        ]);
    }
}
