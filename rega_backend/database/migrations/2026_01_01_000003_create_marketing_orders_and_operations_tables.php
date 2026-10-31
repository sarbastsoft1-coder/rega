<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('coupons', function (Blueprint $table) {
            $table->id();
            $table->string('code', 40)->unique();
            $table->foreignId('store_id')->nullable()->constrained('stores')->cascadeOnDelete();
            $table->string('title_ku');
            $table->string('title_ar')->nullable();
            $table->string('title_en')->nullable();
            $table->string('discount_type', 30)->default('fixed'); // percentage, fixed, free_delivery
            $table->integer('discount_value')->default(0);
            $table->integer('min_order_amount')->default(0);
            $table->integer('max_discount_amount')->nullable();
            $table->integer('usage_limit')->nullable();
            $table->integer('used_count')->default(0);
            $table->timestamp('starts_at')->nullable();
            $table->timestamp('expires_at')->nullable();
            $table->boolean('is_active')->default(true)->index();
            $table->timestamps();
        });

        Schema::create('banners', function (Blueprint $table) {
            $table->id();
            $table->string('title_ku');
            $table->string('title_ar')->nullable();
            $table->string('title_en')->nullable();
            $table->string('subtitle_ku')->nullable();
            $table->string('badge_text', 80)->nullable();
            $table->string('image_url');
            $table->string('target_type', 30)->default('none'); // store, category, none
            $table->foreignId('store_id')->nullable()->constrained('stores')->nullOnDelete();
            $table->foreignId('category_id')->nullable()->constrained('categories')->nullOnDelete();
            $table->boolean('is_active')->default(true)->index();
            $table->integer('sort_order')->default(0);
            $table->timestamps();
        });

        Schema::create('orders', function (Blueprint $table) {
            $table->id();
            $table->string('order_number', 40)->unique();
            $table->foreignId('customer_id')->constrained('users')->restrictOnDelete();
            $table->foreignId('store_id')->constrained('stores')->restrictOnDelete();
            $table->foreignId('driver_id')->nullable()->constrained('users')->nullOnDelete();
            $table->foreignId('neighborhood_id')->nullable()->constrained('neighborhoods')->nullOnDelete();
            $table->foreignId('coupon_id')->nullable()->constrained('coupons')->nullOnDelete();

            $table->string('status', 30)->default('pending')->index();
            $table->string('vendor_status', 30)->default('pending')->index();
            $table->string('driver_status', 30)->default('unassigned')->index();

            $table->string('handover_pin', 10);
            $table->string('delivery_pin', 10);

            $table->integer('subtotal')->default(0);
            $table->integer('discount_amount')->default(0);
            $table->integer('delivery_fee')->default(0);
            $table->integer('driver_tip')->default(0);
            $table->integer('waiting_bonus')->default(0);
            $table->integer('total_amount')->default(0);

            $table->decimal('commission_rate', 5, 2)->default(12.00);
            $table->integer('commission_amount')->default(0);
            $table->integer('vendor_net_amount')->default(0);
            $table->integer('driver_total_earning')->default(0);

            $table->string('payment_method', 30)->default('cash');
            $table->string('payment_status', 30)->default('pending');

            $table->string('customer_name');
            $table->string('customer_phone', 30);
            $table->string('delivery_address');
            $table->decimal('delivery_lat', 10, 7)->nullable();
            $table->decimal('delivery_lng', 10, 7)->nullable();
            $table->text('customer_notes')->nullable();
            $table->string('cancellation_reason')->nullable();
            $table->string('cancelled_by', 30)->nullable();

            $table->timestamp('accepted_at')->nullable();
            $table->timestamp('ready_at')->nullable();
            $table->timestamp('driver_assigned_at')->nullable();
            $table->timestamp('arrived_pickup_at')->nullable();
            $table->timestamp('picked_up_at')->nullable();
            $table->timestamp('arrived_customer_at')->nullable();
            $table->timestamp('delivered_at')->nullable()->index();
            $table->timestamp('cancelled_at')->nullable();
            $table->timestamps();
        });

        Schema::create('order_items', function (Blueprint $table) {
            $table->id();
            $table->foreignId('order_id')->constrained('orders')->cascadeOnDelete();
            $table->foreignId('product_id')->nullable()->constrained('products')->nullOnDelete();
            $table->string('product_name');
            $table->string('product_image')->nullable();
            $table->integer('unit_price');
            $table->integer('quantity');
            $table->integer('line_total');
            $table->string('special_notes')->nullable();
            $table->timestamps();
        });

        Schema::create('order_status_logs', function (Blueprint $table) {
            $table->id();
            $table->foreignId('order_id')->constrained('orders')->cascadeOnDelete();
            $table->string('from_status', 40)->nullable();
            $table->string('to_status', 40);
            $table->foreignId('actor_id')->nullable()->constrained('users')->nullOnDelete();
            $table->string('actor_role', 30)->nullable();
            $table->string('note')->nullable();
            $table->timestamps();
        });

        Schema::create('payouts', function (Blueprint $table) {
            $table->id();
            $table->string('reference_code', 50)->unique();
            $table->foreignId('user_id')->constrained('users')->restrictOnDelete();
            $table->foreignId('store_id')->nullable()->constrained('stores')->nullOnDelete();
            $table->string('recipient_type', 20)->index(); // vendor, driver
            $table->string('direction', 40)->default('payout_to_partner'); // payout_to_partner, cod_collection_from_driver
            $table->bigInteger('amount');
            $table->string('payment_method', 30)->default('cash');
            $table->string('status', 20)->default('pending')->index(); // pending, approved, completed, rejected
            $table->text('notes')->nullable();
            $table->foreignId('processed_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamp('processed_at')->nullable();
            $table->timestamps();
        });

        Schema::create('support_tickets', function (Blueprint $table) {
            $table->id();
            $table->string('ticket_number', 40)->unique();
            $table->foreignId('user_id')->constrained('users')->cascadeOnDelete();
            $table->foreignId('order_id')->nullable()->constrained('orders')->nullOnDelete();
            $table->string('category', 40)->default('general')->index();
            $table->string('priority', 20)->default('medium')->index();
            $table->string('subject');
            $table->text('description');
            $table->text('admin_reply')->nullable();
            $table->string('status', 20)->default('open')->index(); // open, in_progress, resolved, closed
            $table->foreignId('resolved_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamp('resolved_at')->nullable();
            $table->timestamps();
        });

        Schema::create('app_notifications', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->nullable()->constrained('users')->cascadeOnDelete();
            $table->string('target_audience', 30)->default('all')->index(); // all, customers, vendors, drivers, specific_user
            $table->string('title_ku');
            $table->string('title_ar')->nullable();
            $table->string('title_en')->nullable();
            $table->text('body_ku');
            $table->text('body_ar')->nullable();
            $table->text('body_en')->nullable();
            $table->string('tag', 60)->default('ئاگاداری');
            $table->string('type', 30)->default('general'); // store, category, order, general
            $table->foreignId('store_id')->nullable()->constrained('stores')->nullOnDelete();
            $table->string('category_name')->nullable();
            $table->string('discount_badge', 80)->nullable();
            $table->boolean('is_read')->default(false)->index();
            $table->timestamps();
        });

        Schema::create('platform_settings', function (Blueprint $table) {
            $table->id();
            $table->string('key', 80)->unique();
            $table->string('group', 40)->default('general')->index();
            $table->jsonb('value');
            $table->string('description')->nullable();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('platform_settings');
        Schema::dropIfExists('app_notifications');
        Schema::dropIfExists('support_tickets');
        Schema::dropIfExists('payouts');
        Schema::dropIfExists('order_status_logs');
        Schema::dropIfExists('order_items');
        Schema::dropIfExists('orders');
        Schema::dropIfExists('banners');
        Schema::dropIfExists('coupons');
    }
};

