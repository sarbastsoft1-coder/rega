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
     * Persist inbox row and fan-out FCM to the target user (customer lock-screen push).
     */
    public static function createAndPush(array $attributes): self
    {
        $notification = static::create($attributes);
        if ($notification->user_id) {
            try {
                app(FcmPushService::class)->sendForNotification(
                    $notification,
                    [$notification->user_id],
                );
            } catch (\Throwable $e) {
                report($e);
            }
        }

        return $notification;
    }
}

