<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('admin_profit_settings_history', function (Blueprint $table) {
            $table->foreignId('store_id')
                ->nullable()
                ->after('commission_percentage')
                ->constrained('stores')
                ->nullOnDelete();
        });
    }

    public function down(): void
    {
        Schema::table('admin_profit_settings_history', function (Blueprint $table) {
            $table->dropConstrainedForeignId('store_id');
        });
    }
};
