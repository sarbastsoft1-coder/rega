<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class AdminProfitSettingsHistory extends Model
{
    protected $table = 'admin_profit_settings_history';

    protected $fillable = [
        'commission_percentage',
        'changed_by',
        'note',
    ];

    protected function casts(): array
    {
        return [
            'commission_percentage' => 'float',
        ];
    }

    public function changer(): BelongsTo
    {
        return $this->belongsTo(User::class, 'changed_by');
    }
}
