<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Order extends Model
{
    protected $fillable = [
        'order_number',
        'customer_id',
        'store_id',
        'driver_id',
        'neighborhood_id',
        'coupon_id',
        'status',
        'vendor_status',
        'driver_status',
        'handover_pin',
        'delivery_pin',
        'subtotal',
        'total_product_cost',
        'total_gross_profit',
        'discount_amount',
        'delivery_fee',
        'driver_tip',
        'waiting_bonus',
        'total_amount',
        'commission_rate',
        'profit_commission_rate',
        'commission_amount',
        'admin_profit_amount',
        'seller_profit_amount',
        'refunded_amount',
        'is_profit_realized',
        'vendor_net_amount',
        'driver_total_earning',
        'payment_method',
        'payment_status',
        'customer_name',
        'customer_phone',
        'delivery_address',
        'delivery_lat',
        'delivery_lng',
        'driver_lat',
        'driver_lng',
        'driver_heading',
        'driver_speed_kmh',
        'eta_seconds',
        'distance_remaining_meters',
        'route_polyline',
        'last_telemetry_at',
        'customer_notes',
        'cancellation_reason',
        'cancelled_by',
        'accepted_at',
        'ready_at',
        'driver_assigned_at',
        'arrived_pickup_at',
        'picked_up_at',
        'arrived_customer_at',
        'delivered_at',
        'cancelled_at',
    ];

    protected function casts(): array
    {
        return [
            'subtotal' => 'integer',
            'total_product_cost' => 'integer',
            'total_gross_profit' => 'integer',
            'discount_amount' => 'integer',
            'delivery_fee' => 'integer',
            'driver_tip' => 'integer',
            'waiting_bonus' => 'integer',
            'total_amount' => 'integer',
            'commission_rate' => 'float',
            'profit_commission_rate' => 'float',
            'commission_amount' => 'integer',
            'admin_profit_amount' => 'integer',
            'seller_profit_amount' => 'integer',
            'refunded_amount' => 'integer',
            'is_profit_realized' => 'boolean',
            'vendor_net_amount' => 'integer',
            'driver_total_earning' => 'integer',
            'delivery_lat' => 'float',
            'delivery_lng' => 'float',
            'driver_lat' => 'float',
            'driver_lng' => 'float',
            'driver_heading' => 'float',
            'driver_speed_kmh' => 'float',
            'eta_seconds' => 'integer',
            'distance_remaining_meters' => 'integer',
            'route_polyline' => 'array',
            'last_telemetry_at' => 'datetime',
            'accepted_at' => 'datetime',
            'ready_at' => 'datetime',
            'driver_assigned_at' => 'datetime',
            'arrived_pickup_at' => 'datetime',
            'picked_up_at' => 'datetime',
            'arrived_customer_at' => 'datetime',
            'delivered_at' => 'datetime',
            'cancelled_at' => 'datetime',
        ];
    }

    public function customer(): BelongsTo
    {
        return $this->belongsTo(User::class, 'customer_id');
    }

    public function store(): BelongsTo
    {
        return $this->belongsTo(Store::class);
    }

    public function driver(): BelongsTo
    {
        return $this->belongsTo(User::class, 'driver_id');
    }

    public function neighborhood(): BelongsTo
    {
        return $this->belongsTo(Neighborhood::class);
    }

    public function coupon(): BelongsTo
    {
        return $this->belongsTo(Coupon::class);
    }

    public function items(): HasMany
    {
        return $this->hasMany(OrderItem::class);
    }

    public function statusLogs(): HasMany
    {
        return $this->hasMany(OrderStatusLog::class)->orderBy('created_at');
    }

    public function refundTransactions(): HasMany
    {
        return $this->hasMany(AccountingRefundTransaction::class)->latest();
    }
}

