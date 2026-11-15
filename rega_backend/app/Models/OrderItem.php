<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class OrderItem extends Model
{
    protected $fillable = [
        'order_id',
        'product_id',
        'product_name',
        'product_image',
        'unit_price',
        'unit_cost',
        'quantity',
        'line_total',
        'line_cost',
        'unit_gross_profit',
        'line_gross_profit',
        'commission_rate',
        'admin_share',
        'seller_share',
        'special_notes',
    ];

    protected function casts(): array
    {
        return [
            'unit_price' => 'integer',
            'unit_cost' => 'integer',
            'quantity' => 'integer',
            'line_total' => 'integer',
            'line_cost' => 'integer',
            'unit_gross_profit' => 'integer',
            'line_gross_profit' => 'integer',
            'commission_rate' => 'float',
            'admin_share' => 'integer',
            'seller_share' => 'integer',
        ];
    }

    public function order(): BelongsTo
    {
        return $this->belongsTo(Order::class);
    }

    public function product(): BelongsTo
    {
        return $this->belongsTo(Product::class);
    }
}

