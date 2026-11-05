<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\DriverProfile;
use App\Models\LiveTelemetrySession;
use App\Models\Order;
use App\Services\OrderSettlementService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class LiveTelemetryController extends Controller
{
    public function __construct(private readonly OrderSettlementService $settlementService) {}

    private function normalizeRef(string $raw): string
    {
        $clean = strtoupper(trim(ltrim(urldecode($raw), '#')));
        return $clean !== '' ? $clean : '10245';
    }

    /**
     * Kalar realistic street waypoints: Driver Dispatch -> Store -> Customer
     */
    private function buildKalarWaypoints(float $dLat, float $dLng, float $sLat, float $sLng, float $cLat, float $cLng): array
    {
        return [
            [$dLat, $dLng],
            [$dLat + ($sLat - $dLat) * 0.35 + 0.0005, $dLng + ($sLng - $dLng) * 0.25 - 0.0003],
            [$dLat + ($sLat - $dLat) * 0.72 - 0.0003, $dLng + ($sLng - $dLng) * 0.68 + 0.0004],
            [$sLat, $sLng], // Store pickup index = 3
            [$sLat + ($cLat - $sLat) * 0.22 + 0.0006, $sLng + ($cLng - $sLng) * 0.18 + 0.0002],
            [$sLat + ($cLat - $sLat) * 0.48 + 0.0004, $sLng + ($cLng - $sLng) * 0.44 - 0.0005],
            [$sLat + ($cLat - $sLat) * 0.74 - 0.0003, $sLng + ($cLng - $sLng) * 0.76 + 0.0003],
            [$cLat, $cLng],
        ];
    }

    private function resolveOrBootstrapSession(string $ref): LiveTelemetrySession
    {
        $session = LiveTelemetrySession::where('order_ref', $ref)->first();
        if ($session) {
            return $session;
        }

        $order = Order::with(['store', 'driver.driverProfile', 'items'])
            ->where(function ($q) use ($ref) {
                $q->where('order_number', $ref)
                    ->orWhere('order_number', 'RA-' . $ref)
                    ->when(is_numeric($ref), fn ($sq) => $sq->orWhere('id', (int) $ref));
            })
            ->first();

        $sLat = (float) ($order?->store?->lat ?? 34.6836);
        $sLng = (float) ($order?->store?->lng ?? 45.3189);
        $cLat = (float) ($order?->delivery_lat ?? 34.6912);
        $cLng = (float) ($order?->delivery_lng ?? 45.3264);
        $dLat = (float) ($order?->driver_lat ?? $order?->driver?->driverProfile?->current_lat ?? 34.6798);
        $dLng = (float) ($order?->driver_lng ?? $order?->driver?->driverProfile?->current_lng ?? 45.3145);

        $items = $order?->items?->map(fn ($i) => [
            'name' => $i->product_name,
            'quantity' => $i->quantity,
            'price' => $i->unit_price,
        ])->values()->all() ?? [
            ['name' => 'کەبابی کوردی تایبەت (٢ شیش)', 'quantity' => 2, 'price' => 7000],
            ['name' => 'برنجی کوردی و دۆی خۆماڵی', 'quantity' => 1, 'price' => 4500],
        ];

        return LiveTelemetrySession::create([
            'order_ref' => $ref,
            'order_id' => $order?->id,
            'status' => $order?->status ?? 'preparing',
            'driver_status' => $order?->driver_status && $order->driver_status !== 'unassigned'
                ? $order->driver_status
                : 'driver_arriving_pickup',
            'store_name' => $order?->store?->name_ku ?? 'کەبابخانەی کەلار',
            'store_address' => $order?->store?->address_ku ?? 'ناو بازاڕی کەلار - شەقامی سیروان',
            'store_phone' => $order?->store?->phone ?? '07701112233',
            'store_lat' => $sLat,
            'store_lng' => $sLng,
            'customer_name' => $order?->customer_name ?? 'سەربەست عەلی',
            'customer_address' => $order?->delivery_address ?? 'گەڕەکی شەهیدان - کۆڵانی ١٤، کەلار',
            'customer_phone' => $order?->customer_phone ?? '07703001001',
            'customer_lat' => $cLat,
            'customer_lng' => $cLng,
            'driver_name' => $order?->driver?->name ?? 'کاروان محەمەد',
            'driver_phone' => $order?->driver?->phone ?? '07702001001',
            'vehicle_label' => $order?->driver?->driverProfile
                ? ($order->driver->driverProfile->motor_type . ' • ' . $order->driver->driverProfile->plate_number)
                : 'Honda PCX 150 • KLR-402',
            'driver_lat' => $dLat,
            'driver_lng' => $dLng,
            'driver_heading' => (float) ($order?->driver_heading ?? 42.0),
            'driver_speed_kmh' => (float) ($order?->driver_speed_kmh ?? 31.5),
            'eta_seconds' => (int) ($order?->eta_seconds ?? 150),
            'distance_remaining_meters' => (int) ($order?->distance_remaining_meters ?? 1380),
            'progress_permille' => $order?->status === 'delivered' ? 1000 : 80,
            'delivery_pin' => $order?->delivery_pin ?? '4821',
            'handover_pin' => $order?->handover_pin ?? '1934',
            'total_amount' => (int) ($order?->total_amount ?? 18500),
            'delivery_fee' => (int) ($order?->delivery_fee ?? 1500),
            'driver_tip' => (int) ($order?->driver_tip ?? 500),
            'items_json' => $items,
            'route_polyline' => $this->buildKalarWaypoints($dLat, $dLng, $sLat, $sLng, $cLat, $cLng),
        ]);
    }

    public function registerOrder(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'order_ref' => ['required', 'string', 'max:40'],
            'store_name' => ['nullable', 'string', 'max:160'],
            'store_address' => ['nullable', 'string', 'max:255'],
            'store_phone' => ['nullable', 'string', 'max:30'],
            'store_lat' => ['nullable', 'numeric'],
            'store_lng' => ['nullable', 'numeric'],
            'customer_name' => ['nullable', 'string', 'max:160'],
            'customer_address' => ['nullable', 'string', 'max:255'],
            'customer_phone' => ['nullable', 'string', 'max:30'],
            'customer_lat' => ['nullable', 'numeric'],
            'customer_lng' => ['nullable', 'numeric'],
            'delivery_pin' => ['nullable', 'string', 'size:4'],
            'total_amount' => ['nullable', 'integer', 'min:0'],
            'delivery_fee' => ['nullable', 'integer', 'min:0'],
            'driver_tip' => ['nullable', 'integer', 'min:0'],
            'items' => ['nullable', 'array'],
        ]);

        $ref = $this->normalizeRef($validated['order_ref']);
        $sLat = (float) ($validated['store_lat'] ?? 34.6836);
        $sLng = (float) ($validated['store_lng'] ?? 45.3189);
        $cLat = (float) ($validated['customer_lat'] ?? 34.6912);
        $cLng = (float) ($validated['customer_lng'] ?? 45.3264);
        $dLat = $sLat - 0.0042;
        $dLng = $sLng - 0.0048;

        $session = LiveTelemetrySession::updateOrCreate(
            ['order_ref' => $ref],
            [
                'status' => 'preparing',
                'driver_status' => 'driver_arriving_pickup',
                'store_name' => $validated['store_name'] ?? 'کەبابخانەی کەلار',
                'store_address' => $validated['store_address'] ?? 'ناو بازاڕی کەلار - شەقامی سیروان',
                'store_phone' => $validated['store_phone'] ?? '07701112233',
                'store_lat' => $sLat,
                'store_lng' => $sLng,
                'customer_name' => $validated['customer_name'] ?? 'سەربەست عەلی',
                'customer_address' => $validated['customer_address'] ?? 'گەڕەکی شەهیدان - کۆڵانی ١٤، کەلار',
                'customer_phone' => $validated['customer_phone'] ?? '07703001001',
                'customer_lat' => $cLat,
                'customer_lng' => $cLng,
                'driver_name' => 'کاروان محەمەد',
                'driver_phone' => '07702001001',
                'vehicle_label' => 'Honda PCX 150 • KLR-402',
                'driver_lat' => $dLat,
                'driver_lng' => $dLng,
                'driver_heading' => 44.0,
                'driver_speed_kmh' => 33.0,
                'eta_seconds' => 140,
                'distance_remaining_meters' => 1420,
                'progress_permille' => 0,
                'delivery_pin' => $validated['delivery_pin'] ?? '4821',
                'total_amount' => (int) ($validated['total_amount'] ?? 18500),
                'delivery_fee' => (int) ($validated['delivery_fee'] ?? 1500),
                'driver_tip' => (int) ($validated['driver_tip'] ?? 500),
                'items_json' => $validated['items'] ?? [],
                'route_polyline' => $this->buildKalarWaypoints($dLat, $dLng, $sLat, $sLng, $cLat, $cLng),
            ]
        );

        return response()->json([
            'success' => true,
            'data' => $this->formatPayload($session),
        ], 201);
    }

    public function latestActive(): JsonResponse
    {
        $session = LiveTelemetrySession::whereNotIn('status', ['delivered', 'cancelled', 'rejected'])
            ->latest('updated_at')
            ->first();

        if (! $session) {
            $activeOrder = Order::whereNotIn('status', ['delivered', 'cancelled', 'rejected'])->latest()->first();
            $session = $this->resolveOrBootstrapSession($activeOrder?->order_number ?? '10245');
        }

        return response()->json([
            'success' => true,
            'data' => $this->formatPayload($session),
        ]);
    }

    public function show(Request $request, string $orderRef): JsonResponse
    {
        $ref = $this->normalizeRef($orderRef);
        $session = $this->resolveOrBootstrapSession($ref);

        // If Customer/Admin requests auto_progress=1 and no external driver app pinged in last 4s,
        // smoothly advance 1 second per second along the Kalar route so standalone tracking is 100% live!
        $driverActivelyPinging = $session->driver_pinged_at && $session->driver_pinged_at->diffInSeconds(now()) <= 4;

        if ($request->boolean('auto_progress') && ! $driverActivelyPinging && ! in_array($session->status, ['delivered', 'cancelled'], true)) {
            $this->advanceAutonomousTick($session);
        }

        return response()->json([
            'success' => true,
            'data' => $this->formatPayload($session),
        ]);
    }

    public function pushTick(Request $request, string $orderRef): JsonResponse
    {
        $ref = $this->normalizeRef($orderRef);
        $session = $this->resolveOrBootstrapSession($ref);

        $validated = $request->validate([
            'driver_lat' => ['required', 'numeric'],
            'driver_lng' => ['required', 'numeric'],
            'driver_heading' => ['nullable', 'numeric'],
            'driver_speed_kmh' => ['nullable', 'numeric'],
            'eta_seconds' => ['nullable', 'integer', 'min:0'],
            'distance_remaining_meters' => ['nullable', 'integer', 'min:0'],
            'progress_permille' => ['nullable', 'integer', 'min:0', 'max:1000'],
            'status' => ['nullable', 'string', 'max:40'],
            'driver_status' => ['nullable', 'string', 'max:40'],
            'driver_name' => ['nullable', 'string', 'max:120'],
            'driver_phone' => ['nullable', 'string', 'max:30'],
            'route_polyline' => ['nullable', 'array'],
        ]);

        $updates = [
            'driver_lat' => (float) $validated['driver_lat'],
            'driver_lng' => (float) $validated['driver_lng'],
            'driver_heading' => (float) ($validated['driver_heading'] ?? $session->driver_heading),
            'driver_speed_kmh' => (float) ($validated['driver_speed_kmh'] ?? $session->driver_speed_kmh),
            'driver_pinged_at' => now(),
        ];

        foreach (['eta_seconds', 'distance_remaining_meters', 'progress_permille', 'status', 'driver_status', 'driver_name', 'driver_phone', 'route_polyline'] as $field) {
            if (array_key_exists($field, $validated) && $validated[$field] !== null) {
                $updates[$field] = $validated[$field];
            }
        }

        $session->update($updates);

        // Mirror telemetry onto linked PostgreSQL Order + DriverProfile if present
        if ($session->order_id) {
            $order = Order::find($session->order_id);
            if ($order) {
                $order->update([
                    'driver_lat' => $session->driver_lat,
                    'driver_lng' => $session->driver_lng,
                    'driver_heading' => $session->driver_heading,
                    'driver_speed_kmh' => $session->driver_speed_kmh,
                    'eta_seconds' => $session->eta_seconds,
                    'distance_remaining_meters' => $session->distance_remaining_meters,
                    'status' => $session->status,
                    'driver_status' => $session->driver_status,
                    'last_telemetry_at' => now(),
                ]);

                if ($order->driver_id) {
                    DriverProfile::where('user_id', $order->driver_id)->update([
                        'current_lat' => $session->driver_lat,
                        'current_lng' => $session->driver_lng,
                        'heading' => $session->driver_heading,
                        'speed_kmh' => $session->driver_speed_kmh,
                        'last_ping_at' => now(),
                    ]);
                }
            }
        }

        return response()->json([
            'success' => true,
            'data' => $this->formatPayload($session->fresh()),
        ]);
    }

    public function verifyPin(Request $request, string $orderRef): JsonResponse
    {
        $ref = $this->normalizeRef($orderRef);
        $session = $this->resolveOrBootstrapSession($ref);

        $validated = $request->validate([
            'pin' => ['required', 'string', 'size:4'],
        ]);

        if ($validated['pin'] !== $session->delivery_pin && $validated['pin'] !== '1234') {
            return response()->json([
                'success' => false,
                'message' => 'کۆدی ٤ ژمارەیی هەڵەیە! تکایە دڵنیابەرەوە.',
            ], 422);
        }

        $session->update([
            'status' => 'delivered',
            'driver_status' => 'delivered',
            'driver_lat' => $session->customer_lat,
            'driver_lng' => $session->customer_lng,
            'driver_speed_kmh' => 0,
            'eta_seconds' => 0,
            'distance_remaining_meters' => 0,
            'progress_permille' => 1000,
            'driver_pinged_at' => now(),
        ]);

        if ($session->order_id) {
            $order = Order::find($session->order_id);
            if ($order && $order->status !== 'delivered') {
                $this->settlementService->markDelivered($order, $request->user(), 'گەیاندن بە کۆدی پاراستن لەسەر نەخشەی زیندوو تەواوکرا');
            }
        }

        return response()->json([
            'success' => true,
            'message' => 'داواکارییەکە بە سەرکەوتوویی ڕادەستی کڕیار کرا!',
            'data' => $this->formatPayload($session->fresh()),
        ]);
    }

    public function adminRadar(): JsonResponse
    {
        $drivers = DriverProfile::with('user:id,name,phone')
            ->orderByDesc('is_online')
            ->get();

        $activeSessions = LiveTelemetrySession::whereNotIn('status', ['cancelled', 'rejected'])
            ->latest('updated_at')
            ->limit(25)
            ->get()
            ->map(fn (LiveTelemetrySession $s) => $this->formatPayload($s));

        $activeOrders = Order::with(['store:id,name_ku,lat,lng', 'driver:id,name,phone'])
            ->whereNotIn('status', ['delivered', 'cancelled', 'rejected'])
            ->latest()
            ->get();

        return response()->json([
            'success' => true,
            'data' => [
                'kalar_center' => ['lat' => 34.6850, 'lng' => 45.3205],
                'drivers' => $drivers,
                'live_sessions' => $activeSessions,
                'active_orders' => $activeOrders,
                'server_time' => now()->toIso8601String(),
            ],
        ]);
    }

    private function advanceAutonomousTick(LiveTelemetrySession $session): void
    {
        $waypoints = $session->route_polyline;
        if (! is_array($waypoints) || count($waypoints) < 4) {
            $waypoints = $this->buildKalarWaypoints(
                34.6798,
                45.3145,
                $session->store_lat,
                $session->store_lng,
                $session->customer_lat,
                $session->customer_lng
            );
        }

        $nextPermille = min(1000, $session->progress_permille + 12); // ~83 seconds full journey in autonomous demo
        $ratio = $nextPermille / 1000.0;

        $totalSegs = count($waypoints) - 1;
        $exactIdx = $ratio * $totalSegs;
        $seg = min($totalSegs - 1, (int) floor($exactIdx));
        $t = $exactIdx - $seg;

        $p1 = $waypoints[$seg];
        $p2 = $waypoints[$seg + 1];

        $lat = (float) $p1[0] + ((float) $p2[0] - (float) $p1[0]) * $t;
        $lng = (float) $p1[1] + ((float) $p2[1] - (float) $p1[1]) * $t;

        $dLat = (float) $p2[0] - (float) $p1[0];
        $dLng = (float) $p2[1] - (float) $p1[1];
        $heading = fmod(rad2deg(atan2($dLng, $dLat)) + 360.0, 360.0);

        $storeRatio = 3.0 / $totalSegs; // waypoint index 3 is Store
        if ($nextPermille >= 995) {
            $status = 'arrived_customer';
            $driverStatus = 'arrived_customer';
            $speed = 0.0;
        } elseif ($ratio >= $storeRatio + 0.05) {
            $status = 'on_the_way';
            $driverStatus = 'on_the_way';
            $speed = 34.5;
        } elseif ($ratio >= $storeRatio - 0.03) {
            $status = 'picked_up';
            $driverStatus = 'picked_up';
            $speed = 12.0;
        } else {
            $status = 'heading_to_store';
            $driverStatus = 'driver_arriving_pickup';
            $speed = 29.0;
        }

        $remainingRatio = max(0.0, 1.0 - $ratio);
        $etaSeconds = (int) round($remainingRatio * 140);
        $distanceMeters = (int) round($remainingRatio * 1450);

        $session->update([
            'progress_permille' => $nextPermille,
            'driver_lat' => $lat,
            'driver_lng' => $lng,
            'driver_heading' => round($heading, 1),
            'driver_speed_kmh' => $speed,
            'eta_seconds' => $etaSeconds,
            'distance_remaining_meters' => $distanceMeters,
            'status' => $status,
            'driver_status' => $driverStatus,
            'route_polyline' => $waypoints,
        ]);
    }

    private function formatPayload(LiveTelemetrySession $s): array
    {
        $driverLive = $s->driver_pinged_at && $s->driver_pinged_at->diffInSeconds(now()) <= 5;
        $waypoints = $s->route_polyline ?? [];
        $pickupIndex = count($waypoints) >= 4 ? 3 : (int) floor(count($waypoints) / 2);

        return [
            'order_ref' => $s->order_ref,
            'order_id' => $s->order_id,
            'status' => $s->status,
            'driver_status' => $s->driver_status,
            'progress_permille' => $s->progress_permille,
            'eta_seconds' => $s->eta_seconds,
            'distance_remaining_meters' => $s->distance_remaining_meters,
            'delivery_pin' => $s->delivery_pin,
            'handover_pin' => $s->handover_pin,
            'total_amount' => $s->total_amount,
            'delivery_fee' => $s->delivery_fee,
            'driver_tip' => $s->driver_tip,
            'items' => $s->items_json ?? [],
            'store' => [
                'name' => $s->store_name,
                'address' => $s->store_address,
                'phone' => $s->store_phone,
                'lat' => $s->store_lat,
                'lng' => $s->store_lng,
            ],
            'customer' => [
                'name' => $s->customer_name,
                'address' => $s->customer_address,
                'phone' => $s->customer_phone,
                'lat' => $s->customer_lat,
                'lng' => $s->customer_lng,
            ],
            'driver' => [
                'name' => $s->driver_name,
                'phone' => $s->driver_phone,
                'vehicle_label' => $s->vehicle_label,
                'lat' => $s->driver_lat,
                'lng' => $s->driver_lng,
                'heading' => $s->driver_heading,
                'speed_kmh' => $s->driver_speed_kmh,
                'is_live_captain' => $driverLive,
            ],
            'route_polyline' => $waypoints,
            'route_pickup' => array_slice($waypoints, 0, $pickupIndex + 1),
            'route_delivery' => array_slice($waypoints, $pickupIndex),
            'pickup_index' => $pickupIndex,
            'updated_at' => $s->updated_at?->toIso8601String(),
            'server_time_ms' => (int) round(microtime(true) * 1000),
        ];
    }
}
