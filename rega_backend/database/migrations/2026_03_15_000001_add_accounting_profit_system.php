<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('products', function (Blueprint $table) {
            $table->unsignedInteger('cost_price')->default(0)->after('price');
        });

        Schema::table('order_items', function (Blueprint $table) {
            $table->unsignedInteger('unit_cost')->default(0)->after('unit_price');
            $table->unsignedInteger('line_cost')->default(0)->after('line_total');
            $table->unsignedInteger('unit_gross_profit')->default(0)->after('line_cost');
            $table->unsignedInteger('line_gross_profit')->default(0)->after('unit_gross_profit');
            $table->decimal('commission_rate', 5, 2)->default(0)->after('line_gross_profit');
            $table->unsignedInteger('admin_share')->default(0)->after('commission_rate');
            $table->unsignedInteger('seller_share')->default(0)->after('admin_share');
        });

        Schema::table('orders', function (Blueprint $table) {
            $table->unsignedInteger('total_product_cost')->default(0)->after('subtotal');
            $table->unsignedInteger('total_gross_profit')->default(0)->after('total_product_cost');
            $table->decimal('profit_commission_rate', 5, 2)->nullable()->after('commission_rate');
            $table->unsignedInteger('admin_profit_amount')->default(0)->after('commission_amount');
            $table->unsignedInteger('seller_profit_amount')->default(0)->after('admin_profit_amount');
            $table->unsignedInteger('refunded_amount')->default(0)->after('seller_profit_amount');
            $table->boolean('is_profit_realized')->default(false)->after('refunded_amount');
        });

        Schema::create('admin_profit_settings_history', function (Blueprint $table) {
            $table->id();
            $table->decimal('commission_percentage', 5, 2);
            $table->foreignId('changed_by')->nullable()->constrained('users')->nullOnDelete();
            $table->string('note')->nullable();
            $table->timestamps();
            $table->index('created_at');
        });

        Schema::create('accounting_refund_transactions', function (Blueprint $table) {
            $table->id();
            $table->foreignId('order_id')->constrained('orders')->cascadeOnDelete();
            $table->foreignId('order_item_id')->nullable()->constrained('order_items')->nullOnDelete();
            $table->unsignedInteger('quantity')->default(0);
            $table->unsignedInteger('refunded_sales')->default(0);
            $table->unsignedInteger('refunded_cost')->default(0);
            $table->unsignedInteger('refunded_gross_profit')->default(0);
            $table->unsignedInteger('refunded_admin_share')->default(0);
            $table->unsignedInteger('refunded_seller_share')->default(0);
            $table->string('reason')->nullable();
            $table->foreignId('processed_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamps();
            $table->index(['order_id', 'created_at']);
        });

        // Seed global profit commission (default 20%) if missing.
        $exists = DB::table('platform_settings')->where('key', 'admin_profit_commission_rate')->exists();
        if (! $exists) {
            DB::table('platform_settings')->insert([
                'key' => 'admin_profit_commission_rate',
                'group' => 'finance',
                'value' => json_encode(['val' => 20]),
                'description' => 'Global admin share % of product gross profit (selling - cost)',
                'created_at' => now(),
                'updated_at' => now(),
            ]);
        }

        DB::table('admin_profit_settings_history')->insert([
            'commission_percentage' => 20,
            'changed_by' => null,
            'note' => 'Initial global profit commission',
            'created_at' => now(),
            'updated_at' => now(),
        ]);
    }

    public function down(): void
    {
        Schema::dropIfExists('accounting_refund_transactions');
        Schema::dropIfExists('admin_profit_settings_history');

        Schema::table('orders', function (Blueprint $table) {
            $table->dropColumn([
                'total_product_cost',
                'total_gross_profit',
                'profit_commission_rate',
                'admin_profit_amount',
                'seller_profit_amount',
                'refunded_amount',
                'is_profit_realized',
            ]);
        });

        Schema::table('order_items', function (Blueprint $table) {
            $table->dropColumn([
                'unit_cost',
                'line_cost',
                'unit_gross_profit',
                'line_gross_profit',
                'commission_rate',
                'admin_share',
                'seller_share',
            ]);
        });

        Schema::table('products', function (Blueprint $table) {
            $table->dropColumn('cost_price');
        });
    }
};
