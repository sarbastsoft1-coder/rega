<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class Coupon extends Model
{
    protected $fillable = [
        'code',
        'store_id',
        'title_ku',
        'title_ar',
        'title_en',
        'discount_type',
        'discount_value',
        'min_order_amount',
        'max_discount_amount',
        'usage_limit',
        'used_count',
        'starts_at',
        'expires_at',
        'is_active',
    ];

    protected function casts(): array
    {
        return [
            'discount_value' => 'integer',
            'min_order_amount' => 'integer',
            'max_discount_amount' => 'integer',
            'usage_limit' => 'integer',
            'used_count' => 'integer',
            'starts_at' => 'datetime',
            'expires_at' => 'datetime',
            'is_active' => 'boolean',
        ];
    }

    public function store(): BelongsTo
    {
        return $this->belongsTo(Store::class);
    }

    public function calculateDiscount(int $subtotal, int $deliveryFee): int
    {
        if (! $this->is_active) {
            return 0;
        }
        if ($this->starts_at && now()->lt($this->starts_at)) {
            return 0;
        }
        if ($this->expires_at && now()->gt($this->expires_at)) {
            return 0;
        }
        if ($this->usage_limit !== null && $this->used_count >= $this->usage_limit) {
            return 0;
        }
        if ($subtotal < $this->min_order_amount) {
            return 0;
        }

        $discount = match ($this->discount_type) {
            'percentage' => (int) round($subtotal * ($this->discount_value / 100)),
            'free_delivery' => $deliveryFee,
            default => (int) $this->discount_value,
        };

        if ($this->max_discount_amount !== null && $discount > $this->max_discount_amount) {
            $discount = $this->max_discount_amount;
        }

        return min($discount, $subtotal + $deliveryFee);
    }
}

