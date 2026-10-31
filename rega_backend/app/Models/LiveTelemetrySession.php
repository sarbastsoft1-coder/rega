<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class LiveTelemetrySession extends Model
{
    protected $fillable = [
        'order_ref',
        'order_id',
        'status',
        'driver_status',
        'store_name',
        'store_address',
        'store_phone',
        'store_lat',
        'store_lng',
        'customer_name',
        'customer_address',
        'customer_phone',
        'customer_lat',
        'customer_lng',
        'driver_name',
        'driver_phone',
        'vehicle_label',
        'driver_lat',
        'driver_lng',
        'driver_heading',
        'driver_speed_kmh',
        'eta_seconds',
        'distance_remaining_meters',
        'progress_permille',
        'delivery_pin',
        'handover_pin',
        'total_amount',
        'delivery_fee',
        'driver_tip',
        'items_json',
        'route_polyline',
        'driver_pinged_at',
    ];

    protected function casts(): array
    {
        return [
            'store_lat' => 'float',
            'store_lng' => 'float',
            'customer_lat' => 'float',
            'customer_lng' => 'float',
            'driver_lat' => 'float',
            'driver_lng' => 'float',
            'driver_heading' => 'float',
            'driver_speed_kmh' => 'float',
            'eta_seconds' => 'integer',
            'distance_remaining_meters' => 'integer',
            'progress_permille' => 'integer',
            'total_amount' => 'integer',
            'delivery_fee' => 'integer',
            'driver_tip' => 'integer',
            'items_json' => 'array',
            'route_polyline' => 'array',
            'driver_pinged_at' => 'datetime',
        ];
    }

    public function order(): BelongsTo
    {
        return $this->belongsTo(Order::class);
    }
}

