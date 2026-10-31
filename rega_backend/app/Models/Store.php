<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Store extends Model
{
    protected $fillable = [
        'owner_id',
        'category_id',
        'neighborhood_id',
        'slug',
        'name_ku',
        'name_ar',
        'name_en',
        'phone',
        'address_ku',
        'address_ar',
        'address_en',
        'lat',
        'lng',
        'logo_url',
        'cover_url',
        'rating',
        'review_count',
        'delivery_time',
        'base_delivery_fee',
        'commission_rate',
        'discount_badge',
        'open_time',
        'close_time',
        'is_online',
        'is_approved',
        'is_featured',
        'wallet_balance',
    ];

    protected function casts(): array
    {
        return [
            'lat' => 'float',
            'lng' => 'float',
            'rating' => 'float',
            'review_count' => 'integer',
            'base_delivery_fee' => 'integer',
            'commission_rate' => 'float',
            'is_online' => 'boolean',
            'is_approved' => 'boolean',
            'is_featured' => 'boolean',
            'wallet_balance' => 'integer',
        ];
    }

    public function owner(): BelongsTo
    {
        return $this->belongsTo(User::class, 'owner_id');
    }

    public function category(): BelongsTo
    {
        return $this->belongsTo(Category::class);
    }

    public function neighborhood(): BelongsTo
    {
        return $this->belongsTo(Neighborhood::class);
    }

    public function storeCategories(): HasMany
    {
        return $this->hasMany(StoreCategory::class)->orderBy('sort_order');
    }

    public function products(): HasMany
    {
        return $this->hasMany(Product::class);
    }

    public function orders(): HasMany
    {
        return $this->hasMany(Order::class);
    }
}

