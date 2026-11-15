<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('categories', function (Blueprint $table) {
            $table->string('secondary_image_url')->nullable()->after('image_url');
        });

        Schema::table('store_categories', function (Blueprint $table) {
            $table->string('image_url')->nullable()->after('name_en');
            $table->string('secondary_image_url')->nullable()->after('image_url');
        });
    }

    public function down(): void
    {
        Schema::table('categories', function (Blueprint $table) {
            $table->dropColumn('secondary_image_url');
        });

        Schema::table('store_categories', function (Blueprint $table) {
            $table->dropColumn(['image_url', 'secondary_image_url']);
        });
    }
};
