<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        $realCoords = [
            'n1' => ['lat' => 34.6250, 'lng' => 45.2760],
            'n2' => ['lat' => 34.6485, 'lng' => 45.3295],
            'n3' => ['lat' => 34.6345, 'lng' => 45.3185],
            'n4' => ['lat' => 34.6242, 'lng' => 45.3235],
            'n5' => ['lat' => 34.6312, 'lng' => 45.3088],
            'n6' => ['lat' => 34.6410, 'lng' => 45.3208],
            'n7' => ['lat' => 34.6265, 'lng' => 45.3122],
            'n8' => ['lat' => 34.6372, 'lng' => 45.3242],
            'n9' => ['lat' => 34.6295, 'lng' => 45.3159],
        ];

        foreach ($realCoords as $code => $coords) {
            DB::table('neighborhoods')
                ->where('code', $code)
                ->whereBetween('center_lat', [34.668, 34.710])
                ->update([
                    'center_lat' => $coords['lat'],
                    'center_lng' => $coords['lng'],
                    'updated_at' => now(),
                ]);
        }
    }

    public function down(): void
    {
        // Non-destructive data correction; no rollback needed.
    }
};
