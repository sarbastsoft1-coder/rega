<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class Product extends Model
{
    protected $fillable = [
        'store_id',
        'store_category_id',
        'name_ku',
        'name_ar',
        'name_en',
        'description_ku',
        'description_ar',
        'description_en',
        'price',
        'discount_price',
        'image_url',
        'is_available',
        'is_featured',
        'sold_count',
    ];

    protected function casts(): array
    {
        return [
            'price' => 'integer',
            'discount_price' => 'integer',
            'is_available' => 'boolean',
            'is_featured' => 'boolean',
            'sold_count' => 'integer',
        ];
    }

    public function effectivePrice(): int
    {
        if ($this->discount_price !== null && $this->discount_price > 0 && $this->discount_price < $this->price) {
            return (int) $this->discount_price;
        }
        return (int) $this->price;
    }

    public function store(): BelongsTo
    {
        return $this->belongsTo(Store::class);
    }

    public function storeCategory(): BelongsTo
    {
        return $this->belongsTo(StoreCategory::class);
    }
}

