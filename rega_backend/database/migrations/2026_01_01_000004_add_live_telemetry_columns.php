<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('driver_profiles', function (Blueprint $table) {
            $table->decimal('heading', 6, 2)->default(0)->after('current_lng');
            $table->decimal('speed_kmh', 5, 1)->default(0)->after('heading');
            $table->timestamp('last_ping_at')->nullable()->after('speed_kmh');
        });

        Schema::table('orders', function (Blueprint $table) {
            $table->decimal('driver_lat', 10, 7)->nullable()->after('delivery_lng');
            $table->decimal('driver_lng', 10, 7)->nullable()->after('driver_lat');
            $table->decimal('driver_heading', 6, 2)->default(0)->after('driver_lng');
            $table->decimal('driver_speed_kmh', 5, 1)->default(0)->after('driver_heading');
            $table->integer('eta_seconds')->nullable()->after('driver_speed_kmh');
            $table->integer('distance_remaining_meters')->nullable()->after('eta_seconds');
            $table->jsonb('route_polyline')->nullable()->after('distance_remaining_meters');
            $table->timestamp('last_telemetry_at')->nullable()->after('route_polyline');
        });

        Schema::create('live_telemetry_sessions', function (Blueprint $table) {
            $table->id();
            $table->string('order_ref', 40)->unique();
            $table->foreignId('order_id')->nullable()->constrained('orders')->nullOnDelete();
            $table->string('status', 40)->default('preparing');
            $table->string('driver_status', 40)->default('driver_arriving_pickup');
            $table->string('store_name')->default('کەبابخانەی کەلار');
            $table->string('store_address')->nullable();
            $table->string('store_phone', 30)->nullable();
            $table->decimal('store_lat', 10, 7)->default(34.6836000);
            $table->decimal('store_lng', 10, 7)->default(45.3189000);
            $table->string('customer_name')->default('سەربەست عەلی');
            $table->string('customer_address')->nullable();
            $table->string('customer_phone', 30)->nullable();
            $table->decimal('customer_lat', 10, 7)->default(34.6912000);
            $table->decimal('customer_lng', 10, 7)->default(45.3264000);
            $table->string('driver_name')->default('کاروان محەمەد');
            $table->string('driver_phone', 30)->default('07702001001');
            $table->string('vehicle_label')->default('ماتۆڕسوار • KLR-402');
            $table->decimal('driver_lat', 10, 7)->default(34.6798000);
            $table->decimal('driver_lng', 10, 7)->default(45.3145000);
            $table->decimal('driver_heading', 6, 2)->default(45.0);
            $table->decimal('driver_speed_kmh', 5, 1)->default(32.0);
            $table->integer('eta_seconds')->default(420);
            $table->integer('distance_remaining_meters')->default(1450);
            $table->integer('progress_permille')->default(0); // 0..1000
            $table->string('delivery_pin', 4)->default('4821');
            $table->string('handover_pin', 4)->default('1934');
            $table->integer('total_amount')->default(18500);
            $table->integer('delivery_fee')->default(1500);
            $table->integer('driver_tip')->default(500);
            $table->jsonb('items_json')->nullable();
            $table->jsonb('route_polyline')->nullable();
            $table->timestamp('driver_pinged_at')->nullable();
            $table->timestamps();

            $table->index(['status', 'updated_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('live_telemetry_sessions');

        Schema::table('orders', function (Blueprint $table) {
            $table->dropColumn([
                'driver_lat',
                'driver_lng',
                'driver_heading',
                'driver_speed_kmh',
                'eta_seconds',
                'distance_remaining_meters',
                'route_polyline',
                'last_telemetry_at',
            ]);
        });

        Schema::table('driver_profiles', function (Blueprint $table) {
            $table->dropColumn(['heading', 'speed_kmh', 'last_ping_at']);
        });
    }
};

