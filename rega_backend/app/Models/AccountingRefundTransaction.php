<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class AccountingRefundTransaction extends Model
{
    protected $fillable = [
        'order_id',
        'order_item_id',
        'quantity',
        'refunded_sales',
        'refunded_cost',
        'refunded_gross_profit',
        'refunded_admin_share',
        'refunded_seller_share',
        'reason',
        'processed_by',
    ];

    protected function casts(): array
    {
        return [
            'quantity' => 'integer',
            'refunded_sales' => 'integer',
            'refunded_cost' => 'integer',
            'refunded_gross_profit' => 'integer',
            'refunded_admin_share' => 'integer',
            'refunded_seller_share' => 'integer',
        ];
    }

    public function order(): BelongsTo
    {
        return $this->belongsTo(Order::class);
    }

    public function orderItem(): BelongsTo
    {
        return $this->belongsTo(OrderItem::class);
    }

    public function processor(): BelongsTo
    {
        return $this->belongsTo(User::class, 'processed_by');
    }
}
