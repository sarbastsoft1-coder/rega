<?php

namespace App\Services;

use App\Models\AccountingRefundTransaction;
use App\Models\Order;
use App\Models\OrderItem;
use App\Models\PlatformSetting;
use App\Models\Product;
use App\Models\User;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

/**
 * Profit-share accounting: commission is taken from product gross profit
 * (selling_price - cost_price), not from full selling price.
 */
class OrderProfitService
{
    public const SETTINGS_KEY = 'admin_profit_commission_rate';

    public function globalCommissionPercentage(): float
    {
        $raw = PlatformSetting::getValue(self::SETTINGS_KEY, 20);

        return max(0.0, min(100.0, (float) $raw));
    }

    /**
     * Pure calculator used by tests and validation.
     *
     * @return array{gross_profit:int,admin_share:int,seller_share:int}
     */
    public function calculateShares(int $costPrice, int $sellingPrice, float $commissionPercent, int $quantity = 1): array
    {
        $qty = max(1, $quantity);
        $cost = max(0, $costPrice);
        $sell = max(0, $sellingPrice);
        if ($cost > $sell) {
            $cost = $sell;
        }
        $rate = max(0.0, min(100.0, $commissionPercent));
        $unitGross = max(0, $sell - $cost);
        $gross = $unitGross * $qty;
        $admin = (int) round($gross * ($rate / 100));
        $seller = max(0, $gross - $admin);

        return [
            'gross_profit' => $gross,
            'admin_share' => $admin,
            'seller_share' => $seller,
        ];
    }

    /**
     * Build immutable line snapshot + rolling totals.
     *
     * @return array{item: array<string, mixed>, totals: array<string, int|float>}
     */
    public function buildLineSnapshot(Product $product, int $quantity, ?float $commissionPercent = null): array
    {
        $qty = max(1, $quantity);
        $unitPrice = $product->effectivePrice();
        $unitCost = max(0, (int) ($product->cost_price ?? 0));
        if ($unitCost > $unitPrice) {
            // Cap cost at selling price so profit never goes negative from bad data.
            $unitCost = $unitPrice;
        }

        $rate = $commissionPercent ?? $this->globalCommissionPercentage();
        $rate = max(0.0, min(100.0, (float) $rate));

        $lineTotal = $unitPrice * $qty;
        $lineCost = $unitCost * $qty;
        $unitGross = max(0, $unitPrice - $unitCost);
        $lineGross = $unitGross * $qty;
        $adminShare = (int) round($lineGross * ($rate / 100));
        $sellerShare = max(0, $lineGross - $adminShare);

        return [
            'item' => [
                'product_id' => $product->id,
                'product_name' => $product->name_ku,
                'product_image' => $product->image_url,
                'unit_price' => $unitPrice,
                'unit_cost' => $unitCost,
                'quantity' => $qty,
                'line_total' => $lineTotal,
                'line_cost' => $lineCost,
                'unit_gross_profit' => $unitGross,
                'line_gross_profit' => $lineGross,
                'commission_rate' => $rate,
                'admin_share' => $adminShare,
                'seller_share' => $sellerShare,
            ],
            'totals' => [
                'line_total' => $lineTotal,
                'line_cost' => $lineCost,
                'line_gross' => $lineGross,
                'admin_share' => $adminShare,
                'seller_share' => $sellerShare,
                'commission_rate' => $rate,
            ],
        ];
    }

    /**
     * Aggregate order-level financial fields from prepared item rows.
     *
     * @param  array<int, array<string, mixed>>  $preparedItems
     * @return array<string, int|float>
     */
    public function aggregateOrderFinancials(array $preparedItems, ?float $commissionPercent = null): array
    {
        $rate = $commissionPercent ?? $this->globalCommissionPercentage();
        $subtotal = 0;
        $totalCost = 0;
        $totalGross = 0;
        $adminProfit = 0;
        $sellerProfit = 0;

        foreach ($preparedItems as $row) {
            $subtotal += (int) ($row['line_total'] ?? 0);
            $totalCost += (int) ($row['line_cost'] ?? 0);
            $totalGross += (int) ($row['line_gross_profit'] ?? 0);
            $adminProfit += (int) ($row['admin_share'] ?? 0);
            $sellerProfit += (int) ($row['seller_share'] ?? 0);
        }

        // Seller wallet credit = recover cost + seller profit share = sales - admin share.
        $vendorNet = max(0, $subtotal - $adminProfit);

        return [
            'subtotal' => $subtotal,
            'total_product_cost' => $totalCost,
            'total_gross_profit' => $totalGross,
            'profit_commission_rate' => $rate,
            // Keep legacy commission_* aligned with profit-share admin cut for delivered reporting.
            'commission_rate' => $rate,
            'commission_amount' => $adminProfit,
            'admin_profit_amount' => $adminProfit,
            'seller_profit_amount' => $sellerProfit,
            'vendor_net_amount' => $vendorNet,
        ];
    }

    /**
     * Process full or partial refund. Never deletes financial snapshots.
     *
     * @return array<string, mixed>
     */
    public function processRefund(
        Order $order,
        ?User $actor = null,
        ?int $orderItemId = null,
        ?int $quantity = null,
        bool $full = false,
        ?string $reason = null,
    ): array {
        return DB::transaction(function () use ($order, $actor, $orderItemId, $quantity, $full, $reason) {
            /** @var Order $locked */
            $locked = Order::query()->with('items')->lockForUpdate()->findOrFail($order->id);

            if (in_array($locked->status, ['cancelled', 'rejected'], true) && ! $locked->is_profit_realized) {
                throw ValidationException::withMessages([
                    'order' => ['داواکاری هەڵوەشاوە و قازانجی بەدەست‌نەهاتووە.'],
                ]);
            }

            $items = $locked->items;
            if ($orderItemId) {
                $items = $items->where('id', $orderItemId)->values();
                if ($items->isEmpty()) {
                    throw ValidationException::withMessages(['order_item_id' => ['بەرهەم لەم داواکارییەدا نییە.']]);
                }
            }

            $refundedSales = 0;
            $refundedCost = 0;
            $refundedGross = 0;
            $refundedAdmin = 0;
            $refundedSeller = 0;
            $created = [];

            foreach ($items as $item) {
                /** @var OrderItem $item */
                $alreadyQty = (int) AccountingRefundTransaction::query()
                    ->where('order_item_id', $item->id)
                    ->sum('quantity');

                $remainingQty = max(0, (int) $item->quantity - $alreadyQty);
                if ($remainingQty <= 0) {
                    continue;
                }

                $qty = $full || $orderItemId === null
                    ? $remainingQty
                    : min($remainingQty, max(1, (int) ($quantity ?? $remainingQty)));

                $unitSales = (int) $item->unit_price;
                $unitCost = (int) $item->unit_cost;
                $unitGross = (int) $item->unit_gross_profit;
                $rate = (float) $item->commission_rate;

                $lineSales = $unitSales * $qty;
                $lineCost = $unitCost * $qty;
                $lineGross = $unitGross * $qty;
                $lineAdmin = (int) round($lineGross * ($rate / 100));
                $lineSeller = max(0, $lineGross - $lineAdmin);

                $tx = AccountingRefundTransaction::create([
                    'order_id' => $locked->id,
                    'order_item_id' => $item->id,
                    'quantity' => $qty,
                    'refunded_sales' => $lineSales,
                    'refunded_cost' => $lineCost,
                    'refunded_gross_profit' => $lineGross,
                    'refunded_admin_share' => $lineAdmin,
                    'refunded_seller_share' => $lineSeller,
                    'reason' => $reason,
                    'processed_by' => $actor?->id,
                ]);

                $created[] = $tx;
                $refundedSales += $lineSales;
                $refundedCost += $lineCost;
                $refundedGross += $lineGross;
                $refundedAdmin += $lineAdmin;
                $refundedSeller += $lineSeller;
            }

            if ($refundedSales <= 0) {
                throw ValidationException::withMessages([
                    'order' => ['هیچ بڕێکی گەڕاندنەوە ماوە نییە.'],
                ]);
            }

            // Reverse realized profit amounts on the order (keep original snapshots on items).
            $locked->admin_profit_amount = max(0, (int) $locked->admin_profit_amount - $refundedAdmin);
            $locked->seller_profit_amount = max(0, (int) $locked->seller_profit_amount - $refundedSeller);
            $locked->total_gross_profit = max(0, (int) $locked->total_gross_profit - $refundedGross);
            $locked->total_product_cost = max(0, (int) $locked->total_product_cost - $refundedCost);
            $locked->commission_amount = (int) $locked->admin_profit_amount;
            $locked->vendor_net_amount = max(0, (int) $locked->subtotal - (int) $locked->admin_profit_amount - (int) $locked->refunded_amount - $refundedSales);
            // Simpler vendor net after refunds: remaining sales - remaining admin share.
            $remainingSales = max(0, (int) $locked->subtotal - ((int) $locked->refunded_amount + $refundedSales));
            $locked->vendor_net_amount = max(0, $remainingSales - (int) $locked->admin_profit_amount);
            $locked->refunded_amount = (int) $locked->refunded_amount + $refundedSales;
            $locked->payment_status = $locked->refunded_amount >= (int) $locked->subtotal ? 'refunded' : $locked->payment_status;

            // If fully refunded after delivery, claw back seller wallet credit for refunded portion.
            if ($locked->is_profit_realized && $locked->store_id) {
                $clawback = $refundedSales - $refundedAdmin; // seller portion of refunded sales (= cost+seller share)
                if ($clawback > 0 && $locked->store) {
                    $locked->store->decrement('wallet_balance', min((int) $locked->store->wallet_balance, $clawback));
                }
            }

            if ($locked->refunded_amount >= (int) $locked->subtotal) {
                $locked->is_profit_realized = false;
            }

            $locked->save();

            return [
                'order' => $locked->fresh(['items', 'refundTransactions']),
                'refund_transactions' => $created,
                'refunded' => [
                    'sales' => $refundedSales,
                    'cost' => $refundedCost,
                    'gross_profit' => $refundedGross,
                    'admin_share' => $refundedAdmin,
                    'seller_share' => $refundedSeller,
                ],
            ];
        });
    }

    public function markNotRealizedOnCancel(Order $order): void
    {
        $order->update(['is_profit_realized' => false]);
    }
}
