<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class PlatformSetting extends Model
{
    protected $fillable = [
        'key',
        'group',
        'value',
        'description',
    ];

    protected function casts(): array
    {
        return [
            'value' => 'json',
        ];
    }

    public static function getValue(string $key, mixed $default = null): mixed
    {
        $record = static::query()->where('key', $key)->first();
        if (! $record) {
            return $default;
        }
        $val = $record->value;
        if (is_array($val) && array_key_exists('val', $val) && count($val) === 1) {
            return $val['val'];
        }
        return $val;
    }

    public static function setValue(string $key, mixed $value, string $group = 'general', ?string $description = null): self
    {
        $stored = is_array($value) ? $value : ['val' => $value];
        return static::query()->updateOrCreate(
            ['key' => $key],
            array_filter([
                'group' => $group,
                'value' => $stored,
                'description' => $description,
            ], fn ($v) => $v !== null)
        );
    }
}

