<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Models\DriverDocument;
use App\Models\DriverProfile;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class DriverManagementController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $query = DriverProfile::query()
            ->with(['user', 'documents']);

        if ($request->has('is_online') && $request->input('is_online') !== '') {
            $query->where('is_online', filter_var($request->input('is_online'), FILTER_VALIDATE_BOOLEAN));
        }

        if ($request->has('is_verified') && $request->input('is_verified') !== '') {
            $query->where('is_verified', filter_var($request->input('is_verified'), FILTER_VALIDATE_BOOLEAN));
        }

        if ($request->filled('search')) {
            $s = trim((string) $request->string('search'));
            $query->where(function ($q) use ($s) {
                $q->where('driver_code', 'ILIKE', "%{$s}%")
                    ->orWhere('plate_number', 'ILIKE', "%{$s}%")
                    ->orWhere('motor_type', 'ILIKE', "%{$s}%")
                    ->orWhereHas('user', fn ($uq) => $uq->where('name', 'ILIKE', "%{$s}%")->orWhere('phone', 'ILIKE', "%{$s}%"));
            });
        }

        $drivers = $query->orderByDesc('is_online')->orderByDesc('total_deliveries')->get();

        return response()->json([
            'success' => true,
            'data' => $drivers,
        ]);
    }

    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'name' => ['required', 'string', 'max:120'],
            'phone' => ['required', 'string', 'max:30', 'unique:users,phone'],
            'email' => ['nullable', 'email', 'max:150', 'unique:users,email'],
            'password' => ['nullable', 'string', 'min:6'],
            'driver_code' => ['nullable', 'string', 'max:30', 'unique:driver_profiles,driver_code'],
            'motor_type' => ['required', 'string', 'max:120'],
            'plate_number' => ['required', 'string', 'max:50'],
            'model_year' => ['nullable', 'string', 'max:10'],
            'motor_color' => ['nullable', 'string', 'max:60'],
            'is_verified' => ['nullable', 'boolean'],
            'national_id_number' => ['nullable', 'string', 'max:80'],
            'license_number' => ['nullable', 'string', 'max:80'],
            'registration_number' => ['nullable', 'string', 'max:80'],
        ]);

        $profile = DB::transaction(function () use ($validated, $request) {
            $phone = preg_replace('/\s+/', '', $validated['phone']);

            $user = User::create([
                'name' => $validated['name'],
                'phone' => $phone,
                'email' => $validated['email'] ?? null,
                'password' => $validated['password'] ?? 'password123',
                'role' => 'driver',
                'language' => 'ku',
                'is_active' => true,
            ]);

            $code = $validated['driver_code'] ?? ('RA-' . random_int(100, 999));
            while (DriverProfile::where('driver_code', $code)->exists()) {
                $code = 'RA-' . random_int(1000, 9999);
            }

            $isVerified = (bool) ($validated['is_verified'] ?? false);

            $dp = DriverProfile::create([
                'user_id' => $user->id,
                'driver_code' => $code,
                'is_verified' => $isVerified,
                'is_online' => false,
                'current_lat' => 34.6845,
                'current_lng' => 45.3195,
                'motor_type' => $validated['motor_type'],
                'plate_number' => $validated['plate_number'],
                'model_year' => $validated['model_year'] ?? '2024',
                'motor_color' => $validated['motor_color'] ?? 'ڕەش و سەوز',
                'is_vehicle_verified' => $isVerified,
            ]);

            $docStatus = $isVerified ? 'verified' : 'pending';
            $docs = [
                ['doc_type' => 'national_id', 'document_number' => $validated['national_id_number'] ?? 'NID-' . random_int(100000, 999999)],
                ['doc_type' => 'driver_license', 'document_number' => $validated['license_number'] ?? 'DL-' . random_int(100000, 999999)],
                ['doc_type' => 'vehicle_registration', 'document_number' => $validated['registration_number'] ?? $validated['plate_number']],
            ];

            foreach ($docs as $d) {
                DriverDocument::create([
                    'driver_profile_id' => $dp->id,
                    'doc_type' => $d['doc_type'],
                    'document_number' => $d['document_number'],
                    'status' => $docStatus,
                    'verified_by' => $isVerified ? $request->user()->id : null,
                    'verified_at' => $isVerified ? now() : null,
                ]);
            }

            return $dp->load(['user', 'documents']);
        });

        return response()->json([
            'success' => true,
            'message' => 'شۆفێری نوێ بە سەرکەوتوویی تۆمارکرا.',
            'data' => $profile,
        ], 201);
    }

    public function show(DriverProfile $driverProfile): JsonResponse
    {
        $driverProfile->load(['user', 'documents.verifier:id,name']);

        $recentDeliveries = $driverProfile->user
            ? $driverProfile->user->driverOrders()->with(['store:id,name_ku', 'customer:id,name'])->latest()->limit(15)->get()
            : [];

        return response()->json([
            'success' => true,
            'data' => $driverProfile,
            'recent_deliveries' => $recentDeliveries,
        ]);
    }

    public function update(Request $request, DriverProfile $driverProfile): JsonResponse
    {
        $validated = $request->validate([
            'name' => ['sometimes', 'string', 'max:120'],
            'phone' => ['sometimes', 'string', 'max:30', 'unique:users,phone,' . $driverProfile->user_id],
            'password' => ['nullable', 'string', 'min:6'],
            'is_active' => ['nullable', 'boolean'],
            'motor_type' => ['sometimes', 'string', 'max:120'],
            'plate_number' => ['sometimes', 'string', 'max:50'],
            'model_year' => ['nullable', 'string', 'max:10'],
            'motor_color' => ['nullable', 'string', 'max:60'],
            'is_verified' => ['nullable', 'boolean'],
            'is_vehicle_verified' => ['nullable', 'boolean'],
            'is_online' => ['nullable', 'boolean'],
        ]);

        DB::transaction(function () use ($driverProfile, $validated) {
            $userUpdates = array_filter([
                'name' => $validated['name'] ?? null,
                'phone' => $validated['phone'] ?? null,
                'password' => $validated['password'] ?? null,
                'is_active' => $validated['is_active'] ?? null,
            ], fn ($v) => $v !== null);

            if (! empty($userUpdates) && $driverProfile->user) {
                $driverProfile->user->update($userUpdates);
            }

            $profileUpdates = collect($validated)->only([
                'motor_type',
                'plate_number',
                'model_year',
                'motor_color',
                'is_verified',
                'is_vehicle_verified',
                'is_online',
            ])->toArray();

            if (! empty($profileUpdates)) {
                $driverProfile->update($profileUpdates);
            }
        });

        return response()->json([
            'success' => true,
            'message' => 'زانیاری شۆفێر نوێکرایەوە.',
            'data' => $driverProfile->fresh(['user', 'documents']),
        ]);
    }

    public function verifyDocument(Request $request, DriverDocument $document): JsonResponse
    {
        $validated = $request->validate([
            'status' => ['required', 'string', 'in:pending,verified,rejected'],
            'rejection_reason' => ['nullable', 'string', 'max:255'],
        ]);

        $document->update([
            'status' => $validated['status'],
            'rejection_reason' => $validated['status'] === 'rejected' ? ($validated['rejection_reason'] ?? 'بەڵگەنامە ڕەتکرایەوە') : null,
            'verified_by' => $request->user()->id,
            'verified_at' => $validated['status'] === 'verified' ? now() : null,
        ]);

        // Auto-verify driver profile if all 3 KYC documents are verified
        $profile = $document->driverProfile()->with('documents')->first();
        if ($profile) {
            $allVerified = $profile->documents->count() >= 3
                && $profile->documents->every(fn (DriverDocument $d) => $d->status === 'verified');

            if ($allVerified) {
                $profile->update([
                    'is_verified' => true,
                    'is_vehicle_verified' => true,
                ]);
            } elseif ($validated['status'] === 'rejected') {
                $profile->update(['is_verified' => false]);
            }
        }

        return response()->json([
            'success' => true,
            'message' => 'بارودۆخی بەڵگەنامەی یاسایی نوێکرایەوە.',
            'data' => $profile?->fresh(['user', 'documents']),
        ]);
    }

    public function toggleStatus(Request $request, DriverProfile $driverProfile): JsonResponse
    {
        $validated = $request->validate([
            'field' => ['required', 'string', 'in:is_verified,is_online,is_vehicle_verified'],
        ]);

        $field = $validated['field'];
        $newVal = ! $driverProfile->{$field};
        $driverProfile->update([$field => $newVal]);

        if ($field === 'is_verified' && $newVal) {
            $driverProfile->documents()->update([
                'status' => 'verified',
                'verified_by' => $request->user()->id,
                'verified_at' => now(),
            ]);
            $driverProfile->update(['is_vehicle_verified' => true]);
        }

        return response()->json([
            'success' => true,
            'message' => 'بارودۆخی شۆفێر گۆڕدرا.',
            'data' => $driverProfile->fresh(['user', 'documents']),
        ]);
    }
}

