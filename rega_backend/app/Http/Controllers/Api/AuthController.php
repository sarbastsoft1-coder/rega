<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Middleware\EnsureUserIsActive;
use App\Models\CustomerAddress;
use App\Models\User;
use App\Services\CustomerPasswordResetService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;

class AuthController extends Controller
{
    public function login(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'identifier' => ['nullable', 'string'],
            'phone' => ['nullable', 'string'],
            'email' => ['nullable', 'string'],
            'password' => ['required', 'string'],
            'role_filter' => ['nullable', 'string'],
            'device_name' => ['nullable', 'string'],
        ]);

        $loginValue = trim((string) ($validated['identifier'] ?? $validated['phone'] ?? $validated['email'] ?? ''));

        if ($loginValue === '') {
            return response()->json([
                'success' => false,
                'message' => 'ژمارەی مۆبایل یان ئیمەیڵ پێویستە.',
            ], 422);
        }

        $normalizedPhone = preg_replace('/\s+/', '', $loginValue) ?? $loginValue;
        $emailCandidate = strtolower($loginValue);

        $user = User::query()
            ->where(function ($q) use ($loginValue, $normalizedPhone, $emailCandidate) {
                $q->whereRaw('LOWER(email) = ?', [$emailCandidate])
                    ->orWhere('phone', $loginValue)
                    ->orWhere('phone', $normalizedPhone);
            })
            ->first();

        if (! $user || ! Hash::check($validated['password'], $user->password)) {
            return response()->json([
                'success' => false,
                'message' => 'زانیاری چوونە ژوورەوە هەڵەیە.',
            ], 401);
        }

        if (! $user->is_active) {
            return response()->json([
                'success' => false,
                'code' => 'account_blocked',
                'message' => 'هەژمارەکەت لەلایەن بەڕێوەبەرەوە مسدود کراوە. تکایە پەیوەندی بە یارمەتی پشتگیری بکە لە ڕێگەی واتسئاپ.',
                'contact' => EnsureUserIsActive::supportContacts(),
            ], 403);
        }

        if (! empty($validated['role_filter'])) {
            $filter = $validated['role_filter'];
            $allowed = match ($filter) {
                'admin' => $user->isAdmin(),
                'vendor' => $user->isVendor(),
                'driver' => $user->isDriver(),
                'customer' => $user->isCustomer(),
                default => true,
            };

            if (! $allowed) {
                return response()->json([
                    'success' => false,
                    'message' => 'ئەم هەژمارە ڕێگەپێدراو نییە بۆ ئەم ئەپە.',
                ], 403);
            }
        }

        $user->update(['last_login_at' => now()]);

        $token = $user->createToken($validated['device_name'] ?? 'rega-client')->plainTextToken;

        return response()->json([
            'success' => true,
            'message' => 'بە سەرکەوتوویی چوویتە ژوورەوە.',
            'data' => [
                'token' => $token,
                'user' => $this->loadUserRelations($user),
            ],
        ]);
    }

    public function register(Request $request): JsonResponse
    {
        // Normalize phone before unique validation so "0750 123 4567" matches DB digits.
        if ($request->has('phone')) {
            $request->merge([
                'phone' => preg_replace('/\s+/', '', (string) $request->input('phone')),
            ]);
        }

        $validated = $request->validate([
            'name' => ['required', 'string', 'max:120'],
            'phone' => ['required', 'string', 'max:30', 'unique:users,phone'],
            'email' => ['nullable', 'email', 'max:150', 'unique:users,email'],
            'password' => ['required', 'string', 'min:6'],
            'language' => ['nullable', 'string', 'in:ku,ar,en'],
            'neighborhood_id' => ['nullable', 'exists:neighborhoods,id'],
            'address' => ['nullable', 'string', 'max:255'],
        ]);

        $phone = $validated['phone'];

        $user = User::create([
            'name' => $validated['name'],
            'phone' => $phone,
            'email' => $validated['email'] ?? null,
            'password' => $validated['password'],
            'role' => 'customer',
            'language' => $validated['language'] ?? 'ku',
            'is_active' => true,
            'last_login_at' => now(),
        ]);

        if (! empty($validated['address']) || ! empty($validated['neighborhood_id'])) {
            CustomerAddress::create([
                'user_id' => $user->id,
                'neighborhood_id' => $validated['neighborhood_id'] ?? null,
                'label' => 'ماڵەوە',
                'address_line' => $validated['address'] ?? 'کەلار',
                'is_default' => true,
            ]);
        }

        $token = $user->createToken('rega-customer')->plainTextToken;

        return response()->json([
            'success' => true,
            'message' => 'هەژمارەکەت بە سەرکەوتوویی دروستکرا.',
            'data' => [
                'token' => $token,
                'user' => $this->loadUserRelations($user),
            ],
        ], 201);
    }

    public function me(Request $request): JsonResponse
    {
        $user = $request->user();
        if ($user && ! $user->is_active) {
            $user->tokens()->delete();

            return response()->json([
                'success' => false,
                'code' => 'account_blocked',
                'message' => 'هەژمارەکەت لەلایەن بەڕێوەبەرەوە مسدود کراوە. تکایە پەیوەندی بە یارمەتی پشتگیری بکە لە ڕێگەی واتسئاپ.',
                'contact' => EnsureUserIsActive::supportContacts(),
            ], 403);
        }

        return response()->json([
            'success' => true,
            'data' => $this->loadUserRelations($user),
        ]);
    }

    public function updateProfile(Request $request): JsonResponse
    {
        /** @var User $user */
        $user = $request->user();

        $validated = $request->validate([
            'name' => ['sometimes', 'string', 'max:120'],
            'phone' => ['sometimes', 'string', 'max:30', 'unique:users,phone,' . $user->id],
            'email' => ['nullable', 'email', 'max:150', 'unique:users,email,' . $user->id],
            'language' => ['sometimes', 'string', 'in:ku,ar,en'],
            'avatar_url' => ['nullable', 'string', 'max:500'],
            'fcm_token' => ['nullable', 'string', 'max:500'],
        ]);

        $user->update($validated);

        return response()->json([
            'success' => true,
            'message' => 'زانیاری پڕۆفایل نوێکرایەوە.',
            'data' => $this->loadUserRelations($user->fresh()),
        ]);
    }

    public function changePassword(Request $request): JsonResponse
    {
        /** @var User $user */
        $user = $request->user();

        $validated = $request->validate([
            'current_password' => ['required', 'string'],
            'new_password' => ['required', 'string', 'min:6'],
        ]);

        if (! Hash::check($validated['current_password'], $user->password)) {
            return response()->json([
                'success' => false,
                'message' => 'وشەی نهێنی ئێستا هەڵەیە.',
            ], 422);
        }

        $user->update(['password' => $validated['new_password']]);

        return response()->json([
            'success' => true,
            'message' => 'وشەی نهێنی بە سەرکەوتوویی گۆڕدرا.',
        ]);
    }

    public function logout(Request $request): JsonResponse
    {
        $request->user()?->currentAccessToken()?->delete();

        return response()->json([
            'success' => true,
            'message' => 'چوویتە دەرەوە لە هەژمار.',
        ]);
    }

    public function requestPasswordResetOtp(Request $request, CustomerPasswordResetService $reset): JsonResponse
    {
        $validated = $request->validate([
            'phone' => ['required', 'string', 'max:30'],
        ]);

        $result = $reset->requestOtp($validated['phone']);
        $data = [
            'expires_in' => $result['expires_in'] ?? null,
        ];
        if (isset($result['debug_otp'])) {
            $data['debug_otp'] = $result['debug_otp'];
        }

        return response()->json([
            'success' => (bool) ($result['ok'] ?? false),
            'message' => $result['message'] ?? '',
            'data' => $data,
        ], (int) ($result['status'] ?? 500));
    }

    public function resetPasswordWithOtp(Request $request, CustomerPasswordResetService $reset): JsonResponse
    {
        $validated = $request->validate([
            'phone' => ['required', 'string', 'max:30'],
            'otp' => ['required', 'string', 'max:12'],
            'new_password' => ['required', 'string', 'min:6'],
        ]);

        $result = $reset->resetWithOtp(
            $validated['phone'],
            $validated['otp'],
            $validated['new_password'],
        );

        return response()->json([
            'success' => (bool) ($result['ok'] ?? false),
            'message' => $result['message'] ?? '',
        ], (int) ($result['status'] ?? 500));
    }

    private function loadUserRelations(User $user): User
    {
        $user->load([
            'driverProfile.documents',
            'addresses.neighborhood',
        ]);

        // Same selection as VendorAppController::resolveStore — keeps login
        // payload aligned with the store the vendor app reads/writes.
        if ($user->isVendor()) {
            $store = $user->resolveOwnedStore();
            if ($store) {
                $store->loadMissing(['category', 'neighborhood']);
            }
            $user->setRelation('ownedStore', $store);
        } else {
            $user->load(['ownedStore.category', 'ownedStore.neighborhood']);
        }

        return $user;
    }
}

