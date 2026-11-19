<?php

namespace App\Console\Commands;

use App\Models\User;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * Deletes marketplace demo data (fake vendors/products/customers/drivers/orders)
 * while keeping admin accounts, delivery zones, categories, and platform settings.
 */
class PurgeFakeDataCommand extends Command
{
    protected $signature = 'rega:purge-fake-data {--force : Skip confirmation}';

    protected $description = 'Delete all fake/demo marketplace users, stores, products, and orders';

    public function handle(): int
    {
        if (! $this->option('force') && ! $this->confirm('Delete ALL stores, products, orders, vendors, drivers, and customers?', true)) {
            $this->warn('Cancelled.');

            return self::FAILURE;
        }

        DB::transaction(function () {
            $this->wipeTable('accounting_refund_transactions');
            $this->wipeTable('order_status_logs');
            $this->wipeTable('order_items');
            $this->wipeTable('orders');
            $this->wipeTable('live_telemetry_sessions');
            $this->wipeTable('payouts');
            $this->wipeTable('support_tickets');
            $this->wipeTable('app_notification_reads');
            $this->wipeTable('app_notifications');
            $this->wipeTable('admin_inbox_reads');
            $this->wipeTable('banners');
            $this->wipeTable('coupons');
            $this->wipeTable('favorite_stores');
            $this->wipeTable('products');
            $this->wipeTable('store_categories');
            $this->wipeTable('stores');
            $this->wipeTable('driver_documents');
            $this->wipeTable('driver_profiles');
            $this->wipeTable('customer_addresses');

            // Non-admin users (vendors, drivers, customers)
            $kept = User::query()
                ->whereIn('role', ['super_admin', 'dispatcher', 'admin'])
                ->pluck('id');

            User::query()
                ->whereNotIn('id', $kept)
                ->delete();

            // Sanctum tokens for deleted users are cascade / leftover cleanup
            if (Schema::hasTable('personal_access_tokens')) {
                DB::table('personal_access_tokens')
                    ->where('tokenable_type', User::class)
                    ->whereNotIn('tokenable_id', $kept)
                    ->delete();
            }
        });

        $this->info('Fake marketplace data purged.');
        $this->line('Kept: admin/dispatcher users, neighborhoods, categories, platform settings.');

        return self::SUCCESS;
    }

    private function wipeTable(string $table): void
    {
        if (! Schema::hasTable($table)) {
            return;
        }
        DB::table($table)->delete();
        $this->line("  cleared {$table}");
    }
}
