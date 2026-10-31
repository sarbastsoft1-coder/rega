<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('driver_profiles', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->unique()->constrained('users')->cascadeOnDelete();
            $table->string('driver_code', 30)->unique();
            $table->boolean('is_verified')->default(false)->index();
            $table->boolean('is_online')->default(false)->index();
            $table->decimal('current_lat', 10, 7)->nullable();
            $table->decimal('current_lng', 10, 7)->nullable();
            $table->string('motor_type')->nullable();
            $table->string('plate_number', 50)->nullable();
            $table->string('model_year', 10)->nullable();
            $table->string('motor_color', 60)->nullable();
            $table->boolean('is_vehicle_verified')->default(false);
            $table->decimal('completion_rate', 5, 2)->default(100.00);
            $table->integer('total_deliveries')->default(0);
            $table->decimal('rating', 3, 2)->default(5.00);
            $table->decimal('online_hours_total', 8, 2)->default(0.00);
            $table->bigInteger('wallet_balance')->default(0);
            $table->bigInteger('cash_collected_hand')->default(0);
            $table->timestamp('online_since')->nullable();
            $table->timestamps();
        });

        Schema::create('driver_documents', function (Blueprint $table) {
            $table->id();
            $table->foreignId('driver_profile_id')->constrained('driver_profiles')->cascadeOnDelete();
            $table->string('doc_type', 40);
            $table->string('document_number', 80)->nullable();
            $table->string('file_url')->nullable();
            $table->string('status', 20)->default('pending')->index();
            $table->string('rejection_reason')->nullable();
            $table->foreignId('verified_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamp('verified_at')->nullable();
            $table->timestamps();

            $table->unique(['driver_profile_id', 'doc_type']);
        });

        Schema::create('customer_addresses', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained('users')->cascadeOnDelete();
            $table->foreignId('neighborhood_id')->nullable()->constrained('neighborhoods')->nullOnDelete();
            $table->string('label', 60)->default('ماڵەوە');
            $table->string('address_line');
            $table->string('landmark')->nullable();
            $table->decimal('lat', 10, 7)->nullable();
            $table->decimal('lng', 10, 7)->nullable();
            $table->boolean('is_default')->default(false);
            $table->timestamps();
        });

        Schema::create('favorite_stores', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained('users')->cascadeOnDelete();
            $table->foreignId('store_id')->constrained('stores')->cascadeOnDelete();
            $table->timestamps();

            $table->unique(['user_id', 'store_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('favorite_stores');
        Schema::dropIfExists('customer_addresses');
        Schema::dropIfExists('driver_documents');
        Schema::dropIfExists('driver_profiles');
    }
};

