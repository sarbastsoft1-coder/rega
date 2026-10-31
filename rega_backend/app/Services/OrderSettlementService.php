<?php

namespace App\Services;

use App\Models\Order;
use App\Models\OrderStatusLog;
use App\Models\User;
use Illuminate\Support\Facades\DB;

class OrderSettlementService
{
    /**
     * Transition an order to delivered and atomically settle vendor/driver balances once.
     */
    public function markDelivered(Order $order, ?User $actor = null, ?string $note = null): Order
    {
        return DB::transaction(function () use ($order, $actor, $note) {
            /** @var Order $locked */
            $locked = Order::query()->with(['store', 'driver.driverProfile', 'items'])->lockForUpdate()->findOrFail($order->id);

            if ($locked->status === 'delivered') {
                return $locked;
            }

            $previousStatus = $locked->status;

            // Recompute driver total earning in case waiting_bonus or tip was updated
            $driverEarning = (int) $locked->delivery_fee + (int) $locked->driver_tip + (int) $locked->waiting_bonus;

            $locked->update([
                'status' => 'delivered',
                'vendor_status' => 'completed',
                'driver_status' => 'delivered',
                'driver_total_earning' => $driverEarning,
                'payment_status' => 'paid',
                'delivered_at' => now(),
            ]);

            // Credit store net profit (subtotal - commission)
            if ($locked->store) {
                $locked->store->increment('wallet_balance', (int) $locked->vendor_net_amount);
            }

            // Increment product sold counts
            foreach ($locked->items as $item) {
                if ($item->product_id) {
                    $item->product()->increment('sold_count', (int) $item->quantity);
                }
            }

            // Credit driver earnings & track COD cash on hand
            if ($locked->driver && $locked->driver->driverProfile) {
                $profile = $locked->driver->driverProfile;
                $profile->increment('wallet_balance', $driverEarning);
                $profile->increment('total_deliveries');

                if ($locked->payment_method === 'cash') {
                    $profile->increment('cash_collected_hand', (int) $locked->total_amount);
                }
            }

            OrderStatusLog::create([
                'order_id' => $locked->id,
                'from_status' => $previousStatus,
                'to_status' => 'delivered',
                'actor_id' => $actor?->id,
                'actor_role' => $actor?->role ?? 'system',
                'note' => $note ?? 'گەیاندن تەواوکرا و حسابەکان یەکلاکرانەوە',
            ]);

            return $locked->fresh(['items', 'store', 'customer', 'driver.driverProfile', 'neighborhood', 'statusLogs']);
        });
    }
}

