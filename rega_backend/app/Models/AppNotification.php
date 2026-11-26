<?php

namespace App\Models;

use App\Services\FcmPushService;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class AppNotification extends Model
{
    protected $fillable = [
        'campaign_id',
        'user_id',
        'target_audience',
        'title_ku',
        'title_ar',
        'title_en',
        'body_ku',
        'body_ar',
        'body_en',
        'tag',
        'type',
        'store_id',
        'category_name',
        'discount_badge',
        'is_read',
    ];

    protected function casts(): array
    {
        return [
            'is_read' => 'boolean',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function store(): BelongsTo
    {
        return $this->belongsTo(Store::class);
    }

    /**
     * Persist inbox row and fan-out FCM to the target user
     * (customer / vendor / driver lock-screen push).
     *
     * @param  array<string, mixed>  $extraData  Extra FCM data keys (e.g. order_number).
     */
    public static function createAndPush(array $attributes, array $extraData = []): self
    {
        $notification = static::create($attributes);
        if ($notification->user_id) {
            try {
                app(FcmPushService::class)->sendForNotification(
                    $notification,
                    [$notification->user_id],
                    $extraData,
                );
            } catch (\Throwable $e) {
                report($e);
            }
        }

        return $notification;
    }
}

