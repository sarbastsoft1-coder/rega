<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('neighborhoods', function (Blueprint $table) {
            $table->id();
            $table->string('code', 30)->unique();
            $table->string('name_ku');
            $table->string('name_ar')->nullable();
            $table->string('name_en')->nullable();
            $table->integer('delivery_fee')->default(1500);
            $table->decimal('center_lat', 10, 7)->nullable();
            $table->decimal('center_lng', 10, 7)->nullable();
            $table->integer('estimated_minutes')->default(25);
            $table->boolean('is_active')->default(true)->index();
            $table->integer('sort_order')->default(0);
            $table->timestamps();
        });

        Schema::create('categories', function (Blueprint $table) {
            $table->id();
            $table->string('slug')->unique();
            $table->string('name_ku');
            $table->string('name_ar')->nullable();
            $table->string('name_en')->nullable();
            $table->string('icon_name', 60)->default('restaurant');
            $table->string('image_url')->nullable();
            $table->boolean('is_active')->default(true)->index();
            $table->boolean('is_featured_home')->default(true);
            $table->integer('sort_order')->default(0);
            $table->timestamps();
        });

        Schema::create('stores', function (Blueprint $table) {
            $table->id();
            $table->foreignId('owner_id')->nullable()->constrained('users')->nullOnDelete();
            $table->foreignId('category_id')->constrained('categories')->restrictOnDelete();
            $table->foreignId('neighborhood_id')->nullable()->constrained('neighborhoods')->nullOnDelete();
            $table->string('slug')->unique();
            $table->string('name_ku');
            $table->string('name_ar')->nullable();
            $table->string('name_en')->nullable();
            $table->string('phone', 30);
            $table->string('address_ku');
            $table->string('address_ar')->nullable();
            $table->string('address_en')->nullable();
            $table->decimal('lat', 10, 7)->default(34.6836000);
            $table->decimal('lng', 10, 7)->default(45.3189000);
            $table->string('logo_url')->nullable();
            $table->string('cover_url')->nullable();
            $table->decimal('rating', 3, 2)->default(4.80);
            $table->integer('review_count')->default(0);
            $table->string('delivery_time', 60)->default('20-30 خولەک');
            $table->integer('base_delivery_fee')->default(1500);
            $table->decimal('commission_rate', 5, 2)->default(12.00);
            $table->string('discount_badge', 80)->nullable();
            $table->string('open_time', 20)->default('09:00 AM');
            $table->string('close_time', 20)->default('11:00 PM');
            $table->boolean('is_online')->default(true)->index();
            $table->boolean('is_approved')->default(true)->index();
            $table->boolean('is_featured')->default(false);
            $table->bigInteger('wallet_balance')->default(0);
            $table->timestamps();
        });

        Schema::create('store_categories', function (Blueprint $table) {
            $table->id();
            $table->foreignId('store_id')->constrained('stores')->cascadeOnDelete();
            $table->string('name_ku');
            $table->string('name_ar')->nullable();
            $table->string('name_en')->nullable();
            $table->integer('sort_order')->default(0);
            $table->timestamps();
        });

        Schema::create('products', function (Blueprint $table) {
            $table->id();
            $table->foreignId('store_id')->constrained('stores')->cascadeOnDelete();
            $table->foreignId('store_category_id')->nullable()->constrained('store_categories')->nullOnDelete();
            $table->string('name_ku');
            $table->string('name_ar')->nullable();
            $table->string('name_en')->nullable();
            $table->text('description_ku')->nullable();
            $table->text('description_ar')->nullable();
            $table->text('description_en')->nullable();
            $table->integer('price');
            $table->integer('discount_price')->nullable();
            $table->string('image_url')->nullable();
            $table->boolean('is_available')->default(true)->index();
            $table->boolean('is_featured')->default(false);
            $table->integer('sold_count')->default(0);
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('products');
        Schema::dropIfExists('store_categories');
        Schema::dropIfExists('stores');
        Schema::dropIfExists('categories');
        Schema::dropIfExists('neighborhoods');
    }
};

