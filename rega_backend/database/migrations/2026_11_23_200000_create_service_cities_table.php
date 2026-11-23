<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('service_cities', function (Blueprint $table) {
            $table->id();
            $table->string('code', 30)->unique();
            $table->string('name_ku');
            $table->string('name_ar')->nullable();
            $table->string('name_en')->nullable();
            $table->decimal('center_lat', 10, 7);
            $table->decimal('center_lng', 10, 7);
            $table->unsignedSmallInteger('radius_km')->default(10);
            $table->boolean('is_active')->default(true)->index();
            $table->integer('sort_order')->default(0);
            $table->timestamps();
        });

        $now = now();
        $kalarId = DB::table('service_cities')->insertGetId([
            'code' => 'kalar',
            'name_ku' => 'کەلار',
            'name_ar' => 'كلار',
            'name_en' => 'Kalar',
            'center_lat' => 34.6295,
            'center_lng' => 45.3159,
            'radius_km' => 10,
            'is_active' => true,
            'sort_order' => 1,
            'created_at' => $now,
            'updated_at' => $now,
        ]);

        DB::table('service_cities')->insert([
            'code' => 'hawler',
            'name_ku' => 'هەولێر',
            'name_ar' => 'أربيل',
            'name_en' => 'Hawler',
            'center_lat' => 36.1911,
            'center_lng' => 44.0093,
            'radius_km' => 15,
            'is_active' => true,
            'sort_order' => 2,
            'created_at' => $now,
            'updated_at' => $now,
        ]);

        Schema::table('neighborhoods', function (Blueprint $table) {
            $table->foreignId('service_city_id')
                ->nullable()
                ->after('id')
                ->constrained('service_cities')
                ->nullOnDelete();
        });

        Schema::table('stores', function (Blueprint $table) {
            $table->foreignId('service_city_id')
                ->nullable()
                ->after('neighborhood_id')
                ->constrained('service_cities')
                ->nullOnDelete();
        });

        DB::table('neighborhoods')->whereNull('service_city_id')->update([
            'service_city_id' => $kalarId,
        ]);

        // Backfill stores from their neighborhood city when possible.
        DB::statement('
            UPDATE stores s
            SET service_city_id = n.service_city_id
            FROM neighborhoods n
            WHERE s.neighborhood_id = n.id
              AND s.service_city_id IS NULL
              AND n.service_city_id IS NOT NULL
        ');

        DB::table('stores')->whereNull('service_city_id')->update([
            'service_city_id' => $kalarId,
        ]);
    }

    public function down(): void
    {
        Schema::table('stores', function (Blueprint $table) {
            $table->dropConstrainedForeignId('service_city_id');
        });
        Schema::table('neighborhoods', function (Blueprint $table) {
            $table->dropConstrainedForeignId('service_city_id');
        });
        Schema::dropIfExists('service_cities');
    }
};
