<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        $now = now();
        $rows = [
            [
                'key' => 'service_radius_km',
                'group' => 'public',
                'value' => json_encode(['val' => 10]),
                'description' => 'Service area radius in km from Kalar center (5/10/15/20)',
            ],
            [
                'key' => 'service_center_lat',
                'group' => 'public',
                'value' => json_encode(['val' => 34.6295]),
                'description' => 'Service area center latitude (Kalar)',
            ],
            [
                'key' => 'service_center_lng',
                'group' => 'public',
                'value' => json_encode(['val' => 45.3159]),
                'description' => 'Service area center longitude (Kalar)',
            ],
            [
                'key' => 'service_area_name',
                'group' => 'public',
                'value' => json_encode(['val' => 'کەلار']),
                'description' => 'Human-readable service area name',
            ],
        ];

        foreach ($rows as $row) {
            $exists = DB::table('platform_settings')->where('key', $row['key'])->exists();
            if ($exists) {
                continue;
            }
            DB::table('platform_settings')->insert([
                'key' => $row['key'],
                'group' => $row['group'],
                'value' => $row['value'],
                'description' => $row['description'],
                'created_at' => $now,
                'updated_at' => $now,
            ]);
        }
    }

    public function down(): void
    {
        DB::table('platform_settings')->whereIn('key', [
            'service_radius_km',
            'service_center_lat',
            'service_center_lng',
            'service_area_name',
        ])->delete();
    }
};
