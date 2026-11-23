<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

class ServiceCity extends Model
{
    protected $fillable = [
        'code',
        'name_ku',
        'name_ar',
        'name_en',
        'center_lat',
        'center_lng',
        'radius_km',
        'is_active',
        'sort_order',
    ];

    protected function casts(): array
    {
        return [
            'center_lat' => 'float',
            'center_lng' => 'float',
            'radius_km' => 'integer',
            'is_active' => 'boolean',
            'sort_order' => 'integer',
        ];
    }

    public function neighborhoods(): HasMany
    {
        return $this->hasMany(Neighborhood::class);
    }

    public function stores(): HasMany
    {
        return $this->hasMany(Store::class);
    }
}
