<?php

namespace App\Services;

use App\Models\Order;
use Illuminate\Support\Carbon;
use Illuminate\Support\Collection;

/**
 * Per-driver workload helpers (today order counts).
 */
class DriverWorkloadService
{
    /**
     * Delivered orders today keyed by driver user_id.
     *
     * @return Collection<int, int>
     */
    public function todayDeliveredCounts(?Carbon $day = null): Collection
    {
        $day = $day ?? Carbon::today();

        return Order::query()
            ->whereNotNull('driver_id')
            ->where('status', 'delivered')
            ->whereDate('delivered_at', $day)
            ->selectRaw('driver_id, COUNT(*) as c')
            ->groupBy('driver_id')
            ->pluck('c', 'driver_id')
            ->map(fn ($c) => (int) $c);
    }

    /**
     * Active/assigned orders today keyed by driver user_id
     * (assigned today, not cancelled/rejected).
     *
     * @return Collection<int, int>
     */
    public function todayAssignedCounts(?Carbon $day = null): Collection
    {
        $day = $day ?? Carbon::today();

        return Order::query()
            ->whereNotNull('driver_id')
            ->whereNotIn('status', ['cancelled', 'rejected'])
            ->where(function ($q) use ($day) {
                $q->whereDate('driver_assigned_at', $day)
                    ->orWhere(function ($qq) use ($day) {
                        $qq->whereNull('driver_assigned_at')->whereDate('created_at', $day);
                    });
            })
            ->selectRaw('driver_id, COUNT(*) as c')
            ->groupBy('driver_id')
            ->pluck('c', 'driver_id')
            ->map(fn ($c) => (int) $c);
    }
}
