<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class DriverProfile extends Model
{
    protected $fillable = [
        'user_id',
        'driver_code',
        'is_verified',
        'is_online',
        'current_lat',
        'current_lng',
        'heading',
        'speed_kmh',
        'last_ping_at',
        'motor_type',
        'plate_number',
        'model_year',
        'motor_color',
        'is_vehicle_verified',
        'completion_rate',
        'total_deliveries',
        'rating',
        'online_hours_total',
        'wallet_balance',
        'cash_collected_hand',
        'online_since',
    ];

    protected function casts(): array
    {
        return [
            'is_verified' => 'boolean',
            'is_online' => 'boolean',
            'current_lat' => 'float',
            'current_lng' => 'float',
            'heading' => 'float',
            'speed_kmh' => 'float',
            'last_ping_at' => 'datetime',
            'is_vehicle_verified' => 'boolean',
            'completion_rate' => 'float',
            'total_deliveries' => 'integer',
            'rating' => 'float',
            'online_hours_total' => 'float',
            'wallet_balance' => 'integer',
            'cash_collected_hand' => 'integer',
            'online_since' => 'datetime',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function documents(): HasMany
    {
        return $this->hasMany(DriverDocument::class);
    }
}

