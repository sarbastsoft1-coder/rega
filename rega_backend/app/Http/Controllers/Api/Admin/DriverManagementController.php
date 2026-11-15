<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Models\DriverDocument;
use App\Models\DriverProfile;
use App\Models\Order;
use App\Models\Store;
use App\Models\User;
use App\Services\DriverDispatchService;
use App\Services\DriverWorkloadService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;

class DriverManagementController extends Controller
{
    /** Required KYC document types for a captain/driver. */
    private const REQUIRED_DOC_TYPES = [
        'info_card',
        'national_id',
        'driver_license',
        'vehicle_registration',
    ];

    private function publicUrlForPath(string $path): string
    {
        return \App\Support\PublicMedia::url($path);
    }

    private function deleteStoredFile(?string $fileUrl): void
    {
        $relative = \App\Support\PublicMedia::relativePathFromUrl($fileUrl);
        if ($relative !== null && $relative !== '' && Storage::disk('public')->exists($relative)) {
            Storage::disk('public')->delete($relative);
        }
    }

    private function syncVerificationFlags(?DriverProfile $profile): void
    {
        if (! $profile) {
            return;
        }

        $profile->load('documents');
        $byType = $profile->documents->keyBy('doc_type');
        $allPresentAndVerified = collect(self::REQUIRED_DOC_TYPES)->every(
            fn (string $type) => ($byType[$type]->status ?? null) === 'verified'
        );

        if ($allPresentAndVerified) {
            $profile->update([
                'is_verified' => true,
                'is_vehicle_verified' => true,
            ]);
        }
    }

    private function applyDocumentStatusMeta(array &$updates, Request $request, DriverDocument $document): void
    {
        if (! array_key_exists('status', $updates)) {
            return;
        }

        if ($updates['status'] === 'verified') {
            $updates['verified_by'] = $request->user()->id;
            $updates['verified_at'] = now();
            $updates['rejection_reason'] = null;
        } elseif ($updates['status'] === 'rejected') {
            $updates['verified_by'] = $request->user()->id;
            $updates['verified_at'] = null;
            if (! array_key_exists('rejection_reason', $updates)) {
                $updates['rejection_reason'] = $document->rejection_reason ?: 'بەڵگەنامە ڕەتکرایەوە';
            }
        } elseif ($updates['status'] === 'pending') {
            $updates['verified_by'] = null;
            $updates['verified_at'] = null;
            $updates['rejection_reason'] = null;
        }
    }

    public function index(Request $request, DriverWorkloadService $workload, DriverDispatchService $dispatch): JsonResponse
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

        $todayDelivered = $workload->todayDeliveredCounts();
        $todayAssigned = $workload->todayAssignedCounts();

        $storeLat = null;
        $storeLng = null;
        $storeId = $request->filled('store_id') ? (int) $request->integer('store_id') : null;
        if (! $storeId && $request->filled('order_id')) {
            $storeId = Order::query()->whereKey((int) $request->integer('order_id'))->value('store_id');
            $storeId = $storeId ? (int) $storeId : null;
        }
        if ($storeId) {
            $store = Store::query()->find($storeId);
            if ($store) {
                $storeLat = (float) ($store->lat ?? 34.6836);
                $storeLng = (float) ($store->lng ?? 45.3189);
            }
        }

        $payload = $drivers->map(function (DriverProfile $d) use ($todayDelivered, $todayAssigned, $storeLat, $storeLng, $dispatch) {
            $lat = $d->current_lat !== null ? (float) $d->current_lat : null;
            $lng = $d->current_lng !== null ? (float) $d->current_lng : null;
            $meters = ($storeLat !== null && $storeLng !== null && $lat !== null && $lng !== null)
                ? $dispatch->calculateHaversineDistanceMeters($storeLat, $storeLng, $lat, $lng)
                : null;

            $row = $d->toArray();
            $row['today_deliveries'] = (int) ($todayDelivered[$d->user_id] ?? 0);
            $row['today_orders'] = (int) ($todayAssigned[$d->user_id] ?? 0);
            $row['distance_meters'] = $meters;

            return $row;
        });

        if ($storeLat !== null) {
            $payload = $payload->sort(function ($a, $b) {
                $ao = ! empty($a['is_online']) ? 0 : 1;
                $bo = ! empty($b['is_online']) ? 0 : 1;
                if ($ao !== $bo) {
                    return $ao <=> $bo;
                }
                $ad = $a['distance_meters'] ?? PHP_INT_MAX;
                $bd = $b['distance_meters'] ?? PHP_INT_MAX;
                if ($ad != $bd) {
                    return $ad <=> $bd;
                }

                return ((int) ($a['today_orders'] ?? 0)) <=> ((int) ($b['today_orders'] ?? 0));
            })->values();
        }

        return response()->json([
            'success' => true,
            'data' => $payload,
            'meta' => [
                'store_id' => $storeId,
                'store_lat' => $storeLat,
                'store_lng' => $storeLng,
            ],
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
            'blood_type' => ['nullable', 'string', 'max:10'],
            'home_phone' => ['nullable', 'string', 'max:30'],
            'info_card_number' => ['nullable', 'string', 'max:80'],
            'is_verified' => ['nullable', 'boolean'],
            'language' => ['nullable', 'string', 'in:ku,ar,en'],
            'national_id_number' => ['nullable', 'string', 'max:80'],
            'license_number' => ['nullable', 'string', 'max:80'],
            'registration_number' => ['nullable', 'string', 'max:80'],
            'info_card_file_url' => ['nullable', 'string', 'max:500'],
            'national_id_file_url' => ['nullable', 'string', 'max:500'],
            'license_file_url' => ['nullable', 'string', 'max:500'],
            'registration_file_url' => ['nullable', 'string', 'max:500'],
            'info_card_status' => ['nullable', 'string', 'in:pending,verified,rejected'],
            'national_id_status' => ['nullable', 'string', 'in:pending,verified,rejected'],
            'license_status' => ['nullable', 'string', 'in:pending,verified,rejected'],
            'registration_status' => ['nullable', 'string', 'in:pending,verified,rejected'],
        ]);

        $profile = DB::transaction(function () use ($validated, $request) {
            $phone = preg_replace('/\s+/', '', $validated['phone']);

            $user = User::create([
                'name' => $validated['name'],
                'phone' => $phone,
                'email' => $validated['email'] ?? null,
                'password' => $validated['password'] ?? 'password123',
                'role' => 'driver',
                'language' => $validated['language'] ?? 'ku',
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
                'blood_type' => $validated['blood_type'] ?? null,
                'home_phone' => $validated['home_phone'] ?? null,
                'info_card_number' => $validated['info_card_number'] ?? null,
                'is_vehicle_verified' => $isVerified,
            ]);

            $defaultStatus = $isVerified ? 'verified' : 'pending';
            $docs = [
                [
                    'doc_type' => 'info_card',
                    'document_number' => $validated['info_card_number'] ?? 'INFO-' . random_int(100000, 999999),
                    'file_url' => ! empty($validated['info_card_file_url'] ?? null) ? $validated['info_card_file_url'] : null,
                    'status' => $validated['info_card_status'] ?? $defaultStatus,
                ],
                [
                    'doc_type' => 'national_id',
                    'document_number' => $validated['national_id_number'] ?? 'NID-' . random_int(100000, 999999),
                    'file_url' => ! empty($validated['national_id_file_url'] ?? null) ? $validated['national_id_file_url'] : null,
                    'status' => $validated['national_id_status'] ?? $defaultStatus,
                ],
                [
                    'doc_type' => 'driver_license',
                    'document_number' => $validated['license_number'] ?? 'DL-' . random_int(100000, 999999),
                    'file_url' => ! empty($validated['license_file_url'] ?? null) ? $validated['license_file_url'] : null,
                    'status' => $validated['license_status'] ?? $defaultStatus,
                ],
                [
                    'doc_type' => 'vehicle_registration',
                    'document_number' => $validated['registration_number'] ?? $validated['plate_number'],
                    'file_url' => ! empty($validated['registration_file_url'] ?? null) ? $validated['registration_file_url'] : null,
                    'status' => $validated['registration_status'] ?? $defaultStatus,
                ],
            ];

            foreach ($docs as $d) {
                $status = $d['status'];
                DriverDocument::create([
                    'driver_profile_id' => $dp->id,
                    'doc_type' => $d['doc_type'],
                    'document_number' => $d['document_number'],
                    'file_url' => $d['file_url'],
                    'status' => $status,
                    'verified_by' => $status === 'verified' ? $request->user()->id : null,
                    'verified_at' => $status === 'verified' ? now() : null,
                ]);
            }

            $this->syncVerificationFlags($dp);

            return $dp->fresh(['user', 'documents']);
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
            'email' => ['nullable', 'email', 'max:150', 'unique:users,email,' . $driverProfile->user_id],
            'password' => ['nullable', 'string', 'min:6'],
            'is_active' => ['nullable', 'boolean'],
            'motor_type' => ['sometimes', 'string', 'max:120'],
            'plate_number' => ['sometimes', 'string', 'max:50'],
            'model_year' => ['nullable', 'string', 'max:10'],
            'motor_color' => ['nullable', 'string', 'max:60'],
            'blood_type' => ['nullable', 'string', 'max:10'],
            'home_phone' => ['nullable', 'string', 'max:30'],
            'info_card_number' => ['nullable', 'string', 'max:80'],
            'is_verified' => ['nullable', 'boolean'],
            'is_vehicle_verified' => ['nullable', 'boolean'],
            'is_online' => ['nullable', 'boolean'],
            'language' => ['nullable', 'string', 'in:ku,ar,en'],
            'wallet_balance' => ['nullable', 'numeric', 'min:0'],
            'cash_collected_hand' => ['nullable', 'numeric', 'min:0'],
            'current_lat' => ['nullable', 'numeric'],
            'current_lng' => ['nullable', 'numeric'],
            'national_id_number' => ['nullable', 'string', 'max:80'],
            'license_number' => ['nullable', 'string', 'max:80'],
            'registration_number' => ['nullable', 'string', 'max:80'],
            'info_card_file_url' => ['nullable', 'string', 'max:500'],
            'national_id_file_url' => ['nullable', 'string', 'max:500'],
            'license_file_url' => ['nullable', 'string', 'max:500'],
            'registration_file_url' => ['nullable', 'string', 'max:500'],
            'info_card_status' => ['nullable', 'string', 'in:pending,verified,rejected'],
            'national_id_status' => ['nullable', 'string', 'in:pending,verified,rejected'],
            'license_status' => ['nullable', 'string', 'in:pending,verified,rejected'],
            'registration_status' => ['nullable', 'string', 'in:pending,verified,rejected'],
        ]);

        DB::transaction(function () use ($driverProfile, $validated, $request) {
            $userUpdates = array_filter([
                'name' => $validated['name'] ?? null,
                'phone' => $validated['phone'] ?? null,
                'email' => array_key_exists('email', $validated) ? $validated['email'] : null,
                'password' => $validated['password'] ?? null,
                'is_active' => $validated['is_active'] ?? null,
                'language' => $validated['language'] ?? null,
            ], fn ($v) => $v !== null);

            // Allow clearing email with empty string when key present
            if (array_key_exists('email', $validated) && ($validated['email'] === null || $validated['email'] === '')) {
                $userUpdates['email'] = null;
            }

            if (! empty($userUpdates) && $driverProfile->user) {
                $driverProfile->user->update($userUpdates);
                if (array_key_exists('is_active', $userUpdates) && ! $userUpdates['is_active']) {
                    $driverProfile->user->tokens()->delete();
                    $driverProfile->update(['is_online' => false]);
                }
            }

            $profileUpdates = collect($validated)->only([
                'motor_type',
                'plate_number',
                'model_year',
                'motor_color',
                'blood_type',
                'home_phone',
                'info_card_number',
                'is_verified',
                'is_vehicle_verified',
                'is_online',
                'wallet_balance',
                'cash_collected_hand',
                'current_lat',
                'current_lng',
            ])->toArray();

            if (! empty($profileUpdates)) {
                $driverProfile->update($profileUpdates);
            }

            $docMap = [
                'info_card' => [
                    'number' => $validated['info_card_number'] ?? null,
                    'file' => $validated['info_card_file_url'] ?? null,
                    'status' => $validated['info_card_status'] ?? null,
                ],
                'national_id' => [
                    'number' => $validated['national_id_number'] ?? null,
                    'file' => $validated['national_id_file_url'] ?? null,
                    'status' => $validated['national_id_status'] ?? null,
                ],
                'driver_license' => [
                    'number' => $validated['license_number'] ?? null,
                    'file' => $validated['license_file_url'] ?? null,
                    'status' => $validated['license_status'] ?? null,
                ],
                'vehicle_registration' => [
                    'number' => $validated['registration_number'] ?? null,
                    'file' => $validated['registration_file_url'] ?? null,
                    'status' => $validated['registration_status'] ?? null,
                ],
            ];

            foreach ($docMap as $docType => $values) {
                $updates = [];
                if ($values['number'] !== null) {
                    $updates['document_number'] = $values['number'];
                }
                if ($values['file'] !== null) {
                    // Empty string clears the stored file URL
                    if ($values['file'] === '') {
                        $existing = $driverProfile->documents()->where('doc_type', $docType)->first();
                        $this->deleteStoredFile($existing?->file_url);
                        $updates['file_url'] = null;
                    } else {
                        $updates['file_url'] = $values['file'];
                    }
                }
                if ($values['status'] !== null) {
                    $updates['status'] = $values['status'];
                }

                if (empty($updates)) {
                    continue;
                }

                $existing = $driverProfile->documents()->where('doc_type', $docType)->first()
                    ?? new DriverDocument(['driver_profile_id' => $driverProfile->id, 'doc_type' => $docType]);
                $this->applyDocumentStatusMeta($updates, $request, $existing);

                $driverProfile->documents()->updateOrCreate(
                    ['doc_type' => $docType],
                    $updates
                );
            }

            $this->syncVerificationFlags($driverProfile);
        });

        return response()->json([
            'success' => true,
            'message' => 'زانیاری شۆفێر نوێکرایەوە.',
            'data' => $driverProfile->fresh(['user', 'documents']),
        ]);
    }

    public function documents(DriverProfile $driverProfile): JsonResponse
    {
        $driverProfile->load(['documents.verifier:id,name']);

        // Ensure all 4 required rows exist so admin can edit/upload immediately
        foreach (self::REQUIRED_DOC_TYPES as $type) {
            $driverProfile->documents()->firstOrCreate(
                ['doc_type' => $type],
                [
                    'document_number' => null,
                    'file_url' => null,
                    'status' => 'pending',
                ]
            );
        }

        return response()->json([
            'success' => true,
            'data' => $driverProfile->fresh(['documents.verifier:id,name'])->documents,
        ]);
    }

    public function updateDocument(Request $request, DriverDocument $document): JsonResponse
    {
        $validated = $request->validate([
            'document_number' => ['nullable', 'string', 'max:80'],
            'status' => ['nullable', 'string', 'in:pending,verified,rejected'],
            'rejection_reason' => ['nullable', 'string', 'max:255'],
            'clear_file' => ['nullable', 'boolean'],
            'file' => ['nullable', 'file', 'max:10240', 'mimes:jpg,jpeg,png,webp,gif,pdf'],
        ]);

        $updates = [];

        if (array_key_exists('document_number', $validated)) {
            $updates['document_number'] = $validated['document_number'];
        }
        if (array_key_exists('status', $validated) && $validated['status'] !== null) {
            $updates['status'] = $validated['status'];
            if ($validated['status'] === 'rejected' && array_key_exists('rejection_reason', $validated)) {
                $updates['rejection_reason'] = $validated['rejection_reason'];
            }
            $this->applyDocumentStatusMeta($updates, $request, $document);
        }

        if ($request->boolean('clear_file') && ! $request->hasFile('file')) {
            $this->deleteStoredFile($document->file_url);
            $updates['file_url'] = null;
        }

        if ($request->hasFile('file')) {
            $this->deleteStoredFile($document->file_url);
            $path = $request->file('file')->store('driver-documents', 'public');
            $updates['file_url'] = $this->publicUrlForPath($path);
        }

        if (! empty($updates)) {
            $document->update($updates);
        }

        $profile = $document->driverProfile()->first();
        if ($profile && (($updates['status'] ?? null) === 'rejected')) {
            $profile->update(['is_verified' => false]);
        }
        $this->syncVerificationFlags($profile);

        return response()->json([
            'success' => true,
            'message' => 'بەڵگەنامە نوێکرایەوە.',
            'data' => $document->fresh(['verifier:id,name']),
            'profile' => $profile?->fresh(['user', 'documents']),
        ]);
    }

    public function uploadDocument(Request $request, DriverDocument $document): JsonResponse
    {
        $request->validate([
            'file' => ['required', 'file', 'max:10240', 'mimes:jpg,jpeg,png,webp,gif,pdf'],
            'document_number' => ['nullable', 'string', 'max:80'],
            'status' => ['nullable', 'string', 'in:pending,verified,rejected'],
        ]);

        $this->deleteStoredFile($document->file_url);
        $path = $request->file('file')->store('driver-documents', 'public');
        $url = $this->publicUrlForPath($path);

        $updates = [
            'file_url' => $url,
            'document_number' => $request->input('document_number', $document->document_number),
        ];

        if ($request->filled('status')) {
            $updates['status'] = $request->input('status');
            $this->applyDocumentStatusMeta($updates, $request, $document);
        }

        $document->update($updates);

        $profile = $document->driverProfile()->first();
        $this->syncVerificationFlags($profile);

        return response()->json([
            'success' => true,
            'message' => 'بەڵگەنامە بە سەرکەوتوویی بارکرا (وێنە / PDF).',
            'data' => $document->fresh(),
            'profile' => $profile?->fresh(['user', 'documents']),
        ]);
    }

    public function verifyDocument(Request $request, DriverDocument $document): JsonResponse
    {
        $validated = $request->validate([
            'status' => ['required', 'string', 'in:pending,verified,rejected'],
            'rejection_reason' => ['nullable', 'string', 'max:255'],
        ]);

        $updates = [
            'status' => $validated['status'],
            'rejection_reason' => $validated['status'] === 'rejected'
                ? ($validated['rejection_reason'] ?? 'بەڵگەنامە ڕەتکرایەوە')
                : null,
        ];
        $this->applyDocumentStatusMeta($updates, $request, $document);
        $document->update($updates);

        $profile = $document->driverProfile()->first();
        if ($profile && $validated['status'] === 'rejected') {
            $profile->update(['is_verified' => false]);
        }
        $this->syncVerificationFlags($profile);

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

    public function toggleActive(DriverProfile $driverProfile): JsonResponse
    {
        $user = $driverProfile->user;
        if (! $user) {
            return response()->json([
                'success' => false,
                'message' => 'هەژماری شۆفێر نەدۆزرایەوە.',
            ], 404);
        }

        $user->update(['is_active' => ! $user->is_active]);
        if (! $user->is_active) {
            $user->tokens()->delete();
            $driverProfile->update(['is_online' => false]);
        }

        return response()->json([
            'success' => true,
            'message' => $user->is_active
                ? 'هەژماری شۆفێر چالاککرایەوە.'
                : 'هەژماری شۆفێر مسدود کرا. دەبێت پەیوەندی بە ئادمین بکات.',
            'data' => $driverProfile->fresh(['user', 'documents']),
        ]);
    }
}

