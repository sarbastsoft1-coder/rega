<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('driver_profiles', function (Blueprint $table) {
            if (! Schema::hasColumn('driver_profiles', 'blood_type')) {
                $table->string('blood_type', 10)->nullable()->after('motor_color');
            }
            if (! Schema::hasColumn('driver_profiles', 'home_phone')) {
                $table->string('home_phone', 30)->nullable()->after('blood_type');
            }
            if (! Schema::hasColumn('driver_profiles', 'info_card_number')) {
                $table->string('info_card_number', 80)->nullable()->after('home_phone');
            }
        });
    }

    public function down(): void
    {
        Schema::table('driver_profiles', function (Blueprint $table) {
            foreach (['blood_type', 'home_phone', 'info_card_number'] as $col) {
                if (Schema::hasColumn('driver_profiles', $col)) {
                    $table->dropColumn($col);
                }
            }
        });
    }
};
