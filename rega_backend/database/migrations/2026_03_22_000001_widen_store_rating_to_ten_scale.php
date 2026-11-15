<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // ڕێژەی ئەستێرە لە ١٠ (پێشتر لە ٥ بوو) — هەموو نمرەکان ×٢
        if (Schema::hasTable('stores')) {
            DB::statement('ALTER TABLE stores ALTER COLUMN rating TYPE DECIMAL(4, 2)');
            DB::statement('UPDATE stores SET rating = LEAST(10, ROUND(rating * 2, 2)) WHERE rating <= 5.01');
        }
    }

    public function down(): void
    {
        if (Schema::hasTable('stores')) {
            DB::statement('UPDATE stores SET rating = ROUND(rating / 2, 2) WHERE rating > 5');
            DB::statement('ALTER TABLE stores ALTER COLUMN rating TYPE DECIMAL(3, 2)');
        }
    }
};
